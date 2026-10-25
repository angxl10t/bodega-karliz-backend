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
import '../../core/widgets/product_image_widget.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'documento_service.dart';
import '../../core/secure_storage_service.dart';
import '../../core/widgets/briefing_turno_modal.dart';
import '../clientes/cliente_model.dart';
import '../clientes/cliente_service.dart';
import '../clientes/nuevo_cliente_sheet.dart';
import '../../core/offline/offline_models.dart';
import '../../core/offline/offline_sync_manager.dart';
import '../../core/offline/offline_status_bar.dart';
import '../../core/offline/uuid_helper.dart';
import '../../core/configuracion_ticket_service.dart';
import '../home/configuracion_ticket_modal.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final ProductoService _productoService = ProductoService();
  final VentaService _ventaService = VentaService();
  final DocumentoService _documentoService = DocumentoService();
  final ClienteService _clienteService = ClienteService();

  List<Producto> _productosDisponibles = [];
  final List<CartItem> _carrito = [];

  Cliente? _clienteSeleccionado;
  String _metodoPago = 'Efectivo';
  String _tipoComprobante = 'BOLETA_ELECTRONICA'; // Por defecto Boleta de Venta (99% de clientes)
  String _regimenTributario = 'NUEVO_RUS';
  bool _facturacionSunatActiva = false;
  bool _isConsultandoDoc = false;
  String? _alertaDocMensaje;
  String _nombreBodega = 'CajaYa POS';
  String? _rucBodega;
  String? _direccionBodega;
  String? _lemaBodega;

  bool _identificarCliente = false;
  final _clienteNombreController = TextEditingController();
  final _clienteDocController = TextEditingController();
  final _clienteDocFocusNode = FocusNode();
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

  List<String> _tabletCategorias = ['⭐ Frecuentes', 'Todos'];
  Map<String, int> _tabletCategoryCounts = {'⭐ Frecuentes': 0, 'Todos': 0};
  List<Producto> _frecuentesProductos = [];

  void _recalcularTabletCatalogCache() {
    final copy = List<Producto>.from(_safeDisponibles);
    copy.sort((a, b) => b.stockActual.compareTo(a.stockActual));
    _frecuentesProductos = copy.take(16).toList();

    final Map<String, int> counts = {
      '⭐ Frecuentes': _frecuentesProductos.length,
      'Todos': _safeDisponibles.length,
    };
    final Set<String> uniqueCats = {};
    for (final p in _safeDisponibles) {
      final cat = p.nombreCategoria?.trim();
      final catKey = (cat != null && cat.isNotEmpty) ? cat : 'General';
      uniqueCats.add(catKey);
      counts[catKey] = (counts[catKey] ?? 0) + 1;
    }
    _tabletCategorias = ['⭐ Frecuentes', 'Todos', ...(uniqueCats.toList()..sort())];
    _tabletCategoryCounts = counts;
  }

  List<Producto> get _filteredTabletProductos {
    if (_tabletSelectedCategoria == '⭐ Frecuentes') {
      if (_tabletSearchQuery.isNotEmpty) {
        final q = _tabletSearchQuery.toLowerCase().trim();
        return _frecuentesProductos.where((p) =>
            p.nombre.toLowerCase().contains(q) ||
            _coincideCodigo(p, q) ||
            (p.codigoBarras ?? '').toLowerCase().contains(q) ||
            (p.marca ?? '').toLowerCase().contains(q)
        ).toList();
      }
      return _frecuentesProductos;
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
    return _tabletCategoryCounts[cat] ?? 0;
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
    OfflineSyncManager.instance.init();
    ConfiguracionTicketService.cargar();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    _cargarConfiguracionTributaria();
    _cargarProductos();
  }

  Future<void> _cargarConfiguracionTributaria() async {
    final results = await Future.wait([
      SecureStorageService.read('regimen_tributario'),
      SecureStorageService.read('facturacion_sunat_activa'),
      SecureStorageService.read('nombre_bodega'),
      SecureStorageService.read('ruc_bodega'),
      SecureStorageService.read('direccion_bodega'),
      SecureStorageService.read('lema_comercial'),
    ]);
    final reg = results[0];
    final sunat = results[1];
    final nombre = results[2];
    final ruc = results[3];
    final dir = results[4];
    final lema = results[5];

    if (mounted) {
      setState(() {
        _regimenTributario = (reg != null && reg.isNotEmpty) ? reg : 'NUEVO_RUS';
        _facturacionSunatActiva = sunat == 'true';
        if (nombre != null && nombre.isNotEmpty) _nombreBodega = nombre;
        _rucBodega = ruc;
        _direccionBodega = dir;
        _lemaBodega = lema;

        if (_facturacionSunatActiva) {
          _tipoComprobante = 'BOLETA_ELECTRONICA';
        } else {
          _tipoComprobante = 'TICKET';
        }
      });
    }
  }

  Future<void> _onDocChanged(String value) async {
    final doc = value.trim();
    if (mounted) {
      setState(() => _alertaDocMensaje = null);
    }

    // DNI (8 dígitos numéricos) para Boletas de Venta y Tickets
    if (doc.length == 8 && RegExp(r'^[0-9]{8}$').hasMatch(doc)) {
      setState(() => _isConsultandoDoc = true);
      final res = await _documentoService.consultarDni(doc);
      if (mounted) {
        setState(() {
          _isConsultandoDoc = false;
          if (res != null && res.encontrado && res.nombreCompleto.isNotEmpty) {
            _clienteNombreController.text = res.nombreCompleto;
            KarlizSoundService.instance.playBarcodeBeep();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    ProductoService.productosRevision.removeListener(_onProductosRevisionChanged);
    _clienteNombreController.dispose();
    _clienteDocController.dispose();
    _clienteDocFocusNode.dispose();
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
        _recalcularTabletCatalogCache();
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

  void _verificarNormativaSunat700() {
    if (_tipoComprobante == 'BOLETA_ELECTRONICA' && _totalVenta >= 700.0) {
      if (!_identificarCliente) {
        _identificarCliente = true;
      }
    }
  }

  void _actualizarMontoExactoSiCorresponde(double totalAnterior) {
    if (_metodoPago == 'Efectivo' && _pagoConController.text.isNotEmpty) {
      final actual = double.tryParse(_pagoConController.text.replaceAll(',', '.').trim()) ?? 0.0;
      if ((actual - totalAnterior).abs() < 0.01) {
        _pagoConController.text = _totalVenta.toStringAsFixed(2);
      }
    }
    _verificarNormativaSunat700();
  }

  List<double> _calcularBilletesSugeridos(double total) {
    if (total <= 0) return [];
    final sugerencias = <double>{};

    const billetes = [10.0, 20.0, 50.0, 100.0, 200.0];
    for (final b in billetes) {
      if (b >= total) {
        sugerencias.add(b);
      }
    }

    final proxDecena = (total / 10).ceil() * 10.0;
    if (proxDecena > total && proxDecena <= 200) {
      sugerencias.add(proxDecena);
    }

    final proxCincuenta = (total / 50).ceil() * 50.0;
    if (proxCincuenta > total && proxCincuenta <= 200) {
      sugerencias.add(proxCincuenta);
    }

    final lista = sugerencias.toList()..sort();
    return lista.take(5).toList();
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

    final totalAnterior = _totalVenta;
    setState(() {
      if (idx != -1) {
        _carrito[idx].cantidad += 1;
      } else {
        _carrito.add(CartItem(producto: p, cantidad: 1.0));
      }
      _actualizarMontoExactoSiCorresponde(totalAnterior);
    });
  }

  void _incrementarCantidad(int index) {
    final item = _carrito[index];
    if (item.cantidad < item.producto.stockActual) {
      final totalAnterior = _totalVenta;
      setState(() {
        item.cantidad += 1;
        _actualizarMontoExactoSiCorresponde(totalAnterior);
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
    final totalAnterior = _totalVenta;
    setState(() {
      if (_carrito[index].cantidad > 1) {
        _carrito[index].cantidad -= 1;
      } else {
        _carrito.removeAt(index);
      }
      _actualizarMontoExactoSiCorresponde(totalAnterior);
    });
  }

  void _eliminarDelCarrito(int index) {
    final totalAnterior = _totalVenta;
    setState(() {
      _carrito.removeAt(index);
      _actualizarMontoExactoSiCorresponde(totalAnterior);
    });
  }

  void _vaciarCarrito() {
    setState(() {
      _carrito.clear();
      _pagoConController.clear();
      _identificarCliente = false;
      _clienteDocController.clear();
      _clienteNombreController.clear();
      _clienteSeleccionado = null;
      _alertaDocMensaje = null;
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
          _recalcularTabletCatalogCache();
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

  void _mostrarModalInfoProducto(Producto p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';
    final isLowStock = p.stockActual <= (p.stockMinimo > 0 ? p.stockMinimo : 5.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cartIdx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
            final inCart = cartIdx != -1;
            final inCartQty = inCart ? _carrito[cartIdx].cantidad : 0.0;

            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Píldora de arrastre superior
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

                  // Fila de Encabezado: Categoría y Botón Cerrar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CategoryHelper.getIcon(p.nombreCategoria), size: 16, color: catColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            categoriaNombre.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: catColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x, size: 20),
                        color: isDark ? Colors.white60 : Colors.black45,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Imagen en Grande del Producto (140 px de estudio)
                  Center(
                    child: ProductImageWidget(
                      imagenUrl: p.imagenUrl,
                      categoria: p.nombreCategoria,
                      size: 140,
                      borderRadius: 24,
                      isDark: isDark,
                      padding: 8,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nombre del Producto
                  Text(
                    p.nombre,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Badges de Metadatos (SKU, Marca, Barcode, Perecible)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'SKU: ${p.codigo}',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      if (p.marca != null && p.marca!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Marca: ${p.marca}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      if (p.codigoBarras != null && p.codigoBarras!.trim().isNotEmpty && p.codigoBarras != p.codigo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.barcode, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                p.codigoBarras!,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (p.controlaVencimiento)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.amber.shade700.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.calendarClock, size: 11, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Controla Vencimiento',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tarjetas Informativas: Precio + Stock Actual
                  Row(
                    children: [
                      // Precio de Venta
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131D2E) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Precio Unitario',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'S/ ${p.precioVenta.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.brandPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stock Disponible
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLowStock
                                ? AppTheme.alertRed.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF132A24) : const Color(0xFFECFDF5)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLowStock
                                  ? AppTheme.alertRed.withValues(alpha: 0.4)
                                  : (isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Stock Disponible',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isLowStock ? AppTheme.alertRed : AppTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isLowStock) ...[
                                    const SizedBox(width: 4),
                                    Icon(LucideIcons.alertTriangle, size: 12, color: AppTheme.alertRed),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatStock(p.stockActual)} u.',
                                style: GoogleFonts.outfit(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: isLowStock ? AppTheme.alertRed : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botón de Acción Directo: Agregar / Gestionar en Carrito
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inCart ? const Color(0xFF0D9488) : AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _agregarAlCarrito(p);
                        });
                        setModalState(() {});
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(inCart ? LucideIcons.plus : LucideIcons.shoppingBag, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            inCart
                                ? 'Agregar Más (+1) • En Carrito: ${inCartQty.toInt()} u.'
                                : 'Agregar al Carrito • S/ ${p.precioVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ProductImageWidget(
                                      imagenUrl: p.imagenUrl,
                                      categoria: p.nombreCategoria,
                                      size: 58,
                                      borderRadius: 16,
                                      isDark: isDark,
                                    ),
                                    Positioned(
                                      top: -3,
                                      right: -3,
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _mostrarModalInfoProducto(p);
                                        },
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              LucideIcons.info,
                                              size: 9.5,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (yaEnCarrito)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.brandPrimary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF1E2430) : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(LucideIcons.check, size: 9, color: Colors.white),
                                        ),
                                      ),
                                  ],
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

  bool _esErrorDeRed(String? error) {
    if (error == null) return false;
    final e = error.toLowerCase();
    return e.contains('conexión') ||
        e.contains('conexion') ||
        e.contains('internet') ||
        e.contains('servidor') ||
        e.contains('timeout') ||
        e.contains('socket') ||
        e.contains('failed host lookup') ||
        e.contains('network') ||
        e.contains('clientexception') ||
        e.contains('502') ||
        e.contains('503') ||
        e.contains('504');
  }

  Future<RegistroVentaResult> _firmarVentaOffline(VentaEnvio envio, String uuid) async {
    final idBodega = int.tryParse(await SecureStorageService.read('id_bodega') ?? '0') ?? 0;
    final localTicket = UuidHelper.generateLocalTicket(idBodega);

    final offlineDetalles = _carrito.map((item) {
      return OfflineVentaDetalle(
        idProducto: item.producto.idProducto!,
        nombreProducto: item.producto.nombre,
        cantidad: item.cantidad,
        precioUnitario: item.producto.precioVenta,
        subtotal: item.subtotal,
        codigo: item.producto.codigo,
      );
    }).toList();

    final offlineVenta = OfflineVenta(
      uuid: uuid,
      localTicket: localTicket,
      idBodega: idBodega,
      idCliente: envio.idCliente,
      clienteDocumento: envio.clienteDocumento,
      clienteNombre: envio.clienteNombre,
      metodoPago: envio.metodoPago,
      tipoComprobante: envio.tipoComprobante,
      montoRecibido: envio.montoRecibido,
      vuelto: _vuelto,
      total: _totalVenta,
      usuarioRegistro: _nombreBodega,
      fechaCreacion: DateTime.now(),
      detalles: offlineDetalles,
    );

    await OfflineSyncManager.instance.enqueueSale(offlineVenta);

    return RegistroVentaResult(
      success: true,
      venta: offlineVenta.toVentaRegistro(),
    );
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
      if (_montoRecibido <= 0) {
        KarlizSoundService.instance.playErrorBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.banknote, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ Indica con cuánto paga el cliente o presiona "Pago Exacto" para continuar.',
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
        return;
      }

      if (_montoRecibido < _totalVenta) {
        KarlizSoundService.instance.playErrorBeep();
        final faltante = _totalVenta - _montoRecibido;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ Monto insuficiente: el cliente pagó S/ ${_montoRecibido.toStringAsFixed(2)}, faltan S/ ${faltante.toStringAsFixed(2)} para completar el total de S/ ${_totalVenta.toStringAsFixed(2)}.',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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
        return;
      }
    }

    if (_metodoPago == 'Crédito') {
      if (_clienteSeleccionado == null) {
        KarlizSoundService.instance.playErrorBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.handCoins, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠️ Selecciona un cliente para registrar la venta al crédito en la libreta.',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        _mostrarSelectorCliente();
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

    final String docIngresado = _clienteDocController.text.trim();
    if (_identificarCliente) {
      if (docIngresado.isEmpty || docIngresado.length != 8 || !RegExp(r'^[0-9]{8}$').hasMatch(docIngresado)) {
        KarlizSoundService.instance.playErrorBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Por favor ingresa un DNI válido de 8 dígitos numéricos.'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }
    }

    if (_tipoComprobante == 'BOLETA_ELECTRONICA') {
      if (_totalVenta >= 700.0) {
        if (!_identificarCliente || docIngresado.length != 8) {
          KarlizSoundService.instance.playErrorBeep();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Normativa SUNAT: Para Boletas de Venta iguales o mayores a S/ 700.00 es obligatorio identificar al cliente con su DNI.'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isProcesando = true);

    final idempotencyKey = UuidHelper.generateV4();

    final String? docCliente = (_identificarCliente && docIngresado.isNotEmpty) ? docIngresado : null;
    final String nomCliente = (_identificarCliente && _clienteNombreController.text.trim().isNotEmpty)
        ? _clienteNombreController.text.trim()
        : 'Público General';

    String? finalDocCliente = docCliente;
    String finalNomCliente = nomCliente;
    if (_metodoPago == 'Crédito' && _clienteSeleccionado != null) {
      if (finalDocCliente == null || finalDocCliente.isEmpty) {
        finalDocCliente = _clienteSeleccionado!.documento;
      }
      if (finalNomCliente == 'Público General' || finalNomCliente.isEmpty) {
        finalNomCliente = _clienteSeleccionado!.nombreCompleto;
      }
    }

    final venta = VentaEnvio(
      idCliente: _metodoPago == 'Crédito' ? _clienteSeleccionado?.idCliente : null,
      clienteDocumento: finalDocCliente,
      clienteNombre: finalNomCliente,
      metodoPago: _metodoPago,
      tipoComprobante: _tipoComprobante,
      idempotencyKey: idempotencyKey,
      montoRecibido: _metodoPago == 'Efectivo' ? (_montoRecibido > 0 ? _montoRecibido : _totalVenta) : null,
      detalles: _carrito.map((item) {
        return VentaDetalleEnvio(
          idProducto: item.producto.idProducto!,
          cantidad: item.cantidad,
        );
      }).toList(),
    );

    RegistroVentaResult result;
    bool esOffline = false;

    // Si el sistema ya detectó modo offline o servidor caído, encolar sin demoras
    if (OfflineSyncManager.instance.isOfflineNotifier.value) {
      esOffline = true;
      result = await _firmarVentaOffline(venta, idempotencyKey);
    } else {
      result = await _ventaService.registrarVentaCompleta(venta);
      // Fallback resiliente automático: si falla la red, guardar localmente
      if (!result.success && _esErrorDeRed(result.errorMessage)) {
        esOffline = true;
        result = await _firmarVentaOffline(venta, idempotencyKey);
      }
    }

    if (mounted) {
      setState(() => _isProcesando = false);
      if (result.success) {
        final totalCobrado = _totalVenta;
        final cambio = _vuelto;
        final pagadoCon = _montoRecibido > 0 ? _montoRecibido : totalCobrado;
        final itemsVendidos = List<CartItem>.from(_carrito);
        final clienteFiado = _clienteSeleccionado;

        _vaciarCarrito();

        if (esOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.cloudOff, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '¡Venta firmada localmente! (Modo Offline). Se enviará a la nube al volver internet.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (ConfiguracionTicketService.actual.impresionAutomatica) {
          _despacharImpresionDirecta(
            items: itemsVendidos,
            total: totalCobrado,
            metodo: _metodoPago,
            pagadoCon: pagadoCon,
            vuelto: cambio,
            ventaGenerada: result.venta,
            silencioso: true,
          );
        }

        _mostrarConfirmacionCobro(
          items: itemsVendidos,
          total: totalCobrado,
          metodo: _metodoPago,
          pagadoCon: pagadoCon,
          vuelto: cambio,
          ventaGenerada: result.venta,
          clienteCredito: clienteFiado,
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
                    result.errorMessage ?? 'Error al registrar la venta.',
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
    VentaRegistro? ventaGenerada,
    Cliente? clienteCredito,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool esCredito = metodo == 'Crédito' || clienteCredito != null;

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
              decoration: BoxDecoration(
                color: esCredito ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esCredito ? LucideIcons.handCoins : LucideIcons.checkCheck,
                color: esCredito ? const Color(0xFFD97706) : AppTheme.accentGreen,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              esCredito ? '¡Anotado en Libreta de Fiados!' : '¡Cobro Realizado con Éxito!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            if (esCredito && clienteCredito != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Vecino: ${clienteCredito.nombreCompleto} • Nuevo Saldo: S/ ${(clienteCredito.saldoDeudor + total).toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
            if (ventaGenerada != null && ventaGenerada.estadoSunat == 'OFFLINE_PENDIENTE') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.cloudOff, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      'TICKET LOCAL OFFLINE • PENDIENTE DE SINCRONIZACIÓN',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (ventaGenerada != null && ventaGenerada.esSunat) ...[
              const SizedBox(height: 6),
              () {
                final estado = (ventaGenerada.estadoSunat ?? 'ACEPTADO').toUpperCase();
                final Color badgeColor;
                final IconData badgeIcon;
                final String badgeText;

                switch (estado) {
                  case 'ACEPTADO':
                    badgeColor = AppTheme.accentGreen;
                    badgeIcon = LucideIcons.checkCircle2;
                    badgeText = '${ventaGenerada.etiquetaComprobante} • SUNAT ACEPTADO';
                    break;
                  case 'ACEPTADO_BETA':
                    badgeColor = const Color(0xFF0D9488);
                    badgeIcon = LucideIcons.checkCheck;
                    badgeText = '${ventaGenerada.etiquetaComprobante} • SUNAT BETA (MODO PRUEBA)';
                    break;
                  case 'RECHAZADO':
                    badgeColor = const Color(0xFFEF4444);
                    badgeIcon = LucideIcons.alertCircle;
                    badgeText = '${ventaGenerada.etiquetaComprobante} • RECHAZADO SUNAT';
                    break;
                  case 'PENDIENTE_ENVIO':
                  default:
                    badgeColor = const Color(0xFFF59E0B);
                    badgeIcon = LucideIcons.clock;
                    badgeText = '${ventaGenerada.etiquetaComprobante} • PENDIENTE ENVÍO SUNAT';
                    break;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
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
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (metodo == 'Efectivo') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: vuelto > 0
                            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFD1FAE5))
                            : (isDark ? const Color(0xFF172554).withValues(alpha: 0.35) : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vuelto > 0 ? AppTheme.accentGreen : const Color(0xFF3B82F6),
                          width: vuelto > 0 ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vuelto > 0 ? 'VUELTO A ENTREGAR:' : 'EFECTIVO:',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: vuelto > 0 ? const Color(0xFF065F46) : const Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                'Pagó con S/ ${pagadoCon.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            vuelto > 0 ? 'S/ ${vuelto.toStringAsFixed(2)}' : 'EXACTO',
                            style: GoogleFonts.outfit(
                              fontSize: vuelto > 0 ? 20 : 14,
                              fontWeight: FontWeight.w900,
                              color: vuelto > 0 ? const Color(0xFF047857) : const Color(0xFF2563EB),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
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
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: Text(
                  esCredito ? 'ENVIAR TICKET AL WHATSAPP DEL VECINO' : 'COMPARTIR POR WHATSAPP',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                onPressed: () {
                  _compartirPorWhatsApp(
                    items: items,
                    total: total,
                    metodo: metodo,
                    ventaGenerada: ventaGenerada,
                    clienteCredito: clienteCredito,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandPrimary,
                        side: const BorderSide(color: AppTheme.brandPrimary, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(LucideIcons.printer, size: 17),
                      label: Text(
                        'IMPRIMIR ESC/POS',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      onPressed: () {
                        _despacharImpresionDirecta(
                          items: items,
                          total: total,
                          metodo: metodo,
                          pagadoCon: pagadoCon,
                          vuelto: vuelto,
                          ventaGenerada: ventaGenerada,
                          silencioso: false,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppTheme.brandPrimary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  tooltip: 'Vista Previa del Ticket',
                  icon: const Icon(LucideIcons.eye, size: 18, color: AppTheme.brandPrimary),
                  onPressed: () {
                    _mostrarTicketTermicoDialog(
                      items: items,
                      total: total,
                      metodo: metodo,
                      pagadoCon: pagadoCon,
                      vuelto: vuelto,
                      ventaGenerada: ventaGenerada,
                    );
                  },
                ),
              ],
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

  Future<void> _despacharImpresionDirecta({
    required List<CartItem> items,
    required double total,
    required String metodo,
    required double pagadoCon,
    required double vuelto,
    VentaRegistro? ventaGenerada,
    bool silencioso = false,
  }) async {
    final cfg = ConfiguracionTicketService.actual;
    final ticketItems = items.map((it) {
      return TicketItem(
        nombre: it.producto.nombre,
        cantidad: it.cantidad,
        precioUnitario: it.producto.precioVenta,
        subtotal: it.subtotal,
      );
    }).toList();

    final escPosBytes = ThermalTicketService.generateEscPosBytes(
      ticketId: ventaGenerada?.idVenta,
      clienteNombre: (!_identificarCliente || _clienteNombreController.text.trim().isEmpty) ? 'Público General' : _clienteNombreController.text.trim(),
      clienteDocumento: (!_identificarCliente || _clienteDocController.text.trim().isEmpty) ? null : _clienteDocController.text.trim(),
      metodoPago: metodo,
      items: ticketItems,
      total: total,
      pagadoCon: pagadoCon,
      vuelto: vuelto,
      width: cfg.anchoPapel,
      nombreComercio: _nombreBodega,
      rucDni: _rucBodega,
      direccion: _direccionBodega,
      lemaComercial: _lemaBodega,
      tipoComprobante: ventaGenerada?.tipoComprobante ?? _tipoComprobante,
      serieCorrelativo: ventaGenerada?.serieCorrelativo,
      estadoSunat: ventaGenerada?.estadoSunat,
      sunatHash: ventaGenerada?.sunatHash,
      regimenTributario: _regimenTributario,
      configTicket: cfg,
      forzarAperturaGaveta: cfg.abrirGaveta && metodo.toLowerCase().contains('efectivo'),
    );

    final receiptText = ThermalTicketService.generateReceiptText(
      ticketId: ventaGenerada?.idVenta,
      clienteNombre: (!_identificarCliente || _clienteNombreController.text.trim().isEmpty) ? 'Público General' : _clienteNombreController.text.trim(),
      clienteDocumento: (!_identificarCliente || _clienteDocController.text.trim().isEmpty) ? null : _clienteDocController.text.trim(),
      metodoPago: metodo,
      items: ticketItems,
      total: total,
      pagadoCon: pagadoCon,
      vuelto: vuelto,
      width: cfg.anchoPapel,
      nombreComercio: _nombreBodega,
      rucDni: _rucBodega,
      direccion: _direccionBodega,
      lemaComercial: _lemaBodega,
      tipoComprobante: ventaGenerada?.tipoComprobante ?? _tipoComprobante,
      serieCorrelativo: ventaGenerada?.serieCorrelativo,
      estadoSunat: ventaGenerada?.estadoSunat,
      sunatHash: ventaGenerada?.sunatHash,
      regimenTributario: _regimenTributario,
      configTicket: cfg,
    );

    final res = await ThermalTicketService.imprimirTicketDirecto(
      escPosBytes: escPosBytes,
      receiptText: receiptText,
      config: cfg,
    );

    if (!silencioso && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensaje),
          backgroundColor: res.exito ? AppTheme.accentGreen : const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarTicketTermicoDialog({
    required List<CartItem> items,
    required double total,
    required String metodo,
    required double pagadoCon,
    required double vuelto,
    VentaRegistro? ventaGenerada,
  }) {
    final ticketItems = items.map((it) {
      return TicketItem(
        nombre: it.producto.nombre,
        cantidad: it.cantidad,
        precioUnitario: it.producto.precioVenta,
        subtotal: it.subtotal,
      );
    }).toList();

    int selectedWidth = ConfiguracionTicketService.actual.anchoPapel;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cfg = ConfiguracionTicketService.actual.copyWith(anchoPapel: selectedWidth);

          final receiptText = ThermalTicketService.generateReceiptText(
            ticketId: ventaGenerada?.idVenta,
            clienteNombre: (!_identificarCliente || _clienteNombreController.text.trim().isEmpty) ? 'Público General' : _clienteNombreController.text.trim(),
            clienteDocumento: (!_identificarCliente || _clienteDocController.text.trim().isEmpty) ? null : _clienteDocController.text.trim(),
            metodoPago: metodo,
            items: ticketItems,
            total: total,
            pagadoCon: pagadoCon,
            vuelto: vuelto,
            width: selectedWidth,
            nombreComercio: _nombreBodega,
            rucDni: _rucBodega,
            direccion: _direccionBodega,
            lemaComercial: _lemaBodega,
            tipoComprobante: ventaGenerada?.tipoComprobante ?? _tipoComprobante,
            serieCorrelativo: ventaGenerada?.serieCorrelativo,
            estadoSunat: ventaGenerada?.estadoSunat,
            sunatHash: ventaGenerada?.sunatHash,
            regimenTributario: _regimenTributario,
            configTicket: cfg,
          );

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(LucideIcons.printer, color: AppTheme.brandPrimary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket Térmico POS',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.settings, size: 18),
                  tooltip: 'Configurar Pie de Ticket y Gaveta',
                  onPressed: () async {
                    await ConfiguracionTicketModal.show(context);
                    setDlgState(() {
                      selectedWidth = ConfiguracionTicketService.actual.anchoPapel;
                    });
                  },
                ),
                const SizedBox(width: 4),
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
              width: selectedWidth == ThermalTicketService.width58mm ? 320 : 440,
              height: 360,
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
                label: const Text('Copiar'),
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(LucideIcons.printer, size: 16),
                label: const Text('Imprimir ESC/POS'),
                onPressed: () async {
                  final escPosBytes = ThermalTicketService.generateEscPosBytes(
                    ticketId: ventaGenerada?.idVenta,
                    clienteNombre: (!_identificarCliente || _clienteNombreController.text.trim().isEmpty) ? 'Público General' : _clienteNombreController.text.trim(),
                    clienteDocumento: (!_identificarCliente || _clienteDocController.text.trim().isEmpty) ? null : _clienteDocController.text.trim(),
                    metodoPago: metodo,
                    items: ticketItems,
                    total: total,
                    pagadoCon: pagadoCon,
                    vuelto: vuelto,
                    width: selectedWidth,
                    nombreComercio: _nombreBodega,
                    rucDni: _rucBodega,
                    direccion: _direccionBodega,
                    lemaComercial: _lemaBodega,
                    tipoComprobante: ventaGenerada?.tipoComprobante ?? _tipoComprobante,
                    serieCorrelativo: ventaGenerada?.serieCorrelativo,
                    estadoSunat: ventaGenerada?.estadoSunat,
                    sunatHash: ventaGenerada?.sunatHash,
                    regimenTributario: _regimenTributario,
                    configTicket: cfg,
                    forzarAperturaGaveta: cfg.abrirGaveta && metodo.toLowerCase().contains('efectivo'),
                  );

                  final res = await ThermalTicketService.imprimirTicketDirecto(
                    escPosBytes: escPosBytes,
                    receiptText: receiptText,
                    config: cfg,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.mensaje),
                        backgroundColor: res.exito ? AppTheme.accentGreen : const Color(0xFFEF4444),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              TextButton(
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
              const OfflineStatusBar(),
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
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFFE0F2FE),
                      foregroundColor: const Color(0xFF0284C7),
                    ),
                    tooltip: 'Consejos de Turno & Tips',
                    icon: const Icon(LucideIcons.sparkles, size: 19),
                    onPressed: () => BriefingTurnoModal.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de Comprobante (Boleta de Venta, Ticket de Venta - Nuevo RUS)
              _buildTipoComprobanteSelector(isDark),

              // Cliente (Consumidor Final / Con DNI)
              _buildCustomerCard(isDark, cardBg, borderColor, labelColor, isTablet: false),
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

              // Forma de Pago & Calculadora de Vuelto
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
                        Flexible(
                          child: Text(
                            'Forma de Pago',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: labelColor,
                            ),
                          ),
                        ),
                        if (_metodoPago == 'Efectivo')
                          Flexible(
                            child: Text(
                              'Calculadora de Vuelto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentAndCashSection(isDark, cardBg, borderColor, labelColor, isTablet: false),
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
                        Expanded(
                          child: Column(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'S/ ${_totalVenta.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              color: AppTheme.brandPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCobrarButton(isDark: isDark, height: 52, isTablet: false),
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
          child: Column(
            children: [
              const OfflineStatusBar(),
              Expanded(
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
                      maxCrossAxisExtent: 165,
                      childAspectRatio: 0.74,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: productos.length,
                    itemBuilder: (context, idx) {
                      final p = productos[idx];
                      final cartIdx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
                      final inCart = cartIdx != -1;
                      final inCartQty = inCart ? _carrito[cartIdx].cantidad : 0.0;
                      final isLowStock = p.stockActual <= (p.stockMinimo > 0 ? p.stockMinimo : 5.0);

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

                                // Centro Visual: Packshot de Estudio Frontal (88 px) con Botón Info (i)
                                Expanded(
                                  child: Center(
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        ProductImageWidget(
                                          imagenUrl: p.imagenUrl,
                                          categoria: p.nombreCategoria,
                                          size: 88,
                                          borderRadius: 16,
                                          isDark: isDark,
                                          padding: 2,
                                        ),
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                _mostrarModalInfoProducto(p);
                                              },
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                                                      blurRadius: 3,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    LucideIcons.info,
                                                    size: 11.5,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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

          // Selector de Comprobante (Boleta de Venta, Ticket de Venta - Nuevo RUS)
          _buildTipoComprobanteSelector(isDark),

          // Cliente (Consumidor Final / Con DNI)
          _buildCustomerCard(isDark, cardBg, borderColor, labelColor, isTablet: true),
          const SizedBox(height: 8),

          // Lista de items en ticket o Banner de terminal listo
          Expanded(
            child: _carrito.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Icon(LucideIcons.scanLine, size: 28, color: AppTheme.brandPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'TERMINAL LISTO',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
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
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
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

                      return Row(
                        children: [
                          // Foto de estudio o glyph de categoría en lista de carrito
                          ProductImageWidget(
                            imagenUrl: item.producto.imagenUrl,
                            categoria: item.producto.nombreCategoria,
                            size: 34,
                            borderRadius: 10,
                            isDark: isDark,
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

          // Canales de pago & Calculadora de Vuelto
          _buildPaymentAndCashSection(isDark, cardBg, borderColor, labelColor, isTablet: true),

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL A COBRAR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                      Text(
                        '${_carrito.length} items seleccionados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'S/ ${_totalVenta.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
                child: _buildCobrarButton(isDark: isDark, height: 46, isTablet: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(bool isDark, Color cardBg, Color borderColor, Color labelColor, {bool isTablet = false}) {
    if (!_identificarCliente) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(isTablet ? 14 : 18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 14, vertical: isTablet ? 8 : 10),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 5 : 7),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.userCheck, size: isTablet ? 14 : 16, color: AppTheme.accentGreen),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Consumidor Final',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isTablet ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sin DNI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Público general • Boleta o Ticket rápido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 10 : 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandPrimary,
                side: BorderSide(color: AppTheme.brandPrimary.withValues(alpha: 0.5), width: 1.2),
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 12, vertical: isTablet ? 4 : 6),
                minimumSize: Size(0, isTablet ? 30 : 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(LucideIcons.idCard, size: isTablet ? 13 : 15),
              label: Text(
                '+ DNI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isTablet ? 11 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                setState(() => _identificarCliente = true);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _clienteDocFocusNode.requestFocus();
                });
              },
            ),
          ],
        ),
      );
    }

    // Modo Con DNI
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(isTablet ? 14 : 18),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 9 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.idCard, size: isTablet ? 13 : 15, color: AppTheme.brandPrimary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Cliente con DNI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 11.5 : 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (_tipoComprobante == 'BOLETA_ELECTRONICA' && _totalVenta >= 700.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shieldAlert, size: 10, color: Colors.amber.shade900),
                      const SizedBox(width: 3),
                      Text(
                        'SUNAT ≥ S/ 700',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _identificarCliente = false;
                      _clienteDocController.clear();
                      _clienteNombreController.clear();
                      _alertaDocMensaje = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.rotateCcw, size: 11, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Consumidor Final',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isTablet ? 6 : 8),
          Row(
            children: [
              SizedBox(
                width: isTablet ? 105 : 120,
                child: TextField(
                  controller: _clienteDocController,
                  focusNode: _clienteDocFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 12.5 : 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  onChanged: _onDocChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isTablet ? 7 : 9),
                    hintText: 'DNI (8 d.)',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.brandPrimary, width: 1.4),
                    ),
                    suffixIcon: _isConsultandoDoc
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: Padding(
                              padding: EdgeInsets.all(7.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandPrimary),
                            ),
                          )
                        : (_clienteDocController.text.length == 8
                            ? const Icon(LucideIcons.checkCheck, size: 14, color: AppTheme.accentGreen)
                            : null),
                    suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _clienteNombreController,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isTablet ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isTablet ? 7 : 9),
                    hintText: 'Nombre del Cliente',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.brandPrimary, width: 1.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_clienteNombreController.text.isNotEmpty && _clienteDocController.text.length == 8) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(LucideIcons.badgeCheck, size: 12, color: AppTheme.accentGreen),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Identificado: ${_clienteNombreController.text.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDenomChip({
    required String label,
    required double amount,
    required bool isDark,
    bool isExacto = false,
  }) {
    final isSelected = (_montoRecibido - amount).abs() < 0.01;
    final primaryColor = isExacto ? AppTheme.accentGreen : AppTheme.brandPrimary;

    return ActionChip(
      avatar: isExacto
          ? Icon(LucideIcons.zap, size: 13, color: isSelected ? Colors.white : AppTheme.accentGreen)
          : null,
      label: Text(label),
      labelStyle: GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textDark),
      ),
      backgroundColor: isSelected
          ? primaryColor
          : (isExacto
              ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFD1FAE5))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      side: BorderSide(
        color: isSelected
            ? primaryColor
            : (isExacto ? AppTheme.accentGreen.withValues(alpha: 0.7) : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0))),
        width: isSelected || isExacto ? 1.4 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () {
        setState(() {
          _pagoConController.text = amount.toStringAsFixed(2);
        });
        HapticFeedback.selectionClick();
        KarlizSoundService.instance.playBarcodeBeep();
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
      case 'Crédito':
        methodColor = const Color(0xFFD97706);
        break;
      case 'Efectivo':
      default:
        methodColor = AppTheme.brandPrimary;
        break;
    }

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (_) {
        setState(() {
          _metodoPago = metodo;
          _pagoConController.clear();
        });
        HapticFeedback.selectionClick();
      },
    );
  }

  Widget _buildVueltoCard(bool isDark, {bool isTablet = false}) {
    if (_montoRecibido <= 0) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 14, vertical: isTablet ? 8 : 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.banknote, size: 15, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Efectivo no especificado',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Toca un billete o pulsa Pagar Exacto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 9.5 : 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _pagoConController.text = _totalVenta.toStringAsFixed(2);
                });
                HapticFeedback.selectionClick();
                KarlizSoundService.instance.playBarcodeBeep();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.zap, size: 12, color: AppTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Pagar Exacto',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_montoRecibido < _totalVenta) {
      final faltante = _totalVenta - _montoRecibido;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 14, vertical: isTablet ? 8 : 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.6), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.alertTriangle, size: 16, color: AppTheme.alertRed),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MONTO INSUFICIENTE',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppTheme.alertRed,
                    ),
                  ),
                  Text(
                    'Faltan S/ ${faltante.toStringAsFixed(2)} para completar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '- S/ ${faltante.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: isTablet ? 14 : 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.alertRed,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    if (_vuelto == 0) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 14, vertical: isTablet ? 8 : 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2942) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.6), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCheck, size: 16, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAGO EXACTO',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  Text(
                    'Monto cubierto al centavo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'SIN VUELTO',
              style: GoogleFonts.outfit(
                fontSize: isTablet ? 12 : 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2563EB),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    // _vuelto > 0
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 14, vertical: isTablet ? 8 : 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.45) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.coins, size: 20, color: Color(0xFF047857)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VUELTO A ENTREGAR',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: const Color(0xFF065F46),
                  ),
                ),
                Text(
                  'Pagó con S/ ${_montoRecibido.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/ ${_vuelto.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: isTablet ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF047857),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndCashSection(bool isDark, Color cardBg, Color borderColor, Color labelColor, {bool isTablet = false}) {
    final billetes = _calcularBilletesSugeridos(_totalVenta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Canales de Pago
        Wrap(
          spacing: isTablet ? 5 : 8,
          runSpacing: isTablet ? 4 : 6,
          children: [
            _buildPaymentChip('Efectivo', LucideIcons.banknote, isDark),
            _buildPaymentChip('Yape', LucideIcons.smartphone, isDark),
            _buildPaymentChip('Plin', LucideIcons.smartphone, isDark),
            _buildPaymentChip('Tarjeta', LucideIcons.creditCard, isDark),
            _buildPaymentChip('Crédito', LucideIcons.handCoins, isDark),
          ],
        ),
        SizedBox(height: isTablet ? 8 : 12),

        if (_metodoPago == 'Efectivo') ...[
          // Denominaciones sugeridas rápidas
          Wrap(
            spacing: isTablet ? 5 : 7,
            runSpacing: isTablet ? 4 : 6,
            children: [
              _buildDenomChip(
                label: 'Exacto (S/ ${_totalVenta.toStringAsFixed(2)})',
                amount: _totalVenta,
                isDark: isDark,
                isExacto: true,
              ),
              for (final b in billetes)
                _buildDenomChip(
                  label: 'S/ ${b % 1 == 0 ? b.toInt() : b.toStringAsFixed(2)}',
                  amount: b,
                  isDark: isDark,
                ),
            ],
          ),
          SizedBox(height: isTablet ? 8 : 10),

          // Campo "Pagó con"
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: isTablet ? 40 : 46,
                  child: TextField(
                    controller: _pagoConController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(
                      fontSize: isTablet ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Efectivo recibido',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: isTablet ? 11.5 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                      prefixText: 'S/ ',
                      prefixStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: isTablet ? 14 : 16,
                        color: AppTheme.brandPrimary,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isTablet ? 8 : 12),
                      suffixIcon: _pagoConController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 14),
                              onPressed: () {
                                setState(() => _pagoConController.clear());
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 8 : 10),

          // Tarjeta Inteligente de Vuelto
          _buildVueltoCard(isDark, isTablet: isTablet),
        ] else if (_metodoPago == 'Crédito') ...[
          _buildCreditCustomerCard(isDark, isTablet: isTablet),
        ] else ...[
          // Banner informativo para métodos digitales (Yape, Plin, Tarjeta)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTablet ? 8 : 10),
            decoration: BoxDecoration(
              color: _metodoPago == 'Yape'
                  ? const Color(0xFF742284).withValues(alpha: isDark ? 0.2 : 0.1)
                  : (_metodoPago == 'Plin'
                      ? const Color(0xFF0891B2).withValues(alpha: isDark ? 0.2 : 0.1)
                      : const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _metodoPago == 'Yape'
                    ? const Color(0xFF742284).withValues(alpha: 0.35)
                    : (_metodoPago == 'Plin'
                        ? const Color(0xFF0891B2).withValues(alpha: 0.35)
                        : const Color(0xFF2563EB).withValues(alpha: 0.35)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _metodoPago == 'Tarjeta' ? LucideIcons.creditCard : LucideIcons.smartphone,
                  size: 18,
                  color: _metodoPago == 'Yape'
                      ? const Color(0xFF9333EA)
                      : (_metodoPago == 'Plin' ? const Color(0xFF0891B2) : const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _metodoPago == 'Yape'
                        ? 'Cobro Yape: Verifica la notificación en tu celular antes de confirmar.'
                        : (_metodoPago == 'Plin'
                            ? 'Cobro Plin: Verifica la transferencia recibida en tu cuenta bancaria.'
                            : 'Cobro Tarjeta: Desliza o inserta la tarjeta en tu terminal POS.'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 10.5 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCreditCustomerCard(bool isDark, {bool isTablet = false}) {
    if (_clienteSeleccionado == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.handCoins, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venta al Crédito (Fiado en Libreta)',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Selecciona un vecino de la libreta para cargar la cuenta.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(LucideIcons.search, size: 16),
                    label: Text(
                      'BUSCAR CLIENTE',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    onPressed: _mostrarSelectorCliente,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: Text(
                    '+ NUEVO',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  onPressed: () {
                    NuevoClienteSheet.show(
                      context,
                      onCreated: (nuevo) {
                        setState(() => _clienteSeleccionado = nuevo);
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    final c = _clienteSeleccionado!;
    final double nuevaDeuda = c.saldoDeudor + _totalVenta;
    final bool excedeLimite = c.limiteCredito > 0 && nuevaDeuda > c.limiteCredito;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: excedeLimite
              ? AppTheme.alertRed
              : (const Color(0xFFD97706).withValues(alpha: 0.4)),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    c.nombreCompleto.isNotEmpty ? c.nombreCompleto[0].toUpperCase() : 'C',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombreCompleto,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.telefono != null && c.telefono!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(LucideIcons.phone, size: 11, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            c.telefono!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _mostrarSelectorCliente,
                child: Text(
                  'Cambiar',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 16, color: AppTheme.textMuted),
                onPressed: () => setState(() => _clienteSeleccionado = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Balances
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'DEUDA ACTUAL',
                      style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
                    ),
                    Text(
                      'S/ ${c.saldoDeudor.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFFD97706)),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    Text(
                      'LÍMITE',
                      style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.textMuted),
                    ),
                    Text(
                      'S/ ${c.limiteCredito.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppTheme.textDark),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    Text(
                      'NUEVO SALDO',
                      style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                    ),
                    Text(
                      'S/ ${nuevaDeuda.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: excedeLimite ? AppTheme.alertRed : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (excedeLimite) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 14, color: AppTheme.alertRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '¡Atención! Esta compra supera el límite de crédito (S/ ${c.limiteCredito.toStringAsFixed(2)}).',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.alertRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _mostrarSelectorCliente() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.bookUser, size: 18, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Libreta de Clientes / Vecinos',
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(LucideIcons.userPlus, size: 15),
                          label: Text(
                            '+ Nuevo',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          onPressed: () {
                            NuevoClienteSheet.show(
                              context,
                              onCreated: (nuevo) {
                                if (mounted) {
                                  setState(() => _clienteSeleccionado = nuevo);
                                }
                                Navigator.pop(bottomCtx);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, DNI o teléfono...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<Cliente>>(
                      future: _clienteService.buscarClientes(searchCtrl.text),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)));
                        }
                        final clientes = snapshot.data ?? [];
                        if (clientes.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.users, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No se encontraron vecinos',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Registra un nuevo cliente con el botón superior para fiarle.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          itemCount: clientes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = clientes[i];
                            final bool isSelected = _clienteSeleccionado?.idCliente == c.idCliente;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _clienteSeleccionado = c;
                                  if (_clienteNombreController.text.isEmpty || _clienteNombreController.text == 'Público General') {
                                    _clienteNombreController.text = c.nombreCompleto;
                                  }
                                  if (c.documento != null && c.documento!.isNotEmpty && _clienteDocController.text.isEmpty) {
                                    _clienteDocController.text = c.documento!;
                                  }
                                });
                                Navigator.pop(bottomCtx);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD97706).withValues(alpha: 0.12)
                                      : (isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD97706)
                                        : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected
                                          ? const Color(0xFFD97706)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      child: Text(
                                        c.nombreCompleto.isNotEmpty ? c.nombreCompleto[0].toUpperCase() : 'C',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.nombreCompleto,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : AppTheme.textDark,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (c.documento != null && c.documento!.isNotEmpty) ...[
                                                Text(
                                                  'DNI: ${c.documento}',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              if (c.telefono != null && c.telefono!.isNotEmpty)
                                                Text(
                                                  'Tel: ${c.telefono}',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: c.tieneDeuda
                                                ? const Color(0xFFD97706).withValues(alpha: 0.15)
                                                : AppTheme.accentGreen.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            c.tieneDeuda ? 'Debe S/ ${c.saldoDeudor.toStringAsFixed(2)}' : 'Al día',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: c.tieneDeuda ? const Color(0xFFD97706) : AppTheme.accentGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Límite: S/ ${c.limiteCredito.toStringAsFixed(0)}',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
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

  Widget _buildCobrarButton({required bool isDark, required double height, bool isTablet = false}) {
    final bool canCobrar = !_isProcesando && _carrito.isNotEmpty;

    if (_isProcesando) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
          ),
          label: Text(
            'PROCESANDO COBRO...',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
          ),
        ),
      );
    }

    if (_carrito.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(LucideIcons.shoppingBag, size: 18),
          label: Text(
            'CANASTA VACÍA',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            foregroundColor: AppTheme.textMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
          ),
        ),
      );
    }

    if (_metodoPago == 'Efectivo') {
      if (_montoRecibido <= 0) {
        return SizedBox(
          width: double.infinity,
          height: height,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _pagoConController.text = _totalVenta.toStringAsFixed(2);
              });
              HapticFeedback.mediumImpact();
              KarlizSoundService.instance.playBarcodeBeep();
            },
            icon: const Icon(LucideIcons.zap, size: 18),
            label: Text(
              'COBRAR EXACTO • S/ ${_totalVenta.toStringAsFixed(2)}',
              style: GoogleFonts.plusJakartaSans(fontSize: isTablet ? 12.5 : 13.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0xFF0D9488).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
            ),
          ),
        );
      }

      if (_montoRecibido < _totalVenta) {
        final faltante = _totalVenta - _montoRecibido;
        return SizedBox(
          width: double.infinity,
          height: height,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(LucideIcons.alertTriangle, size: 18),
            label: Text(
              'FALTA DINERO: S/ ${faltante.toStringAsFixed(2)}',
              style: GoogleFonts.plusJakartaSans(fontSize: isTablet ? 12 : 13, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed.withValues(alpha: 0.15),
              foregroundColor: AppTheme.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
            ),
          ),
        );
      }

      // Efectivo cubierto
      final String labelText = _vuelto > 0
          ? 'COBRAR S/ ${_totalVenta.toStringAsFixed(2)} • VUELTO: S/ ${_vuelto.toStringAsFixed(2)}'
          : 'COBRAR S/ ${_totalVenta.toStringAsFixed(2)} • PAGO EXACTO';

      return SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton.icon(
          onPressed: _procesarVenta,
          icon: const Icon(LucideIcons.checkCheck, size: 18),
          label: Text(
            labelText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTablet ? 12.5 : 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
          ),
        ),
      );
    }

    // Métodos digitales
    Color btnColor = AppTheme.brandPrimary;
    String btnLabel = 'CONFIRMAR Y COBRAR • S/ ${_totalVenta.toStringAsFixed(2)}';
    IconData btnIcon = LucideIcons.checkCheck;

    if (_metodoPago == 'Yape') {
      btnColor = const Color(0xFF742284);
      btnLabel = 'CONFIRMAR PAGO YAPE • S/ ${_totalVenta.toStringAsFixed(2)}';
      btnIcon = LucideIcons.smartphone;
    } else if (_metodoPago == 'Plin') {
      btnColor = const Color(0xFF0891B2);
      btnLabel = 'CONFIRMAR PAGO PLIN • S/ ${_totalVenta.toStringAsFixed(2)}';
      btnIcon = LucideIcons.smartphone;
    } else if (_metodoPago == 'Tarjeta') {
      btnColor = const Color(0xFF2563EB);
      btnLabel = 'CONFIRMAR POS TARJETA • S/ ${_totalVenta.toStringAsFixed(2)}';
      btnIcon = LucideIcons.creditCard;
    } else if (_metodoPago == 'Crédito') {
      btnColor = const Color(0xFFD97706);
      btnIcon = LucideIcons.handCoins;
      if (_clienteSeleccionado == null) {
        btnLabel = 'SELECCIONAR CLIENTE PARA FIADO';
      } else {
        btnLabel = 'ANOTAR EN LIBRETA • S/ ${_totalVenta.toStringAsFixed(2)}';
      }
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: canCobrar
            ? ((_metodoPago == 'Crédito' && _clienteSeleccionado == null) ? _mostrarSelectorCliente : _procesarVenta)
            : null,
        icon: Icon(btnIcon, size: 18),
        label: Text(
          btnLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isTablet ? 12.5 : 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: btnColor.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
        ),
      ),
    );
  }

  Future<void> _compartirPorWhatsApp({
    required List<CartItem> items,
    required double total,
    required String metodo,
    VentaRegistro? ventaGenerada,
    Cliente? clienteCredito,
  }) async {
    final doc = (_identificarCliente && _clienteDocController.text.trim().isNotEmpty)
        ? _clienteDocController.text.trim()
        : (clienteCredito?.documento ?? '');
    final nom = (_identificarCliente && _clienteNombreController.text.trim().isNotEmpty)
        ? _clienteNombreController.text.trim()
        : (clienteCredito?.nombreCompleto ?? 'Público General');

    String numTelf = '';
    if (clienteCredito?.telefono != null && clienteCredito!.telefono!.trim().isNotEmpty) {
      final clean = clienteCredito.telefono!.replaceAll(RegExp(r'\D'), '');
      if (clean.length == 9 && clean.startsWith('9')) {
        numTelf = '51$clean';
      } else if (clean.length > 9) {
        numTelf = clean;
      }
    } else if (doc.length == 9 && doc.startsWith('9')) {
      numTelf = '51$doc';
    }

    final comprobanteStr = ventaGenerada != null && ventaGenerada.etiquetaComprobante.isNotEmpty
        ? ventaGenerada.etiquetaComprobante
        : (_tipoComprobante == 'BOLETA_ELECTRONICA' ? 'Boleta de Venta' : 'Ticket de Venta');

    final buffer = StringBuffer();
    if (metodo == 'Crédito' || clienteCredito != null) {
      final double nuevoSaldo = (clienteCredito?.saldoDeudor ?? 0.0) + total;
      buffer.writeln('📒 *$_nombreBodega - Libreta de Fiados*');
      buffer.writeln('¡Hola $nom! Te enviamos la constancia de tu compra al crédito:');
      buffer.writeln('--------------------------------');
      for (final it in items) {
        buffer.writeln('${it.cantidad.toStringAsFixed(0)}x ${it.producto.nombre} - S/ ${it.subtotal.toStringAsFixed(2)}');
      }
      buffer.writeln('--------------------------------');
      buffer.writeln('*Total Fiado en esta compra: S/ ${total.toStringAsFixed(2)}*');
      buffer.writeln('*Tu Saldo Total Pendiente: S/ ${nuevoSaldo.toStringAsFixed(2)}*');
      buffer.writeln('Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
      buffer.writeln('\n¡Gracias por tu preferencia y confianza siempre vecino(a)! ✨🏪');
    } else {
      buffer.writeln('🧾 *$_nombreBodega - Comprobante Digital*');
      buffer.writeln('*$comprobanteStr*');
      if (_rucBodega != null && _rucBodega!.isNotEmpty) {
        buffer.writeln('RUC Emisor: $_rucBodega');
      }
      buffer.writeln('Régimen: NUEVO RUS');
      buffer.writeln('Cliente: $nom');
      if (doc.isNotEmpty) {
        buffer.writeln('DNI: $doc');
      }
      if (ventaGenerada?.serieCorrelativo != null) {
        buffer.writeln('Serie-Correlativo: ${ventaGenerada!.serieCorrelativo}');
        buffer.writeln('Estado SUNAT: ${ventaGenerada.estadoSunat ?? "ACEPTADO"}');
      }
      buffer.writeln('Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
      buffer.writeln('--------------------------------');
      for (final it in items) {
        buffer.writeln('${it.cantidad.toStringAsFixed(0)}x ${it.producto.nombre} - S/ ${it.subtotal.toStringAsFixed(2)}');
      }
      buffer.writeln('--------------------------------');
      buffer.writeln('*TOTAL COBRADO: S/ ${total.toStringAsFixed(2)}*');
      buffer.writeln('Método de Pago: $metodo');
      buffer.writeln('\n¡Muchas gracias por su preferencia! ✨');
    }

    final uri = Uri.parse(numTelf.isNotEmpty
        ? 'https://wa.me/$numTelf?text=${Uri.encodeComponent(buffer.toString())}'
        : 'https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo.')),
        );
      }
    }
  }

  Widget _buildTipoComprobanteSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildTipoComprobanteTab('BOLETA_ELECTRONICA', 'Boleta de Venta', LucideIcons.fileText, isDark),
              _buildTipoComprobanteTab('TICKET', 'Ticket de Venta', LucideIcons.receipt, isDark),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.checkCircle2, size: 11, color: AppTheme.accentGreen),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Régimen Nuevo RUS (SUNAT): Venta ágil a consumidor final',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_alertaDocMensaje != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, size: 12, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _alertaDocMensaje!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_tipoComprobante == 'BOLETA_ELECTRONICA' && _totalVenta >= 700.0)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldAlert, size: 12, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SUNAT: Boletas ≥ S/ 700.00 requieren DNI del cliente obligatoriamente (Art. 8 RCP).',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTipoComprobanteTab(String code, String label, IconData icon, bool isDark) {
    final isSelected = _tipoComprobante == code;
    return Expanded(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _tipoComprobante = code;
              _verificarNormativaSunat700();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : (isDark ? Colors.white60 : AppTheme.textMuted),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
