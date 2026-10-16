import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'venta_model.dart';
import 'venta_service.dart';
import 'caja_ventas_screen.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/karliz_sound_service.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/category_helper.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final ProductoService _productoService = ProductoService();
  final VentaService _ventaService = VentaService();

  List<Producto> _productosDisponibles = [];
  final List<CartItem> _carrito = [];

  String _metodoPago = 'Efectivo';
  final _clienteNombreController = TextEditingController(text: 'Público General');
  final _clienteDocController = TextEditingController(text: '00000000');
  final _pagoConController = TextEditingController();
  final _tabletSearchCtrl = TextEditingController();
  String _tabletSearchQuery = '';
  String? _tabletSelectedCategoria = '⭐ Frecuentes';

  final FocusNode _screenFocusNode = FocusNode();
  final FocusNode _tabletSearchFocusNode = FocusNode();
  final StringBuffer _hwScanBuffer = StringBuffer();
  DateTime _lastHwKeyTime = DateTime.now();

  bool _isLoading = true;
  bool _isProcesando = false;

  List<Producto> get _safeDisponibles => _productosDisponibles;

  String _formatStock(double stock) {
    return stock % 1 == 0 ? stock.toInt().toString() : stock.toStringAsFixed(2);
  }

  List<String> get _tabletCategorias {
    final list = <String>['⭐ Frecuentes', 'Todos'];
    final uniqueCats = <String>{};
    for (final p in _safeDisponibles) {
      final cat = p.nombreCategoria?.trim();
      if (cat != null && cat.isNotEmpty) {
        uniqueCats.add(cat);
      }
    }
    list.addAll(uniqueCats);
    return list;
  }

  List<Producto> get _filteredTabletProductos {
    if (_tabletSelectedCategoria == '⭐ Frecuentes') {
      final copy = List<Producto>.from(_safeDisponibles);
      copy.sort((a, b) => b.stockActual.compareTo(a.stockActual));
      final frecuentes = copy.take(16).toList();
      if (_tabletSearchQuery.isNotEmpty) {
        final q = _tabletSearchQuery.toLowerCase().trim();
        return frecuentes.where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            _coincideCodigo(p, q) ||
            (p.codigoBarras ?? '').toLowerCase().contains(q) ||
            (p.marca ?? '').toLowerCase().contains(q)
        ).toList();
      }
      return frecuentes;
    }

    return _safeDisponibles.where((p) {
      if (_tabletSelectedCategoria != null && _tabletSelectedCategoria != 'Todos') {
        final cat = p.nombreCategoria?.trim() ?? 'General';
        if (cat != _tabletSelectedCategoria) return false;
      }
      if (_tabletSearchQuery.isNotEmpty) {
        final q = _tabletSearchQuery.toLowerCase().trim();
        final matches = p.nombre.toLowerCase().contains(q) ||
            _coincideCodigo(p, q) ||
            (p.codigoBarras ?? '').toLowerCase().contains(q) ||
            (p.marca ?? '').toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  int _getCountForCategoria(String cat) {
    if (cat == '⭐ Frecuentes') return _safeDisponibles.take(16).length;
    if (cat == 'Todos') return _safeDisponibles.length;
    return _safeDisponibles.where((p) => (p.nombreCategoria?.trim() ?? 'General') == cat).length;
  }

  IconData _getCategoryIcon(String? categoryName) => CategoryHelper.getIcon(categoryName);

  Color _getCategoryColor(String? categoryName, bool isDark) => CategoryHelper.getColor(categoryName, isDark);

  void _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Si el usuario está escribiendo en campos de texto editables (nombre/DNI/pago), no interceptar
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      final widget = primaryFocus.context!.widget;
      if (widget is EditableText && primaryFocus != _tabletSearchFocusNode) {
        return;
      }
    }

    final now = DateTime.now();
    if (now.difference(_lastHwKeyTime).inMilliseconds > 120) {
      _hwScanBuffer.clear();
    }
    _lastHwKeyTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _hwScanBuffer.toString().trim();
      _hwScanBuffer.clear();
      if (code.isNotEmpty) {
        if (_tabletSearchCtrl.text.trim() == code) {
          _tabletSearchCtrl.clear();
          setState(() => _tabletSearchQuery = '');
        }
        _procesarCodigoEscaneado(code);
      }
    } else if (event.character != null && event.character!.isNotEmpty) {
      _hwScanBuffer.write(event.character);
    }
  }

  @override
  void initState() {
    super.initState();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    _cargarProductos();
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onProductosRevisionChanged);
    _clienteNombreController.dispose();
    _clienteDocController.dispose();
    _pagoConController.dispose();
    _tabletSearchCtrl.dispose();
    _tabletSearchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _onProductosRevisionChanged() {
    if (mounted) {
      _cargarProductos(forceRefresh: true);
    }
  }

  Future<void> _cargarProductos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final productos = await _productoService.getProductos(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _productosDisponibles = List<Producto>.from(productos.where((p) => p.stockActual > 0));
        _isLoading = false;
      });
    }
  }

  double get _totalVenta {
    return _carrito.fold(0.0, (acc, item) => acc + item.subtotal);
  }

  int get _totalUnidades {
    return _carrito.fold(0, (acc, item) => acc + item.cantidad.toInt());
  }

  double get _montoRecibido {
    final val = double.tryParse(_pagoConController.text.replaceAll(',', '.').trim());
    return val ?? 0.0;
  }

  double get _vuelto {
    if (_metodoPago != 'Efectivo') return 0.0;
    final recibido = _montoRecibido;
    if (recibido <= 0) return 0.0;
    return recibido - _totalVenta;
  }

  void _agregarAlCarrito(Producto p, {bool playSound = true}) {
    final idx = _carrito.indexWhere((item) => item.producto.idProducto == p.idProducto);
    if (idx != -1 && _carrito[idx].cantidad >= p.stockActual) {
      KarlizSoundService.instance.playErrorBeep();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock máximo alcanzado para ${p.nombre} (${_formatStock(p.stockActual)} u.)'),
          backgroundColor: AppTheme.alertRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (playSound) {
      KarlizSoundService.instance.playBarcodeBeep();
    }

    setState(() {
      if (idx != -1) {
        _carrito[idx].cantidad += 1;
      } else {
        _carrito.add(CartItem(producto: p, cantidad: 1.0));
      }

      // Si el pago era exacto, actualizar el campo si está en efectivo
      if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
        _pagoConController.text = _totalVenta.toStringAsFixed(2);
      }
    });
  }

  void _incrementarCantidad(int index) {
    final item = _carrito[index];
    if (item.cantidad < item.producto.stockActual) {
      setState(() {
        item.cantidad += 1;
        if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
          _pagoConController.text = _totalVenta.toStringAsFixed(2);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay más stock disponible para ${item.producto.nombre}'),
          backgroundColor: AppTheme.alertRed,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _decrementarCantidad(int index) {
    setState(() {
      if (_carrito[index].cantidad > 1) {
        _carrito[index].cantidad -= 1;
      } else {
        _carrito.removeAt(index);
      }
      if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
        _pagoConController.text = _totalVenta.toStringAsFixed(2);
      }
    });
  }

  void _eliminarDelCarrito(int index) {
    setState(() {
      _carrito.removeAt(index);
      if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
        _pagoConController.text = _totalVenta.toStringAsFixed(2);
      }
    });
  }

  void _vaciarCarrito() {
    setState(() {
      _carrito.clear();
      _pagoConController.clear();
    });
  }

  Future<void> _escanearCodigoParaVenta() async {
    final scannedCode = await KarlizBarcodeScannerModal.scan(
      context,
      title: 'Lector de Cobro POS',
      subtitle: 'Enfoque el código del producto para agregarlo',
    );
    if (scannedCode != null && scannedCode.trim().isNotEmpty) {
      await _procesarCodigoEscaneado(scannedCode);
    }
  }

  Future<void> _procesarCodigoEscaneado(String rawCode) async {
    final codeClean = rawCode.trim();
    if (codeClean.isEmpty) return;

    // 1. Buscar entre los productos en memoria del POS
    Producto? productoEncontrado;
    for (final p in _safeDisponibles) {
      if (_coincideCodigo(p, codeClean)) {
        productoEncontrado = p;
        break;
      }
    }

    // 2. Si no estaba en _safeDisponibles, consultar al servidor con forceRefresh
    if (productoEncontrado == null) {
      final productosFrescos = await _productoService.getProductos(forceRefresh: true);
      if (mounted) {
        setState(() {
          _productosDisponibles = List<Producto>.from(productosFrescos.where((p) => p.stockActual > 0));
        });
      }

      for (final p in productosFrescos) {
        if (_coincideCodigo(p, codeClean)) {
          productoEncontrado = p;
          break;
        }
      }
    }

    // 3. Evaluar el producto si fue encontrado
    if (productoEncontrado != null) {
      // Verificar si realmente tiene stock
      if (productoEncontrado.stockActual <= 0) {
        KarlizSoundService.instance.playErrorBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ "${productoEncontrado.nombre}" existe en el catálogo pero no tiene stock disponible (0 u.)',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.alertRed,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }

      // Verificar si ya se alcanzó el stock máximo en la canasta actual
      final currentInCart = _carrito.firstWhere(
        (item) => item.producto.idProducto == productoEncontrado!.idProducto,
        orElse: () => CartItem(producto: productoEncontrado!, cantidad: 0),
      );

      if (currentInCart.cantidad >= productoEncontrado.stockActual) {
        KarlizSoundService.instance.playErrorBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Stock máximo alcanzado para "${productoEncontrado.nombre}" (${_formatStock(productoEncontrado.stockActual)} u. disponibles)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.alertRed,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }

      // Añadir directamente a la canasta con audio de éxito
      _agregarAlCarrito(productoEncontrado, playSound: true);

      if (mounted) {
        final restante = (productoEncontrado.stockActual - currentInCart.cantidad - 1).clamp(0, 999999);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✓ Agregado: ${productoEncontrado.nombre} (S/ ${productoEncontrado.precioVenta.toStringAsFixed(2)}) • Quedan ${restante.toStringAsFixed(0)} u.',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
      return;
    }

    // 4. Si definitivamente no existe ningún producto registrado con ese código
    KarlizSoundService.instance.playErrorBeep();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.xCircle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ Código "$codeClean" no encontrado en el inventario',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE11D48),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _editarCantidadDirecta(int index) {
    final item = _carrito[index];
    final initialQty = item.cantidad % 1 == 0 ? item.cantidad.toInt().toString() : item.cantidad.toStringAsFixed(2);
    final ctrl = TextEditingController(text: initialQty);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stockFormatted = item.producto.stockActual % 1 == 0
        ? item.producto.stockActual.toInt().toString()
        : item.producto.stockActual.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(LucideIcons.hash, color: AppTheme.brandPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modificar Cantidad',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.producto.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock disponible: $stockFormatted unidades',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.brandPrimary),
              decoration: InputDecoration(
                labelText: 'Cantidad a vender',
                suffixText: 'unidades',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.producto.stockActual >= 6)
                  ActionChip(
                    label: const Text('+6 (Six-pack)'),
                    onPressed: () => ctrl.text = '6',
                  ),
                if (item.producto.stockActual >= 12)
                  ActionChip(
                    label: const Text('+12 (Docena)'),
                    onPressed: () => ctrl.text = '12',
                  ),
                if (item.producto.stockActual >= 24)
                  ActionChip(
                    label: const Text('+24 (Caja)'),
                    onPressed: () => ctrl.text = '24',
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? item.cantidad;
              if (parsed <= 0) {
                _eliminarDelCarrito(index);
                Navigator.pop(dlgCtx);
                return;
              }
              if (parsed > item.producto.stockActual) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stock insuficiente: solo hay $stockFormatted disponibles.'),
                    backgroundColor: AppTheme.alertRed,
                  ),
                );
                return;
              }
              setState(() {
                item.cantidad = parsed;
                if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
                  _pagoConController.text = _totalVenta.toStringAsFixed(2);
                }
              });
              Navigator.pop(dlgCtx);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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

  void _abrirSelectorProductos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = _safeDisponibles.where((p) {
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              return p.nombre.toLowerCase().contains(q) ||
                  _coincideCodigo(p, q) ||
                  (p.codigoBarras ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
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
                            'Catálogo de Productos',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Toca cualquier producto para añadirlo a la canasta',
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
                          '${_carrito.length} en carrito',
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
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: false,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
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
                              setModalState(() => query = code);
                            }
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => query = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtrados.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron productos disponibles',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (_, index) => Divider(
                              height: 1,
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                            itemBuilder: (context, idx) {
                              final p = filtrados[idx];
                              final inCart = _carrito.firstWhere(
                                (c) => c.producto.idProducto == p.idProducto,
                                orElse: () => CartItem(producto: p, cantidad: 0),
                              );
                              final bool yaEnCarrito = inCart.cantidad > 0;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: yaEnCarrito
                                        ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                                        : (isDark ? AppTheme.surfaceTintDark : AppTheme.surfaceTint),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    yaEnCarrito ? LucideIcons.check : LucideIcons.package2,
                                    color: AppTheme.brandPrimary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  p.nombre,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  'Disp: ${_formatStock(p.stockActual)} u.  •  Cód: ${p.codigo}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'S/ ${p.precioVenta.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppTheme.brandPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.brandPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.all(8),
                                        minimumSize: const Size(36, 36),
                                      ),
                                      icon: const Icon(LucideIcons.plus, size: 16),
                                      onPressed: () {
                                        _agregarAlCarrito(p);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _agregarAlCarrito(p);
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'LISTO • VOLVER A LA CANASTA (${_carrito.length} ITEMS)',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
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

  Future<void> _procesarVenta() async {
    if (_isProcesando) return;

    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La canasta está vacía. Añade productos para cobrar.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (_metodoPago == 'Efectivo') {
      if (_montoRecibido > 0 && _montoRecibido < _totalVenta) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El monto recibido (S/ ${_montoRecibido.toStringAsFixed(2)}) es menor al total a cobrar (S/ ${_totalVenta.toStringAsFixed(2)})'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }
    }

    // Validar que todos los productos del carrito tengan un ID de base de datos válido
    for (final item in _carrito) {
      if (item.producto.idProducto == null || item.producto.idProducto! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ El producto "${item.producto.nombre}" no tiene un ID válido. Actualiza la lista.'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }
    }

    setState(() => _isProcesando = true);

    final venta = VentaEnvio(
      clienteDocumento: _clienteDocController.text.trim().isEmpty ? '00000000' : _clienteDocController.text.trim(),
      clienteNombre: _clienteNombreController.text.trim().isEmpty ? 'Público General' : _clienteNombreController.text.trim(),
      metodoPago: _metodoPago,
      detalles: _carrito.map((item) {
        return VentaDetalleEnvio(
          idProducto: item.producto.idProducto!,
          cantidad: item.cantidad,
        );
      }).toList(),
    );

    final errorMsg = await _ventaService.registrarVenta(venta);

    if (mounted) {
      setState(() => _isProcesando = false);
      if (errorMsg == null) {
        final totalCobrado = _totalVenta;
        final cambio = _vuelto;
        final pagadoCon = _montoRecibido > 0 ? _montoRecibido : totalCobrado;
        final itemsVendidos = List<CartItem>.from(_carrito);

        _vaciarCarrito();
        _cargarProductos();

        _mostrarConfirmacionCobro(
          items: itemsVendidos,
          total: totalCobrado,
          metodo: _metodoPago,
          pagadoCon: pagadoCon,
          vuelto: cambio,
        );
      } else {
        KarlizSoundService.instance.playErrorBeep();
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

  void _mostrarConfirmacionCobro({
    required List<CartItem> items,
    required double total,
    required String metodo,
    required double pagadoCon,
    required double vuelto,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCheck, color: AppTheme.accentGreen, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Cobro Realizado con Éxito!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Método: $metodo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Resumen de productos en el diálogo
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return Row(
                    children: [
                      Text(
                        '${it.cantidad.toStringAsFixed(0)}x ',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          it.producto.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      Text(
                        'S/ ${it.subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : AppTheme.textDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Desglose Financiero
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cobrado:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        'S/ ${total.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (metodo == 'Efectivo' && vuelto > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vuelto Entregado:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        Text(
                          'S/ ${vuelto.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandPrimary,
                  side: const BorderSide(color: AppTheme.brandPrimary, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(LucideIcons.printer, size: 18),
                label: Text(
                  'TICKET TÉRMICO (58 / 80 MM)',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                onPressed: () {
                  _mostrarTicketTermicoDialog(
                    items: items,
                    total: total,
                    metodo: metodo,
                    pagadoCon: pagadoCon,
                    vuelto: vuelto,
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
                  'NUEVA VENTA',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarTicketTermicoDialog({
    required List<CartItem> items,
    required double total,
    required String metodo,
    required double pagadoCon,
    required double vuelto,
  }) {
    final ticketItems = items.map((it) {
      return TicketItem(
        nombre: it.producto.nombre,
        cantidad: it.cantidad,
        precioUnitario: it.producto.precioVenta,
        subtotal: it.subtotal,
      );
    }).toList();

    int selectedWidth = ThermalTicketService.width58mm;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final receiptText = ThermalTicketService.generateReceiptText(
            ticketId: null,
            clienteNombre: _clienteNombreController.text.trim().isEmpty ? 'Público General' : _clienteNombreController.text.trim(),
            clienteDocumento: _clienteDocController.text.trim().isEmpty ? null : _clienteDocController.text.trim(),
            metodoPago: metodo,
            items: ticketItems,
            total: total,
            pagadoCon: pagadoCon,
            vuelto: vuelto,
            width: selectedWidth,
          );

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(LucideIcons.printer, color: AppTheme.brandPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ticket Térmico POS',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: ThermalTicketService.width58mm, label: Text('58mm')),
                    ButtonSegment(value: ThermalTicketService.width80mm, label: Text('80mm')),
                  ],
                  selected: {selectedWidth},
                  onSelectionChanged: (val) {
                    setDlgState(() => selectedWidth = val.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: selectedWidth == ThermalTicketService.width58mm ? 320 : 420,
              height: 340,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    receiptText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.25,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Copiar Texto'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receiptText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Texto del ticket copiado al portapapeles!'),
                      backgroundColor: AppTheme.accentGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final labelColor = isDark ? Colors.white : AppTheme.textDark;

    return KeyboardListener(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleHardwareKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= ResponsiveLayout.mobileBreakpoint) {
            return _buildTabletLayout(isDark, cardBg, borderColor, labelColor);
          }
          return _buildMobileLayout(isDark, cardBg, borderColor, labelColor);
        },
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark, Color cardBg, Color borderColor, Color labelColor) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Superior POS Rebrandeada
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.15) : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.shoppingBag, color: AppTheme.brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terminal de Venta (POS)',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          'Cobro rápido con descuento de stock en vivo',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    tooltip: 'Sincronizar Productos & Stock',
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandPrimary),
                          )
                        : const Icon(LucideIcons.refreshCw, size: 18),
                    onPressed: _isLoading ? null : () => _cargarProductos(forceRefresh: true),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                      foregroundColor: const Color(0xFF0F766E),
                    ),
                    tooltip: 'Escanear con Cámara (Lector POS)',
                    icon: const Icon(LucideIcons.scanLine, size: 20),
                    onPressed: _escanearCodigoParaVenta,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.15) : AppTheme.surfaceTint,
                      foregroundColor: AppTheme.brandPrimary,
                    ),
                    tooltip: 'Cierre del Día & Ventas',
                    icon: const Icon(LucideIcons.receiptText, size: 19),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CajaVentasScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Guía Didáctica POS
              if (_carrito.isEmpty) ...[
                const DidacticBanner(
                  title: '¿Cómo cobrar una venta?',
                  description: '1. Añade productos desde el Catálogo.\n2. Selecciona Efectivo, Yape, Plin o Tarjeta.\n3. Presiona Confirmar Cobro.',
                  icon: LucideIcons.sparkles,
                ),
                const SizedBox(height: 12),
              ],

              // Cliente (Compacto)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(LucideIcons.user, size: 18, color: AppTheme.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _clienteNombreController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Cliente / Razón Social',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _clienteDocController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'DNI / RUC',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_clienteNombreController.text.trim() != 'Público General' || _clienteDocController.text.trim() != '00000000')
                      IconButton(
                        icon: const Icon(LucideIcons.rotateCcw, size: 16),
                        tooltip: 'Restaurar Público General',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          setState(() {
                            _clienteNombreController.text = 'Público General';
                            _clienteDocController.text = '00000000';
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tarjeta Canasta de Compras (POS)
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
                        Row(
                          children: [
                            Text(
                              'Canasta de Venta',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_carrito.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_totalUnidades u.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_carrito.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.alertRed,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _vaciarCarrito,
                            child: Text(
                              'Vaciar',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de items en canasta o placeholder
                    if (_carrito.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101622) : const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(LucideIcons.shoppingBag, size: 36, color: AppTheme.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                'La canasta está vacía',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Añade productos para cobrar la venta',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _carrito.length,
                        separatorBuilder: (_, index) => Divider(
                          height: 16,
                          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        ),
                        itemBuilder: (context, idx) {
                          final item = _carrito[idx];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.producto.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: labelColor,
                                      ),
                                    ),
                                    Text(
                                      'S/ ${item.producto.precioVenta.toStringAsFixed(2)} c/u  •  Disp: ${_formatStock(item.producto.stockActual)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Cantidad steppers
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                                      foregroundColor: labelColor,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 28),
                                    ),
                                    icon: const Icon(LucideIcons.minus, size: 14),
                                    onPressed: () => _decrementarCantidad(idx),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _editarCantidadDirecta(idx),
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.cardDarkElevated.withValues(alpha: 0.5) : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.cantidad.toStringAsFixed(0),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: labelColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                                      foregroundColor: labelColor,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 28),
                                    ),
                                    icon: const Icon(LucideIcons.plus, size: 14),
                                    onPressed: () => _incrementarCantidad(idx),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  'S/ ${item.subtotal.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.brandPrimary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () => _eliminarDelCarrito(idx),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 14),

                    // Botones para agregar productos y escanear
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.brandPrimary,
                                side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              ),
                              icon: const Icon(LucideIcons.plusCircle, size: 18),
                              label: Text(
                                'Catálogo',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              onPressed: _abrirSelectorProductos,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D9488),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              ),
                              icon: const Icon(LucideIcons.scanLine, size: 18),
                              label: Text(
                                'Escanear',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              onPressed: _escanearCodigoParaVenta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Selector de Método de Pago
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
                      'Forma de Pago',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPaymentChip('Efectivo', LucideIcons.banknote, isDark),
                        _buildPaymentChip('Yape', LucideIcons.smartphone, isDark),
                        _buildPaymentChip('Plin', LucideIcons.smartphone, isDark),
                        _buildPaymentChip('Tarjeta', LucideIcons.creditCard, isDark),
                      ],
                    ),

                    // Calculadora de Vuelto para Efectivo
                    if (_metodoPago == 'Efectivo') ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calculadora de Vuelto',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                          Text(
                            'Total a cobrar: S/ ${_totalVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Botones rápidos de denominaciones
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildDenomChip('Exacto', _totalVenta, isDark),
                          if (_totalVenta <= 10) _buildDenomChip('S/ 10', 10.0, isDark),
                          if (_totalVenta <= 20) _buildDenomChip('S/ 20', 20.0, isDark),
                          if (_totalVenta <= 50) _buildDenomChip('S/ 50', 50.0, isDark),
                          if (_totalVenta <= 100) _buildDenomChip('S/ 100', 100.0, isDark),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Campo "Pagó con" y Tarjeta de "Vuelto"
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pagoConController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: labelColor,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Pagó con',
                                prefixText: 'S/ ',
                                prefixStyle: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brandPrimary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Indicador de Vuelto
                          Container(
                            constraints: const BoxConstraints(minWidth: 130),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _montoRecibido >= _totalVenta && _montoRecibido > 0
                                  ? const Color(0xFFD1FAE5)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _montoRecibido >= _totalVenta && _montoRecibido > 0
                                    ? AppTheme.accentGreen
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _montoRecibido >= _totalVenta ? 'Vuelto' : 'Falta',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _montoRecibido >= _totalVenta
                                        ? const Color(0xFF065F46)
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  'S/ ${_vuelto >= 0 ? _vuelto.toStringAsFixed(2) : (_totalVenta - _montoRecibido).toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _montoRecibido >= _totalVenta
                                        ? const Color(0xFF047857)
                                        : AppTheme.alertRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tarjeta Resumen & Botón de Cobro
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderTint,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                              'TOTAL A COBRAR',
                              style: GoogleFonts.outfit(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '$_totalUnidades productos en canasta',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'S/ ${_totalVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            color: AppTheme.brandPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_isProcesando || _carrito.isEmpty) ? null : _procesarVenta,
                        icon: _isProcesando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.checkCheck, size: 20),
                        label: Text(
                          _isProcesando
                              ? 'PROCESANDO...'
                              : 'CONFIRMAR Y COBRAR • S/ ${_totalVenta.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
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

  Widget _buildTabletLayout(bool isDark, Color cardBg, Color borderColor, Color labelColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // En tablets y pantallas de mostrador fijamos el ancho del ticket al estándar ergonómico POS (385dp)
        // permitiendo que el catálogo se expanda fluidamente con 4 a 6 columnas sin espacios muertos
        final ticketWidth = constraints.maxWidth >= 1050
            ? 385.0
            : (constraints.maxWidth * 0.38).clamp(330.0, 420.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PANEL IZQUIERDO: Catálogo Interactivo con densidad visual de terminal insignia
              Expanded(
                child: _buildTabletCatalogoPanel(isDark, cardBg, borderColor, labelColor),
              ),
              const SizedBox(width: 12),
              // PANEL DERECHO: Terminal de Cobro POS / Ticket Digital
              SizedBox(
                width: ticketWidth,
                child: _buildTabletTicketPanel(isDark, cardBg, borderColor, labelColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletCatalogoPanel(bool isDark, Color cardBg, Color borderColor, Color labelColor) {
    final cats = _tabletCategorias;
    final productos = _filteredTabletProductos;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior de búsqueda y acciones rápidas
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: TextField(
                    controller: _tabletSearchCtrl,
                    focusNode: _tabletSearchFocusNode,
                    onChanged: (val) {
                      setState(() => _tabletSearchQuery = val);
                    },
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar producto, marca o código de barras...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppTheme.textMuted,
                      ),
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.brandPrimary),
                      suffixIcon: _tabletSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _tabletSearchCtrl.clear();
                                setState(() => _tabletSearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Indicador de conteo de productos
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.boxes, size: 15, color: AppTheme.brandPrimary),
                    const SizedBox(width: 5),
                    Text(
                      '${productos.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Botón Escáner Láser / Cámara
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                  foregroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(44, 44),
                ),
                tooltip: 'Escanear Código de Barras (Cámara / Láser USB)',
                icon: const Icon(LucideIcons.scanLine, size: 20),
                onPressed: _escanearCodigoParaVenta,
              ),
              const SizedBox(width: 6),

              // Botón Actualizar
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(44, 44),
                ),
                tooltip: 'Actualizar Catálogo & Stock',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: () => _cargarProductos(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pestañas de categorías estilizadas estilo POS (con icono y cantidad)
          if (cats.length > 1)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  final isSelected = (_tabletSelectedCategoria ?? 'Todos') == cat;
                  final catIcon = _getCategoryIcon(cat);
                  final catColor = _getCategoryColor(cat, isDark);
                  final count = _getCountForCategoria(cat);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _tabletSelectedCategoria = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.brandPrimary
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.brandPrimary
                                : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              catIcon,
                              size: 15,
                              color: isSelected ? Colors.white : catColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),

          // Cuadrícula de productos de alta densidad visual
          Expanded(
            child: productos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.packageSearch, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron productos disponibles',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta con otra búsqueda o filtro de categoría',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 6),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      childAspectRatio: 0.88,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: productos.length,
                    itemBuilder: (context, idx) {
                      final p = productos[idx];
                      final cartIdx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
                      final inCart = cartIdx != -1;
                      final inCartQty = inCart ? _carrito[cartIdx].cantidad : 0.0;
                      final isLowStock = p.stockActual <= 5;
                      final catIcon = _getCategoryIcon(p.nombreCategoria);
                      final catColor = _getCategoryColor(p.nombreCategoria, isDark);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _agregarAlCarrito(p);
                          },
                          onLongPress: () {
                            if (cartIdx != -1) {
                              _editarCantidadDirecta(cartIdx);
                            } else {
                              _agregarAlCarrito(p);
                              final newIdx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
                              if (newIdx != -1) {
                                _editarCantidadDirecta(newIdx);
                              }
                            }
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (inCart ? const Color(0xFF132A30) : const Color(0xFF0F172A))
                                  : (inCart ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: inCart
                                    ? AppTheme.brandPrimary
                                    : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                                width: inCart ? 1.8 : 1.0,
                              ),
                              boxShadow: inCart
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.brandPrimary.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Fila Superior: Stock & Badge en carrito
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isLowStock
                                            ? AppTheme.alertRed.withValues(alpha: 0.15)
                                            : (isDark
                                                ? const Color(0xFF134E4A).withValues(alpha: 0.5)
                                                : const Color(0xFFCCFBF1)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_formatStock(p.stockActual)} u.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isLowStock ? AppTheme.alertRed : const Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),
                                    if (inCart)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.brandPrimary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(LucideIcons.check, size: 9, color: Colors.white),
                                            const SizedBox(width: 2),
                                            Text(
                                              'x${inCartQty.toInt()}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Centro Visual: Squircle del icono de categoría con gradiente armónico
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            catColor.withValues(alpha: isDark ? 0.28 : 0.16),
                                            catColor.withValues(alpha: isDark ? 0.12 : 0.06),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: catColor.withValues(alpha: isDark ? 0.4 : 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(catIcon, size: 21, color: catColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Nombre del producto (2 líneas máximo)
                                Text(
                                  p.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 5),

                                // Fila Inferior: Precio + Botón Táctil Rápido
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'S/ ${p.precioVenta.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.brandPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: inCart
                                            ? AppTheme.brandPrimary
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 13,
                                        color: inCart ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletTicketPanel(bool isDark, Color cardBg, Color borderColor, Color labelColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del Ticket POS de Mostrador
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.brandPrimary.withValues(alpha: 0.2) : AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.receiptText, color: AppTheme.brandPrimary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'TICKET POS • CAJA 1',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: labelColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _carrito.isEmpty
                          ? 'Listo para escanear'
                          : '$_totalUnidades u. • ${_carrito.length} productos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_carrito.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.alertRed,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: _vaciarCarrito,
                  child: Text(
                    'Vaciar',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Barra Compacta de Datos del Cliente
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Icon(LucideIcons.userCheck, size: 15, color: AppTheme.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _clienteNombreController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Cliente',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 82,
                  child: TextField(
                    controller: _clienteDocController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: labelColor),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'DNI / RUC',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_clienteNombreController.text.trim() != 'Público General' || _clienteDocController.text.trim() != '00000000')
                  IconButton(
                    icon: const Icon(LucideIcons.rotateCcw, size: 13),
                    tooltip: 'Restaurar Público General',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    onPressed: () {
                      setState(() {
                        _clienteNombreController.text = 'Público General';
                        _clienteDocController.text = '00000000';
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de items en ticket o Banner de terminal listo
          Expanded(
            child: _carrito.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Icon(LucideIcons.scanLine, size: 32, color: AppTheme.brandPrimary),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'TERMINAL LISTO',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pasa el lector láser o toca productos del catálogo para agregarlos a la venta.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _carrito.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 10,
                      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                    ),
                    itemBuilder: (context, idx) {
                      final item = _carrito[idx];
                      final catIcon = _getCategoryIcon(item.producto.nombreCategoria);
                      final catColor = _getCategoryColor(item.producto.nombreCategoria, isDark);

                      return Row(
                        children: [
                          // Glyph de categoría en lista
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(catIcon, size: 16, color: catColor),
                          ),
                          const SizedBox(width: 8),

                          // Título y Precio Unitario
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.producto.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                  ),
                                ),
                                Text(
                                  'S/ ${item.producto.precioVenta.toStringAsFixed(2)} c/u',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Steppers compactos táctiles
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _decrementarCantidad(idx);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(LucideIcons.minus, size: 12),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _editarCantidadDirecta(idx),
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 26),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.cantidad.toStringAsFixed(0),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _incrementarCantidad(idx);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(LucideIcons.plus, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Subtotal
                          SizedBox(
                            width: 62,
                            child: Text(
                              'S/ ${item.subtotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ),

                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            icon: const Icon(LucideIcons.trash2, size: 13, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _eliminarDelCarrito(idx);
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
          const SizedBox(height: 6),

          // Canales de pago
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              _buildPaymentChip('Efectivo', LucideIcons.banknote, isDark),
              _buildPaymentChip('Yape', LucideIcons.smartphone, isDark),
              _buildPaymentChip('Plin', LucideIcons.smartphone, isDark),
              _buildPaymentChip('Tarjeta', LucideIcons.creditCard, isDark),
            ],
          ),

          // Si es Efectivo: calculadora rápida con billetes
          if (_metodoPago == 'Efectivo') ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                _buildDenomChip('Exacto', _totalVenta, isDark),
                if (_totalVenta <= 10) _buildDenomChip('S/ 10', 10.0, isDark),
                if (_totalVenta <= 20) _buildDenomChip('S/ 20', 20.0, isDark),
                if (_totalVenta <= 50) _buildDenomChip('S/ 50', 50.0, isDark),
                if (_totalVenta <= 100) _buildDenomChip('S/ 100', 100.0, isDark),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _pagoConController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: labelColor),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Pagó con',
                        prefixText: 'S/ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _montoRecibido >= _totalVenta
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _montoRecibido >= _totalVenta ? 'Vuelto' : 'Falta',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        'S/ ${_vuelto >= 0 ? _vuelto.toStringAsFixed(2) : (_totalVenta - _montoRecibido).toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _montoRecibido >= _totalVenta ? AppTheme.accentGreen : AppTheme.alertRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Totalizador Digital LED de Caja
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0B0F19), const Color(0xFF1E293B)]
                    : [const Color(0xFF0F172A), const Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                    : AppTheme.brandPrimary.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL A COBRAR',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                    Text(
                      '${_carrito.length} items seleccionados',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  'S/ ${_totalVenta.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Botones de Acción (Ticket Térmico + Cobro)
          Row(
            children: [
              Tooltip(
                message: 'Imprimir Ticket Térmico (58 / 80 mm)',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandPrimary,
                    side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(46, 46),
                  ),
                  onPressed: () {
                    _mostrarTicketTermicoDialog(
                      items: _carrito,
                      total: _totalVenta,
                      metodo: _metodoPago,
                      pagadoCon: _montoRecibido,
                      vuelto: _vuelto,
                    );
                  },
                  child: const Icon(LucideIcons.printer, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcesando || _carrito.isEmpty) ? null : _procesarVenta,
                    icon: _isProcesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.checkCheck, size: 18),
                    label: Text(
                      _isProcesando ? 'PROCESANDO...' : 'COBRAR • S/ ${_totalVenta.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDenomChip(String label, double amount, bool isDark) {
    return ActionChip(
      label: Text(label),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : AppTheme.textDark,
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: () {
        setState(() {
          _pagoConController.text = amount.toStringAsFixed(2);
        });
      },
    );
  }

  Widget _buildPaymentChip(String metodo, IconData icon, bool isDark) {
    final bool isSelected = _metodoPago == metodo;
    Color methodColor;
    switch (metodo) {
      case 'Yape':
        methodColor = const Color(0xFF742284);
        break;
      case 'Plin':
        methodColor = const Color(0xFF0891B2);
        break;
      case 'Tarjeta':
        methodColor = const Color(0xFF2563EB);
        break;
      case 'Efectivo':
      default:
        methodColor = AppTheme.brandPrimary;
        break;
    }

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : methodColor),
      ),
      label: Text(metodo),
      selected: isSelected,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
      ),
      selectedColor: methodColor,
      backgroundColor: isDark ? const Color(0xFF101622) : const Color(0xFFF5F6F8),
      side: BorderSide(
        color: isSelected ? methodColor : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
        width: isSelected ? 1.4 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) {
        setState(() {
          _metodoPago = metodo;
          if (_metodoPago == 'Efectivo') {
            _pagoConController.text = _totalVenta.toStringAsFixed(2);
          } else {
            _pagoConController.clear();
          }
        });
      },
    );
  }
}
