import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import '../proveedores/proveedor_model.dart';
import '../proveedores/proveedor_service.dart';
import '../proveedores/nuevo_proveedor_sheet.dart';
import 'compra_model.dart';
import 'compra_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../auth/auth_service.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductoService _productoService = ProductoService();
  final ProveedorService _proveedorService = ProveedorService();
  final CompraService _compraService = CompraService();

  List<Producto> _productos = [];
  List<Proveedor> _proveedores = [];
  List<CompraRegistro> _historialCompras = [];

  Proveedor? _proveedorSeleccionado;

  final _comprobanteController = TextEditingController(text: 'FAC-001');
  String _tipoComprobante = 'Factura';

  final List<CompraCartItem> _canastaCompras = [];

  bool _isLoading = true;
  bool _isProcesando = false;
  String _busquedaHistorial = '';
  String _userRol = 'ADMIN';
  bool get _esAdmin => _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';

  List<Producto> get _safeProductos => _productos;
  List<Proveedor> get _safeProveedores => _proveedores;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    ProveedorService.proveedoresRevision.addListener(_onProveedoresRevisionChanged);
    _cargarDatos();
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onProductosRevisionChanged);
    ProveedorService.proveedoresRevision.removeListener(_onProveedoresRevisionChanged);
    _tabController.dispose();
    _comprobanteController.dispose();
    super.dispose();
  }

  void _onProductosRevisionChanged() {
    if (mounted) {
      _cargarDatos(forceRefresh: true);
    }
  }

  void _onProveedoresRevisionChanged() {
    if (mounted) {
      _cargarDatos(forceRefresh: true);
    }
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final rol = await AuthService().getUserRole();
    if (!mounted) return;
    _userRol = rol;
    final esAdmin = rol.toUpperCase() == 'ADMIN' || rol.toUpperCase() == 'SUPERADMIN';

    final results = await Future.wait([
      _productoService.getProductos(forceRefresh: forceRefresh),
      _proveedorService.getProveedores(forceRefresh: forceRefresh),
      esAdmin ? _compraService.getCompras() : Future.value(<CompraRegistro>[]),
    ]);

    if (mounted) {
      setState(() {
        _productos = List<Producto>.from(results[0] as List<Producto>);
        _proveedores = List<Proveedor>.from(results[1] as List<Proveedor>);
        _historialCompras = List<CompraRegistro>.from(results[2] as List<CompraRegistro>);
        if (_safeProveedores.isNotEmpty && _proveedorSeleccionado == null) {
          _proveedorSeleccionado = _safeProveedores.first;
        }
        _isLoading = false;
      });
    }
  }

  double get _totalCompra {
    return _canastaCompras.fold(0.0, (acc, item) => acc + item.subtotal);
  }

  num get _totalUnidadesCompra {
    return _canastaCompras.fold(0.0, (acc, item) => acc + item.cantidad);
  }

  String get _totalUnidadesCompraFormatted {
    final t = _totalUnidadesCompra;
    return t % 1 == 0 ? t.toInt().toString() : t.toStringAsFixed(2);
  }

  void _eliminarItemDeCanasta(int index) {
    setState(() {
      _canastaCompras.removeAt(index);
    });
  }

  Future<void> _escanearCodigoParaCompra() async {
    final scannedCode = await KarlizBarcodeScannerModal.scan(
      context,
      title: 'Recepción de Mercadería',
      subtitle: 'Enfoque el código del producto a ingresar',
    );

    if (scannedCode == null || scannedCode.trim().isEmpty) return;

    final codeClean = scannedCode.trim();
    int matchIdx = _safeProductos.indexWhere((p) => _coincideCodigo(p, codeClean));

    if (matchIdx == -1) {
      // Intentar refrescar catálogo en vivo desde el servidor para detectar productos recién creados
      final prodsFrescos = await _productoService.getProductos(forceRefresh: true);
      if (mounted) {
        setState(() {
          _productos = prodsFrescos;
        });
      }
      matchIdx = prodsFrescos.indexWhere((p) => _coincideCodigo(p, codeClean));
    }

    if (matchIdx != -1) {
      final prod = _safeProductos[matchIdx];
      _mostrarDialogoDetalleIngreso(prod);
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Código "$scannedCode" no encontrado en catálogo de productos'),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _coincideCodigo(Producto p, String rawCode) {
    if (rawCode.trim().isEmpty) return false;
    final codeClean = rawCode.trim().toLowerCase();
    final codeDigits = codeClean.replaceAll(RegExp(r'\D'), '');

    final bc = (p.codigoBarras ?? '').trim().toLowerCase();
    final cod = p.codigo.trim().toLowerCase();

    if (bc.isNotEmpty && bc == codeClean) return true;
    if (cod.isNotEmpty && cod == codeClean) return true;

    // Comparación numérica sin caracteres de puntuación/espacios
    if (codeDigits.isNotEmpty) {
      final bcDigits = bc.replaceAll(RegExp(r'\D'), '');
      if (bcDigits.isNotEmpty) {
        if (bcDigits == codeDigits) return true;
        // Variaciones UPC-A / EAN-13 (con/sin ceros a la izquierda)
        if (codeDigits.length == 13 && codeDigits.startsWith('0') && codeDigits.substring(1) == bcDigits) return true;
        if (bcDigits.length == 13 && bcDigits.startsWith('0') && bcDigits.substring(1) == codeDigits) return true;
        if (codeDigits.length == 14 && codeDigits.startsWith('00') && codeDigits.substring(2) == bcDigits) return true;
        if (bcDigits.length == 14 && bcDigits.startsWith('00') && bcDigits.substring(2) == codeDigits) return true;
      }
    }

    return false;
  }

  void _abrirSelectorProveedor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String filtro = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final proveedoresFiltrados = _safeProveedores.where((p) {
              return p.razonSocial.toLowerCase().contains(filtro.toLowerCase()) ||
                  p.ruc.contains(filtro);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distribuidores / Proveedores',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.brandPrimary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(LucideIcons.plusCircle, size: 16),
                        label: Text(
                          'Nuevo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final nuevo = await NuevoProveedorSheet.show(context);
                          if (nuevo != null && mounted) {
                            setState(() => _proveedorSeleccionado = nuevo);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextField(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por Razón Social o RUC...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setModalState(() => filtro = val),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: proveedoresFiltrados.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron proveedores',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: proveedoresFiltrados.length,
                            separatorBuilder: (_, index) => Divider(
                              height: 1,
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                            itemBuilder: (context, index) {
                              final p = proveedoresFiltrados[index];
                              final isSelected = p.idProveedor == _proveedorSeleccionado?.idProveedor;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.brandPrimary
                                        : (isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    LucideIcons.building2,
                                    color: isSelected ? Colors.white : AppTheme.brandPrimary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  p.razonSocial,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  'RUC: ${p.ruc}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                                ),
                                trailing: isSelected
                                    ? const Icon(LucideIcons.check, color: AppTheme.brandPrimary, size: 20)
                                    : null,
                                onTap: () {
                                  setState(() => _proveedorSeleccionado = p);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirModalAgregarProductos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      builder: (ctx) {
        String filtro = searchCtrl.text;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final f = filtro.toLowerCase();
            final prodsFiltrados = _safeProductos.where((p) {
              return p.nombre.toLowerCase().contains(f) ||
                  p.codigo.toLowerCase().contains(f) ||
                  (p.codigoBarras ?? '').toLowerCase().contains(f);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catálogo de Abastecimiento',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Toca cualquier producto para añadirlo a la compra',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_canastaCompras.length} en orden',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, código o barra...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(LucideIcons.scanLine, size: 18, color: Color(0xFF0D9488)),
                          tooltip: 'Escanear código de barras',
                          onPressed: () async {
                            final code = await KarlizBarcodeScannerModal.scan(context);
                            if (code != null && code.isNotEmpty) {
                              searchCtrl.text = code;
                              setModalState(() => filtro = code);
                            }
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setModalState(() => filtro = val),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: prodsFiltrados.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron productos',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: prodsFiltrados.length,
                            separatorBuilder: (_, index) => Divider(
                              height: 1,
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                            itemBuilder: (context, index) {
                              final p = prodsFiltrados[index];
                              final idxCanasta = _canastaCompras.indexWhere((c) => c.idProducto == p.idProducto);
                              final bool yaEnOrden = idxCanasta != -1;
                              final itemEnOrden = yaEnOrden ? _canastaCompras[idxCanasta] : null;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: yaEnOrden
                                        ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                        : (isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    yaEnOrden ? LucideIcons.check : LucideIcons.package,
                                    color: yaEnOrden ? AppTheme.accentGreen : AppTheme.brandPrimary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  p.nombre,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: yaEnOrden ? FontWeight.w800 : FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  yaEnOrden
                                      ? 'En orden: ${itemEnOrden!.cantidad.toStringAsFixed(0)} u. (Costo: S/ ${itemEnOrden.precioUnitario.toStringAsFixed(2)})'
                                      : 'Stock actual: ${p.stockActual.toStringAsFixed(0)} u. • P. Venta: S/ ${p.precioVenta.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: yaEnOrden ? AppTheme.accentGreen : AppTheme.textMuted,
                                    fontWeight: yaEnOrden ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: yaEnOrden ? AppTheme.accentGreen : AppTheme.brandPrimary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        yaEnOrden ? LucideIcons.pencil : LucideIcons.plus,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        yaEnOrden ? 'Editar' : 'Añadir',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _mostrarDialogoDetalleIngreso(p, setModalState),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'VER ORDEN (${_canastaCompras.length} ITEMS - S/ ${_totalCompra.toStringAsFixed(2)})',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => searchCtrl.dispose());
  }

  void _mostrarDialogoDetalleIngreso(Producto p, [StateSetter? setModalState]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idxExistente = _canastaCompras.indexWhere((c) => c.idProducto == p.idProducto);
    final existente = idxExistente != -1 ? _canastaCompras[idxExistente] : null;

    final cantCtrl = TextEditingController(
      text: existente != null ? existente.cantidad.toStringAsFixed(0) : '12',
    );
    final costoCtrl = TextEditingController(
      text: existente != null
          ? existente.precioUnitario.toStringAsFixed(2)
          : (p.precioVenta * 0.7).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final cant = double.tryParse(cantCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
          final costo = double.tryParse(costoCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
          final subtotal = cant * costo;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.packagePlus, color: AppTheme.brandPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'P. Venta público: S/ ${p.precioVenta.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          suffixText: 'u.',
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          labelText: 'Costo Unit.',
                          prefixText: 'S/ ',
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal a pagar:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'S/ ${subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text('Cancelar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  final c = double.tryParse(cantCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
                  final cost = double.tryParse(costoCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;

                  if (c <= 0 || cost < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa valores válidos'), backgroundColor: AppTheme.alertRed),
                    );
                    return;
                  }

                  setState(() {
                    final idx = _canastaCompras.indexWhere((item) => item.idProducto == p.idProducto);
                    if (idx != -1) {
                      _canastaCompras[idx].cantidad = c;
                      _canastaCompras[idx].precioUnitario = cost;
                    } else {
                      _canastaCompras.add(
                        CompraCartItem(
                          idProducto: p.idProducto!,
                          nombreProducto: p.nombre,
                          codigo: p.codigo,
                          cantidad: c,
                          precioUnitario: cost,
                        ),
                      );
                    }
                  });

                  setModalState?.call(() {});
                  Navigator.pop(dlgCtx);

                  final cantFormatted = c % 1 == 0 ? c.toInt().toString() : c.toStringAsFixed(2);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Agregado: ${p.nombre} ($cantFormatted u.)'),
                      backgroundColor: AppTheme.accentGreen,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(
                  yaEnExistencia(p) ? 'Actualizar' : 'Añadir al Lote',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      cantCtrl.dispose();
      costoCtrl.dispose();
    });
  }

  bool yaEnExistencia(Producto p) {
    return _canastaCompras.any((c) => c.idProducto == p.idProducto);
  }

  Future<void> _procesarCompra() async {
    if (_isProcesando) return;

    if (_proveedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un proveedor'), backgroundColor: AppTheme.alertRed),
      );
      return;
    }

    if (_canastaCompras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto a la orden de compra'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    setState(() => _isProcesando = true);

    int? idProv = _proveedorSeleccionado?.idProveedor;
    if (idProv == null) {
      // Fallback: buscar en la lista de proveedores cargada por RUC
      try {
        final coincidencia = _proveedores.firstWhere(
          (p) => p.ruc == _proveedorSeleccionado?.ruc,
        );
        idProv = coincidencia.idProveedor;
      } catch (_) {}
    }

    if (idProv == null) {
      setState(() => _isProcesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se pudo determinar el ID del proveedor. Vuelve a seleccionarlo de la lista.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    final numeroDoc = _comprobanteController.text.trim().isEmpty ? 'S/C' : _comprobanteController.text.trim();
    final comprobanteCompleto = '$_tipoComprobante $numeroDoc'.trim();
    final comprobanteFinal = comprobanteCompleto.length > 50 ? comprobanteCompleto.substring(0, 50) : comprobanteCompleto;

    final compra = CompraEnvio(
      idProveedor: idProv,
      comprobante: comprobanteFinal,
      detalles: _canastaCompras.map((item) {
        return CompraDetalleEnvio(
          idProducto: item.idProducto,
          cantidad: item.cantidad,
          precioUnitario: item.precioUnitario,
        );
      }).toList(),
    );

    final errorMsg = await _compraService.registrarCompra(compra);

    if (mounted) {
      setState(() => _isProcesando = false);
      if (errorMsg == null) {
        final totalInvertido = _totalCompra;
        final totalProds = _canastaCompras.length;

        setState(() {
          _canastaCompras.clear();
        });

        _cargarDatos();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.checkCheck, color: AppTheme.accentGreen, size: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  '¡Mercadería Ingresada con Éxito!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se han actualizado los stocks de $totalProds productos por un valor de S/ ${totalInvertido.toStringAsFixed(2)}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CONTINUAR', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_esAdmin) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        body: _buildCajeroRestringido(isDark),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: isDark ? AppTheme.cardDark : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.brandPrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.brandPrimary,
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(LucideIcons.truck, size: 17), text: 'Nueva Compra en Lote'),
              Tab(icon: Icon(LucideIcons.clipboardList, size: 17), text: 'Historial de Compras'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormularioCompra(isDark),
          _buildHistorialCompras(isDark),
        ],
      ),
    );
  }

  Widget _buildCajeroRestringido(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.shieldAlert, size: 36, color: AppTheme.brandPrimary),
              ),
              const SizedBox(height: 20),
              Text(
                'Módulo Reservado para Administrador',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'El registro de compras a proveedores, costos mayoristas de adquisición y márgenes comerciales está restringido a administradores.\n\nComo operador de caja, tus funciones autorizadas se concentran en la atención al cliente, cobros en caja y ventas en el POS.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormularioCompra(bool isDark) {
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final labelColor = isDark ? Colors.white : AppTheme.textDark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Guía Didáctica de Abastecimiento
              const DidacticBanner(
                title: 'Abastecimiento de Almacén',
                description: 'Registra facturas o boletas con múltiples productos a la vez. El stock de tu inventario y el Kardex se incrementarán al confirmar.',
                icon: LucideIcons.packagePlus,
              ),
              const SizedBox(height: 14),

              // 1. Selector de Proveedor
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Proveedor / Distribuidor',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: labelColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _abrirSelectorProveedor,
                          icon: const Icon(LucideIcons.search, size: 15),
                          label: Text(
                            'Cambiar',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_proveedorSeleccionado != null)
                      InkWell(
                        onTap: _abrirSelectorProveedor,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(LucideIcons.building2, color: AppTheme.brandPrimary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _proveedorSeleccionado!.razonSocial,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      'RUC: ${_proveedorSeleccionado!.ruc}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8), size: 18),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Comprobante de Compra
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comprobante de Ingreso',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: labelColor),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _tipoComprobante,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                              items: ['Factura', 'Boleta', 'Guía', 'Nota'].map((e) {
                                return DropdownMenuItem(value: e, child: Text(e));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _tipoComprobante = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _comprobanteController,
                            maxLength: 35,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              labelText: 'N° de Comprobante / Factura',
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Lote de Productos a Ingresar
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lote de Productos a Ingresar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: labelColor,
                          ),
                        ),
                        if (_canastaCompras.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${_canastaCompras.length} prods. • $_totalUnidadesCompraFormatted u.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Botones de acción: Catálogo y Escáner de Mercadería
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.brandPrimary,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              icon: const Icon(LucideIcons.packagePlus, size: 18),
                              label: Text(
                                _canastaCompras.isEmpty ? 'Catálogo' : 'Agregar (${_canastaCompras.length})',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              onPressed: _abrirModalAgregarProductos,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              icon: const Icon(LucideIcons.scanLine, size: 18),
                              label: Text(
                                'Escanear',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              onPressed: _escanearCodigoParaCompra,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Lista de Productos en la Canasta
                    if (_canastaCompras.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(LucideIcons.shoppingBag, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                              const SizedBox(height: 8),
                              Text(
                                'Aún no has agregado productos a esta compra.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pulsa el botón naranja para seleccionar múltiples productos, fijar sus costos y cantidades.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _canastaCompras.length,
                        separatorBuilder: (_, index) => Divider(
                          height: 16,
                          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        ),
                        itemBuilder: (context, idx) {
                          final item = _canastaCompras[idx];
                          return Row(
                            children: [
                              // Ícono y Nombre
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nombreProducto,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: labelColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Costo unit.: S/ ${item.precioUnitario.toStringAsFixed(2)} • Subtotal: S/ ${item.subtotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Controles de Cantidad [-] [ 12 ] [+]
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(LucideIcons.minusCircle, size: 20, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      setState(() {
                                        if (item.cantidad > 1) {
                                          item.cantidad -= 1;
                                        } else {
                                          _canastaCompras.removeAt(idx);
                                        }
                                      });
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF101622) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${item.cantidad.toStringAsFixed(0)} u.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(LucideIcons.plusCircle, size: 20, color: AppTheme.brandPrimary),
                                    onPressed: () {
                                      setState(() {
                                        item.cantidad += 1;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              // Botón Eliminar
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: const Icon(LucideIcons.trash2, size: 17, color: Color(0xFFEF4444)),
                                onPressed: () => _eliminarItemDeCanasta(idx),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Total y Botón de Registro
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderTint,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL DE LA COMPRA',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${_canastaCompras.length} prods. • $_totalUnidadesCompraFormatted unid.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: _totalCompra),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return Text(
                              'S/ ${val.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.brandPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: (_isProcesando || _canastaCompras.isEmpty) ? null : _procesarCompra,
                        icon: _isProcesando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.arrowDownToDot, size: 18),
                        label: Text(
                          _isProcesando
                              ? 'INGRESANDO...'
                              : 'REGISTRAR COMPRA (${_canastaCompras.length} PRODUCTOS)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialCompras(bool isDark) {
    final filtradas = _historialCompras.where((c) {
      final prov = c.razonSocialProveedor.toLowerCase();
      final comp = c.comprobante.toLowerCase();
      final q = _busquedaHistorial.toLowerCase();
      return prov.contains(q) || comp.contains(q) || c.idCompra.toString().contains(q);
    }).toList();

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por proveedor o comprobante...',
                hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _busquedaHistorial = val),
            ),
          ),
        ),

        // Lista de Compras
        Expanded(
          child: filtradas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.truck, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No hay compras registradas',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white70 : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtradas.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final c = filtradas[idx];
                    final fechaStr = c.fechaCompra != null
                        ? '${c.fechaCompra!.day.toString().padLeft(2, '0')}/${c.fechaCompra!.month.toString().padLeft(2, '0')} ${c.fechaCompra!.hour.toString().padLeft(2, '0')}:${c.fechaCompra!.minute.toString().padLeft(2, '0')}'
                        : 'Reciente';

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(LucideIcons.truck, color: AppTheme.brandPrimary, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.razonSocialProveedor,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : AppTheme.textDark,
                                            ),
                                          ),
                                          Text(
                                            'Doc: ${c.comprobante} • $fechaStr',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'S/ ${c.total.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (c.detalles.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: c.detalles.map((d) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '+${d.cantidad.toStringAsFixed(0)}x ${d.nombreProducto}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white70 : AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'S/ ${d.subtotal.toStringAsFixed(2)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
