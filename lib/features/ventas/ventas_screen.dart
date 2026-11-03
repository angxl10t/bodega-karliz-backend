import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../productos/producto_model.dart';
import '../productos/producto_service.dart';
import 'venta_model.dart';
import 'venta_service.dart';
import 'caja_ventas_screen.dart';
import '../../core/widgets/egreso_caja_modal.dart';
import '../../core/widgets/karliz_barcode_scanner_modal.dart';
import '../../core/karliz_sound_service.dart';
import '../../core/thermal_ticket_service.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/category_helper.dart';
import '../../core/widgets/product_image_widget.dart';
import '../../core/marca_detector_service.dart';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'documento_service.dart';
import '../../core/secure_storage_service.dart';
import '../../core/widgets/briefing_turno_modal.dart';
import '../clientes/cliente_model.dart';
import '../clientes/cliente_service.dart';
import '../clientes/nuevo_cliente_sheet.dart';
import '../clientes/nueva_garantia_sheet.dart';
import '../../core/offline/offline_models.dart';
import '../../core/offline/offline_sync_manager.dart';
import '../../core/offline/offline_status_bar.dart';
import '../../core/offline/uuid_helper.dart';
import '../../core/configuracion_ticket_service.dart';
import '../home/configuracion_ticket_modal.dart';
import '../fiscal/monitor_nuevo_rus_modal.dart';
import '../promociones/promocion_model.dart';
import '../promociones/promocion_service.dart';
import '../catalogo/pedido_web_service.dart';
import 'venta_en_espera_service.dart';
import '../../core/widgets/solicitar_pin_dialog.dart';
import '../movimientos/movimiento_service.dart';
import '../auth/auth_service.dart';

class PromoAplicada {
  final Promocion promocion;
  final double descuento;
  final String descripcion;

  PromoAplicada({
    required this.promocion,
    required this.descuento,
    required this.descripcion,
  });
}

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
  final PromocionService _promocionService = PromocionService();
  final MovimientoService _movimientoService = MovimientoService();
  List<Promocion> _promocionesActivas = [];
  double _descuentoManualCarrito = 0.0;
  String _descuentoManualMotivo = '';

  List<Producto> _productosDisponibles = [];
  final List<CartItem> _carrito = [];

  Cliente? _clienteSeleccionado;
  String _metodoPago = 'Efectivo';
  String _tipoComprobante =
      'BOLETA_ELECTRONICA'; // Por defecto Boleta de Venta (99% de clientes)
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
  String? _tabletSelectedCategoria = 'Frecuentes';

  final FocusNode _screenFocusNode = FocusNode();
  final FocusNode _tabletSearchFocusNode = FocusNode();
  final StringBuffer _hwScanBuffer = StringBuffer();
  DateTime _lastHwKeyTime = DateTime.now();

  bool _isLoading = true;
  bool _isProcesando = false;

  List<Producto> get _safeDisponibles => _productosDisponibles;

  String _formatCantidad(double cant) {
    if (cant % 1 == 0) return cant.toInt().toString();
    if ((cant * 10) % 1 == 0) return cant.toStringAsFixed(1);
    if ((cant * 100) % 1 == 0) return cant.toStringAsFixed(2);
    return cant.toStringAsFixed(3);
  }

  String _formatStock(double stock) {
    return stock % 1 == 0 ? stock.toInt().toString() : stock.toStringAsFixed(2);
  }

  bool _aplicarPromocionesWeb = false;

  Promocion? _obtenerPromocionActivaParaProducto(Producto p) {
    if (_promocionesActivas.isEmpty) return null;
    final now = DateTime.now();

    for (final promo in _promocionesActivas) {
      if (!promo.activo) continue;

      if (promo.fechaInicio != null && promo.fechaInicio!.trim().isNotEmpty) {
        final ini = DateTime.tryParse(promo.fechaInicio!.trim());
        if (ini != null && now.isBefore(ini)) continue;
      }
      if (promo.fechaFin != null && promo.fechaFin!.trim().isNotEmpty) {
        final fin = DateTime.tryParse(promo.fechaFin!.trim());
        if (fin != null && now.isAfter(fin.add(const Duration(days: 1))))
          continue;
      }

      // 1. Producto individual, 2x1 o 3x2
      if ((promo.alcance == 'PRODUCTO' ||
              promo.tipoPromocion == 'DOS_POR_UNO' ||
              promo.tipoPromocion == 'TRES_POR_DOS') &&
          promo.idProductoPrincipal == p.idProducto) {
        return promo;
      }

      // 2. Combo
      if (promo.alcance == 'COMBO' &&
          (promo.idProductoPrincipal == p.idProducto ||
              promo.idProductoSecundario == p.idProducto)) {
        return promo;
      }

      // 3. Marca
      if (promo.alcance == 'MARCA' &&
          promo.marcaObjetivo != null &&
          promo.marcaObjetivo!.trim().isNotEmpty) {
        if (MarcaDetectorService.coincideMarca(
          promo.marcaObjetivo,
          p.marca,
          p.nombre,
        )) {
          return promo;
        }
      }

      // 4. Categoría
      if (promo.alcance == 'CATEGORIA' &&
          promo.categoriaObjetivo != null &&
          promo.categoriaObjetivo!.trim().isNotEmpty) {
        final catNorm = promo.categoriaObjetivo!.trim().toLowerCase();
        if ((p.nombreCategoria?.trim().toLowerCase() ?? '') == catNorm) {
          return promo;
        }
      }
    }
    return null;
  }

  List<String> _tabletCategorias = ['Frecuentes', 'Todos'];
  Map<String, int> _tabletCategoryCounts = {'Frecuentes': 0, 'Todos': 0};
  List<Producto> _frecuentesProductos = [];

  void _recalcularTabletCatalogCache() {
    final copy = List<Producto>.from(_safeDisponibles);
    copy.sort((a, b) => b.stockActual.compareTo(a.stockActual));
    _frecuentesProductos = copy.take(16).toList();

    final int promosCount = _safeDisponibles
        .where((p) => _obtenerPromocionActivaParaProducto(p) != null)
        .length;

    final Map<String, int> counts = {
      'Frecuentes': _frecuentesProductos.length,
      if (promosCount > 0) 'Promociones': promosCount,
      'Todos': _safeDisponibles.length,
    };
    final Set<String> uniqueCats = {};
    for (final p in _safeDisponibles) {
      final catKey = CategoryHelper.normalize(p.nombreCategoria);
      uniqueCats.add(catKey);
      counts[catKey] = (counts[catKey] ?? 0) + 1;
    }
    _tabletCategorias = [
      'Frecuentes',
      if (promosCount > 0) 'Promociones',
      'Todos',
      ...(uniqueCats.toList()..sort()),
    ];
    _tabletCategoryCounts = counts;
  }

  List<Producto> get _filteredTabletProductos {
    if (_tabletSelectedCategoria == 'Promociones') {
      return _safeDisponibles.where((p) {
        if (_obtenerPromocionActivaParaProducto(p) == null) return false;
        if (_tabletSearchQuery.isNotEmpty) {
          final q = _tabletSearchQuery.toLowerCase().trim();
          return p.nombre.toLowerCase().contains(q) ||
              _coincideCodigo(p, q) ||
              (p.codigoBarras ?? '').toLowerCase().contains(q) ||
              (p.marca ?? '').toLowerCase().contains(q);
        }
        return true;
      }).toList();
    }

    if (_tabletSelectedCategoria == 'Frecuentes') {
      if (_tabletSearchQuery.isNotEmpty) {
        final q = _tabletSearchQuery.toLowerCase().trim();
        return _frecuentesProductos
            .where(
              (p) =>
                  p.nombre.toLowerCase().contains(q) ||
                  _coincideCodigo(p, q) ||
                  (p.codigoBarras ?? '').toLowerCase().contains(q) ||
                  (p.marca ?? '').toLowerCase().contains(q),
            )
            .toList();
      }
      return _frecuentesProductos;
    }

    return _safeDisponibles.where((p) {
      if (_tabletSelectedCategoria != null &&
          _tabletSelectedCategoria != 'Todos') {
        final cat = CategoryHelper.normalize(p.nombreCategoria);
        if (cat != _tabletSelectedCategoria) return false;
      }
      if (_tabletSearchQuery.isNotEmpty) {
        final q = _tabletSearchQuery.toLowerCase().trim();
        final matches =
            p.nombre.toLowerCase().contains(q) ||
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

  IconData _getCategoryIcon(String? categoryName) {
    if (categoryName == 'Promociones') return LucideIcons.tag;
    return CategoryHelper.getIcon(categoryName);
  }

  Color _getCategoryColor(String? categoryName, bool isDark) {
    if (categoryName == 'Promociones') return const Color(0xFFEF4444);
    return CategoryHelper.getColor(categoryName, isDark);
  }

  void _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Fast-keys comerciales de caja (F2, F4, F9, F12, Escape)
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _tabletSearchFocusNode.requestFocus();
      HapticFeedback.lightImpact();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.f4 ||
        event.logicalKey == LogicalKeyboardKey.f12) {
      if (_carrito.isNotEmpty && !_isProcesando) {
        HapticFeedback.mediumImpact();
        _ejecutarCobroRapido();
      }
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.f9) {
      _alternarTipoComprobante();
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_tabletSearchFocusNode.hasFocus ||
          _tabletSearchCtrl.text.isNotEmpty) {
        _tabletSearchCtrl.clear();
        setState(() => _tabletSearchQuery = '');
        _tabletSearchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
      } else if (_carrito.isNotEmpty) {
        _vaciarCarrito();
      }
      return;
    }

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

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
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
    PedidoWebService.inicializar();
    PedidoWebService.iniciarPollingRevision();
    PedidoWebService.onNuevoPedidoRecibido = _onNuevoPedidoWebRecibido;
    VentaEnEsperaService.inicializar();
    OfflineSyncManager.instance.init();
    ConfiguracionTicketService.cargar();
    ProductoService.productosRevision.addListener(_onProductosRevisionChanged);
    _cargarConfiguracionTributaria();
    _cargarProductos();
    _cargarPromociones();
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
        _regimenTributario = (reg != null && reg.isNotEmpty)
            ? reg
            : 'NUEVO_RUS';
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

  void _onNuevoPedidoWebRecibido(PedidoWeb pedido) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.globe, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Nuevo Pedido Web recibido (${pedido.codigoDisplay}) de ${pedido.nombreCliente}!',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VER',
          textColor: Colors.white,
          onPressed: _mostrarBandejaPedidosWeb,
        ),
      ),
    );
  }

  @override
  void dispose() {
    PedidoWebService.detenerPollingRevision();
    PedidoWebService.onNuevoPedidoRecibido = null;
    ProductoService.productosRevision.removeListener(
      _onProductosRevisionChanged,
    );
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
    final productos = await _productoService.getProductos(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _productosDisponibles = List<Producto>.from(
          productos.where((p) => p.stockActual > 0),
        );
        _recalcularTabletCatalogCache();
        _isLoading = false;
        if (forceRefresh) {
          _cargarPromociones();
        }
      });
    }
  }

  double get _totalVenta {
    final finalTotal = _subtotalVenta - _totalDescuentoPromociones - _descuentoManualCarrito;
    return finalTotal < 0 ? 0.0 : finalTotal;
  }

  Future<void> _cargarPromociones() async {
    try {
      final promos = await _promocionService.obtenerPromociones();
      if (mounted) {
        setState(() {
          _promocionesActivas = promos.where((p) => p.activo).toList();
          _recalcularTabletCatalogCache();
        });
      }
    } catch (_) {
      // Offline fallback: continuar sin bloquear el POS
    }
  }

  List<PromoAplicada> get _promocionesAplicadas {
    if (_promocionesActivas.isEmpty || _carrito.isEmpty) return [];
    final List<PromoAplicada> aplicadas = [];

    for (final promo in _promocionesActivas) {
      if (!promo.activo) continue;

      if (promo.tipoPromocion == 'COMBO' ||
          promo.tipoPromocion == 'COMBO_HUESO') {
        if (promo.idProductoPrincipal != null &&
            promo.idProductoSecundario != null &&
            promo.precioCombo != null) {
          CartItem? itA;
          CartItem? itB;
          for (final it in _carrito) {
            if (it.producto.idProducto == promo.idProductoPrincipal) itA = it;
            if (it.producto.idProducto == promo.idProductoSecundario) itB = it;
          }
          if (itA != null && itB != null) {
            final countCombos =
                (itA.cantidad < itB.cantidad ? itA.cantidad : itB.cantidad)
                    .toInt();
            if (countCombos > 0) {
              final precioNormal =
                  (itA.producto.precioVenta + itB.producto.precioVenta) *
                  countCombos;
              final precioConPromo = promo.precioCombo! * countCombos;
              final ahorro = (precioNormal - precioConPromo).clamp(
                0.0,
                999999.0,
              );
              if (ahorro > 0.01) {
                aplicadas.add(
                  PromoAplicada(
                    promocion: promo,
                    descuento: ahorro,
                    descripcion:
                        '${promo.titulo}: -S/ ${ahorro.toStringAsFixed(2)} ($countCombos combo${countCombos > 1 ? 's' : ''})',
                  ),
                );
              }
            }
          }
        }
      } else if (promo.tipoPromocion == 'DOS_POR_UNO') {
        if (promo.idProductoPrincipal != null) {
          CartItem? it;
          for (final c in _carrito) {
            if (c.producto.idProducto == promo.idProductoPrincipal) {
              it = c;
              break;
            }
          }
          if (it != null && it.cantidad >= 2) {
            final pares = (it.cantidad ~/ 2);
            final ahorro = pares * it.producto.precioVenta;
            if (ahorro > 0.01) {
              aplicadas.add(
                PromoAplicada(
                  promocion: promo,
                  descuento: ahorro,
                  descripcion:
                      '${promo.titulo}: 2x1 en ${it.producto.nombre} (-S/ ${ahorro.toStringAsFixed(2)})',
                ),
              );
            }
          }
        }
      } else if (promo.tipoPromocion == 'TRES_POR_DOS') {
        if (promo.idProductoPrincipal != null) {
          CartItem? it;
          for (final c in _carrito) {
            if (c.producto.idProducto == promo.idProductoPrincipal) {
              it = c;
              break;
            }
          }
          if (it != null && it.cantidad >= 3) {
            final trios = (it.cantidad ~/ 3);
            final ahorro = trios * it.producto.precioVenta;
            if (ahorro > 0.01) {
              aplicadas.add(
                PromoAplicada(
                  promocion: promo,
                  descuento: ahorro,
                  descripcion:
                      '${promo.titulo}: 3x2 en ${it.producto.nombre} (-S/ ${ahorro.toStringAsFixed(2)})',
                ),
              );
            }
          }
        }
      } else if (promo.tipoPromocion == 'PORCENTAJE') {
        if (promo.alcance == 'PRODUCTO' && promo.idProductoPrincipal != null) {
          for (final it in _carrito) {
            if (it.producto.idProducto == promo.idProductoPrincipal) {
              final ahorro = it.subtotal * (promo.valorDescuento / 100.0);
              if (ahorro > 0.01) {
                aplicadas.add(
                  PromoAplicada(
                    promocion: promo,
                    descuento: ahorro,
                    descripcion:
                        '${promo.titulo}: ${promo.valorDescuento.toStringAsFixed(0)}% dscto. (-S/ ${ahorro.toStringAsFixed(2)})',
                  ),
                );
              }
            }
          }
        } else if (promo.alcance == 'CATEGORIA' &&
            promo.categoriaObjetivo != null) {
          final catNorm = promo.categoriaObjetivo!.toLowerCase().trim();
          double subtotalCat = 0.0;
          for (final it in _carrito) {
            if ((it.producto.nombreCategoria ?? '').toLowerCase().trim() ==
                catNorm) {
              subtotalCat += it.subtotal;
            }
          }
          if (subtotalCat > 0) {
            final ahorro = subtotalCat * (promo.valorDescuento / 100.0);
            if (ahorro > 0.01) {
              aplicadas.add(
                PromoAplicada(
                  promocion: promo,
                  descuento: ahorro,
                  descripcion:
                      '${promo.titulo}: ${promo.valorDescuento.toStringAsFixed(0)}% dscto. (-S/ ${ahorro.toStringAsFixed(2)})',
                ),
              );
            }
          }
        }
      } else if (promo.tipoPromocion == 'MONTO_FIJO') {
        if (promo.alcance == 'PRODUCTO' && promo.idProductoPrincipal != null) {
          for (final it in _carrito) {
            if (it.producto.idProducto == promo.idProductoPrincipal) {
              final ahorro = (promo.valorDescuento * it.cantidad).clamp(
                0.0,
                it.subtotal,
              );
              if (ahorro > 0.01) {
                aplicadas.add(
                  PromoAplicada(
                    promocion: promo,
                    descuento: ahorro,
                    descripcion:
                        '${promo.titulo}: -S/ ${ahorro.toStringAsFixed(2)}',
                  ),
                );
              }
            }
          }
        }
      }
    }
    return aplicadas;
  }

  double get _subtotalVenta {
    return _carrito.fold(0.0, (acc, item) => acc + item.subtotal);
  }

  double get _totalDescuentoPromociones {
    if (!_aplicarPromocionesWeb) return 0.0;
    return _promocionesAplicadas.fold<double>(
      0.0,
      (acc, p) => acc + p.descuento,
    );
  }

  String get _totalUnidadesTexto {
    final total = _carrito.fold<double>(
      0.0,
      (acc, item) => acc + item.cantidad,
    );
    return _formatCantidad(total);
  }

  int get _totalUnidades {
    return _carrito.fold(0, (acc, item) => acc + item.cantidad.toInt());
  }

  double get _montoRecibido {
    final val = double.tryParse(
      _pagoConController.text.replaceAll(',', '.').trim(),
    );
    return val ?? 0.0;
  }

  double get _vuelto {
    if (_metodoPago != 'Efectivo') return 0.0;
    final recibido = _montoRecibido;
    if (recibido <= 0) return 0.0;
    return recibido - _totalVenta;
  }

  void _ejecutarCobroRapido() {
    if (_carrito.isEmpty || _isProcesando) return;
    if (_metodoPago == 'Efectivo' && _montoRecibido < _totalVenta) {
      setState(() {
        _pagoConController.text = _totalVenta.toStringAsFixed(2);
      });
    }
    _procesarVenta();
  }

  void _alternarTipoComprobante() {
    setState(() {
      _tipoComprobante = (_tipoComprobante == 'BOLETA_ELECTRONICA')
          ? 'TICKET'
          : 'BOLETA_ELECTRONICA';
      _verificarNormativaSunat700();
    });
    HapticFeedback.lightImpact();
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
      final actual =
          double.tryParse(
            _pagoConController.text.replaceAll(',', '.').trim(),
          ) ??
          0.0;
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

  void _agregarAlCarrito(
    Producto p, {
    bool playSound = true,
    double cantidad = 1.0,
  }) {
    final idx = _carrito.indexWhere(
      (item) => item.producto.idProducto == p.idProducto,
    );
    final cantidadActual = idx != -1 ? _carrito[idx].cantidad : 0.0;
    if (cantidadActual + cantidad > p.stockActual) {
      KarlizSoundService.instance.playErrorBeep();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock máximo alcanzado para ${p.nombre} (${_formatStock(p.stockActual)} u.)',
          ),
          backgroundColor: AppTheme.alertRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (playSound) {
      KarlizSoundService.instance.playBarcodeBeep();
    }
    HapticFeedback.lightImpact();

    final totalAnterior = _totalVenta;
    setState(() {
      if (idx != -1) {
        _carrito[idx].cantidad += cantidad;
      } else {
        _carrito.add(CartItem(producto: p, cantidad: cantidad));
      }
      _actualizarMontoExactoSiCorresponde(totalAnterior);
    });
  }

  void _incrementarCantidad(int index) {
    final item = _carrito[index];
    if (item.cantidad < item.producto.stockActual) {
      HapticFeedback.selectionClick();
      final totalAnterior = _totalVenta;
      setState(() {
        item.cantidad += 1;
        _actualizarMontoExactoSiCorresponde(totalAnterior);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay más stock disponible para ${item.producto.nombre}',
          ),
          backgroundColor: AppTheme.alertRed,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _decrementarCantidad(int index) {
    HapticFeedback.selectionClick();
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
    HapticFeedback.lightImpact();
    final totalAnterior = _totalVenta;
    setState(() {
      _carrito.removeAt(index);
      _actualizarMontoExactoSiCorresponde(totalAnterior);
    });
  }

  void _vaciarCarrito() {
    HapticFeedback.mediumImpact();
    setState(() {
      _carrito.clear();
      _pagoConController.clear();
      _identificarCliente = false;
      _clienteDocController.clear();
      _clienteNombreController.clear();
      _clienteSeleccionado = null;
      _alertaDocMensaje = null;
      _aplicarPromocionesWeb = false;
      _descuentoManualCarrito = 0.0;
      _descuentoManualMotivo = '';
    });
  }

  Future<void> _ponerVentaEnEspera() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La canasta está vacía. No hay productos para poner en espera.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    final refCtrl = TextEditingController(
      text: _clienteNombreController.text.trim().isNotEmpty
          ? _clienteNombreController.text.trim()
          : '',
    );

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.pauseCircle, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Poner Venta en Espera',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta venta ($_totalUnidades u. • S/ ${_totalVenta.toStringAsFixed(2)}) se pausará para atender al siguiente cliente en la fila sin perder los productos escaneados.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: refCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre o referencia del cliente (opcional)',
                  hintText: 'Ej. Don Carlos (fue por dinero), Señora de chompa roja',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(LucideIcons.pause, size: 16),
              label: const Text('Poner en Espera'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      final etiqueta = refCtrl.text.trim().isNotEmpty
          ? refCtrl.text.trim()
          : 'Cliente ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';

      final ventaPausada = VentaEnEspera(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fecha: DateTime.now(),
        etiqueta: etiqueta,
        items: _carrito.map((it) => CartItem(
          producto: it.producto,
          cantidad: it.cantidad,
          descuentoManual: it.descuentoManual,
          descuentoMotivo: it.descuentoMotivo,
        )).toList(),
        cliente: _clienteSeleccionado,
        metodoPago: _metodoPago,
        tipoComprobante: _tipoComprobante,
        descuentoManualCarrito: _descuentoManualCarrito,
        descuentoManualMotivo: _descuentoManualMotivo,
        aplicarPromocionesWeb: _aplicarPromocionesWeb,
      );

      await VentaEnEsperaService.ponerEnEspera(ventaPausada);
      _vaciarCarrito();
      KarlizSoundService.instance.playBarcodeBeep();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.pauseCircle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket "$etiqueta" guardado en espera. Listo para la siguiente venta.',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _mostrarModalVentasEnEspera() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lista = VentaEnEsperaService.ventas;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.pauseCircle, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tickets en Espera (Park Cart)',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${lista.length} tickets pausados en caja',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: lista.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shoppingCart,
                                    size: 48,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay tickets en espera',
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cuando un cliente olvide un producto o vaya a sacar efectivo, presiona el icono de pausa en el carrito para seguir atendiendo a los demás clientes sin perder su canasta.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: lista.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final venta = lista[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            venta.etiqueta,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            venta.tiempoTranscurrido,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${venta.items.length} productos (${venta.totalUnidades.toStringAsFixed(venta.totalUnidades % 1 == 0 ? 0 : 2)} u.) • Comprobante: ${venta.tipoComprobante}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: S/ ${venta.totalNeto.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.brandPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.alertRed),
                                          tooltip: 'Descartar ticket',
                                          onPressed: () async {
                                            await VentaEnEsperaService.eliminar(venta.id);
                                            setModalState(() {});
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.brandPrimary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          icon: const Icon(LucideIcons.play, size: 15),
                                          label: const Text('Recuperar a Caja'),
                                          onPressed: () async {
                                            if (_carrito.isNotEmpty) {
                                              final sobreescribir = await showDialog<bool>(
                                                context: context,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text('¿Reemplazar canasta actual?'),
                                                  content: const Text(
                                                    'Tienes productos en la canasta actual. ¿Deseas pausar la venta actual antes de recuperar este ticket?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dCtx, false),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () => Navigator.pop(dCtx, true),
                                                      child: const Text('Pausar actual y Recuperar'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (sobreescribir != true) return;
                                              final actualPausada = VentaEnEspera(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                fecha: DateTime.now(),
                                                etiqueta: 'Venta rápida ${_carrito.length} items',
                                                items: List<CartItem>.from(_carrito),
                                                cliente: _clienteSeleccionado,
                                                metodoPago: _metodoPago,
                                                tipoComprobante: _tipoComprobante,
                                                descuentoManualCarrito: _descuentoManualCarrito,
                                                descuentoManualMotivo: _descuentoManualMotivo,
                                                aplicarPromocionesWeb: _aplicarPromocionesWeb,
                                              );
                                              await VentaEnEsperaService.ponerEnEspera(actualPausada);
                                            }

                                            final recuperada = await VentaEnEsperaService.recuperar(venta.id);
                                            if (recuperada != null) {
                                              setState(() {
                                                _carrito.clear();
                                                _carrito.addAll(recuperada.items);
                                                _clienteSeleccionado = recuperada.cliente;
                                                _metodoPago = recuperada.metodoPago;
                                                _tipoComprobante = recuperada.tipoComprobante;
                                                _descuentoManualCarrito = recuperada.descuentoManualCarrito;
                                                _descuentoManualMotivo = recuperada.descuentoManualMotivo ?? '';
                                                _aplicarPromocionesWeb = recuperada.aplicarPromocionesWeb;
                                              });
                                              KarlizSoundService.instance.playBarcodeBeep();
                                            }
                                            if (ctx.mounted) Navigator.pop(ctx);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  void _mostrarBandejaPedidosWeb() {
    // Sincronizar de inmediato con la nube al abrir la bandeja
    PedidoWebService.sincronizarConNube(forzar: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String filtroBusqueda = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final todos = PedidoWebService.pedidos;
            final lista = filtroBusqueda.isEmpty
                ? todos
                : todos.where((p) =>
                    p.codigoDisplay.toLowerCase().contains(filtroBusqueda) ||
                    p.nombreCliente.toLowerCase().contains(filtroBusqueda) ||
                    (p.telefonoCliente != null && p.telefonoCliente!.contains(filtroBusqueda))
                  ).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.globe, color: Color(0xFF0D9488), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bandeja de Pedidos Web',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${PedidoWebService.pedidosPendientes.length} pedidos web pendientes de atención',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: PedidoWebService.estaSincronizandoNotifier,
                          builder: (context, sincronizando, _) {
                            return IconButton(
                              icon: sincronizando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                                    )
                                  : const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF0D9488)),
                              tooltip: 'Sincronizar con la nube',
                              onPressed: sincronizando
                                  ? null
                                  : () async {
                                      await PedidoWebService.sincronizarConNube(forzar: true);
                                      setModalState(() {});
                                    },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: TextField(
                      onChanged: (val) => setModalState(() => filtroBusqueda = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar por código #W-XXXX, cliente o teléfono...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: lista.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.globe,
                                    size: 48,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay pedidos web registrados',
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cuando los clientes armen su pedido desde el catálogo web de la bodega, aparecerán aquí para cargarlos al carrito en 1 toque.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: lista.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final pedido = lista[index];
                              final esPendiente = pedido.estado == 'PENDIENTE';
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: esPendiente
                                        ? const Color(0xFF0D9488)
                                        : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                                    width: esPendiente ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            pedido.codigoDisplay,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0D9488),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pedido.nombreCliente,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: esPendiente
                                                ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            esPendiente ? 'PENDIENTE' : pedido.estado,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: esPendiente ? const Color(0xFF0D9488) : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (pedido.telefonoCliente != null && pedido.telefonoCliente!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.phone, size: 14, color: AppTheme.brandPrimary),
                                          const SizedBox(width: 6),
                                          Text(
                                            pedido.telefonoCliente!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nota: ${pedido.notas!}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.cardDarkSunken : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          for (final it in pedido.items)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '${it.cantidad.toStringAsFixed(it.cantidad % 1 == 0 ? 0 : 2)}x',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.brandPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      it.nombre,
                                                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                                    ),
                                                  ),
                                                  Text(
                                                    'S/ ${it.subtotal.toStringAsFixed(2)}',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total: S/ ${pedido.total.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.brandPrimary,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.alertRed),
                                              tooltip: 'Eliminar pedido',
                                              onPressed: () async {
                                                await PedidoWebService.eliminarPedido(pedido.idPedido, idPedidoWeb: pedido.idPedidoWeb);
                                                setModalState(() {});
                                              },
                                            ),
                                            if (esPendiente) ...[
                                              const SizedBox(width: 6),
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0D9488),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                                icon: const Icon(LucideIcons.shoppingBag, size: 15),
                                                label: const Text('Cargar al Carrito'),
                                                onPressed: () async {
                                                  int itemsCargados = 0;
                                                  setState(() {
                                                    for (final itemWeb in pedido.items) {
                                                      Producto? prod;
                                                      for (final p in _productosDisponibles) {
                                                        if (p.idProducto == itemWeb.idProducto) {
                                                          prod = p;
                                                          break;
                                                        }
                                                      }
                                                      if (prod == null) {
                                                        final nomLimpio = itemWeb.nombre.trim().toLowerCase();
                                                        for (final p in _productosDisponibles) {
                                                          if (p.nombre.trim().toLowerCase() == nomLimpio) {
                                                            prod = p;
                                                            break;
                                                          }
                                                        }
                                                      }

                                                      if (prod != null) {
                                                        _agregarAlCarrito(prod, playSound: false, cantidad: itemWeb.cantidad);
                                                        itemsCargados++;
                                                      }
                                                    }

                                                    _identificarCliente = true;
                                                    _clienteNombreController.text = pedido.nombreCliente;
                                                    if (pedido.ahorroPromociones > 0) {
                                                      _aplicarPromocionesWeb = true;
                                                    }
                                                  });

                                                  await PedidoWebService.marcarComoCargadoEnPos(pedido.idPedido, idPedidoWeb: pedido.idPedidoWeb);
                                                  KarlizSoundService.instance.playBarcodeBeep();

                                                  if (ctx.mounted) {
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '¡Pedido de ${pedido.nombreCliente} ($itemsCargados productos) cargado al carrito!',
                                                        ),
                                                        backgroundColor: const Color(0xFF0D9488),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  Future<void> _mostrarModalDescuentoManual({CartItem? itemEspecifico}) async {
    if (_carrito.isEmpty && itemEspecifico == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade productos a la canasta antes de aplicar un descuento.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (AuthService.esCajero) {
      final autorizado = await SolicitarPinDialog.mostrar(
        context,
        titulo: 'Autorización de Descuento',
        mensaje: 'Se requiere PIN de Administrador para aplicar un descuento manual o de cortesía.',
      );
      if (!mounted) return;
      if (autorizado != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada o PIN incorrecto.'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }
    }

    final double baseCalculo = itemEspecifico != null
        ? itemEspecifico.subtotalBruto
        : _subtotalVenta;

    final valorCtrl = TextEditingController();
    final motivoCtrl = TextEditingController(text: 'Cortesía');
    bool esPorcentaje = false;

    if (!mounted) return;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) {
        final isDark = Theme.of(dlgCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final double val = double.tryParse(valorCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
            final double dsctoCalculado = esPorcentaje
                ? (baseCalculo * (val / 100.0)).clamp(0.0, baseCalculo)
                : val.clamp(0.0, baseCalculo);

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.tag, color: AppTheme.brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      itemEspecifico != null
                          ? 'Descuento en ${itemEspecifico.producto.nombre}'
                          : 'Descuento de Cortesía / Manual',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base sobre la cual aplica: S/ ${baseCalculo.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Monto Fijo (S/)')),
                            selected: !esPorcentaje,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => esPorcentaje = false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Porcentaje (%)')),
                            selected: esPorcentaje,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => esPorcentaje = true);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        labelText: esPorcentaje ? 'Porcentaje de Descuento (%)' : 'Monto de Descuento (S/)',
                        prefixText: esPorcentaje ? '% ' : 'S/ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (val > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Descuento a descontar: - S/ ${dsctoCalculado.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Motivo / Justificación:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final m in ['Cortesía', 'Redondeo', 'Empaque dañado', 'Familiar', 'Promoción especial'])
                          ActionChip(
                            label: Text(m, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDlgState(() => motivoCtrl.text = m);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: motivoCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ej. Cortesía al vecino / cliente frecuente',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dlgCtx, true),
                  child: const Text('Aplicar Descuento'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true) {
      final double val = double.tryParse(valorCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
      final double dsctoFinal = esPorcentaje
          ? (baseCalculo * (val / 100.0)).clamp(0.0, baseCalculo)
          : val.clamp(0.0, baseCalculo);
      final motivoFinal = motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : 'Cortesía';

      final totalAnterior = _totalVenta;
      setState(() {
        if (itemEspecifico != null) {
          itemEspecifico.descuentoManual = dsctoFinal;
          itemEspecifico.descuentoMotivo = motivoFinal;
        } else {
          _descuentoManualCarrito = dsctoFinal;
          _descuentoManualMotivo = motivoFinal;
        }
        _actualizarMontoExactoSiCorresponde(totalAnterior);
      });

      KarlizSoundService.instance.playBarcodeBeep();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Descuento de S/ ${dsctoFinal.toStringAsFixed(2)} ($motivoFinal) aplicado.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _registrarConsumoInterno() async {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade productos a la canasta para registrar el autoconsumo.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (AuthService.esCajero) {
      final autorizado = await SolicitarPinDialog.mostrar(
        context,
        titulo: 'Autorización de Consumo Interno',
        mensaje: 'Se requiere PIN de Administrador para autorizar salida por autoconsumo o uso de la bodega.',
      );
      if (!mounted) return;
      if (autorizado != true) return;
    }

    final double totalCosto = _carrito.fold(
      0.0,
      (acc, it) => acc + ((it.producto.precioCosto ?? 0.0) * it.cantidad),
    );

    final motivoCtrl = TextEditingController(text: 'Refrigerio de personal');

    if (!mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.coffee, color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Consumo Interno / Bodega',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Los productos se darán de baja del stock al costo sin generar cobro en caja:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (final it in _carrito)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${_formatCantidad(it.cantidad)}x ${it.producto.nombre}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                ),
                              ),
                              Text(
                                'Costo: S/ ${((it.producto.precioCosto ?? 0.0) * it.cantidad).toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Valor total al costo:', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                          Text(
                            'S/ ${totalCosto.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Motivo del consumo:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TextField(
                  controller: motivoCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej. Refrigerio de personal, Limpieza de local, Muestra',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              icon: const Icon(LucideIcons.check, size: 16),
              label: const Text('Confirmar Autoconsumo'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      final motivo = motivoCtrl.text.trim().isNotEmpty ? motivoCtrl.text.trim() : 'Consumo interno de bodega';
      setState(() => _isProcesando = true);

      int exitos = 0;
      for (final it in _carrito) {
        if (it.producto.idProducto != null) {
          final ok = await _movimientoService.registrarAjuste(
            idProducto: it.producto.idProducto!,
            cantidad: it.cantidad,
            tipoAjuste: 'CONSUMO_INTERNO',
            motivo: 'Consumo Interno: $motivo',
          );
          if (ok) exitos++;
        }
      }

      setState(() => _isProcesando = false);
      _vaciarCarrito();
      KarlizSoundService.instance.playBarcodeBeep();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $exitos productos registrados como consumo interno de bodega.'),
            backgroundColor: const Color(0xFF8B5CF6),
          ),
        );
      }
    }
  }

  Widget _buildDescuentoManualBanner(bool isDark) {
    final double itemDsctos = _carrito.fold(0.0, (acc, it) => acc + it.descuentoManual);
    final double totalDscto = _descuentoManualCarrito + itemDsctos;

    if (totalDscto > 0.01) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.tag, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎁 Descuento Manual / Cortesía: -S/ ${totalDscto.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    ),
                  ),
                  if (_descuentoManualMotivo.isNotEmpty)
                    Text(
                      'Motivo: $_descuentoManualMotivo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF2563EB)),
              tooltip: 'Quitar descuento manual',
              onPressed: () {
                final totalAnterior = _totalVenta;
                setState(() {
                  _descuentoManualCarrito = 0.0;
                  _descuentoManualMotivo = '';
                  for (final it in _carrito) {
                    it.descuentoManual = 0.0;
                    it.descuentoMotivo = null;
                  }
                  _actualizarMontoExactoSiCorresponde(totalAnterior);
                });
              },
            ),
          ],
        ),
      );
    }

    if (_carrito.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF2563EB),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
        ),
        icon: const Icon(LucideIcons.tag, size: 14),
        label: Text(
          '+ Descuento / Cortesía',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: () => _mostrarModalDescuentoManual(),
      ),
    );
  }

  void _abrirModalGarantiaEnvase({
    int? cantidadSugerida,
    String? tipoBotellaSugerida,
    Cliente? clientePreseleccionado,
  }) async {
    HapticFeedback.lightImpact();
    List<Cliente> clientes = [];
    try {
      clientes = await _clienteService.getClientes();
    } catch (_) {}
    if (!mounted) return;
    NuevaGarantiaSheet.show(
      context,
      clientesDisponibles: clientes,
      clienteInicial: clientePreseleccionado ?? _clienteSeleccionado,
      cantidadInicial: cantidadSugerida,
      tipoBotellaInicial: tipoBotellaSugerida,
      onGuardado: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Garantía de botellas registrada exitosamente en custodia!',
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  bool _esBotellaRetornable(String nombreProducto, [String? categoria]) {
    final n = nombreProducto.toLowerCase();
    final cat = (categoria ?? '').toLowerCase();

    // Descartar explícitamente no retornables o latas/packs descartables
    if (n.contains('no retornable') ||
        n.contains('descartable') ||
        n.contains('lata') ||
        n.contains('six pack') ||
        n.contains('sixpack') ||
        n.contains('pack') ||
        n.contains('tetra') ||
        n.contains('caja')) {
      return false;
    }

    // Coincidencias directas por palabra clave
    if (n.contains('retornable') ||
        n.contains('retorn.') ||
        n.contains('retorn') ||
        n.contains('envase')) {
      return true;
    }

    // Bidones y galoneras de agua que requieren garantía de envase
    if (n.contains('bidon') || n.contains('bidón') || n.contains('galonera')) {
      return true;
    }

    // Cervezas clásicas en botella de vidrio de bodega peruana
    final esCerveza =
        cat.contains('cerveza') ||
        cat.contains('licor') ||
        n.contains('cerveza') ||
        n.contains('cristal') ||
        n.contains('pilsen') ||
        n.contains('cusqueña') ||
        n.contains('cusquena') ||
        n.contains('arequipeña') ||
        n.contains('trujillo') ||
        n.contains('stella') ||
        n.contains('corona');

    if (esCerveza) {
      if (n.contains('650') ||
          n.contains('630') ||
          n.contains('620') ||
          n.contains('1l') ||
          n.contains('1 litro') ||
          n.contains('1.1l') ||
          n.contains('litro') ||
          n.contains('botella') ||
          n.contains('vidrio')) {
        return true;
      }
    }

    // Gaseosas retornables clásicas
    final esGaseosa =
        cat.contains('gaseosa') ||
        cat.contains('bebida') ||
        n.contains('inca kola') ||
        n.contains('inka kola') ||
        n.contains('coca cola') ||
        n.contains('pepsi') ||
        n.contains('concordia') ||
        n.contains('kola real') ||
        n.contains('fanta') ||
        n.contains('sprite');

    if (esGaseosa) {
      if (n.contains('vidrio') ||
          n.contains('gordita') ||
          n.contains('1l') ||
          n.contains('1.5l') ||
          n.contains('litro')) {
        return true;
      }
    }

    return false;
  }

  String _determinarTipoBotella(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('bidon') || n.contains('bidón') || n.contains('galonera')) {
      return 'Bidón / Galonera';
    }
    if (n.contains('personal') ||
        n.contains('300') ||
        n.contains('296') ||
        n.contains('330') ||
        n.contains('355')) {
      return 'Personal Vidrio';
    }
    if (n.contains('1l') ||
        n.contains('1 litro') ||
        n.contains('litro') ||
        n.contains('1.1l')) {
      if (n.contains('cerveza') ||
          n.contains('cristal') ||
          n.contains('pilsen') ||
          n.contains('cusque')) {
        return 'Cerveza 1L';
      }
      return 'Gaseosa 1L / 1.5L';
    }
    if (n.contains('1.5l') || n.contains('1.25l')) {
      return 'Gaseosa 1L / 1.5L';
    }
    if (n.contains('gaseosa') || n.contains('kola') || n.contains('cola')) {
      return 'Gaseosa 1L / 1.5L';
    }
    return 'Cerveza 650ml';
  }

  int get _totalBotellasRetornablesEnCarrito {
    int total = 0;
    for (final item in _carrito) {
      if (_esBotellaRetornable(
        item.producto.nombre,
        item.producto.nombreCategoria,
      )) {
        total += item.cantidad.toInt();
      }
    }
    return total;
  }

  String get _tipoBotellaSugeridaEnCarrito {
    for (final item in _carrito) {
      if (_esBotellaRetornable(
        item.producto.nombre,
        item.producto.nombreCategoria,
      )) {
        return _determinarTipoBotella(item.producto.nombre);
      }
    }
    return 'Cerveza 650ml';
  }

  Widget _buildRetornablesCartBanner(bool isDark) {
    final int count = _totalBotellasRetornablesEnCarrito;
    if (count <= 0) return const SizedBox.shrink();

    final tipoSugerido = _tipoBotellaSugeridaEnCarrito;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.wine,
              size: 16,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count ${count == 1 ? "botella retornable" : "botellas retornables"} en carrito',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
                Text(
                  '¿El cliente trajo envases vacíos para cambio?',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _abrirModalGarantiaEnvase(
              cantidadSugerida: count,
              tipoBotellaSugerida: tipoSugerido,
              clientePreseleccionado: _clienteSeleccionado,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Garantía',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      final productosFrescos = await _productoService.getProductos(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _productosDisponibles = List<Producto>.from(
            productosFrescos.where((p) => p.stockActual > 0),
          );
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

    double cantidadPesada = 1.0;
    bool esBalanzaDetectada = false;

    // 3. Decodificador Inteligente de Balanza Electrónica (Estándar GS1 in-store 13 dígitos)
    // Prefijo (2 dígitos: 20 ó 21) + SKU Producto (4 ó 5 dígitos) + Peso en gramos (5 dígitos) + Checksum (1 dígito)
    if (productoEncontrado == null &&
        codeClean.length == 13 &&
        (codeClean.startsWith('20') || codeClean.startsWith('21'))) {
      final prodSku5 = codeClean.substring(2, 7);
      final prodSku4 = codeClean.substring(2, 6);
      final rawWeight = int.tryParse(codeClean.substring(7, 12)) ?? 0;

      if (rawWeight > 0) {
        cantidadPesada = rawWeight / 1000.0;
        for (final p in _safeDisponibles) {
          if (_coincideCodigoBalanza(p, prodSku5, prodSku4)) {
            productoEncontrado = p;
            esBalanzaDetectada = true;
            break;
          }
        }
        if (productoEncontrado == null) {
          final productosFrescos = await _productoService.getProductos(
            forceRefresh: true,
          );
          for (final p in productosFrescos) {
            if (_coincideCodigoBalanza(p, prodSku5, prodSku4)) {
              productoEncontrado = p;
              esBalanzaDetectada = true;
              break;
            }
          }
        }
      }
    }

    // 4. Evaluar el producto si fue encontrado
    if (productoEncontrado != null) {
      // Verificar si realmente tiene stock
      if (productoEncontrado.stockActual <= 0) {
        KarlizSoundService.instance.playErrorBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El producto "${productoEncontrado.nombre}" existe en el catálogo pero no cuenta con stock disponible (0 u.)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.alertRed,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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

      if (currentInCart.cantidad + cantidadPesada >
          productoEncontrado.stockActual) {
        KarlizSoundService.instance.playErrorBeep();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stock máximo alcanzado para "${productoEncontrado.nombre}" (${_formatStock(productoEncontrado.stockActual)} u. disponibles)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.alertRed,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
        return;
      }

      // Añadir directamente a la canasta con audio de éxito
      _agregarAlCarrito(
        productoEncontrado,
        playSound: true,
        cantidad: cantidadPesada,
      );

      if (mounted) {
        final restante =
            (productoEncontrado.stockActual -
                    currentInCart.cantidad -
                    cantidadPesada)
                .clamp(0.0, 999999.0);
        if (esBalanzaDetectada) {
          final importeBalanza =
              productoEncontrado.precioVenta * cantidadPesada;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.scale, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚖️ Balanza detectada: ${productoEncontrado.nombre} • ${_formatCantidad(cantidadPesada)} kg (S/ ${importeBalanza.toStringAsFixed(2)})',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0D9488),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Agregado: ${productoEncontrado.nombre} (S/ ${productoEncontrado.precioVenta.toStringAsFixed(2)}) • Quedan ${_formatStock(restante)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        }
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
                  'Código "$codeClean" no encontrado en el inventario',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE11D48),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  void _editarCantidadDirecta(int index) {
    final item = _carrito[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final esPesable = item.producto.esPesableOGranel;
    final pv = item.producto.precioVenta;
    final stockFormatted = _formatStock(item.producto.stockActual);

    int modo = 0; // 0 = Cantidad / Peso, 1 = Por Dinero (S/.)
    final initialQty = _formatCantidad(item.cantidad);
    final cantCtrl = TextEditingController(text: initialQty);
    final dineroCtrl = TextEditingController(
      text: (item.cantidad * pv).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cantActual =
              double.tryParse(cantCtrl.text.trim().replaceAll(',', '.')) ??
              item.cantidad;
          final importeActual =
              double.tryParse(dineroCtrl.text.trim().replaceAll(',', '.')) ??
              (cantActual * pv);
          final cantCalculada = pv > 0 ? (importeActual / pv) : 0.0;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esPesable ? LucideIcons.scale : LucideIcons.hash,
                    color: AppTheme.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esPesable
                            ? 'Venta por Peso / Granel'
                            : 'Modificar Cantidad',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        item.producto.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(dlgCtx),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Selector de Modo
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.cardDarkSunken
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  modo = 0;
                                  cantCtrl.text = _formatCantidad(
                                    cantCalculada > 0
                                        ? cantCalculada
                                        : item.cantidad,
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: modo == 0
                                      ? (isDark
                                            ? AppTheme.cardDarkElevated
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: modo == 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  esPesable
                                      ? '⚖️ Por Kilos / Cantidad'
                                      : '🔢 Cantidad',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: modo == 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                    color: modo == 0
                                        ? AppTheme.brandPrimary
                                        : (isDark
                                              ? AppTheme.textDarkMuted
                                              : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  modo = 1;
                                  dineroCtrl.text = (cantActual * pv)
                                      .toStringAsFixed(2);
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: modo == 1
                                      ? (isDark
                                            ? AppTheme.cardDarkElevated
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: modo == 1
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  '💵 Por Dinero (S/.)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: modo == 1
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                    color: modo == 1
                                        ? const Color(0xFF0D9488)
                                        : (isDark
                                              ? AppTheme.textDarkMuted
                                              : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Información de stock y precio base
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock: $stockFormatted ${esPesable ? 'kg/u' : 'unid.'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'P. Venta: S/ ${pv.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (modo == 0) ...[
                      // MODO 0: Cantidad / Peso
                      TextField(
                        controller: cantCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: esPesable
                              ? 'Peso / Cantidad'
                              : 'Cantidad a vender',
                          suffixText: esPesable ? 'kg' : 'unid.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Chips de acceso rápido
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (esPesable) ...[
                            ActionChip(
                              label: const Text('¼ kg (0.25)'),
                              onPressed: () {
                                cantCtrl.text = '0.25';
                                setModalState(() {});
                              },
                            ),
                            ActionChip(
                              label: const Text('½ kg (0.50)'),
                              onPressed: () {
                                cantCtrl.text = '0.50';
                                setModalState(() {});
                              },
                            ),
                            ActionChip(
                              label: const Text('¾ kg (0.75)'),
                              onPressed: () {
                                cantCtrl.text = '0.75';
                                setModalState(() {});
                              },
                            ),
                            ActionChip(
                              label: const Text('1 kg'),
                              onPressed: () {
                                cantCtrl.text = '1.0';
                                setModalState(() {});
                              },
                            ),
                            ActionChip(
                              label: const Text('2 kg'),
                              onPressed: () {
                                cantCtrl.text = '2.0';
                                setModalState(() {});
                              },
                            ),
                          ] else ...[
                            if (item.producto.stockActual >= 6)
                              ActionChip(
                                label: const Text('+6 (Six-pack)'),
                                onPressed: () {
                                  cantCtrl.text = '6';
                                  setModalState(() {});
                                },
                              ),
                            if (item.producto.stockActual >= 12)
                              ActionChip(
                                label: const Text('+12 (Docena)'),
                                onPressed: () {
                                  cantCtrl.text = '12';
                                  setModalState(() {});
                                },
                              ),
                            if (item.producto.stockActual >= 24)
                              ActionChip(
                                label: const Text('+24 (Caja)'),
                                onPressed: () {
                                  cantCtrl.text = '24';
                                  setModalState(() {});
                                },
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Importe Total:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'S/ ${(cantActual * pv).toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // MODO 1: Calculadora Inversa ("Deme S/ 2 de queso")
                      TextField(
                        controller: dineroCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0D9488),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Importe solicitado en Soles',
                          prefixText: 'S/ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in [1.0, 1.5, 2.0, 3.0, 5.0, 10.0])
                            ActionChip(
                              label: Text('S/ ${m.toStringAsFixed(2)}'),
                              onPressed: () {
                                dineroCtrl.text = m.toStringAsFixed(2);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF0D9488)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.sparkles,
                                  size: 16,
                                  color: Color(0xFF0D9488),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cálculo Inverso Automático',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: const Color(0xFF0D9488),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '💡 Equivale a ${_formatCantidad(cantCalculada)} ${esPesable ? 'kg (${(cantCalculada * 1000).toStringAsFixed(0)} g)' : 'unidades'}',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: modo == 0
                      ? AppTheme.brandPrimary
                      : const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final finalQty = modo == 0
                      ? (double.tryParse(
                              cantCtrl.text.trim().replaceAll(',', '.'),
                            ) ??
                            item.cantidad)
                      : cantCalculada;

                  if (finalQty <= 0) {
                    _eliminarDelCarrito(index);
                    Navigator.pop(dlgCtx);
                    return;
                  }
                  if (finalQty > item.producto.stockActual) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stock insuficiente: solo hay $stockFormatted disponibles.',
                        ),
                        backgroundColor: AppTheme.alertRed,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    item.cantidad = finalQty;
                    if (_metodoPago == 'Efectivo' &&
                        _pagoConController.text.isNotEmpty) {
                      _pagoConController.text = _totalVenta.toStringAsFixed(2);
                    }
                  });
                  Navigator.pop(dlgCtx);
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      cantCtrl.dispose();
      dineroCtrl.dispose();
    });
  }

  Widget _buildPromocionesCartBanner(bool isDark) {
    if (_promocionesAplicadas.isEmpty) return const SizedBox.shrink();

    final totalAhorroPotencial = _promocionesAplicadas.fold<double>(
      0.0,
      (acc, p) => acc + p.descuento,
    );
    if (totalAhorroPotencial <= 0.01) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _aplicarPromocionesWeb
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _aplicarPromocionesWeb
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.tag,
                size: 16,
                color: _aplicarPromocionesWeb
                    ? const Color(0xFF059669)
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _aplicarPromocionesWeb
                          ? '🎉 ¡Ahorro en Promoción: -S/ ${totalAhorroPotencial.toStringAsFixed(2)}!'
                          : '🏷️ Promoción Web disponible (-S/ ${totalAhorroPotencial.toStringAsFixed(2)})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _aplicarPromocionesWeb
                            ? (isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF065F46))
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                    Text(
                      _aplicarPromocionesWeb
                          ? 'Beneficio web aplicado al total de la venta'
                          : 'Toca el switch para aplicar si el cliente lo solicita',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _aplicarPromocionesWeb,
                  activeTrackColor: const Color(0xFF10B981)
                      .withValues(alpha: 0.5),
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _aplicarPromocionesWeb = val);
                  },
                ),
              ),
            ],
          ),
          if (_aplicarPromocionesWeb) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final pa in _promocionesAplicadas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pa.descripcion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFF065F46),
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
        if (codeDigits.length == 13 &&
            codeDigits.startsWith('0') &&
            codeDigits.substring(1) == bcDigits)
          return true;
        if (bcDigits.length == 13 &&
            bcDigits.startsWith('0') &&
            bcDigits.substring(1) == codeDigits)
          return true;
        if (codeDigits.length == 14 &&
            codeDigits.startsWith('00') &&
            codeDigits.substring(2) == bcDigits)
          return true;
        if (bcDigits.length == 14 &&
            bcDigits.startsWith('00') &&
            bcDigits.substring(2) == codeDigits)
          return true;
      }
    }

    return false;
  }

  bool _coincideCodigoBalanza(Producto p, String sku5, String sku4) {
    final cod = p.codigo.trim().toLowerCase();
    final bc = (p.codigoBarras ?? '').trim().toLowerCase();
    final sku5Num = int.tryParse(sku5)?.toString() ?? '';
    final sku4Num = int.tryParse(sku4)?.toString() ?? '';

    return cod == sku5.toLowerCase() ||
        (sku5Num.isNotEmpty && cod == sku5Num) ||
        cod == sku4.toLowerCase() ||
        (sku4Num.isNotEmpty && cod == sku4Num) ||
        bc == sku5.toLowerCase() ||
        (sku5Num.isNotEmpty && bc == sku5Num) ||
        bc == sku4.toLowerCase() ||
        (sku4Num.isNotEmpty && bc == sku4Num);
  }

  void _mostrarModalInfoProducto(Producto p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final promo = _obtenerPromocionActivaParaProducto(p);
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final catColor = CategoryHelper.getColor(p.nombreCategoria, isDark);
    final categoriaNombre = p.nombreCategoria?.trim() ?? 'General';
    final isLowStock =
        p.stockActual <= (p.stockMinimo > 0 ? p.stockMinimo : 5.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cartIdx = _carrito.indexWhere(
              (it) => it.producto.idProducto == p.idProducto,
            );
            final inCart = cartIdx != -1;
            final inCartQty = inCart ? _carrito[cartIdx].cantidad : 0.0;

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
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
                            color: isDark
                                ? AppTheme.borderDarkElevated
                                : const Color(0xFFE2E8F0),
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
                                  color: catColor.withValues(
                                    alpha: isDark ? 0.2 : 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CategoryHelper.getIcon(p.nombreCategoria),
                                  size: 16,
                                  color: catColor,
                                ),
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
                            color: isDark ? Colors.white : Colors.black54,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Imagen en Grande del Producto (140 px de estudio)
                      Center(
                        child: ProductImageWidget(
                          imagenUrl: p.imagenUrl,
                          nombre: p.nombre,
                          codigoBarras: p.codigoBarras,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.borderDarkElevated
                                    : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'SKU: ${p.codigo}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (p.marca != null && p.marca!.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDarkElevated
                                      : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Marca: ${p.marca}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          if (p.codigoBarras != null &&
                              p.codigoBarras!.trim().isNotEmpty &&
                              p.codigoBarras != p.codigo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDarkElevated
                                      : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.barcode,
                                    size: 12,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    p.codigoBarras!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (p.controlaVencimiento)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.shade700.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.calendarClock,
                                    size: 11,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Controla Vencimiento',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (promo != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  promo.badgeTexto.isNotEmpty
                                      ? promo.badgeTexto
                                      : '🔥 PROMO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      promo.titulo,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark,
                                      ),
                                    ),
                                    if (promo.descripcion.isNotEmpty)
                                      Text(
                                        promo.descripcion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFF991B1B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Tarjetas Informativas: Precio + Stock Actual
                      Row(
                        children: [
                          // Precio de Venta
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF131D2E)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Precio Unitario',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? AppTheme.textDarkSecondary
                                          : const Color(0xFF334155),
                                      fontWeight: FontWeight.w700,
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
                                    : (isDark
                                          ? const Color(0xFF132A24)
                                          : const Color(0xFFECFDF5)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isLowStock
                                      ? AppTheme.alertRed.withValues(alpha: 0.4)
                                      : (isDark
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFFA7F3D0)),
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
                                          fontSize: 11.5,
                                          color: isLowStock
                                              ? (isDark
                                                    ? const Color(0xFFF87171)
                                                    : AppTheme.alertRed)
                                              : (isDark
                                                    ? AppTheme.textDarkSecondary
                                                    : const Color(0xFF334155)),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (isLowStock) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          LucideIcons.alertTriangle,
                                          size: 12,
                                          color: AppTheme.alertRed,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_formatStock(p.stockActual)} u.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: isLowStock
                                          ? AppTheme.alertRed
                                          : const Color(0xFF059669),
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
                            backgroundColor: inCart
                                ? const Color(0xFF0D9488)
                                : AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                              Icon(
                                inCart
                                    ? LucideIcons.plus
                                    : LucideIcons.shoppingBag,
                                size: 18,
                              ),
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
                ),
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
        bool soloPromociones = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final promosCount = _safeDisponibles
                .where((p) => _obtenerPromocionActivaParaProducto(p) != null)
                .length;

            final filtrados = _safeDisponibles.where((p) {
              if (soloPromociones &&
                  _obtenerPromocionActivaParaProducto(p) == null) {
                return false;
              }
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              return p.nombre.toLowerCase().contains(q) ||
                  _coincideCodigo(p, q) ||
                  (p.codigoBarras ?? '').toLowerCase().contains(q);
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.78,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDarkElevated : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: isDark
                        ? const Border(
                            top: BorderSide(
                              color: AppTheme.borderDarkElevated,
                              width: 1.2,
                            ),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.borderDarkElevated
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catálogo de Productos',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  'Toca cualquier producto para añadirlo a la canasta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.surfaceTintDark
                                  : AppTheme.surfaceTint,
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
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppTheme.cardDarkHighlight
                                  : const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(34, 34),
                            ),
                            icon: const Icon(LucideIcons.x, size: 18),
                            tooltip: 'Cerrar Catálogo',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.cardDarkSunken
                              : const Color(0xFFF5F6F8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFE2E8F0),
                          ),
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
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                LucideIcons.scanLine,
                                size: 18,
                                color: Color(0xFF0D9488),
                              ),
                              tooltip: 'Escanear código de barras',
                              onPressed: () async {
                                final code =
                                    await KarlizBarcodeScannerModal.scan(
                                      context,
                                    );
                                if (code != null && code.isNotEmpty) {
                                  searchCtrl.text = code;
                                  setModalState(() => query = code);
                                }
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => query = val);
                          },
                        ),
                      ),
                      if (promosCount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: !soloPromociones,
                              onSelected: (val) {
                                setModalState(() => soloPromociones = false);
                              },
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: !soloPromociones
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : AppTheme.textDark),
                              ),
                              selectedColor: AppTheme.brandPrimary,
                              backgroundColor: isDark
                                  ? AppTheme.cardDarkSunken
                                  : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              avatar: const Icon(
                                LucideIcons.tag,
                                size: 13,
                                color: Colors.white,
                              ),
                              label: Text('🔥 En Promoción ($promosCount)'),
                              selected: soloPromociones,
                              onSelected: (val) {
                                setModalState(() => soloPromociones = val);
                              },
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: soloPromociones
                                    ? Colors.white
                                    : (isDark
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFDC2626)),
                              ),
                              selectedColor: const Color(0xFFEF4444),
                              backgroundColor: isDark
                                  ? const Color(0xFF450A0A)
                                  : const Color(0xFFFEF2F2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtrados.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.brandPrimary
                                              .withValues(
                                                alpha: isDark ? 0.2 : 0.1,
                                              ),
                                          border: Border.all(
                                            color: AppTheme.brandPrimary
                                                .withValues(
                                                  alpha: isDark ? 0.35 : 0.2,
                                                ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            LucideIcons.packageSearch,
                                            size: 24,
                                            color: AppTheme.brandPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        query.isEmpty
                                            ? 'No hay productos en catálogo'
                                            : 'Sin coincidencias para "$query"',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Intenta escanear el código de barras o buscar por otra palabra clave.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtrados.length,
                                separatorBuilder: (_, index) => Divider(
                                  height: 1,
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : AppTheme.borderLight,
                                ),
                                itemBuilder: (context, idx) {
                                  final p = filtrados[idx];
                                  final inCart = _carrito.firstWhere(
                                    (c) =>
                                        c.producto.idProducto == p.idProducto,
                                    orElse: () =>
                                        CartItem(producto: p, cantidad: 0),
                                  );
                                  final bool yaEnCarrito = inCart.cantidad > 0;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    leading: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ProductImageWidget(
                                          imagenUrl: p.imagenUrl,
                                          nombre: p.nombre,
                                          codigoBarras: p.codigoBarras,
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
                                                color: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF475569)
                                                      : const Color(0xFFCBD5E1),
                                                  width: 1.0,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.35
                                                              : 0.1,
                                                        ),
                                                    blurRadius: 3,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  LucideIcons.info,
                                                  size: 9.5,
                                                  color: isDark
                                                      ? AppTheme
                                                            .textDarkSecondary
                                                      : const Color(0xFF475569),
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
                                              padding: const EdgeInsets.all(
                                                2.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.brandPrimary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF1E2430)
                                                      : Colors.white,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                LucideIcons.check,
                                                size: 9,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.nombre,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                        if (_obtenerPromocionActivaParaProducto(
                                              p,
                                            ) !=
                                            null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _obtenerPromocionActivaParaProducto(
                                                    p,
                                                  )!.badgeTexto.isNotEmpty
                                                  ? _obtenerPromocionActivaParaProducto(
                                                      p,
                                                    )!.badgeTexto
                                                  : '🔥 PROMO',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      'Disp: ${_formatStock(p.stockActual)} u.  •  Cód: ${p.codigo}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.textDarkSecondary
                                            : const Color(0xFF334155),
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
                                            backgroundColor:
                                                AppTheme.brandPrimary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.all(8),
                                            minimumSize: const Size(36, 36),
                                          ),
                                          icon: const Icon(
                                            LucideIcons.plus,
                                            size: 16,
                                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'LISTO • VOLVER A LA CANASTA (${_carrito.length} ITEMS)',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Future<RegistroVentaResult> _firmarVentaOffline(
    VentaEnvio envio,
    String uuid,
  ) async {
    final idBodega =
        int.tryParse(await SecureStorageService.read('id_bodega') ?? '0') ?? 0;
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

  Future<bool?> _mostrarDialogoAutorizarExcesoCredito(
    Cliente c,
    double montoVenta,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nuevoSaldo = c.saldoDeudor + montoVenta;
    final exceso = nuevoSaldo - c.limiteCredito;

    return showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.shieldAlert,
                color: AppTheme.alertRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Límite de Crédito Superado',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Se requiere autorización para fiar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.alertRed,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => Navigator.pop(dlgCtx, false),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El cliente ${c.nombreCompleto} superará su límite de crédito autorizado con esta compra:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.alertRed.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Límite asignado:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        'S/ ${c.limiteCredito.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deuda actual:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        'S/ ${c.saldoDeudor.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Venta actual:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '+ S/ ${montoVenta.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nuevo saldo total:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'S/ ${nuevoSaldo.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.alertRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exceso sobre el límite:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.alertRed,
                        ),
                      ),
                      Text(
                        '+ S/ ${exceso.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.alertRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(LucideIcons.check, size: 16),
            label: const Text('Autorizar Exceso'),
            onPressed: () => Navigator.pop(dlgCtx, true),
          ),
        ],
      ),
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
                    'Indica con cuánto paga el cliente o presiona "Pago Exacto" para continuar.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                const Icon(
                  LucideIcons.alertTriangle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Monto insuficiente: el cliente pagó S/ ${_montoRecibido.toStringAsFixed(2)}, faltan S/ ${faltante.toStringAsFixed(2)} para completar el total de S/ ${_totalVenta.toStringAsFixed(2)}.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                const Icon(
                  LucideIcons.handCoins,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selecciona un cliente para registrar la venta al crédito en la libreta.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
        _mostrarSelectorCliente();
        return;
      }

      // Semáforo de Riesgo: Validar límite de crédito antes de fiar
      if (_clienteSeleccionado!.excedeCon(_totalVenta)) {
        KarlizSoundService.instance.playErrorBeep();
        final bool? autorizar = await _mostrarDialogoAutorizarExcesoCredito(
          _clienteSeleccionado!,
          _totalVenta,
        );
        if (autorizar != true) return;
        if (!mounted) return;
      }
    }

    // Validar que todos los productos del carrito tengan un ID de base de datos válido
    for (final item in _carrito) {
      if (item.producto.idProducto == null || item.producto.idProducto! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El producto "${item.producto.nombre}" no tiene un ID válido. Actualiza la lista.',
            ),
            backgroundColor: AppTheme.alertRed,
          ),
        );
        return;
      }
    }

    final String docIngresado = _clienteDocController.text.trim();
    if (_identificarCliente) {
      if (docIngresado.isEmpty ||
          docIngresado.length != 8 ||
          !RegExp(r'^[0-9]{8}$').hasMatch(docIngresado)) {
        KarlizSoundService.instance.playErrorBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por favor ingresa un DNI válido de 8 dígitos numéricos.',
            ),
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
              content: Text(
                'Para Boletas de Venta iguales o mayores a S/ 700.00 es obligatorio identificar al cliente con su DNI.',
              ),
              backgroundColor: AppTheme.alertRed,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isProcesando = true);

    final idempotencyKey = UuidHelper.generateV4();

    final String? docCliente = (_identificarCliente && docIngresado.isNotEmpty)
        ? docIngresado
        : null;
    final String nomCliente =
        (_identificarCliente && _clienteNombreController.text.trim().isNotEmpty)
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
      idCliente: _metodoPago == 'Crédito'
          ? _clienteSeleccionado?.idCliente
          : null,
      clienteDocumento: finalDocCliente,
      clienteNombre: finalNomCliente,
      metodoPago: _metodoPago,
      tipoComprobante: _tipoComprobante,
      idempotencyKey: idempotencyKey,
      montoRecibido: _metodoPago == 'Efectivo'
          ? (_montoRecibido > 0 ? _montoRecibido : _totalVenta)
          : null,
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
        final ahorroPromos = _totalDescuentoPromociones;

        _vaciarCarrito();

        if (esOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.cloudOff,
                    color: Colors.white,
                    size: 18,
                  ),
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
            descuento: ahorroPromos,
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
          descuento: ahorroPromos,
        );
      } else {
        KarlizSoundService.instance.playErrorBeep();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.errorMessage ?? 'Error al registrar la venta.',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.alertRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
    double? descuento,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool esCredito = metodo == 'Crédito' || clienteCredito != null;

    int totalRetornablesVendidas = 0;
    String tipoBotellaDetectada = 'Cerveza 650ml';
    for (final it in items) {
      if (_esBotellaRetornable(
        it.producto.nombre,
        it.producto.nombreCategoria,
      )) {
        totalRetornablesVendidas += it.cantidad.toInt();
        tipoBotellaDetectada = _determinarTipoBotella(it.producto.nombre);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: esCredito
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esCredito ? LucideIcons.handCoins : LucideIcons.checkCheck,
                color: esCredito
                    ? const Color(0xFFD97706)
                    : AppTheme.accentGreen,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              esCredito
                  ? '¡Anotado en Libreta de Fiados!'
                  : '¡Cobro Realizado con Éxito!',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: 0.3),
                  ),
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
            if (ventaGenerada != null &&
                ventaGenerada.estadoSunat == 'OFFLINE_PENDIENTE') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.cloudOff,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
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
                final estado = (ventaGenerada.estadoSunat ?? 'ACEPTADO')
                    .toUpperCase();
                final Color badgeColor;
                final IconData badgeIcon;
                final String badgeText;

                switch (estado) {
                  case 'ACEPTADO':
                    badgeColor = AppTheme.accentGreen;
                    badgeIcon = LucideIcons.checkCircle2;
                    badgeText =
                        '${ventaGenerada.etiquetaComprobante} • EMITIDO';
                    break;
                  case 'ACEPTADO_BETA':
                    badgeColor = const Color(0xFF0D9488);
                    badgeIcon = LucideIcons.checkCheck;
                    badgeText =
                        '${ventaGenerada.etiquetaComprobante} • MODO PRUEBA';
                    break;
                  case 'RECHAZADO':
                    badgeColor = const Color(0xFFEF4444);
                    badgeIcon = LucideIcons.alertCircle;
                    badgeText =
                        '${ventaGenerada.etiquetaComprobante} • RECHAZADO';
                    break;
                  case 'PENDIENTE_ENVIO':
                  default:
                    badgeColor = const Color(0xFFF59E0B);
                    badgeIcon = LucideIcons.clock;
                    badgeText =
                        '${ventaGenerada.etiquetaComprobante} • PENDIENTE';
                    break;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
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
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Resumen de productos en el diálogo
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
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
                        '${_formatCantidad(it.cantidad)}x ',
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
                          color: isDark ? Colors.white : AppTheme.textDark,
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
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  if (descuento != null && descuento > 0.01) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ahorro en Promociones:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        Text(
                          '-S/ ${descuento.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cobrado:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textMuted,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: vuelto > 0
                            ? (isDark
                                  ? const Color(0xFF064E3B)
                                        .withValues(alpha: 0.35)
                                  : const Color(0xFFD1FAE5))
                            : (isDark
                                  ? const Color(0xFF172554)
                                        .withValues(alpha: 0.35)
                                  : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vuelto > 0
                              ? AppTheme.accentGreen
                              : const Color(0xFF3B82F6),
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
                                  color: vuelto > 0
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                'Pagó con S/ ${pagadoCon.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            vuelto > 0
                                ? 'S/ ${vuelto.toStringAsFixed(2)}'
                                : 'EXACTO',
                            style: GoogleFonts.outfit(
                              fontSize: vuelto > 0 ? 20 : 14,
                              fontWeight: FontWeight.w900,
                              color: vuelto > 0
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF2563EB),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (totalRetornablesVendidas > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.wine,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¿El cliente se lleva envases vacíos?',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se ${totalRetornablesVendidas == 1 ? "vendió 1 botella retornable" : "vendieron $totalRetornablesVendidas botellas retornables"}. Si no dejó envases a cambio, registra la garantía en custodia para respaldar la devolución.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(LucideIcons.shieldAlert, size: 16),
                        label: Text(
                          'REGISTRAR GARANTÍA ($totalRetornablesVendidas ${totalRetornablesVendidas == 1 ? "BOTELLA" : "BOTELLAS"})',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _abrirModalGarantiaEnvase(
                            cantidadSugerida: totalRetornablesVendidas,
                            tipoBotellaSugerida: tipoBotellaDetectada,
                            clientePreseleccionado:
                                clienteCredito ?? _clienteSeleccionado,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: Text(
                  esCredito
                      ? 'ENVIAR TICKET AL WHATSAPP DEL VECINO'
                      : 'COMPARTIR POR WHATSAPP',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
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
                        side: const BorderSide(
                          color: AppTheme.brandPrimary,
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(LucideIcons.printer, size: 17),
                      label: Text(
                        'IMPRIMIR ESC/POS',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        _despacharImpresionDirecta(
                          items: items,
                          total: total,
                          metodo: metodo,
                          pagadoCon: pagadoCon,
                          vuelto: vuelto,
                          ventaGenerada: ventaGenerada,
                          descuento: descuento,
                          silencioso: false,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    side: const BorderSide(
                      color: AppTheme.brandPrimary,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  tooltip: 'Vista Previa del Ticket',
                  icon: const Icon(
                    LucideIcons.eye,
                    size: 18,
                    color: AppTheme.brandPrimary,
                  ),
                  onPressed: () {
                    _mostrarTicketTermicoDialog(
                      items: items,
                      total: total,
                      metodo: metodo,
                      pagadoCon: pagadoCon,
                      vuelto: vuelto,
                      ventaGenerada: ventaGenerada,
                      descuento: descuento,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'NUEVA VENTA',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
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
    double? descuento,
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
      clienteNombre:
          (!_identificarCliente || _clienteNombreController.text.trim().isEmpty)
          ? 'Público General'
          : _clienteNombreController.text.trim(),
      clienteDocumento:
          (!_identificarCliente || _clienteDocController.text.trim().isEmpty)
          ? null
          : _clienteDocController.text.trim(),
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
      forzarAperturaGaveta:
          cfg.abrirGaveta && metodo.toLowerCase().contains('efectivo'),
    );

    final receiptText = ThermalTicketService.generateReceiptText(
      ticketId: ventaGenerada?.idVenta,
      clienteNombre:
          (!_identificarCliente || _clienteNombreController.text.trim().isEmpty)
          ? 'Público General'
          : _clienteNombreController.text.trim(),
      clienteDocumento:
          (!_identificarCliente || _clienteDocController.text.trim().isEmpty)
          ? null
          : _clienteDocController.text.trim(),
      metodoPago: metodo,
      items: ticketItems,
      total: total,
      descuento: descuento,
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
          backgroundColor: res.exito
              ? AppTheme.accentGreen
              : const Color(0xFFEF4444),
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
    double? descuento,
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
          final cfg = ConfiguracionTicketService.actual.copyWith(
            anchoPapel: selectedWidth,
          );

          final receiptText = ThermalTicketService.generateReceiptText(
            ticketId: ventaGenerada?.idVenta,
            clienteNombre:
                (!_identificarCliente ||
                    _clienteNombreController.text.trim().isEmpty)
                ? 'Público General'
                : _clienteNombreController.text.trim(),
            clienteDocumento:
                (!_identificarCliente ||
                    _clienteDocController.text.trim().isEmpty)
                ? null
                : _clienteDocController.text.trim(),
            metodoPago: metodo,
            items: ticketItems,
            total: total,
            descuento: descuento,
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
            backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.printer,
                  color: AppTheme.brandPrimary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ticket Térmico POS',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.settings, size: 18),
                  tooltip: 'Configurar Pie de Ticket y Gaveta',
                  onPressed: () async {
                    await ConfiguracionTicketModal.show(context);
                    setDlgState(() {
                      selectedWidth =
                          ConfiguracionTicketService.actual.anchoPapel;
                    });
                  },
                ),
                const SizedBox(width: 4),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: ThermalTicketService.width58mm,
                      label: Text('58mm'),
                    ),
                    ButtonSegment(
                      value: ThermalTicketService.width80mm,
                      label: Text('80mm'),
                    ),
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
              width: selectedWidth == ThermalTicketService.width58mm
                  ? 320
                  : 440,
              height: 360,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.cardDarkSunken
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
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
                      content: Text(
                        '¡Texto del ticket copiado al portapapeles!',
                      ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(LucideIcons.printer, size: 16),
                label: const Text('Imprimir ESC/POS'),
                onPressed: () async {
                  final escPosBytes = ThermalTicketService.generateEscPosBytes(
                    ticketId: ventaGenerada?.idVenta,
                    clienteNombre:
                        (!_identificarCliente ||
                            _clienteNombreController.text.trim().isEmpty)
                        ? 'Público General'
                        : _clienteNombreController.text.trim(),
                    clienteDocumento:
                        (!_identificarCliente ||
                            _clienteDocController.text.trim().isEmpty)
                        ? null
                        : _clienteDocController.text.trim(),
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
                    tipoComprobante:
                        ventaGenerada?.tipoComprobante ?? _tipoComprobante,
                    serieCorrelativo: ventaGenerada?.serieCorrelativo,
                    estadoSunat: ventaGenerada?.estadoSunat,
                    sunatHash: ventaGenerada?.sunatHash,
                    regimenTributario: _regimenTributario,
                    configTicket: cfg,
                    forzarAperturaGaveta:
                        cfg.abrirGaveta &&
                        metodo.toLowerCase().contains('efectivo'),
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
                        backgroundColor: res.exito
                            ? AppTheme.accentGreen
                            : const Color(0xFFEF4444),
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.brandPrimary),
      );
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

  Widget _buildPosActionChip({
    IconData? icon,
    bool isLoading = false,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 14, color: color),
              if (isLoading || icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineStatusBar(),
              // Barra Superior POS Rebrandeada Responsive
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                          : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.shoppingBag,
                      color: AppTheme.brandPrimary,
                      size: 22,
                    ),
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
                          'Cobro rápido con descuento de stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF134E4A)
                          : const Color(0xFFCCFBF1),
                      foregroundColor: const Color(0xFF0F766E),
                    ),
                    tooltip: 'Escanear con Cámara (Lector POS)',
                    icon: const Icon(LucideIcons.scanLine, size: 20),
                    onPressed: _escanearCodigoParaVenta,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: VentaEnEsperaService.countNotifier,
                      builder: (context, count, _) {
                        return _buildPosActionChip(
                          icon: LucideIcons.pauseCircle,
                          label: count > 0 ? 'En Espera ($count)' : 'En Espera',
                          color: count > 0 ? const Color(0xFFD97706) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          bgColor: count > 0
                              ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          onTap: _mostrarModalVentasEnEspera,
                          isDark: isDark,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<int>(
                      valueListenable: PedidoWebService.pedidosPendientesCountNotifier,
                      builder: (context, count, _) {
                        return _buildPosActionChip(
                          icon: LucideIcons.globe,
                          label: count > 0 ? 'Pedidos Web ($count)' : 'Pedidos Web',
                          color: count > 0 ? const Color(0xFF0D9488) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          bgColor: count > 0
                              ? (isDark ? const Color(0xFF134E4A).withValues(alpha: 0.3) : const Color(0xFFCCFBF1))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          onTap: _mostrarBandejaPedidosWeb,
                          isDark: isDark,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: _isLoading ? null : LucideIcons.refreshCw,
                      isLoading: _isLoading,
                      label: 'Sincronizar',
                      color: isDark ? Colors.white : const Color(0xFF475569),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      onTap: _isLoading
                          ? null
                          : () => _cargarProductos(forceRefresh: true),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.arrowDownRight,
                      label: 'Egreso Caja',
                      color: const Color(0xFFE11D48),
                      bgColor: isDark
                          ? const Color(0xFF4C0519)
                          : const Color(0xFFFFE4E6),
                      onTap: () => EgresoCajaModal.show(context),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.wine,
                      label: 'Garantía Botellas',
                      color: const Color(0xFF2563EB),
                      bgColor: isDark
                          ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                          : const Color(0xFFEFF6FF),
                      onTap: _abrirModalGarantiaEnvase,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.receiptText,
                      label: 'Cierre Caja',
                      color: AppTheme.brandPrimary,
                      bgColor: isDark
                          ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                          : AppTheme.surfaceTint,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CajaVentasScreen(),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.sparkles,
                      label: 'Tips Turno',
                      color: const Color(0xFF0284C7),
                      bgColor: isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                          : const Color(0xFFE0F2FE),
                      onTap: () => BriefingTurnoModal.show(context),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Selector de Comprobante (Boleta de Venta, Ticket de Venta - Nuevo RUS)
              _buildTipoComprobanteSelector(isDark),

              // Cliente (Consumidor Final / Con DNI)
              _buildCustomerCard(
                isDark,
                cardBg,
                borderColor,
                labelColor,
                isTablet: false,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_totalUnidadesTexto u.',
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Poner en Espera (Pausar Ticket)',
                                icon: const Icon(LucideIcons.pauseCircle, size: 18, color: Color(0xFFD97706)),
                                onPressed: _ponerVentaEnEspera,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Registrar como Consumo Interno de Bodega',
                                icon: const Icon(LucideIcons.coffee, size: 18, color: Color(0xFF8B5CF6)),
                                onPressed: _registrarConsumoInterno,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Garantía de Botellas / Retornables',
                                icon: const Icon(LucideIcons.wine, size: 18, color: Color(0xFF2563EB)),
                                onPressed: _abrirModalGarantiaEnvase,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 6),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de items en canasta o placeholder
                    if (_carrito.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.cardDarkSunken
                              : const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.borderDark
                                : const Color(0xFFE2E8F0),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.shoppingBag,
                                size: 36,
                                color: isDark
                                    ? AppTheme.textDarkMuted
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'La canasta está vacía',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Añade productos para cobrar la venta',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : AppTheme.textMuted,
                                ),
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
                          color: isDark
                              ? AppTheme.borderDark
                              : AppTheme.borderLight,
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: labelColor,
                                      ),
                                    ),
                                    Text(
                                      'S/ ${item.producto.precioVenta.toStringAsFixed(2)} c/u • Disp: ${_formatStock(item.producto.stockActual)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.textDarkSecondary
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Cantidad steppers
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDark
                                          ? AppTheme.cardDarkElevated
                                          : const Color(0xFFF1F5F9),
                                      foregroundColor: labelColor,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(26, 26),
                                    ),
                                    icon: const Icon(
                                      LucideIcons.minus,
                                      size: 13,
                                    ),
                                    onPressed: () => _decrementarCantidad(idx),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _editarCantidadDirecta(idx),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 26,
                                        minHeight: 26,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 2,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.cardDarkElevated
                                                  .withValues(alpha: 0.5)
                                            : const Color(0xFFF1F5F9)
                                                  .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatCantidad(item.cantidad),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: labelColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: isDark
                                          ? AppTheme.cardDarkElevated
                                          : const Color(0xFFF1F5F9),
                                      foregroundColor: labelColor,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(26, 26),
                                    ),
                                    icon: const Icon(
                                      LucideIcons.plus,
                                      size: 13,
                                    ),
                                    onPressed: () => _incrementarCantidad(idx),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 62,
                                  child: Text(
                                    'S/ ${item.subtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.brandPrimary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                icon: Icon(
                                  LucideIcons.trash2,
                                  size: 15,
                                  color: isDark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFEF4444),
                                ),
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
                                side: const BorderSide(
                                  color: AppTheme.brandPrimary,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              icon: const Icon(
                                LucideIcons.plusCircle,
                                size: 18,
                              ),
                              label: Text(
                                'Catálogo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              icon: const Icon(LucideIcons.scanLine, size: 18),
                              label: Text(
                                'Escanear',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
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
                    _buildPaymentAndCashSection(
                      isDark,
                      cardBg,
                      borderColor,
                      labelColor,
                      isTablet: false,
                    ),
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
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : AppTheme.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '$_totalUnidadesTexto productos en canasta',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.textDarkMuted
                                      : AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_promocionesAplicadas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildPromocionesCartBanner(isDark),
                    ],
                    const SizedBox(height: 6),
                    _buildDescuentoManualBanner(isDark),
                    if (_totalBotellasRetornablesEnCarrito > 0) ...[
                      const SizedBox(height: 12),
                      _buildRetornablesCartBanner(isDark),
                    ],
                    const SizedBox(height: 16),
                    _buildCobrarButton(
                      isDark: isDark,
                      height: 52,
                      isTablet: false,
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

  Widget _buildTabletLayout(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor,
  ) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineStatusBar(),
              // Barra de Acciones POS Integral para Tablet / Escritorio (Scrollable horizontal)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: VentaEnEsperaService.countNotifier,
                      builder: (context, count, _) {
                        return _buildPosActionChip(
                          icon: LucideIcons.pauseCircle,
                          label: count > 0 ? 'En Espera ($count)' : 'En Espera',
                          color: count > 0
                              ? const Color(0xFFD97706)
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          bgColor: count > 0
                              ? (isDark
                                    ? const Color(0xFF78350F).withValues(alpha: 0.3)
                                    : const Color(0xFFFEF3C7))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          onTap: _mostrarModalVentasEnEspera,
                          isDark: isDark,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<int>(
                      valueListenable: PedidoWebService.pedidosPendientesCountNotifier,
                      builder: (context, count, _) {
                        return _buildPosActionChip(
                          icon: LucideIcons.globe,
                          label: count > 0 ? 'Pedidos Web ($count)' : 'Pedidos Web',
                          color: count > 0
                              ? const Color(0xFF0D9488)
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          bgColor: count > 0
                              ? (isDark
                                    ? const Color(0xFF134E4A).withValues(alpha: 0.3)
                                    : const Color(0xFFCCFBF1))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          onTap: _mostrarBandejaPedidosWeb,
                          isDark: isDark,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.wine,
                      label: 'Garantía Botellas',
                      color: const Color(0xFF2563EB),
                      bgColor: isDark
                          ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                          : const Color(0xFFEFF6FF),
                      onTap: _abrirModalGarantiaEnvase,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.arrowDownRight,
                      label: 'Egreso Caja',
                      color: const Color(0xFFE11D48),
                      bgColor: isDark
                          ? const Color(0xFF4C0519)
                          : const Color(0xFFFFE4E6),
                      onTap: () => EgresoCajaModal.show(context),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.receiptText,
                      label: 'Cierre Caja',
                      color: AppTheme.brandPrimary,
                      bgColor: isDark
                          ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                          : AppTheme.surfaceTint,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CajaVentasScreen(),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.sparkles,
                      label: 'Tips Turno',
                      color: const Color(0xFF0284C7),
                      bgColor: isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                          : const Color(0xFFE0F2FE),
                      onTap: () => BriefingTurnoModal.show(context),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: LucideIcons.settings,
                      label: 'Ticket',
                      color: const Color(0xFF6B7280),
                      bgColor: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFF3F4F6),
                      onTap: () => ConfiguracionTicketModal.show(context),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildPosActionChip(
                      icon: _isLoading ? null : LucideIcons.refreshCw,
                      isLoading: _isLoading,
                      label: 'Sincronizar',
                      color: isDark ? Colors.white : const Color(0xFF475569),
                      bgColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      onTap: _isLoading
                          ? null
                          : () => _cargarProductos(forceRefresh: true),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PANEL IZQUIERDO: Catálogo Interactivo con densidad visual de terminal insignia
                    Expanded(
                      child: _buildTabletCatalogoPanel(
                        isDark,
                        cardBg,
                        borderColor,
                        labelColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PANEL DERECHO: Terminal de Cobro POS / Ticket Digital
                    SizedBox(
                      width: ticketWidth,
                      child: _buildTabletTicketPanel(
                        isDark,
                        cardBg,
                        borderColor,
                        labelColor,
                      ),
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

  Widget _buildFastKeysBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeyBadge('F2', 'Buscar', LucideIcons.search, isDark, () {
            _tabletSearchFocusNode.requestFocus();
            HapticFeedback.lightImpact();
          }),
          const SizedBox(width: 6),
          _buildKeyBadge(
            'F4',
            'Cobrar',
            LucideIcons.creditCard,
            isDark,
            _carrito.isEmpty
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _ejecutarCobroRapido();
                  },
          ),
          const SizedBox(width: 6),
          _buildKeyBadge(
            'F9',
            _tipoComprobante == 'BOLETA_ELECTRONICA' ? 'Boleta' : 'Ticket',
            LucideIcons.fileText,
            isDark,
            () {
              _alternarTipoComprobante();
            },
          ),
          const SizedBox(width: 6),
          _buildKeyBadge(
            'Esc',
            'Limpiar',
            LucideIcons.trash2,
            isDark,
            _carrito.isEmpty
                ? null
                : () {
                    _vaciarCarrito();
                  },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              MonitorNuevoRusModal.show(
                context,
                onRegimenCambiado: _cargarConfiguracionTributaria,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _regimenTributario == 'NUEVO_RUS'
                    ? AppTheme.accentGreen.withValues(alpha: 0.12)
                    : const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _regimenTributario == 'NUEVO_RUS'
                      ? AppTheme.accentGreen.withValues(alpha: 0.35)
                      : const Color(0xFF2563EB).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _regimenTributario == 'NUEVO_RUS'
                        ? LucideIcons.store
                        : LucideIcons.building2,
                    size: 13,
                    color: _regimenTributario == 'NUEVO_RUS'
                        ? AppTheme.accentGreen
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _regimenTributario == 'NUEVO_RUS'
                        ? 'NUEVO RUS'
                        : 'MYPE',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _regimenTributario == 'NUEVO_RUS'
                          ? AppTheme.accentGreen
                          : const Color(0xFF2563EB),
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

  Widget _buildKeyBadge(
    String keyLabel,
    String actionLabel,
    IconData icon,
    bool isDark,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? (enabled
                            ? AppTheme.cardDarkHighlight
                            : AppTheme.cardDark)
                      : (enabled
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDarkElevated
                        : const Color(0xFFCBD5E1),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  keyLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? (isDark ? AppTheme.brandLight : AppTheme.brandPrimary)
                        : (isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                icon,
                size: 11,
                color: enabled
                    ? (isDark ? Colors.white : const Color(0xFF334155))
                    : (isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 3),
              Text(
                actionLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (isDark ? Colors.white : const Color(0xFF334155))
                      : (isDark
                            ? AppTheme.textDarkMuted
                            : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletCatalogoPanel(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor,
  ) {
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
                    color: isDark
                        ? AppTheme.cardDarkSunken
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.borderDark
                          : const Color(0xFFCBD5E1),
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
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        size: 18,
                        color: AppTheme.brandPrimary,
                      ),
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
                  color: isDark
                      ? AppTheme.cardDarkElevated
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.boxes,
                      size: 15,
                      color: AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${productos.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Botón Escáner Láser / Cámara
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF134E4A)
                      : const Color(0xFFCCFBF1),
                  foregroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                  backgroundColor: isDark
                      ? AppTheme.cardDarkHighlight
                      : const Color(0xFFF1F5F9),
                  foregroundColor: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(44, 44),
                ),
                tooltip: 'Actualizar Catálogo & Stock',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: () => _cargarProductos(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Atajos rápidos de teclado para cajero (Fast-keys F2, F4, F9, Esc)
          _buildFastKeysBar(isDark),

          const SizedBox(height: 8),

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
                  final isSelected =
                      (_tabletSelectedCategoria ?? 'Todos') == cat;
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.brandPrimary
                              : (isDark
                                    ? AppTheme.cardDarkHighlight
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.brandPrimary
                                : (isDark
                                      ? AppTheme.borderDark
                                      : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.brandPrimary.withValues(
                                      alpha: 0.3,
                                    ),
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
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white
                                          : AppTheme.textDark),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : (isDark
                                          ? AppTheme.cardDarkElevated
                                          : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? AppTheme.textDarkSecondary
                                            : AppTheme.textMuted),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.brandPrimary.withValues(
                                alpha: isDark ? 0.18 : 0.09,
                              ),
                              border: Border.all(
                                color: AppTheme.brandPrimary.withValues(
                                  alpha: isDark ? 0.35 : 0.2,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.packageSearch,
                                size: 28,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _tabletSearchCtrl.text.isNotEmpty
                                ? 'Sin coincidencias para "${_tabletSearchCtrl.text}"'
                                : 'No hay productos en esta categoría',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Intenta con otra palabra clave o restablece los filtros.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                          if (_tabletSearchCtrl.text.isNotEmpty ||
                              _tabletSelectedCategoria != 'Todos') ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? AppTheme.borderDark
                                      : AppTheme.borderLight,
                                ),
                              ),
                              icon: const Icon(LucideIcons.rotateCcw, size: 14),
                              label: Text(
                                'Restablecer Catálogo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _tabletSearchCtrl.clear();
                                  _tabletSearchQuery = '';
                                  _tabletSelectedCategoria = 'Todos';
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 6),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 165,
                          childAspectRatio: 0.74,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: productos.length,
                    itemBuilder: (context, idx) {
                      final p = productos[idx];
                      final promo = _obtenerPromocionActivaParaProducto(p);
                      final cartIdx = _carrito.indexWhere(
                        (it) => it.producto.idProducto == p.idProducto,
                      );
                      final inCart = cartIdx != -1;
                      final inCartQty = inCart
                          ? _carrito[cartIdx].cantidad
                          : 0.0;
                      final isLowStock =
                          p.stockActual <=
                          (p.stockMinimo > 0 ? p.stockMinimo : 5.0);

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
                              final newIdx = _carrito.indexWhere(
                                (it) => it.producto.idProducto == p.idProducto,
                              );
                              if (newIdx != -1) {
                                _editarCantidadDirecta(newIdx);
                              }
                            }
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (inCart
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFF1B2030))
                                  : (inCart
                                        ? const Color(0xFFF0FDFA)
                                        : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: inCart
                                    ? AppTheme.brandPrimary
                                    : (isDark
                                          ? const Color(0xFF2C354C)
                                          : const Color(0xFFE2E8F0)),
                                width: inCart ? 1.8 : 1.0,
                              ),
                              boxShadow: inCart
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.brandPrimary.withValues(
                                          alpha: 0.18,
                                        ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLowStock
                                            ? AppTheme.alertRed.withValues(
                                                alpha: 0.15,
                                              )
                                            : (isDark
                                                  ? const Color(0xFF134E4A)
                                                        .withValues(alpha: 0.5)
                                                  : const Color(0xFFCCFBF1)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_formatStock(p.stockActual)} u.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isLowStock
                                              ? AppTheme.alertRed
                                              : (isDark
                                                    ? const Color(0xFF2DD4BF)
                                                    : const Color(0xFF0F766E)),
                                        ),
                                      ),
                                    ),
                                    if (inCart)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.brandPrimary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              LucideIcons.check,
                                              size: 9,
                                              color: Colors.white,
                                            ),
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
                                          nombre: p.nombre,
                                          codigoBarras: p.codigoBarras,
                                          categoria: p.nombreCategoria,
                                          size: 88,
                                          borderRadius: 16,
                                          isDark: isDark,
                                          padding: 2,
                                        ),
                                        if (promo != null)
                                          Positioned(
                                            bottom: -3,
                                            left: -3,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                    blurRadius: 3,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                promo.badgeTexto.isNotEmpty
                                                    ? promo.badgeTexto
                                                    : '🔥 PROMO',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                _mostrarModalInfoProducto(p);
                                              },
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF1E293B)
                                                      : Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF475569,
                                                          )
                                                        : const Color(
                                                            0xFFCBD5E1,
                                                          ),
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: isDark
                                                                ? 0.35
                                                                : 0.12,
                                                          ),
                                                      blurRadius: 3,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    LucideIcons.info,
                                                    size: 11.5,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'S/ ${p.precioVenta.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.brandPrimary,
                                            ),
                                          ),
                                          if (promo != null)
                                            Text(
                                              promo.badgeTexto,
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: inCart
                                            ? AppTheme.brandPrimary
                                            : (isDark
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 13,
                                        color: inCart
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF334155)),
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

  Widget _buildTabletTicketPanel(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor,
  ) {
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
                  color: isDark
                      ? AppTheme.brandPrimary.withValues(alpha: 0.2)
                      : AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.receiptText,
                  color: AppTheme.brandPrimary,
                  size: 18,
                ),
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
                        fontSize: 11.5,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Garantía de Botellas / Retornables',
                    icon: const Icon(LucideIcons.wine, size: 18, color: Color(0xFF2563EB)),
                    onPressed: _abrirModalGarantiaEnvase,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (_carrito.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Poner en Espera (Pausar Ticket)',
                      icon: const Icon(LucideIcons.pauseCircle, size: 18, color: Color(0xFFD97706)),
                      onPressed: _ponerVentaEnEspera,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Registrar como Consumo Interno de Bodega',
                      icon: const Icon(LucideIcons.coffee, size: 18, color: Color(0xFF8B5CF6)),
                      onPressed: _registrarConsumoInterno,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.alertRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                      ),
                      onPressed: _vaciarCarrito,
                      child: Text(
                        'Vaciar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selector de Comprobante (Boleta de Venta, Ticket de Venta - Nuevo RUS)
          _buildTipoComprobanteSelector(isDark),

          // Cliente (Consumidor Final / Con DNI)
          _buildCustomerCard(
            isDark,
            cardBg,
            borderColor,
            labelColor,
            isTablet: true,
          ),
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
                                color: isDark
                                    ? AppTheme.surfaceTintDark
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.borderDarkElevated
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.scanLine,
                                size: 28,
                                color: AppTheme.brandPrimary,
                              ),
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
                                fontSize: 11.5,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
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
                      color: isDark
                          ? AppTheme.borderDark
                          : AppTheme.borderLight,
                    ),
                    itemBuilder: (context, idx) {
                      final item = _carrito[idx];

                      return Row(
                        children: [
                          // Foto de estudio o glyph de categoría en lista de carrito
                          ProductImageWidget(
                            imagenUrl: item.producto.imagenUrl,
                            nombre: item.producto.nombre,
                            codigoBarras: item.producto.codigoBarras,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Steppers compactos táctiles
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardDarkHighlight
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.borderDarkElevated
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(10),
                                  ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _decrementarCantidad(idx);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      LucideIcons.minus,
                                      size: 12,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _editarCantidadDirecta(idx),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 26,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _formatCantidad(item.cantidad),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(10),
                                  ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _incrementarCantidad(idx);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
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
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            icon: Icon(
                              LucideIcons.trash2,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFEF4444),
                            ),
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
          Divider(
            height: 1,
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
          const SizedBox(height: 6),

          // Canales de pago & Calculadora de Vuelto
          _buildPaymentAndCashSection(
            isDark,
            cardBg,
            borderColor,
            labelColor,
            isTablet: true,
          ),

          const SizedBox(height: 8),

          // Totalizador Digital LED de Caja
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF090A0F), const Color(0xFF141724)]
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
                          color: AppTheme.textDarkSecondary,
                          fontWeight: FontWeight.w600,
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
          if (_promocionesAplicadas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPromocionesCartBanner(isDark),
          ],
          const SizedBox(height: 6),
          _buildDescuentoManualBanner(isDark),
          if (_totalBotellasRetornablesEnCarrito > 0) ...[
            const SizedBox(height: 8),
            _buildRetornablesCartBanner(isDark),
          ],
          const SizedBox(height: 8),

          // Botones de Acción (Ticket Térmico + Cobro)
          Row(
            children: [
              Tooltip(
                message: 'Imprimir Ticket Térmico (58 / 80 mm)',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandPrimary,
                    side: const BorderSide(
                      color: AppTheme.brandPrimary,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                child: _buildCobrarButton(
                  isDark: isDark,
                  height: 46,
                  isTablet: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor, {
    bool isTablet = false,
  }) {
    if (!_identificarCliente) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(isTablet ? 14 : 18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10 : 14,
          vertical: isTablet ? 8 : 10,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 5 : 7),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(
                  alpha: isDark ? 0.2 : 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.userCheck,
                size: isTablet ? 14 : 16,
                color: AppTheme.accentGreen,
              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sin DNI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF334155),
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
                      fontSize: isTablet ? 10.5 : 11.5,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandPrimary,
                side: BorderSide(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 8 : 12,
                  vertical: isTablet ? 4 : 6,
                ),
                minimumSize: Size(0, isTablet ? 30 : 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                    Icon(
                      LucideIcons.idCard,
                      size: isTablet ? 13 : 15,
                      color: AppTheme.brandPrimary,
                    ),
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
              if (_tipoComprobante == 'BOLETA_ELECTRONICA' &&
                  _totalVenta >= 700.0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.shieldAlert,
                        size: 10,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Monto ≥ S/ 700',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.rotateCcw,
                          size: 11,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Consumidor Final',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF334155),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: isTablet ? 7 : 9,
                    ),
                    hintText: 'DNI (8 d.)',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.textDarkMuted
                          : AppTheme.textMuted,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.cardDarkSunken
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.brandPrimary,
                        width: 1.4,
                      ),
                    ),
                    suffixIcon: _isConsultandoDoc
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: Padding(
                              padding: EdgeInsets.all(7.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          )
                        : (_clienteDocController.text.length == 8
                              ? const Icon(
                                  LucideIcons.checkCheck,
                                  size: 14,
                                  color: AppTheme.accentGreen,
                                )
                              : null),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: isTablet ? 7 : 9,
                    ),
                    hintText: 'Nombre del Cliente',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.textDarkMuted
                          : AppTheme.textMuted,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.cardDarkSunken
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.brandPrimary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_clienteNombreController.text.isNotEmpty &&
              _clienteDocController.text.length == 8) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  LucideIcons.badgeCheck,
                  size: 12,
                  color: AppTheme.accentGreen,
                ),
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
    final primaryColor = isExacto
        ? AppTheme.accentGreen
        : AppTheme.brandPrimary;

    return ActionChip(
      avatar: isExacto
          ? Icon(
              LucideIcons.zap,
              size: 13,
              color: isSelected ? Colors.white : AppTheme.accentGreen,
            )
          : null,
      label: Text(label),
      labelStyle: GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white : AppTheme.textDark),
      ),
      backgroundColor: isSelected
          ? primaryColor
          : (isExacto
                ? (isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                      : const Color(0xFFD1FAE5))
                : (isDark
                      ? AppTheme.cardDarkHighlight
                      : const Color(0xFFF1F5F9))),
      side: BorderSide(
        color: isSelected
            ? primaryColor
            : (isExacto
                  ? AppTheme.accentGreen.withValues(alpha: 0.7)
                  : (isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0))),
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
        methodColor = const Color(0xFF7C3AED); // Púrpura Yape
        break;
      case 'Plin':
        methodColor = const Color(0xFF0284C7); // Celeste Plin
        break;
      case 'Tarjeta':
        methodColor = const Color(0xFF2563EB); // Azul Cobalto
        break;
      case 'Crédito':
        methodColor = const Color(0xFFD97706); // Ámbar
        break;
      case 'Efectivo':
      default:
        methodColor = const Color(0xFF059669); // Esmeralda Fintech
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            _metodoPago = metodo;
            _pagoConController.clear();
          });
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? methodColor
                : (isDark
                      ? AppTheme.cardDarkHighlight
                      : const Color(0xFFF5F6F8)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? methodColor
                  : (isDark
                        ? AppTheme.borderDarkElevated
                        : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: methodColor.withValues(alpha: 0.35),
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
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : methodColor),
              ),
              const SizedBox(width: 8),
              Text(
                metodo,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVueltoCard(bool isDark, {bool isTablet = false}) {
    if (_montoRecibido <= 0) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10 : 14,
          vertical: isTablet ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.6)
              : const Color(0xFFF8FAFC),
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
              child: const Icon(
                LucideIcons.banknote,
                size: 15,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Efectivo no especificado',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 11.5 : 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Toca un billete o pulsa Pagar Exacto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : AppTheme.textMuted,
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
                  color: AppTheme.accentGreen.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.zap,
                      size: 12,
                      color: AppTheme.accentGreen,
                    ),
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
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10 : 14,
          vertical: isTablet ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF450A0A).withValues(alpha: 0.5)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.alertRed.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                size: 16,
                color: AppTheme.alertRed,
              ),
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
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF7F1D1D),
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
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10 : 14,
          vertical: isTablet ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2942) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCheck,
                size: 16,
                color: Color(0xFF3B82F6),
              ),
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
                      color: isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                  Text(
                    'Monto cubierto al centavo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E3A8A),
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
                color: isDark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF2563EB),
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
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 14,
        vertical: isTablet ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.45)
            : const Color(0xFFD1FAE5),
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
            child: const Icon(
              LucideIcons.coins,
              size: 20,
              color: Color(0xFF047857),
            ),
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
                    color: isDark
                        ? const Color(0xFF34D399)
                        : const Color(0xFF065F46),
                  ),
                ),
                Text(
                  'Pagó con S/ ${_montoRecibido.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF065F46),
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
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndCashSection(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color labelColor, {
    bool isTablet = false,
  }) {
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: isTablet ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Efectivo recibido',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: isTablet ? 12 : 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : AppTheme.textMuted,
                      ),
                      prefixText: 'S/ ',
                      prefixStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: isTablet ? 14 : 16,
                        color: AppTheme.brandPrimary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isTablet ? 8 : 12,
                      ),
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
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isTablet ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: _metodoPago == 'Yape'
                  ? const Color(0xFF742284)
                        .withValues(alpha: isDark ? 0.2 : 0.1)
                  : (_metodoPago == 'Plin'
                        ? const Color(0xFF0891B2)
                              .withValues(alpha: isDark ? 0.2 : 0.1)
                        : const Color(0xFF2563EB)
                              .withValues(alpha: isDark ? 0.2 : 0.1)),
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
                  _metodoPago == 'Tarjeta'
                      ? LucideIcons.creditCard
                      : LucideIcons.smartphone,
                  size: 18,
                  color: _metodoPago == 'Yape'
                      ? const Color(0xFF9333EA)
                      : (_metodoPago == 'Plin'
                            ? const Color(0xFF0891B2)
                            : const Color(0xFF2563EB)),
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
                      fontSize: isTablet ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF334155),
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
          color: const Color(0xFFD97706)
              .withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.35),
            width: 1.2,
          ),
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
                  child: const Icon(
                    LucideIcons.handCoins,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
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
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Selecciona un vecino de la libreta para cargar la cuenta.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF78350F),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(LucideIcons.search, size: 16),
                    label: Text(
                      'BUSCAR CLIENTE',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _mostrarSelectorCliente,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: Text(
                    '+ NUEVO',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
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
    final bool excedeLimite =
        c.limiteCredito > 0 && nuevaDeuda > c.limiteCredito;

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
                    c.nombreCompleto.isNotEmpty
                        ? c.nombreCompleto[0].toUpperCase()
                        : 'C',
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
                          const Icon(
                            LucideIcons.phone,
                            size: 11,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.telefono!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                icon: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _clienteSeleccionado = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Balances
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'DEUDA ACTUAL',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${c.saldoDeudor.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
                Column(
                  children: [
                    Text(
                      'LÍMITE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? AppTheme.textDarkSecondary
                            : AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${c.limiteCredito.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
                Column(
                  children: [
                    Text(
                      'NUEVO SALDO',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      'S/ ${nuevaDeuda.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: excedeLimite
                            ? AppTheme.alertRed
                            : const Color(0xFFDC2626),
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
                  const Icon(
                    LucideIcons.alertTriangle,
                    size: 14,
                    color: AppTheme.alertRed,
                  ),
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
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.78,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.borderDarkElevated
                              : const Color(0xFFCBD5E1),
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
                                    color: const Color(0xFFD97706)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    LucideIcons.bookUser,
                                    size: 18,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Libreta de Clientes / Vecinos',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFD97706),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  icon: const Icon(
                                    LucideIcons.userPlus,
                                    size: 15,
                                  ),
                                  label: Text(
                                    '+ Nuevo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () {
                                    NuevoClienteSheet.show(
                                      context,
                                      onCreated: (nuevo) {
                                        if (mounted) {
                                          setState(
                                            () => _clienteSeleccionado = nuevo,
                                          );
                                        }
                                        Navigator.pop(bottomCtx);
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: const Size(32, 32),
                                  ),
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  tooltip: 'Cerrar Libreta',
                                  onPressed: () => Navigator.pop(bottomCtx),
                                ),
                              ],
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
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.cardDarkElevated
                                : const Color(0xFFF1F5F9),
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
                          future: _clienteService.buscarClientes(
                            searchCtrl.text,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD97706),
                                ),
                              );
                            }
                            final clientes = snapshot.data ?? [];
                            if (clientes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFD97706)
                                              .withValues(
                                                alpha: isDark ? 0.2 : 0.1,
                                              ),
                                          border: Border.all(
                                            color: const Color(0xFFD97706)
                                                .withValues(
                                                  alpha: isDark ? 0.35 : 0.2,
                                                ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            LucideIcons.users,
                                            size: 24,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        searchCtrl.text.isNotEmpty
                                            ? 'Sin coincidencias para "${searchCtrl.text}"'
                                            : 'No hay vecinos en la libreta',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Pulsa "+ Nuevo Vecino" arriba para registrarlo al instante con su límite de crédito.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppTheme.textDarkSecondary
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              itemCount: clientes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = clientes[i];
                                final bool isSelected =
                                    _clienteSeleccionado?.idCliente ==
                                    c.idCliente;

                                return InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _clienteSeleccionado = c;
                                      if (_clienteNombreController
                                              .text
                                              .isEmpty ||
                                          _clienteNombreController.text ==
                                              'Público General') {
                                        _clienteNombreController.text =
                                            c.nombreCompleto;
                                      }
                                      if (c.documento != null &&
                                          c.documento!.isNotEmpty &&
                                          _clienteDocController.text.isEmpty) {
                                        _clienteDocController.text =
                                            c.documento!;
                                      }
                                    });
                                    Navigator.pop(bottomCtx);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFD97706)
                                                .withValues(alpha: 0.12)
                                          : (isDark
                                                ? AppTheme.cardDarkElevated
                                                : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFD97706)
                                            : (isDark
                                                  ? AppTheme.borderDark
                                                  : AppTheme.borderLight),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isSelected
                                              ? const Color(0xFFD97706)
                                              : (isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0)),
                                          child: Text(
                                            c.nombreCompleto.isNotEmpty
                                                ? c.nombreCompleto[0]
                                                      .toUpperCase()
                                                : 'C',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w900,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white
                                                        : AppTheme.textDark),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.nombreCompleto,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textDark,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  if (c.documento != null &&
                                                      c
                                                          .documento!
                                                          .isNotEmpty) ...[
                                                    Text(
                                                      'DNI: ${c.documento}',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 11,
                                                            color: AppTheme
                                                                .textMuted,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (c.telefono != null &&
                                                      c.telefono!.isNotEmpty)
                                                    Text(
                                                      'Tel: ${c.telefono}',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 11,
                                                            color: AppTheme
                                                                .textMuted,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: c.colorRiesgo.withValues(
                                                  alpha: isDark ? 0.2 : 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: c.colorRiesgo
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.4
                                                            : 0.3,
                                                      ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: c.colorRiesgo,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    c.tieneDeuda
                                                        ? 'S/ ${c.saldoDeudor.toStringAsFixed(2)}'
                                                        : 'Al día',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: c.colorRiesgo,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Límite: S/ ${c.limiteCredito.toStringAsFixed(0)} • ${c.etiquetaRiesgo}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: c.colorRiesgo,
                                                  ),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCobrarButton({
    required bool isDark,
    required double height,
    bool isTablet = false,
  }) {
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
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.2,
            ),
          ),
          label: Text(
            'PROCESANDO COBRO...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0),
            foregroundColor: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF64748B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
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
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'COBRAR EXACTO • S/ ${_totalVenta.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isTablet ? 12.5 : 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0xFF0D9488).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height / 2),
              ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: isTablet ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed.withValues(alpha: 0.15),
              foregroundColor: AppTheme.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height / 2),
              ),
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
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              labelText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isTablet ? 12.5 : 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF059669).withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ),
      );
    }

    // Métodos digitales
    Color btnColor = AppTheme.brandPrimary;
    String btnLabel =
        'CONFIRMAR Y COBRAR • S/ ${_totalVenta.toStringAsFixed(2)}';
    IconData btnIcon = LucideIcons.checkCheck;

    if (_metodoPago == 'Yape') {
      btnColor = const Color(0xFF7C3AED);
      btnLabel = 'CONFIRMAR PAGO YAPE • S/ ${_totalVenta.toStringAsFixed(2)}';
      btnIcon = LucideIcons.smartphone;
    } else if (_metodoPago == 'Plin') {
      btnColor = const Color(0xFF0284C7);
      btnLabel = 'CONFIRMAR PAGO PLIN • S/ ${_totalVenta.toStringAsFixed(2)}';
      btnIcon = LucideIcons.zap;
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
            ? ((_metodoPago == 'Crédito' && _clienteSeleccionado == null)
                  ? _mostrarSelectorCliente
                  : _procesarVenta)
            : null,
        icon: Icon(btnIcon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            btnLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTablet ? 12.5 : 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: btnColor.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
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
    final doc =
        (_identificarCliente && _clienteDocController.text.trim().isNotEmpty)
        ? _clienteDocController.text.trim()
        : (clienteCredito?.documento ?? '');
    final nom =
        (_identificarCliente && _clienteNombreController.text.trim().isNotEmpty)
        ? _clienteNombreController.text.trim()
        : (clienteCredito?.nombreCompleto ?? 'Público General');

    String numTelf = '';
    if (clienteCredito?.telefono != null &&
        clienteCredito!.telefono!.trim().isNotEmpty) {
      final clean = clienteCredito.telefono!.replaceAll(RegExp(r'\D'), '');
      if (clean.length == 9 && clean.startsWith('9')) {
        numTelf = '51$clean';
      } else if (clean.length > 9) {
        numTelf = clean;
      }
    } else if (doc.length == 9 && doc.startsWith('9')) {
      numTelf = '51$doc';
    }

    final comprobanteStr =
        ventaGenerada != null && ventaGenerada.etiquetaComprobante.isNotEmpty
        ? ventaGenerada.etiquetaComprobante
        : (_tipoComprobante == 'BOLETA_ELECTRONICA'
              ? 'Boleta de Venta'
              : 'Ticket de Venta');

    final buffer = StringBuffer();
    if (metodo == 'Crédito' || clienteCredito != null) {
      final double nuevoSaldo = (clienteCredito?.saldoDeudor ?? 0.0) + total;
      buffer.writeln('📒 *$_nombreBodega - Libreta de Fiados*');
      buffer.writeln(
        '¡Hola $nom! Te enviamos la constancia de tu compra al crédito:',
      );
      buffer.writeln('--------------------------------');
      for (final it in items) {
        buffer.writeln(
          '${it.cantidad.toStringAsFixed(0)}x ${it.producto.nombre} - S/ ${it.subtotal.toStringAsFixed(2)}',
        );
      }
      buffer.writeln('--------------------------------');
      buffer.writeln(
        '*Total Fiado en esta compra: S/ ${total.toStringAsFixed(2)}*',
      );
      buffer.writeln(
        '*Tu Saldo Total Pendiente: S/ ${nuevoSaldo.toStringAsFixed(2)}*',
      );
      buffer.writeln(
        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );
      buffer.writeln(
        '\n¡Gracias por tu preferencia y confianza siempre vecino(a)! ✨🏪',
      );
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
        buffer.writeln('Comprobante: ${ventaGenerada!.serieCorrelativo}');
        buffer.writeln('Estado: EMITIDO');
      }
      buffer.writeln(
        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );
      buffer.writeln('--------------------------------');
      for (final it in items) {
        buffer.writeln(
          '${it.cantidad.toStringAsFixed(0)}x ${it.producto.nombre} - S/ ${it.subtotal.toStringAsFixed(2)}',
        );
      }
      buffer.writeln('--------------------------------');
      buffer.writeln('*TOTAL COBRADO: S/ ${total.toStringAsFixed(2)}*');
      buffer.writeln('Método de Pago: $metodo');
      buffer.writeln('\n¡Muchas gracias por su preferencia! ✨');
    }

    final uri = Uri.parse(
      numTelf.isNotEmpty
          ? 'https://wa.me/$numTelf?text=${Uri.encodeComponent(buffer.toString())}'
          : 'https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp en este dispositivo.'),
          ),
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
            color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              _buildTipoComprobanteTab(
                'BOLETA_ELECTRONICA',
                'Boleta de Venta',
                LucideIcons.fileText,
                isDark,
              ),
              _buildTipoComprobanteTab(
                'TICKET',
                'Ticket de Venta',
                LucideIcons.receipt,
                isDark,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.checkCircle2,
                size: 11,
                color: AppTheme.accentGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Venta ágil de mostrador a consumidor final',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textMuted,
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
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 12,
                  color: Colors.amber,
                ),
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
              border: Border.all(
                color: Colors.orange.shade700.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.shieldAlert,
                  size: 12,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Boletas ≥ S/ 700.00 requieren registrar el DNI o documento del cliente.',
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

  Widget _buildTipoComprobanteTab(
    String code,
    String label,
    IconData icon,
    bool isDark,
  ) {
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
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF334155)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF334155)),
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
