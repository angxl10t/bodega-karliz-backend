import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_constants.dart';
import '../../core/cajaya_vectors.dart';
import '../../core/category_helper.dart';
import '../../core/marca_detector_service.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';
import '../../core/widgets/adaptive_modal.dart';
import '../../core/widgets/product_image_widget.dart';

import 'package:provider/provider.dart';

import '../../core/theme_provider.dart';
import '../../core/widgets/water_drop_theme_transition.dart';
import '../../core/gastronomia_helper.dart';
import 'pedido_web_service.dart';
import 'widgets/catalogo_gastronomico_view.dart';

class ItemCarritoPublico {
  final int idProducto;
  int cantidad;
  final String? variante;
  final String? notas;

  ItemCarritoPublico({
    required this.idProducto,
    required this.cantidad,
    this.variante,
    this.notas,
  });

  String get cartKey => (variante != null && variante!.isNotEmpty)
      ? '$idProducto#$variante'
      : '$idProducto';
}

class CatalogoPublicoScreen extends StatefulWidget {
  final String tiendaSlug;
  final http.Client? httpClient;

  const CatalogoPublicoScreen({
    super.key,
    required this.tiendaSlug,
    this.httpClient,
  });

  /// Deriva un color de promoción secundario armónico y de alto contraste a partir del color de marca de la tienda
  static Color generarColorSecundarioPromocion(Color primary) {
    // 1. Mapeo armónico curado para los 11 presets de identidad de CajaYa
    final int value = primary.toARGB32() & 0x00FFFFFF;
    switch (value) {
      case 0x2563EB: // Cobalto FinTech -> Naranja Fuego / Coral promocional de alto impacto
        return const Color(0xFFEA580C);
      case 0x0D9488: // Esmeralda Boutique -> Rubí Carmesí
        return const Color(0xFFE11D48);
      case 0x059669: // Verde Retail -> Rubí Carmesí vibrante
        return const Color(0xFFE11D48);
      case 0x4F46E5: // Índigo Real -> Ámbar Dorado brillante
        return const Color(0xFFF59E0B);
      case 0x7C3AED: // Violeta SaaS -> Ámbar Eléctrico
        return const Color(0xFFF59E0B);
      case 0xE11D48: // Rubí Moderno -> Ámbar Cálido
        return const Color(0xFFD97706);
      case 0xD97706: // Ámbar Dinámico -> Rubí Carmesí
        return const Color(0xFFE11D48);
      case 0x06B6D4: // Turquesa Neón -> Rosa Frambuesa
        return const Color(0xFFF43F5E);
      case 0x78350F: // Cacao Artesanal -> Ámbar Cálido
        return const Color(0xFFD97706);
      case 0xC026D3: // Fucsia Vibrante -> Ámbar Dorado
        return const Color(0xFFF59E0B);
      case 0x334155: // Pizarra Minimal -> Cobalto Moderno
        return const Color(0xFF2563EB);
    }

    // 2. Fallback algorítmico dinámico para colores HEX personalizados usando HSV
    final hsv = HSVColor.fromColor(primary);
    final hue = hsv.hue;
    if (hue >= 70 && hue <= 165) {
      // Para tiendas con tonos verdes: usar rubí/carmesí para evitar que todo sea verde
      return const Color(0xFFE11D48);
    }
    if (hue >= 340 || hue <= 25) {
      // Para tiendas con tonos rojos/rosas: usar ámbar cálido para evitar choque cromático
      return const Color(0xFFD97706);
    }
    if (hue >= 190 && hue <= 310) {
      // Para tiendas con tonos azules/violetas: usar naranja coral para pop llamativo
      return const Color(0xFFEA580C);
    }

    // Para cualquier otro tono personalizado, calcular color contrastante armónico
    final targetHue = (hue + 180) % 360;
    return HSVColor.fromAHSV(1.0, targetHue, 0.85, 0.90).toColor();
  }

  @override
  State<CatalogoPublicoScreen> createState() => _CatalogoPublicoScreenState();
}

class _CatalogoPublicoScreenState extends State<CatalogoPublicoScreen> {
  late final http.Client _client = widget.httpClient ?? http.Client();

  bool _isLoading = true;
  String? _error;
  bool _esPro = false;
  String? _mensajeNoPro;

  Map<String, dynamic> _bodega = {};
  List<Map<String, dynamic>> _productos = [];
  Map<String, Map<String, dynamic>> _productosPorId = const {};
  Map<String, int> _conteoPorCategoria = const {};
  int _ofertasCount = 0;
  List<String> _categorias = [];
  List<Map<String, dynamic>> _promociones = [];
  String _categoriaSeleccionada = 'TODAS';
  String _ordenSeleccionado = 'DESTACADOS';
  String _filtroBusqueda = '';
  List<Map<String, dynamic>> _cachedProductosFiltrados = [];
  Timer? _searchDebounce;
  Timer? _autoRetryTimer;

  // Carrito de compras: {cartKey: ItemCarritoPublico}
  final Map<String, ItemCarritoPublico> _carrito = {};

  int _cantidadDeProductoEnCarrito(int idProducto) {
    return _carrito.values
        .where((it) => it.idProducto == idProducto)
        .fold(0, (acc, it) => acc + it.cantidad);
  }

  bool _isEnviandoPedido = false;
  String _modalidadEntrega = 'DELIVERY'; // 'DELIVERY' | 'RECOJO'
  String _metodoPagoSeleccionado =
      'YAPE'; // 'YAPE' | 'PLIN' | 'EFECTIVO' | 'TARJETA'
  bool _dejarGarantiaBotellas = false; // false = Canje envases vacíos (S/ 0.00), true = Garantía (+S/ 2.00 c/u)
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _notasPedidoCtrl = TextEditingController();
  final ScrollController _catScrollCtrl = ScrollController();

  String get _giroNegocio =>
      (_bodega['giroNegocio']?.toString() ?? 'BODEGA').toUpperCase();

  bool get _esPolleria => _giroNegocio == 'POLLERIA';
  bool get _esChifa => _giroNegocio == 'CHIFA';
  bool get _esFastFood =>
      _giroNegocio == 'FASTFOOD' || _giroNegocio.contains('FAST');
  bool get _esRestaurante => _giroNegocio == 'RESTAURANTE';
  bool get _esGastronomico =>
      _esPolleria || _esChifa || _esFastFood || _esRestaurante;

  String get _badgeTipoCatalogo {
    switch (_giroNegocio) {
      case 'POLLERIA':
        return 'POLLERÍA PRO';
      case 'CHIFA':
        return 'CHIFA PRO';
      case 'FASTFOOD':
        return 'FAST FOOD PRO';
      case 'RESTAURANTE':
        return 'RESTAURANTE PRO';
      case 'BODEGA':
      default:
        return 'PRO ONLINE';
    }
  }

  String get _subtituloEncabezado {
    switch (_giroNegocio) {
      case 'POLLERIA':
        return 'Carta Digital Pollería';
      case 'CHIFA':
        return 'Carta Digital Chifa';
      case 'FASTFOOD':
        return 'Menú Digital Fast Food';
      case 'RESTAURANTE':
        return 'Carta Digital Restaurante';
      case 'BODEGA':
      default:
        return 'Catálogo Online de Productos';
    }
  }

  String get _hintBuscador {
    switch (_giroNegocio) {
      case 'POLLERIA':
        return 'Buscar platos, pollos a la brasa, combos, bebidas...';
      case 'CHIFA':
        return 'Buscar chaufas, wantanes, combinados, bebidas...';
      case 'FASTFOOD':
        return 'Buscar broaster, hamburguesas, salchipapas, bebidas...';
      case 'RESTAURANTE':
        return 'Buscar platos, menú ejecutivo, entradas, bebidas...';
      case 'BODEGA':
      default:
        return 'Buscar productos, marcas, bebidas, abarrotes...';
    }
  }

  String get _tituloCarrito {
    if (_esGastronomico) {
      return 'Mi Orden';
    }
    return 'Mi Pedido';
  }

  String get _tituloOrdenWhatsApp {
    if (_esGastronomico) {
      return 'Orden';
    }
    return 'Pedido';
  }

  String get _hintNotasPedido {
    switch (_giroNegocio) {
      case 'POLLERIA':
        return 'Indicaciones (ej. ají y tártara extra, bien doradito, recogeré en 20 min...)';
      case 'CHIFA':
        return 'Indicaciones (ej. wantán extra crocante, sin cebollita china, con limón...)';
      case 'FASTFOOD':
        return 'Indicaciones (ej. todas las cremas excepto golf, papas crocantes...)';
      case 'RESTAURANTE':
        return 'Indicaciones (ej. término medio, sin sal añadida, recogeré a la 1:30pm...)';
      case 'BODEGA':
      default:
        return 'Indicaciones (ej. mi hijo recogerá en 15 min, enviar cambio de S/ 50...)';
    }
  }

  String get _textoRetiroLocal {
    if (_esGastronomico) {
      return 'Para llevar / Recojo en local';
    }
    return 'Retiro en tienda';
  }

  String get _textoSoloRetiroLocal {
    if (_esGastronomico) {
      return 'Solo para llevar / local';
    }
    return 'Solo retiro en tienda';
  }

  String get _textoSeguirExplorando {
    if (_esGastronomico) {
      return 'Seguir Viendo la Carta';
    }
    return 'Seguir Comprando en el Catálogo';
  }

  String get _textoVolverCatalogo {
    if (_esGastronomico) {
      return 'Volver a la Carta';
    }
    return 'Volver al Catálogo';
  }

  String get _textoCarritoVacio {
    if (_esGastronomico) {
      return 'Agrega platos y bebidas desde la carta para enviar tu orden por WhatsApp.';
    }
    return 'Agrega productos desde el catálogo para enviar tu pedido por WhatsApp.';
  }

  String get _textoFooterOficial {
    if (_esGastronomico) {
      return 'Carta Digital Oficial';
    }
    return 'Catálogo Digital Oficial';
  }

  Color get _colorMarca {
    final hex = _bodega['colorPrimario']?.toString();
    if (hex != null && hex.isNotEmpty) {
      try {
        String clean = hex.replaceAll('#', '').trim();
        if (clean.length == 6) clean = 'FF$clean';
        return Color(int.parse(clean, radix: 16));
      } catch (_) {}
    }
    return AppTheme.brandPrimary;
  }

  /// Tono más profundo y saturado del color de marca para garantizar contraste WCAG AA (>= 4.5:1)
  /// con texto blanco en botones, encabezados y acentos sobre fondo claro (especialmente para Cyan/Ámbar).
  Color get _colorMarcaProfundo {
    final hsl = HSLColor.fromColor(_colorMarca);
    return hsl
        .withLightness(hsl.lightness.clamp(0.20, 0.34))
        .withSaturation((hsl.saturation + 0.08).clamp(0.45, 0.96))
        .toColor();
  }

  /// Tono de marca optimizado para texto e iconos según el brillo del tema.
  Color _colorMarcaTexto(bool isDark) {
    final hsl = HSLColor.fromColor(_colorMarca);
    if (isDark) {
      return hsl
          .withLightness(hsl.lightness.clamp(0.62, 0.78))
          .withSaturation((hsl.saturation + 0.06).clamp(0.50, 0.95))
          .toColor();
    }
    return _colorMarcaProfundo;
  }

  LinearGradient get _brandGradient => LinearGradient(
    colors: [_colorMarcaProfundo, _colorMarca],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color get _colorPromocion =>
      CatalogoPublicoScreen.generarColorSecundarioPromocion(_colorMarca);

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _autoRetryTimer?.cancel();
    _searchCtrl.dispose();
    _notasPedidoCtrl.dispose();
    _catScrollCtrl.dispose();
    if (widget.httpClient == null) {
      _client.close();
    }
    super.dispose();
  }

  void _scrollCategorias(double delta) {
    if (!_catScrollCtrl.hasClients) return;
    final target = (_catScrollCtrl.offset + delta).clamp(
      0.0,
      _catScrollCtrl.position.maxScrollExtent,
    );
    _catScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _aplicarDatosCatalogo(Map<String, dynamic> data) {
    final bodegaMap = (data['bodega'] as Map<String, dynamic>?) ?? {};
    final bool esPro = data['esPro'] == true;
    final String? msg = data['mensaje'] as String?;
    final rawProds = (data['productos'] as List<dynamic>?) ?? [];
    final prodsList = rawProds
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where(
          (p) =>
              p['stockActual'] == null ||
              ((p['stockActual'] as num).toDouble() > 0),
        )
        .toList();
    final rawCats = (data['categorias'] as List<dynamic>?) ?? [];
    final catsList = rawCats.map((e) => e.toString()).toList();
    final giro =
        (bodegaMap['giroNegocio']?.toString() ??
                data['giroNegocio']?.toString() ??
                'BODEGA')
            .toUpperCase();
    final bool esGastro =
        giro == 'POLLERIA' ||
        giro == 'CHIFA' ||
        giro == 'FASTFOOD' ||
        giro.contains('FAST') ||
        giro == 'RESTAURANTE';
    if (esGastro) {
      catsList.sort((a, b) {
        final prioA = GastronomiaHelper.prioridadCategoria(a);
        final prioB = GastronomiaHelper.prioridadCategoria(b);
        if (prioA != prioB) return prioA.compareTo(prioB);
        return a.compareTo(b);
      });
    }

    final rawPromos = (data['promociones'] as List<dynamic>?) ?? [];
    final promosList = rawPromos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final prodsById = <String, Map<String, dynamic>>{};
    final catCounts = <String, int>{};
    int ofertas = 0;
    for (final p in prodsList) {
      final idStr = p['idProducto']?.toString();
      if (idStr != null && idStr.isNotEmpty) {
        prodsById[idStr] = p;
      }
      final catKey = (p['categoria']?.toString() ?? '').trim().toUpperCase();
      if (catKey.isNotEmpty) {
        catCounts[catKey] = (catCounts[catKey] ?? 0) + 1;
      }
      if (p['tienePromocion'] == true) {
        ofertas++;
      }
    }

    if (mounted) {
      setState(() {
        _bodega = bodegaMap;
        _esPro = esPro;
        _mensajeNoPro = msg;
        _productos = prodsList;
        _productosPorId = prodsById;
        _conteoPorCategoria = catCounts;
        _ofertasCount = ofertas;
        _categorias = catsList;
        _promociones = promosList;
        _recomputeProductosFiltrados();
        _isLoading = false;
        _error = null;
      });
    }
  }

  Future<void> _cargarSnapshotLocal(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null &&
          cachedJson.isNotEmpty &&
          mounted &&
          _productos.isEmpty) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _aplicarDatosCatalogo(decoded);
      }
    } catch (_) {}
  }

  Future<void> _cargarCatalogo() async {
    _autoRetryTimer?.cancel();
    final slugClean = widget.tiendaSlug.trim().toLowerCase();
    final cacheKey =
        'catalogo_cache_${slugClean.isEmpty ? "default" : slugClean}';

    // 1. Cargar instantáneamente desde snapshot en almacenamiento local si existe (no bloqueante)
    unawaited(_cargarSnapshotLocal(cacheKey));

    if (_productos.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // 2. Consulta de red con timeout extendido para tolerar arranque en frío de Render
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/public/catalogo?tienda=${Uri.encodeComponent(widget.tiendaSlug)}',
      );
      final resp = await _client.get(uri).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final utf8Body = utf8.decode(resp.bodyBytes);
        final data = jsonDecode(utf8Body) as Map<String, dynamic>;
        _aplicarDatosCatalogo(data);

        // Guardar snapshot para próximas aperturas instantáneas sin bloqueo
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, utf8Body);
        } catch (_) {}
      } else {
        if (_productos.isEmpty && mounted) {
          setState(() {
            _error =
                'La tienda en la nube se está activando (Código ${resp.statusCode}). Reintentando conexión...';
            _isLoading = false;
          });
          _iniciarAutoReintento();
        }
      }
    } catch (e) {
      if (_productos.isEmpty && mounted) {
        setState(() {
          _error = 'El catálogo en la nube se está activando (puede tardar unos segundos en la primera visita). Reintentando conexión automáticamente...';
          _isLoading = false;
        });
        _iniciarAutoReintento();
      }
    }
  }

  void _iniciarAutoReintento() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _productos.isEmpty) {
        _cargarCatalogo();
      }
    });
  }

  List<Map<String, dynamic>> get _productosFiltrados =>
      _cachedProductosFiltrados;

  double _precioEfectivoProducto(Map<String, dynamic> p) {
    final double regular = (p['precioVenta'] is num)
        ? (p['precioVenta'] as num).toDouble()
        : 0.0;
    final double? promo = (p['precioPromocional'] is num)
        ? (p['precioPromocional'] as num).toDouble()
        : null;
    if (p['tienePromocion'] == true &&
        promo != null &&
        promo > 0 &&
        promo < regular) {
      return promo;
    }
    return regular;
  }

  void _recomputeProductosFiltrados() {
    final catUpper = _categoriaSeleccionada.toUpperCase();
    final query = _filtroBusqueda.trim();
    final queryLower = query.toLowerCase();

    final filtered = _productos.where((p) {
      bool matchesCat = false;
      if (_categoriaSeleccionada == 'TODAS') {
        matchesCat = true;
      } else if (_categoriaSeleccionada == 'OFERTAS') {
        matchesCat = p['tienePromocion'] == true;
      } else {
        matchesCat = (p['categoria']?.toString().toUpperCase() == catUpper);
      }
      if (!matchesCat) return false;
      if (query.isEmpty) return true;

      final nombre = p['nombre']?.toString() ?? '';
      final codigo = p['codigo']?.toString() ?? '';
      final marca = p['marca']?.toString() ?? '';

      return nombre.toLowerCase().contains(queryLower) ||
          codigo.toLowerCase().contains(queryLower) ||
          marca.toLowerCase().contains(queryLower) ||
          MarcaDetectorService.coincideMarca(query, marca, nombre);
    }).toList();

    if (_ordenSeleccionado == 'PRECIO_ASC' ||
        _ordenSeleccionado == 'MENOR_PRECIO') {
      filtered.sort(
        (a, b) =>
            _precioEfectivoProducto(a).compareTo(_precioEfectivoProducto(b)),
      );
    } else if (_ordenSeleccionado == 'PRECIO_DESC' ||
        _ordenSeleccionado == 'MAYOR_PRECIO') {
      filtered.sort(
        (a, b) =>
            _precioEfectivoProducto(b).compareTo(_precioEfectivoProducto(a)),
      );
    } else if (_ordenSeleccionado == 'NOMBRE_AZ') {
      filtered.sort(
        (a, b) => (a['nombre']?.toString() ?? '').toLowerCase().compareTo(
          (b['nombre']?.toString() ?? '').toLowerCase(),
        ),
      );
    } else if (_esGastronomico) {
      // Por defecto (DESTACADOS): En la carta gastronómica online, los Platos Principales
      // salen siempre al frente y de forma prioritaria, mientras que gaseosas y cremas
      // pasan a sus secciones complementarias correspondientes.
      filtered.sort((a, b) {
        final prioA = GastronomiaHelper.prioridadCulinaria(
          a['nombre']?.toString(),
          a['categoria']?.toString(),
        );
        final prioB = GastronomiaHelper.prioridadCulinaria(
          b['nombre']?.toString(),
          b['categoria']?.toString(),
        );
        if (prioA != prioB) return prioA.compareTo(prioB);

        // A igualdad de prioridad: promociones primero
        final promoA = a['tienePromocion'] == true ? 0 : 1;
        final promoB = b['tienePromocion'] == true ? 0 : 1;
        if (promoA != promoB) return promoA.compareTo(promoB);

        // Mayor precio primero (platos insignia de mayor jerarquía)
        final precioA = _precioEfectivoProducto(a);
        final precioB = _precioEfectivoProducto(b);
        return precioB.compareTo(precioA);
      });
    }
    _cachedProductosFiltrados = filtered;
  }

  double get _totalAhorroCarrito {
    double ahorro = 0.0;
    for (final item in _carrito.values) {
      final prod =
          _productosPorId[item.idProducto.toString()] ??
          const <String, dynamic>{};
      if (prod['tienePromocion'] == true) {
        final double regular = (prod['precioVenta'] is num)
            ? (prod['precioVenta'] as num).toDouble()
            : 0.0;
        final double promo = (prod['precioPromocional'] is num)
            ? (prod['precioPromocional'] as num).toDouble()
            : regular;
        if (regular > promo) {
          ahorro += ((regular - promo) * item.cantidad);
        }
      }
    }
    return ahorro;
  }

  int get _totalUnidadesCarrito {
    return _carrito.values.fold(0, (acc, c) => acc + c.cantidad);
  }

  double get _totalMontoCarrito {
    double total = 0.0;
    for (final item in _carrito.values) {
      final prod =
          _productosPorId[item.idProducto.toString()] ??
          const <String, dynamic>{};
      final double regular = (prod['precioVenta'] is num)
          ? (prod['precioVenta'] as num).toDouble()
          : 0.0;
      final double promo = (prod['precioPromocional'] is num)
          ? (prod['precioPromocional'] as num).toDouble()
          : regular;
      final double precio = (prod['tienePromocion'] == true && promo > 0)
          ? promo
          : regular;
      total += (precio * item.cantidad);
    }
    return total;
  }

  int get _totalBotellasRetornables {
    int total = 0;
    for (final item in _carrito.values) {
      final prod =
          _productosPorId[item.idProducto.toString()] ??
          const <String, dynamic>{};
      if (_esProductoRetornable(prod)) {
        total += item.cantidad;
      }
    }
    return total;
  }

  double get _montoGarantiaBotellas {
    if (!_dejarGarantiaBotellas) return 0.0;
    return _totalBotellasRetornables * 2.0;
  }

  double get _totalMontoFinalConGarantia =>
      _totalMontoCarrito + _montoGarantiaBotellas;

  void _modificarCantidad(
    int idProducto,
    int delta, {
    String? variante,
    String? notas,
  }) {
    HapticFeedback.lightImpact();
    setState(() {
      final key = (variante != null && variante.isNotEmpty)
          ? '$idProducto#$variante'
          : '$idProducto';

      if (_carrito.containsKey(key)) {
        final item = _carrito[key]!;
        final nuevo = item.cantidad + delta;
        if (nuevo <= 0) {
          _carrito.remove(key);
        } else {
          item.cantidad = nuevo;
        }
      } else if (delta > 0) {
        _carrito[key] = ItemCarritoPublico(
          idProducto: idProducto,
          cantidad: delta,
          variante: variante,
          notas: notas,
        );
      } else if (delta < 0) {
        final matchingKey = _carrito.keys.firstWhere(
          (k) => _carrito[k]?.idProducto == idProducto,
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          final item = _carrito[matchingKey]!;
          final nuevo = item.cantidad + delta;
          if (nuevo <= 0) {
            _carrito.remove(matchingKey);
          } else {
            item.cantidad = nuevo;
          }
        }
      }
    });
  }

  void _vaciarCarrito() {
    HapticFeedback.mediumImpact();
    setState(() {
      _carrito.clear();
    });
  }

  Future<void> _enviarPedidoWhatsApp([String? notas]) async {
    if (_carrito.isEmpty || _isEnviandoPedido) return;
    setState(() => _isEnviandoPedido = true);

    try {
      final nombreBodega =
          _bodega['nombreComercial']?.toString() ?? 'la Bodega';
      final rawTelefono = _bodega['telefono']?.toString().trim() ?? '';
      final limpio = rawTelefono.replaceAll(RegExp(r'[^0-9]'), '');

      String telefonoFinal = '';
      if (limpio.length == 9 && limpio.startsWith('9')) {
        telefonoFinal = '51$limpio';
      } else if (limpio.length >= 9) {
        telefonoFinal = limpio.startsWith('51') ? limpio : '51$limpio';
      }

      final String codigoShort =
          '#W-${(DateTime.now().millisecondsSinceEpoch % 9000) + 1000}';
      final String codigoPedido =
          'WEB-${(DateTime.now().millisecondsSinceEpoch % 90000) + 10000}';

      final buffer = StringBuffer();
      buffer.writeln('*$_tituloOrdenWhatsApp $codigoShort - $nombreBodega*');
      if (notas != null && notas.trim().isNotEmpty) {
        buffer.writeln('Cliente: ${notas.trim()}');
      }
      buffer.writeln('--------------------------------');

      final List<PedidoWebItem> itemsParaBandeja = [];

      for (final item in _carrito.values) {
        final prod =
            _productosPorId[item.idProducto.toString()] ??
            const <String, dynamic>{};
        final nombre = prod['nombre']?.toString() ?? 'Producto';
        final double regular = (prod['precioVenta'] is num)
            ? (prod['precioVenta'] as num).toDouble()
            : 0.0;
        final double promo = (prod['precioPromocional'] is num)
            ? (prod['precioPromocional'] as num).toDouble()
            : regular;
        final bool tienePromo = prod['tienePromocion'] == true && promo > 0;
        final double precioFinal = tienePromo ? promo : regular;
        final subtotal = precioFinal * item.cantidad;
        final badge = tienePromo
            ? (prod['badgePromocion']?.toString() ?? 'PROMO')
            : null;

        final nombreDetallado = item.variante != null
            ? '$nombre (${item.variante})'
            : nombre;

        itemsParaBandeja.add(
          PedidoWebItem(
            idProducto:
                (prod['idProducto'] as num?)?.toInt() ?? item.idProducto,
            nombre: nombreDetallado,
            cantidad: item.cantidad.toDouble(),
            precioUnitario: precioFinal,
            subtotal: subtotal,
            badge: badge,
            variante: item.variante,
            notas: item.notas,
          ),
        );

        if (tienePromo) {
          buffer.writeln(
            '• ${item.cantidad}x $nombreDetallado - S/ ${subtotal.toStringAsFixed(2)} ($badge)',
          );
        } else {
          buffer.writeln(
            '• ${item.cantidad}x $nombreDetallado - S/ ${subtotal.toStringAsFixed(2)}',
          );
        }
        if (item.notas != null && item.notas!.isNotEmpty) {
          buffer.writeln('  ↳ Detalle: ${item.notas}');
        }
      }

      buffer.writeln('--------------------------------');
      buffer.writeln(
        '*Total a Pagar: S/ ${_totalMontoFinalConGarantia.toStringAsFixed(2)}*',
      );
      if (_totalAhorroCarrito > 0) {
        buffer.writeln(
          'Descuento web aplicado: -S/ ${_totalAhorroCarrito.toStringAsFixed(2)}',
        );
      }
      final bool incluyeRetornables = _carrito.values.any((item) {
        final p =
            _productosPorId[item.idProducto.toString()] ??
            const <String, dynamic>{};
        return _esProductoRetornable(p);
      });
      if (incluyeRetornables) {
        if (_dejarGarantiaBotellas) {
          buffer.writeln(
            '• Envases: Dejaré depósito de garantía (+S/ ${_montoGarantiaBotellas.toStringAsFixed(2)})',
          );
        } else {
          buffer.writeln(
            '• Envases: Tengo botellas vacías listas para canje (S/ 0.00)',
          );
        }
      }
      buffer.writeln('• Método de Pago: $_metodoPagoSeleccionado');
      buffer.writeln('');
      if (_esGastronomico) {
        if (_modalidadEntrega == 'RECOJO' ||
            _bodega['deliveryActivo'] == false) {
          buffer.writeln('Modalidad: Para llevar / Recojo en local');
          buffer.writeln(
            '¿Me confirman tiempo estimado de preparación para pasar a recoger?',
          );
        } else {
          buffer.writeln('Modalidad: Delivery / Envío a domicilio');
          buffer.writeln(
            '¿Me confirman cobertura y tiempo estimado de entrega a mi dirección?',
          );
        }
      } else {
        if (_bodega['deliveryActivo'] == false) {
          buffer.writeln('Modalidad: Retiro en tienda');
          buffer.writeln(
            '¿Me confirman disponibilidad para recoger en su local?',
          );
        } else {
          buffer.writeln(
            '¿Me confirman disponibilidad y si tienen delivery para mi zona?',
          );
        }
      }

      // Registrar en la bandeja de pedidos web de CajaYa y sincronizar en la nube
      final slugOrId = _bodega['idBodega']?.toString() ?? widget.tiendaSlug;
      final nuevoPedido = PedidoWeb(
        idPedido: codigoPedido,
        codigoPedido: codigoShort,
        fecha: DateTime.now(),
        nombreCliente: (notas != null && notas.trim().isNotEmpty)
            ? notas.trim()
            : 'Cliente Web',
        telefonoCliente: limpio,
        notas: notas,
        items: itemsParaBandeja,
        total: _totalMontoFinalConGarantia,
        ahorroPromociones: _totalAhorroCarrito,
        incluyeRetornables: incluyeRetornables,
        estado: 'PENDIENTE',
      );
      PedidoWebService.registrarPedido(nuevoPedido, slugOrIdBodega: slugOrId);

      final encoded = Uri.encodeComponent(buffer.toString());
      final urlStr = telefonoFinal.isNotEmpty
          ? 'https://wa.me/$telefonoFinal?text=$encoded'
          : 'https://wa.me/?text=$encoded';

      final uri = Uri.parse(urlStr);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {
        // Fallback: copiar pedido al portapapeles si el navegador bloquea ventanas emergentes
        if (mounted) {
          Clipboard.setData(ClipboardData(text: buffer.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '¡Pedido copiado al portapapeles! Puedes pegarlo directamente en WhatsApp.',
              ),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _carrito.clear();
          _isEnviandoPedido = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isEnviandoPedido = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0F19)
          : const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: _colorMarcaProfundo.withValues(
                      alpha: isDark ? 0.35 : 0.24,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.store,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _bodega['nombreComercial']?.toString() ??
                              'CajaYa POS',
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_esPro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: isDark ? 0.22 : 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.badgeCheck,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _subtituloEncabezado,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_esPro && _carrito.isNotEmpty) ...[
            InkWell(
              onTap: _mostrarCarritoModal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _colorMarcaProfundo.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.shoppingBag,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_totalUnidadesCarrito',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          WaterDropThemeButton(
            isDark: isDark,
            onToggle: () => context.read<ThemeProvider>().toggleTheme(),
            iconSize: 17,
            padding: const EdgeInsets.all(8),
            borderRadius: 10,
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            borderColor: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Actualizar catálogo',
            child: InkWell(
              onTap: _cargarCatalogo,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  LucideIcons.refreshCw,
                  size: 17,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _buildBody(isDark),
      bottomNavigationBar: _esPro && _carrito.isNotEmpty
          ? _buildFloatingOrderBar(isDark)
          : null,
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _colorMarca),
            const SizedBox(height: 16),
            Text(
              'Cargando catálogo en vivo...',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.circleAlert,
                  color: Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Catálogo no disponible',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorMarca,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _cargarCatalogo,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_esPro) {
      return _buildNoProView(isDark);
    }

    return _buildCatalogoProView(isDark);
  }

  Widget _buildNoProView(bool isDark) {
    final nombreBodega =
        _bodega['nombreComercial']?.toString() ?? 'Esta bodega';
    final telefono = _bodega['telefono']?.toString() ?? '';
    final direccion = _bodega['direccion']?.toString() ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.lock,
                  color: Color(0xFFD97706),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                nombreBodega,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SUSCRIPCIÓN PRO REQUERIDA',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD97706),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _mensajeNoPro ??
                    'La vitrina y ${_esGastronomico ? "carta digital" : "catálogo online"} para recepción de pedidos digitales por WhatsApp está disponible de forma exclusiva para negocios con Suscripción PRO en CajaYa Cloud POS.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
              if (telefono.isNotEmpty || direccion.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                if (direccion.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 15,
                        color: isDark ? const Color(0xFF93C5FD) : _colorMarca,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          direccion,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                if (telefono.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.phone,
                        size: 15,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Contacto: $telefono',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColorBadge(dynamic hex) {
    if (hex == null) return _colorPromocion;
    try {
      final s = hex.toString().replaceAll('#', '0xFF');
      final c = Color(int.parse(s));
      final rgb = c.toARGB32() & 0x00FFFFFF;
      // Si era el verde genérico heredado (#16A34A, #10B981, #059669, #047857),
      // o si la tienda tiene marca verde, adoptar el color de promociones dinámico
      if (rgb == 0x16A34A ||
          rgb == 0x10B981 ||
          rgb == 0x059669 ||
          rgb == 0x047857) {
        return _colorPromocion;
      }
      return c;
    } catch (_) {
      return _colorPromocion;
    }
  }

  IconData _iconoParaPromo(String badge) {
    final lower = badge.toLowerCase();
    if (lower.contains('x') || lower.contains('3x') || lower.contains('2x')) {
      return LucideIcons.gift;
    }
    if (lower.contains('%') || lower.contains('desc')) {
      return LucideIcons.percent;
    }
    if (lower.contains('combo') ||
        lower.contains('dúo') ||
        lower.contains('duo')) {
      return LucideIcons.sparkles;
    }
    return LucideIcons.flame;
  }

  String _limpiarBadgePromo(String raw) {
    // Remueve emojis bitmap que se renderizan borrosos en Flutter Web CanvasKit
    final cleaned = raw
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
          '',
        )
        .trim();
    return cleaned.isEmpty ? 'OFERTA' : cleaned;
  }

  Widget _buildPromocionesHeroBanner(bool isDark, bool isTablet) {
    if (_promociones.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(
        isTablet ? 20 : 16,
        2,
        isTablet ? 20 : 16,
        isTablet ? 14 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _colorPromocion.withValues(
                    alpha: isDark ? 0.22 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.flame,
                  size: 14,
                  color: _colorPromocion,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OFERTAS Y PROMOCIONES ACTIVAS',
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 12.5 : 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isTablet ? 0.8 : 0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 10 : 6),
          SizedBox(
            height: isTablet ? 142 : 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _promociones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final pm = _promociones[i];
                final color = _parseColorBadge(pm['colorBadge']);
                final hslColor = HSLColor.fromColor(color);
                final colorDeep = hslColor
                    .withLightness(
                      (hslColor.lightness - 0.12).clamp(0.18, 0.42),
                    )
                    .toColor();
                final titulo = pm['titulo']?.toString() ?? 'Oferta Especial';
                final desc = pm['descripcion']?.toString() ?? '';
                final rawBadge = pm['badgeTexto']?.toString() ?? 'OFERTA';
                final badgeText = _limpiarBadgePromo(rawBadge);
                final promoIcon = _iconoParaPromo(rawBadge);
                final cat = pm['categoriaObjetivo']?.toString();
                final marca = pm['marcaObjetivo']?.toString();

                return InkWell(
                  onTap: () {
                    _searchDebounce?.cancel();
                    if (cat != null && cat.isNotEmpty) {
                      setState(() {
                        _categoriaSeleccionada = cat;
                        _filtroBusqueda = '';
                        _searchCtrl.clear();
                        _recomputeProductosFiltrados();
                      });
                    } else if (marca != null && marca.isNotEmpty) {
                      setState(() {
                        _categoriaSeleccionada = 'TODAS';
                        _filtroBusqueda = marca;
                        _searchCtrl.text = marca;
                        _recomputeProductosFiltrados();
                      });
                    } else {
                      setState(() {
                        _categoriaSeleccionada = 'OFERTAS';
                        _filtroBusqueda = '';
                        _searchCtrl.clear();
                        _recomputeProductosFiltrados();
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: isTablet ? 316 : 272,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                colorDeep.withValues(alpha: 0.42),
                                const Color(0xFF162032),
                              ]
                            : [color.withValues(alpha: 0.14), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: color.withValues(alpha: isDark ? 0.50 : 0.35),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Barra lateral de acento vibrante
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 4.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colorDeep, color],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Marca de agua vectorial decorativa
                        Positioned(
                          right: -12,
                          bottom: -14,
                          child: Icon(
                            promoIcon,
                            size: isTablet ? 86 : 74,
                            color: color.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 13, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [colorDeep, color],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.32),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          promoIcon,
                                          size: 11.5,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          badgeText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: isDark ? 0.22 : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ver',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : colorDeep,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 13,
                                          color: isDark
                                              ? Colors.white
                                              : colorDeep,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Text(
                                titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: isTablet ? 15 : 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  desc.isNotEmpty ? desc : 'Aprovecha este descuento exclusivo disponible en tienda.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 11.5 : 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildTrustStep({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required bool isDark,
    required bool isTablet,
  }) {
    final hsl = HSLColor.fromColor(color);
    final deeper = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.20, 0.42))
        .toColor();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isTablet ? 34 : 28,
            height: isTablet ? 34 : 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [deeper, color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.30 : 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: isTablet ? 16 : 13.5, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 12.5 : 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isTablet ? 11 : 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogoProView(bool isDark) {
    if (_esGastronomico) {
      return CatalogoGastronomicoView(
        bodega: _bodega,
        productos: _productosFiltrados,
        totalProductosCount: _productos.length,
        categorias: _categorias,
        categoriaSeleccionada: _categoriaSeleccionada,
        onSeleccionarCategoria: (cat) {
          _searchDebounce?.cancel();
          setState(() {
            _categoriaSeleccionada = cat;
            _filtroBusqueda = '';
            _searchCtrl.clear();
            _recomputeProductosFiltrados();
          });
        },
        conteoPorCategoria: _conteoPorCategoria,
        ofertasCount: _ofertasCount,
        filtroBusqueda: _filtroBusqueda,
        searchController: _searchCtrl,
        onBuscar: (q) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 250), () {
            setState(() {
              _filtroBusqueda = q.trim();
              _recomputeProductosFiltrados();
            });
          });
        },
        onLimpiarBusqueda: () {
          _searchDebounce?.cancel();
          _searchCtrl.clear();
          setState(() {
            _filtroBusqueda = '';
            _recomputeProductosFiltrados();
          });
        },
        ordenSeleccionado: _ordenSeleccionado,
        onCambiarOrden: (ord) {
          setState(() {
            _ordenSeleccionado = ord;
            _recomputeProductosFiltrados();
          });
        },
        promociones: _promociones,
        carrito: _carrito,
        cantidadDeProductoEnCarrito: _cantidadDeProductoEnCarrito,
        onAgregarProducto: (prod) {
          final nombre = prod['nombre']?.toString() ?? '';
          final categoria = prod['categoria']?.toString() ?? '';
          final id = (prod['idProducto'] is num)
              ? (prod['idProducto'] as num).toInt()
              : int.tryParse(prod['idProducto']?.toString() ?? '') ?? 0;
          if (GastronomiaHelper.esProductoConPresa(nombre, categoria)) {
            _mostrarDetalleProductoOnline(prod);
          } else {
            _modificarCantidad(id, 1);
          }
        },
        onModificarCantidad: (id, delta) => _modificarCantidad(id, delta),
        onVerDetalleProducto: (prod) => _mostrarDetalleProductoOnline(prod),
        colorMarca: _colorMarca,
        colorPromocion: _colorPromocion,
        isDark: isDark,
        modalidadEntrega: _modalidadEntrega,
        onCambiarModalidad: (mod) {
          setState(() => _modalidadEntrega = mod);
        },
        onVerCarrito: _mostrarCarritoModal,
        onActualizarCatalogo: _cargarCatalogo,
      );
    }

    return _buildBodegaProView(isDark);
  }

  Widget _buildBodegaProView(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet =
        isPhysicalTablet ||
        (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);
    final bool isShortHeight = mediaQuery.size.height < 500;

    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'Bodega';
    final lema = _bodega['lemaComercial']?.toString() ?? '';
    final direccion = _bodega['direccion']?.toString() ?? '';
    final prods = _productosFiltrados;
    final bool estaAbierto =
        _bodega['catalogoAbierto'] != false && _bodega['abierto'] != false;
    final bool deliveryActivo = _bodega['deliveryActivo'] != false;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Banner Superior de la Tienda (Premium Retail Storefront)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 14,
                  isShortHeight ? 6 : (isTablet ? 18 : 10),
                  isTablet ? 20 : 14,
                  isShortHeight ? 6 : (isTablet ? 14 : 8),
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.45)
                          : const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera de Marca de Alto Impacto (Gradiente profundo WCAG-safe)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF0F172A),
                                  _colorMarcaProfundo,
                                  _colorMarca.withValues(alpha: 0.85),
                                ]
                              : [
                                  _colorMarcaProfundo,
                                  Color.lerp(
                                        _colorMarcaProfundo,
                                        _colorMarca,
                                        0.68,
                                      ) ??
                                      _colorMarca,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Destello ambiental suave en esquina superior derecha
                          Positioned(
                            right: -32,
                            top: -32,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.09),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 48,
                            bottom: -44,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              isShortHeight ? 12 : (isTablet ? 24 : 14),
                              isShortHeight ? 10 : (isTablet ? 22 : 12),
                              isShortHeight ? 12 : (isTablet ? 24 : 14),
                              isShortHeight ? 10 : (isTablet ? 20 : 12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar / Logo del Comercio con marco cristalino
                                Container(
                                  width: isShortHeight
                                      ? 44
                                      : (isTablet ? 68 : 48),
                                  height: isShortHeight
                                      ? 44
                                      : (isTablet ? 68 : 48),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(
                                      isShortHeight ? 12 : (isTablet ? 18 : 15),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.42,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      isShortHeight ? 11 : (isTablet ? 17 : 14),
                                    ),
                                    child:
                                        (_bodega['logoUrl'] != null &&
                                            _bodega['logoUrl']
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                        ? Image.network(
                                            _bodega['logoUrl']
                                                .toString()
                                                .trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Center(
                                              child: Icon(
                                                LucideIcons.store,
                                                size: isShortHeight
                                                    ? 22
                                                    : (isTablet ? 32 : 26),
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              LucideIcons.store,
                                              size: isShortHeight
                                                  ? 22
                                                  : (isTablet ? 32 : 26),
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(
                                  width: isShortHeight
                                      ? 12
                                      : (isTablet ? 18 : 14),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            nombreBodega,
                                            style: GoogleFonts.outfit(
                                              fontSize: isShortHeight
                                                  ? 17
                                                  : (isTablet ? 24 : 19.5),
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.3,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isTablet ? 9 : 8,
                                              vertical: isTablet ? 4 : 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF065F46),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFF34D399),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  LucideIcons.badgeCheck,
                                                  size: 13,
                                                  color: Color(0xFF6EE7B7),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _badgeTipoCatalogo,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: isTablet
                                                        ? 10.5
                                                        : 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.6,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (lema.isNotEmpty &&
                                          !isShortHeight) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          lema,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: isTablet ? 13 : 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.90,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (!isShortHeight) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            // Valoración y Calificación de la Tienda
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.18,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(0xFFFDE047)
                                                      .withValues(alpha: 0.45),
                                                  width: 0.9,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    LucideIcons.star,
                                                    size: 12,
                                                    color: Color(0xFFFACC15),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '4.9 (184)',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Estado Abierto / Cerrado
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: estaAbierto
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.white,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    estaAbierto
                                                        ? 'Abierto ahora'
                                                        : 'Cerrado temporalmente',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (deliveryActivo) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                    width: 0.9,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.bike,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        'Delivery rápido',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.28,
                                                        ),
                                                    width: 0.9,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _esGastronomico
                                                          ? LucideIcons.utensils
                                                          : LucideIcons
                                                                .shoppingBag,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        _textoRetiroLocal,
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B)
                                                      .withValues(alpha: 0.25),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFDE68A,
                                                    ).withValues(alpha: 0.65),
                                                    width: 0.9,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _esGastronomico
                                                          ? LucideIcons.utensils
                                                          : LucideIcons
                                                                .shoppingBag,
                                                      size: 12,
                                                      color: Color(0xFFFEF3C7),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Flexible(
                                                      child: Text(
                                                        _textoSoloRetiroLocal,
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  const Color(
                                                                    0xFFFEF3C7,
                                                                  ),
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            // Contador vivo del catálogo
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.22,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _esGastronomico
                                                        ? LucideIcons.utensils
                                                        : LucideIcons
                                                              .layoutGrid,
                                                    size: 11.5,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Flexible(
                                                    child: Text(
                                                      isTablet
                                                          ? '${_productos.length} ${_esGastronomico ? "platos y bebidas" : "productos"} · ${_categorias.length} ${_esGastronomico ? "secciones" : "categorías"}'
                                                          : '${_productos.length} ${_esGastronomico ? "ítems" : "prods"} · ${_categorias.length} ${_esGastronomico ? "secs" : "cats"}',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_bodega['telefono'] != null &&
                                                _bodega['telefono']
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty)
                                              InkWell(
                                                onTap: () async {
                                                  final rawT =
                                                      _bodega['telefono']
                                                          .toString()
                                                          .trim();
                                                  final l = rawT.replaceAll(
                                                    RegExp(r'[^0-9]'),
                                                    '',
                                                  );
                                                  final tf =
                                                      (l.length == 9 &&
                                                          l.startsWith('9'))
                                                      ? '51$l'
                                                      : (l.startsWith('51')
                                                            ? l
                                                            : '51$l');
                                                  final msg = Uri.encodeComponent(
                                                    '¡Hola *$nombreBodega*! Quisiera hacerles una consulta sobre su catálogo online.',
                                                  );
                                                  final uri = Uri.parse(
                                                    'https://wa.me/$tf?text=$msg',
                                                  );
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(
                                                      uri,
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  }
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 11,
                                                        vertical: 4.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF16A34A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.22,
                                                            ),
                                                        blurRadius: 6,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        LucideIcons
                                                            .messageCircle,
                                                        size: 13,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Flexible(
                                                        child: Text(
                                                          'WhatsApp: ${_bodega['telefono']}',
                                                          style:
                                                              GoogleFonts.outfit(
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (direccion.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                LucideIcons.mapPin,
                                                size: isTablet ? 14 : 12.5,
                                                color: Colors.white.withValues(
                                                  alpha: 0.90,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  direccion,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: isTablet
                                                            ? 12
                                                            : 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.92,
                                                            ),
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cuerpo inferior del Hero: Guía 3 Pasos + Buscador de Alto Contraste
                    Padding(
                      padding: EdgeInsets.all(
                        isShortHeight ? 8 : (isTablet ? 18 : 10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isShortHeight) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 14 : 8,
                                vertical: isTablet ? 10 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0B0F19)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTrustStep(
                                      icon: LucideIcons.shoppingBag,
                                      color: _colorMarcaProfundo,
                                      title: '1. Elige',
                                      desc: 'Agrega a tu lista',
                                      isDark: isDark,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 26,
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  Expanded(
                                    child: _buildTrustStep(
                                      icon: LucideIcons.messageCircle,
                                      color: const Color(0xFF16A34A),
                                      title: '2. Pide',
                                      desc: 'Directo a WhatsApp',
                                      isDark: isDark,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 26,
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  Expanded(
                                    child: _buildTrustStep(
                                      icon: LucideIcons.wallet,
                                      color: const Color(0xFFD97706),
                                      title: '3. Paga',
                                      desc: 'Yape, Plin o Efectivo',
                                      isDark: isDark,
                                      isTablet: isTablet,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isTablet ? 14 : 10),
                          ],
                          if (!estaAbierto) ...[
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTablet ? 12 : 8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF450A0A)
                                          .withValues(alpha: 0.6)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFFFCA5A5),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.doorClosed,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tienda en pausa temporal: puedes explorar productos y precios, pero los pedidos están en espera.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFFFCA5A5)
                                            : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Buscador con contraste reforzado
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (val) {
                              _searchDebounce?.cancel();
                              if (val.isEmpty) {
                                setState(() {
                                  _filtroBusqueda = '';
                                  _recomputeProductosFiltrados();
                                });
                                return;
                              }
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 180),
                                () {
                                  if (!mounted) return;
                                  setState(() {
                                    _filtroBusqueda = val;
                                    _recomputeProductosFiltrados();
                                  });
                                },
                              );
                            },
                            onSubmitted: (val) {
                              _searchDebounce?.cancel();
                              setState(() {
                                _filtroBusqueda = val;
                                _recomputeProductosFiltrados();
                              });
                            },
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isTablet ? 14.5 : 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: _hintBuscador,
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: isTablet ? 14 : 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF475569),
                              ),
                              prefixIcon: Icon(
                                LucideIcons.search,
                                size: isTablet ? 20 : 18,
                                color: _colorMarcaTexto(isDark),
                              ),
                              suffixIcon: _filtroBusqueda.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        LucideIcons.x,
                                        size: isTablet ? 18 : 16,
                                      ),
                                      onPressed: () {
                                        _searchDebounce?.cancel();
                                        _searchCtrl.clear();
                                        setState(() {
                                          _filtroBusqueda = '';
                                          _recomputeProductosFiltrados();
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0B0F19)
                                  : const Color(0xFFF8FAFC),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 14,
                                vertical: isShortHeight
                                    ? 8
                                    : (isTablet ? 14 : 11),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 14 : 12,
                                ),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 14 : 12,
                                ),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 14 : 12,
                                ),
                                borderSide: BorderSide(
                                  color: _colorMarcaTexto(isDark),
                                  width: 1.8,
                                ),
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

            // Carrusel Hero de Promociones Activas
            SliverToBoxAdapter(
              child: _buildPromocionesHeroBanner(isDark, isTablet),
            ),

            // Historias / Destacados Rápidos ("Stories" tipo Instagram / Rappi)
            SliverToBoxAdapter(child: _buildStoriesRow(isDark, isTablet)),

            // Barra de Categorías con Iconos Temáticos, Conteo y Flechas Desktop
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 8 : 6,
                ),
                child: Row(
                  children: [
                    if (isTablet) ...[
                      _buildScrollArrowButton(
                        icon: LucideIcons.chevronLeft,
                        isDark: isDark,
                        onTap: () => _scrollCategorias(-320),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _catScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildCategoriaChip(
                              'TODAS',
                              _esGastronomico ? 'Carta' : 'Todos',
                              isDark,
                              isTablet,
                              count: _productos.length,
                            ),
                            if (_ofertasCount > 0)
                              _buildCategoriaChip(
                                'OFERTAS',
                                'Ofertas',
                                isDark,
                                isTablet,
                                esOferta: true,
                                count: _ofertasCount,
                              ),
                            ..._categorias.map(
                              (c) => _buildCategoriaChip(
                                c,
                                c,
                                isDark,
                                isTablet,
                                count:
                                    _conteoPorCategoria[c.trim().toUpperCase()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isTablet) ...[
                      const SizedBox(width: 8),
                      _buildScrollArrowButton(
                        icon: LucideIcons.chevronRight,
                        isDark: isDark,
                        onTap: () => _scrollCategorias(320),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Barra de Resultados y Ordenamiento
            SliverToBoxAdapter(
              child: _buildResultsAndSortBar(prods.length, isDark, isTablet),
            ),

            // Grilla de Productos
            if (prods.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _esGastronomico
                            ? LucideIcons.utensils
                            : LucideIcons.shoppingBag,
                        size: isTablet ? 48 : 40,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron ${_esGastronomico ? "platos ni bebidas" : "productos"}',
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prueba con otro término de búsqueda o ${_esGastronomico ? "sección del menú." : "categoría."}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.crossAxisExtent;
                  final config = _getDeviceConfig(context, width);

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 20 : 16,
                      10,
                      isTablet ? 20 : 16,
                      20,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: config.crossAxisCount,
                        childAspectRatio: config.childAspectRatio,
                        crossAxisSpacing: config.gridSpacing,
                        mainAxisSpacing: config.gridSpacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildProductoCard(prods[index], isDark, config),
                        childCount: prods.length,
                      ),
                    ),
                  );
                },
              ),
            SliverToBoxAdapter(child: _buildFooterLegal(context, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesRow(bool isDark, bool isTablet) {
    if (_productos.isEmpty) return const SizedBox.shrink();

    final List<_StoryConfig> stories = [];

    if (_esGastronomico) {
      if (_ofertasCount > 0) {
        stories.add(
          const _StoryConfig(
            label: 'Ofertas Flash',
            icon: LucideIcons.flame,
            gradient: [Color(0xFFF43F5E), Color(0xFFF59E0B)],
            directCategory: 'OFERTAS',
          ),
        );
      }
      stories.addAll(const [
        _StoryConfig(
          label: 'Pollos Brasa',
          icon: LucideIcons.drumstick,
          gradient: [Color(0xFFEA580C), Color(0xFFF97316)],
          keywords: ['POLLO', 'BRASA', 'COMBO'],
        ),
        _StoryConfig(
          label: 'Chifa & Chaufa',
          icon: LucideIcons.utensilsCrossed,
          gradient: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          keywords: ['CHIFA', 'CHAUFA', 'AEROPUERTO', 'TALLARIN'],
        ),
        _StoryConfig(
          label: 'Guarniciones',
          icon: LucideIcons.utensils,
          gradient: [Color(0xFFEAB308), Color(0xFFCA8A04)],
          keywords: ['GUARNICION', 'PAPA', 'PORCION'],
        ),
        _StoryConfig(
          label: 'Jarras & Bebidas',
          icon: LucideIcons.cupSoda,
          gradient: [Color(0xFF0284C7), Color(0xFF0369A1)],
          keywords: ['BEBIDA', 'JARRA', 'CHICHA', 'REFRESCO', 'GASEOSA'],
        ),
        _StoryConfig(
          label: 'Salsas & Ají',
          icon: LucideIcons.sparkles,
          gradient: [Color(0xFF16A34A), Color(0xFF15803D)],
          keywords: ['SALSA', 'AJI', 'CREMA', 'EXTRA'],
        ),
      ]);
    } else {
      if (_ofertasCount > 0) {
        stories.add(
          const _StoryConfig(
            label: 'Ofertas Flash',
            icon: LucideIcons.flame,
            gradient: [Color(0xFFF43F5E), Color(0xFFF59E0B)],
            directCategory: 'OFERTAS',
          ),
        );
      }
      stories.addAll(const [
        _StoryConfig(
          label: 'Chelas & Licores',
          icon: LucideIcons.bottleWine,
          gradient: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          keywords: ['ALCOHOL', 'LICOR', 'CERVEZA', 'VINOS'],
        ),
        _StoryConfig(
          label: 'Gaseosas',
          icon: LucideIcons.cupSoda,
          gradient: [Color(0xFF38BDF8), Color(0xFF2563EB)],
          keywords: ['GASEOSA', 'BEBIDA', 'REFRESCO', 'AGUA'],
        ),
        _StoryConfig(
          label: 'Snacks Snax',
          icon: LucideIcons.cookie,
          gradient: [Color(0xFFFBBF24), Color(0xFFEA580C)],
          keywords: ['SNACK', 'PIQUEO', 'PAPAS', 'DORITOS'],
        ),
        _StoryConfig(
          label: 'Lácteos Gloria',
          icon: LucideIcons.milk,
          gradient: [Color(0xFF60A5FA), Color(0xFF6366F1)],
          keywords: ['LÁCTEO', 'LACTEO', 'LECHE', 'YOGURT', 'QUESO', 'HUEVO'],
        ),
        _StoryConfig(
          label: 'Despensa Básica',
          icon: LucideIcons.shoppingBag,
          gradient: [Color(0xFF34D399), Color(0xFF059669)],
          keywords: [
            'ABARROTE',
            'DESPENSA',
            'VÍVERE',
            'ARROZ',
            'AZÚCAR',
            'ACEITE',
          ],
        ),
        _StoryConfig(
          label: 'Hogar & Aseo',
          icon: LucideIcons.sparkles,
          gradient: [Color(0xFF22D3EE), Color(0xFF0D9488)],
          keywords: ['LIMPIEZA', 'ASEO', 'HOGAR', 'DETERGENTE', 'JABÓN'],
        ),
      ]);
    }

    final activeStories = <_ResolvedStory>[];
    for (final s in stories) {
      if (s.directCategory != null) {
        activeStories.add(
          _ResolvedStory(config: s, targetCategory: s.directCategory!),
        );
      } else {
        String? match;
        for (final cat in _categorias) {
          final catU = cat.toUpperCase();
          for (final kw in s.keywords) {
            if (catU.contains(kw.toUpperCase())) {
              match = cat;
              break;
            }
          }
          if (match != null) break;
        }
        if (match != null &&
            (_conteoPorCategoria[match.trim().toUpperCase()] ?? 0) > 0) {
          activeStories.add(_ResolvedStory(config: s, targetCategory: match));
        }
      }
    }

    if (activeStories.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: isTablet ? 6 : 4, bottom: isTablet ? 8 : 4),
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: activeStories.map((resolved) {
            final isSelected =
                _categoriaSeleccionada.toUpperCase() ==
                resolved.targetCategory.toUpperCase();
            final double ringSize = isTablet ? 56 : 50;
            final double iconSize = isTablet ? 23 : 20;

            return Padding(
              padding: EdgeInsets.only(right: isTablet ? 14 : 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _categoriaSeleccionada = 'TODAS';
                    } else {
                      _categoriaSeleccionada = resolved.targetCategory;
                    }
                    _recomputeProductosFiltrados();
                  });
                },
                child: SizedBox(
                  width: isTablet ? 72 : 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: ringSize,
                        height: ringSize,
                        padding: const EdgeInsets.all(2.4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: resolved.config.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: resolved.config.gradient.first.withValues(
                                alpha: isSelected ? 0.45 : 0.22,
                              ),
                              blurRadius: isSelected ? 8 : 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? resolved.config.gradient.first
                                : (isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white),
                          ),
                          child: Center(
                            child: Icon(
                              resolved.config.icon,
                              size: iconSize,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        resolved.config.label,
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 11 : 10,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isSelected
                              ? _colorMarcaTexto(isDark)
                              : (isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF334155)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFooterLegal(BuildContext context, bool isDark) {
    final String nombreBodega =
        _bodega['nombreComercial']?.toString() ?? 'CajaYa Cloud POS';
    final int? idBodega = _bodega['idBodega'] is int
        ? _bodega['idBodega']
        : int.tryParse(_bodega['idBodega']?.toString() ?? '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CajaYaLogoMark(size: 26),
              const SizedBox(width: 8),
              Text(
                'CajaYa Cloud POS',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$nombreBodega • $_textoFooterOficial',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.getAdaptiveMutedText(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Botón Oficial Libro de Reclamaciones INDECOPI
          InkWell(
            onTap: () {
              final query = Uri(
                queryParameters: {
                  'tienda': nombreBodega,
                  if (idBodega != null) 'idBodega': idBodega.toString(),
                },
              ).query;
              context.push('/reclamaciones?$query');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.bookOpen,
                      color: Color(0xFFD97706),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LIBRO DE RECLAMACIONES',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Conforme a la normativa INDECOPI - D.S. N° 011-2011-PCM',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          color: AppTheme.getAdaptiveMutedText(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppTheme.getAdaptiveMutedText(isDark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Enlaces Legales
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: () => context.push('/terminos'),
                child: Text(
                  'Términos y Condiciones',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _colorMarca,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: AppTheme.getAdaptiveHintText(isDark)),
              ),
              InkWell(
                onTap: () => context.push('/privacidad'),
                child: Text(
                  'Política de Privacidad',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _colorMarca,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Comercio formalizado bajo la Ley del Bodeguero N° 30877 y Código del Consumidor N° 29571.\nTodos los derechos reservados © 2026 CajaYa.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: AppTheme.getAdaptiveHintText(isDark),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  _CatalogoDeviceConfig _getDeviceConfig(BuildContext context, double width) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isLandscape = mediaQuery.orientation == Orientation.landscape;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTabletDevice =
        isPhysicalTablet || (width >= 650 && mediaQuery.size.height >= 550);

    if (isTabletDevice) {
      if (isLandscape) {
        // Tablet en Horizontal (o Desktop grande)
        final int cols = width >= 1250 ? 4 : 3;
        return _CatalogoDeviceConfig(
          crossAxisCount: cols,
          childAspectRatio: 0.74,
          maxImageSize: 140.0,
          categoriaFontSize: 12.0,
          nombreFontSize: 16.5,
          precioFontSize: 21.0,
          botonHeight: 44.0,
          botonFontSize: 14.0,
          botonIconSize: 18.0,
          cardPadding: 14.0,
          gridSpacing: 16.0,
          isTablet: true,
        );
      } else {
        // Tablet en Vertical
        final int cols = width >= 900 ? 3 : 2;
        return _CatalogoDeviceConfig(
          crossAxisCount: cols,
          childAspectRatio: 0.72,
          maxImageSize: 150.0,
          categoriaFontSize: 12.0,
          nombreFontSize: 17.0,
          precioFontSize: 22.0,
          botonHeight: 44.0,
          botonFontSize: 14.5,
          botonIconSize: 18.0,
          cardPadding: 14.0,
          gridSpacing: 16.0,
          isTablet: true,
        );
      }
    } else if (isLandscape) {
      // Celular en Horizontal
      final int cols = width >= 800 ? 3 : 2;
      return _CatalogoDeviceConfig(
        crossAxisCount: cols,
        childAspectRatio: 0.76,
        maxImageSize: 105.0,
        categoriaFontSize: 11.0,
        nombreFontSize: 15.0,
        precioFontSize: 18.0,
        botonHeight: 40.0,
        botonFontSize: 13.0,
        botonIconSize: 16.0,
        cardPadding: 12.0,
        gridSpacing: 12.0,
        isTablet: false,
      );
    } else {
      // Celular en Vertical
      return const _CatalogoDeviceConfig(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        maxImageSize: 84.0,
        categoriaFontSize: 10.0,
        nombreFontSize: 13.5,
        precioFontSize: 16.0,
        botonHeight: 36.0,
        botonFontSize: 12.0,
        botonIconSize: 14.0,
        cardPadding: 10.0,
        gridSpacing: 10.0,
        isTablet: false,
      );
    }
  }

  Widget _buildScrollArrowButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  String get _ordenLabel {
    switch (_ordenSeleccionado) {
      case 'PRECIO_ASC':
        return 'Menor precio';
      case 'PRECIO_DESC':
        return 'Mayor precio';
      case 'NOMBRE_AZ':
        return 'Nombre A-Z';
      default:
        return 'Destacados';
    }
  }

  Widget _buildResultsAndSortBar(
    int totalMostrados,
    bool isDark,
    bool isTablet,
  ) {
    final bool estaFiltrado =
        _categoriaSeleccionada != 'TODAS' || _filtroBusqueda.trim().isNotEmpty;
    final String tituloActual = _categoriaSeleccionada == 'TODAS'
        ? (_esGastronomico ? 'Carta completa' : 'Catálogo completo')
        : (_categoriaSeleccionada == 'OFERTAS'
              ? 'Ofertas activas'
              : _categoriaSeleccionada);
    final Color activeColor = _categoriaSeleccionada == 'OFERTAS'
        ? _colorPromocion
        : (_categoriaSeleccionada == 'TODAS'
              ? _colorMarcaTexto(isDark)
              : CategoryHelper.getColor(_categoriaSeleccionada, isDark));
    final IconData activeIcon = _categoriaSeleccionada == 'OFERTAS'
        ? LucideIcons.flame
        : (_categoriaSeleccionada == 'TODAS'
              ? (_esGastronomico
                    ? LucideIcons.utensils
                    : LucideIcons.layoutGrid)
              : CategoryHelper.getIcon(_categoriaSeleccionada));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 20 : 16,
        4,
        isTablet ? 20 : 16,
        2,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activeIcon, size: 14, color: activeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tituloActual,
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 15 : 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalMostrados ${totalMostrados == 1 ? "disponible" : "disponibles"}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
                if (estaFiltrado)
                  InkWell(
                    onTap: () {
                      _searchDebounce?.cancel();
                      _searchCtrl.clear();
                      setState(() {
                        _categoriaSeleccionada = 'TODAS';
                        _filtroBusqueda = '';
                        _recomputeProductosFiltrados();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: _colorMarcaTexto(isDark).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.x,
                            size: 11,
                            color: _colorMarcaTexto(isDark),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Limpiar filtro',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _colorMarcaTexto(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            initialValue: _ordenSeleccionado,
            tooltip: 'Ordenar productos',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (val) {
              setState(() {
                _ordenSeleccionado = val;
                _recomputeProductosFiltrados();
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'DESTACADOS', child: Text('Destacados')),
              PopupMenuItem(value: 'PRECIO_ASC', child: Text('Menor precio')),
              PopupMenuItem(value: 'PRECIO_DESC', child: Text('Mayor precio')),
              PopupMenuItem(value: 'NOMBRE_AZ', child: Text('Nombre A-Z')),
            ],
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 9,
                vertical: isTablet ? 7 : 6,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.arrowUpDown,
                    size: 13.5,
                    color: _colorMarcaTexto(isDark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ordenLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
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

  Widget _buildCategoriaChip(
    String key,
    String label,
    bool isDark,
    bool isTablet, {
    bool esOferta = false,
    int? count,
  }) {
    final isSelected =
        _categoriaSeleccionada.toUpperCase() == key.toUpperCase();
    final Color catAccent = esOferta
        ? _colorPromocion
        : (key == 'TODAS'
              ? _colorMarcaTexto(isDark)
              : CategoryHelper.getColor(key, isDark));
    final List<Color> selectedGradient = esOferta
        ? [
            HSLColor.fromColor(_colorPromocion)
                .withLightness(
                  (HSLColor.fromColor(_colorPromocion).lightness - 0.10).clamp(
                    0.18,
                    0.42,
                  ),
                )
                .toColor(),
            _colorPromocion,
          ]
        : (key == 'TODAS'
              ? [_colorMarcaProfundo, _colorMarca]
              : CategoryHelper.getGradientColors(key, isDark));
    final iconData = esOferta
        ? LucideIcons.flame
        : (key == 'TODAS'
              ? (_esGastronomico
                    ? LucideIcons.utensils
                    : LucideIcons.layoutGrid)
              : CategoryHelper.getIcon(key));

    return Padding(
      padding: EdgeInsets.only(right: isTablet ? 10 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isTablet ? 15 : 13),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _categoriaSeleccionada = key;
              _recomputeProductosFiltrados();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              isTablet ? 8 : 7,
              isTablet ? 7 : 6,
              isTablet ? 12 : 10,
              isTablet ? 7 : 6,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: selectedGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark
                        ? (esOferta
                              ? _colorPromocion.withValues(alpha: 0.16)
                              : const Color(0xFF162032))
                        : (esOferta
                              ? _colorPromocion.withValues(alpha: 0.08)
                              : Colors.white)),
              borderRadius: BorderRadius.circular(isTablet ? 15 : 13),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : (esOferta
                          ? _colorPromocion.withValues(alpha: 0.45)
                          : (isDark
                                ? const Color(0xFF283548)
                                : const Color(0xFFE2E8F0))),
                width: 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: selectedGradient.first.withValues(
                          alpha: isDark ? 0.40 : 0.28,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      if (!isDark)
                        BoxShadow(
                          color: const Color(0xFF0F172A)
                              .withValues(alpha: 0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Medallón de icono temático con color propio de categoría
                Container(
                  width: isTablet ? 28 : 24,
                  height: isTablet ? 28 : 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : catAccent.withValues(alpha: isDark ? 0.22 : 0.13),
                    borderRadius: BorderRadius.circular(isTablet ? 9 : 7),
                  ),
                  child: Icon(
                    iconData,
                    size: isTablet ? 15 : 13.5,
                    color: isSelected ? Colors.white : catAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isTablet ? 13 : 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (esOferta
                              ? (isDark
                                    ? const Color(0xFFFDA4AF)
                                    : _colorPromocion)
                              : (isDark
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF0F172A))),
                  ),
                ),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : (isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.outfit(
                        fontSize: isTablet ? 11 : 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _esProductoRetornable(Map<String, dynamic> prod) {
    final nombre = (prod['nombre'] ?? '').toString().toLowerCase();
    final categoria = (prod['categoria'] ?? '').toString().toLowerCase();
    if (nombre.contains('retornable') ||
        nombre.contains('envase') ||
        nombre.contains('vidrio')) {
      return true;
    }
    final esCervezaBotella =
        (categoria.contains('cerveza') ||
            nombre.contains('cerveza') ||
            nombre.contains('pilsen') ||
            nombre.contains('cristal') ||
            nombre.contains('cusqueña') ||
            nombre.contains('arequipeña') ||
            nombre.contains('trujillana')) &&
        (nombre.contains('650') ||
            nombre.contains('630') ||
            nombre.contains('620') ||
            nombre.contains('1l') ||
            nombre.contains('1.1l') ||
            nombre.contains('litro')) &&
        !nombre.contains('lata');
    return esCervezaBotella;
  }

  Widget _buildProductoCard(
    Map<String, dynamic> prod,
    bool isDark,
    _CatalogoDeviceConfig config,
  ) {
    final int id = (prod['idProducto'] is num)
        ? (prod['idProducto'] as num).toInt()
        : int.tryParse(prod['idProducto']?.toString() ?? '') ?? 0;
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : 0.0;
    final double? promoPrice = (prod['precioPromocional'] is num)
        ? (prod['precioPromocional'] as num).toDouble()
        : null;
    final bool tienePromoValida =
        prod['tienePromocion'] == true &&
        promoPrice != null &&
        promoPrice < precio;
    final int descuentoPct = (tienePromoValida && precio > 0)
        ? (((precio - promoPrice) / precio) * 100).round()
        : 0;
    final int cantidadEnCarrito = _cantidadDeProductoEnCarrito(id);
    final bool isTablet = config.isTablet;
    final catColor = CategoryHelper.getColor(categoria, isDark);
    final catIcon = CategoryHelper.getIcon(categoria);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        border: Border.all(
          color: cantidadEnCarrito > 0
              ? _colorMarcaTexto(isDark)
              : (isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
          width: cantidadEnCarrito > 0 ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: cantidadEnCarrito > 0
                ? _colorMarcaProfundo.withValues(alpha: isDark ? 0.30 : 0.18)
                : (isDark
                      ? Colors.black.withValues(alpha: 0.28)
                      : const Color(0xFF0F172A).withValues(alpha: 0.06)),
            blurRadius: isTablet ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isTablet ? 20 : 18),
                ),
                onTap: () => _mostrarDetalleProductoOnline(prod),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Escenario de estudio limpio (sin doble marco)
                    Expanded(
                      flex: 3,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(
                          isTablet ? 10 : 8,
                          isTablet ? 10 : 8,
                          isTablet ? 10 : 8,
                          isTablet ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 14,
                          ),
                        ),
                        child: Stack(
                          children: [
                            LayoutBuilder(
                              builder: (context, boxConstraints) {
                                final availableMax = math.min(
                                  boxConstraints.maxWidth,
                                  boxConstraints.maxHeight,
                                );
                                final double effectiveSize =
                                    (availableMax * 0.90).clamp(
                                      68.0,
                                      config.maxImageSize + 14,
                                    );
                                return Center(
                                  child: ProductImageWidget(
                                    imagenUrl: imagenUrl,
                                    nombre: nombre,
                                    codigoBarras: codigoBarras,
                                    categoria: categoria,
                                    size: effectiveSize,
                                    borderRadius: isTablet ? 14 : 12,
                                    isDark: false,
                                    seamless: true,
                                  ),
                                );
                              },
                            ),
                            if (prod['tienePromocion'] == true)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _parseColorBadge(prod['colorBadge']),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _parseColorBadge(
                                          prod['colorBadge'],
                                        ).withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _iconoParaPromo(
                                          prod['badgePromocion']?.toString() ??
                                              'OFERTA',
                                        ),
                                        size: 10.5,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _limpiarBadgePromo(
                                          prod['badgePromocion']?.toString() ??
                                              'OFERTA',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: isTablet ? 10.5 : 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (cantidadEnCarrito > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: _brandGradient,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _colorMarcaProfundo.withValues(
                                          alpha: 0.30,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.check,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$cantidadEnCarrito',
                                        style: GoogleFonts.outfit(
                                          fontSize: isTablet ? 11 : 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
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

                    // Datos del Producto (Categoría con Icono, Marca, Título, Precio)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: config.cardPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 7 : 5.5,
                                  vertical: isTablet ? 3 : 2,
                                ),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(
                                    alpha: isDark ? 0.20 : 0.11,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isTablet ? 7 : 5.5,
                                  ),
                                  border: Border.all(
                                    color: catColor.withValues(
                                      alpha: isDark ? 0.38 : 0.24,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      catIcon,
                                      size: isTablet ? 11 : 9.5,
                                      color: catColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        categoria.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize:
                                              (config.categoriaFontSize - 0.5)
                                                  .clamp(8.5, 11.0),
                                          fontWeight: FontWeight.w800,
                                          color: catColor,
                                          letterSpacing: 0.25,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (prod['marca'] != null &&
                                  prod['marca'].toString().trim().isNotEmpty &&
                                  prod['marca']
                                          .toString()
                                          .trim()
                                          .toLowerCase() !=
                                      'general' &&
                                  prod['marca']
                                          .toString()
                                          .trim()
                                          .toLowerCase() !=
                                      categoria.toLowerCase())
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 6 : 5,
                                    vertical: isTablet ? 3 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(
                                      isTablet ? 7 : 5.5,
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    prod['marca']
                                        .toString()
                                        .trim()
                                        .toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize:
                                          (config.categoriaFontSize * 0.90)
                                              .clamp(8.5, 10.5),
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                      letterSpacing: 0.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (_esProductoRetornable(prod))
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 6 : 5,
                                    vertical: isTablet ? 3 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0284C7,
                                    ).withValues(alpha: isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(
                                      isTablet ? 7 : 5.5,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.35),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.bottleWine,
                                        size: 9.5,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 2.5),
                                      Text(
                                        'Retornable',
                                        style: GoogleFonts.outfit(
                                          fontSize:
                                              (config.categoriaFontSize * 0.90)
                                                  .clamp(8.5, 10.5),
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? const Color(0xFF38BDF8)
                                              : const Color(0xFF0369A1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          Text(
                            nombre,
                            style: GoogleFonts.outfit(
                              fontSize: config.nombreFontSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          if (tienePromoValida) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: (config.precioFontSize * 0.66)
                                        .clamp(9.5, 13.0),
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.lineThrough,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                if (descuentoPct > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _colorPromocion.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _colorPromocion.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '-$descuentoPct%',
                                      style: GoogleFonts.outfit(
                                        fontSize: (config.precioFontSize * 0.52)
                                            .clamp(8.5, 11.0),
                                        fontWeight: FontWeight.w900,
                                        color: _colorPromocion,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'S/ ${promoPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: config.precioFontSize,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: _colorPromocion,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'S/ ${precio.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: config.precioFontSize,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Botón CTA de Alto Contraste / Selector de Cantidad
          Padding(
            padding: EdgeInsets.fromLTRB(
              config.cardPadding,
              isTablet ? 6 : 4,
              config.cardPadding,
              config.cardPadding,
            ),
            child: cantidadEnCarrito == 0
                ? Container(
                    height: config.botonHeight,
                    decoration: BoxDecoration(
                      gradient: _brandGradient,
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                      boxShadow: [
                        BoxShadow(
                          color: _colorMarcaProfundo.withValues(
                            alpha: isDark ? 0.30 : 0.22,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 10,
                          ),
                        ),
                      ),
                      onPressed: () {
                        if (GastronomiaHelper.esProductoConPresa(
                          nombre,
                          categoria,
                        )) {
                          _mostrarDetalleProductoOnline(prod);
                        } else {
                          _modificarCantidad(id, 1);
                        }
                      },
                      icon: Icon(LucideIcons.plus, size: config.botonIconSize),
                      label: Text(
                        'Agregar',
                        style: GoogleFonts.outfit(
                          fontSize: config.botonFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: config.botonHeight,
                    decoration: BoxDecoration(
                      color: _colorMarcaTexto(isDark)
                          .withValues(alpha: isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                      border: Border.all(
                        color: _colorMarcaTexto(isDark).withValues(alpha: 0.40),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: config.botonHeight,
                            minHeight: config.botonHeight,
                          ),
                          icon: Icon(
                            LucideIcons.minus,
                            size: config.botonIconSize,
                            color: _colorMarcaTexto(isDark),
                          ),
                          onPressed: () => _modificarCantidad(id, -1),
                        ),
                        Text(
                          '$cantidadEnCarrito',
                          style: GoogleFonts.outfit(
                            fontSize: config.botonFontSize + 1,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: _colorMarcaTexto(isDark),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: config.botonHeight,
                            minHeight: config.botonHeight,
                          ),
                          icon: Icon(
                            LucideIcons.plus,
                            size: config.botonIconSize,
                            color: _colorMarcaTexto(isDark),
                          ),
                          onPressed: () {
                            if (GastronomiaHelper.esProductoConPresa(
                              nombre,
                              categoria,
                            )) {
                              _mostrarDetalleProductoOnline(prod);
                            } else {
                              _modificarCantidad(id, 1);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleProductoOnline(Map<String, dynamic> prod) {
    final int id = (prod['idProducto'] is num)
        ? (prod['idProducto'] as num).toInt()
        : int.tryParse(prod['idProducto']?.toString() ?? '') ?? 0;
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String marca = prod['marca']?.toString() ?? '';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : 0.0;
    final double? promoPrice = (prod['precioPromocional'] is num)
        ? (prod['precioPromocional'] as num).toDouble()
        : null;
    final bool tienePromoValida =
        prod['tienePromocion'] == true &&
        promoPrice != null &&
        promoPrice < precio;
    final int descuentoPct = (tienePromoValida && precio > 0)
        ? (((precio - promoPrice) / precio) * 100).round()
        : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool esPolloConPresa = GastronomiaHelper.esProductoConPresa(
      nombre,
      categoria,
    );
    final List<String> opcionesPresa = GastronomiaHelper.opcionesPresa(nombre);
    final bool tieneOpcionesMultiples = opcionesPresa.length > 1;
    String seleccionPresa = opcionesPresa.isNotEmpty
        ? opcionesPresa.first
        : 'Pecho (con ala)';
    String seleccionEnsalada = GastronomiaHelper.opcionesEnsalada().first;
    String seleccionPapas = GastronomiaHelper.opcionesPapas().first;
    final TextEditingController notasCtrl = TextEditingController();

    AdaptiveModal.show(
      context: context,
      maxWidth: 540,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isWide = ResponsiveLayout.isTabletOrLarger(modalCtx);
            final String cartKeyActual = esPolloConPresa
                ? '$id#$seleccionPresa'
                : '$id';
            final int cantActual = _carrito[cartKeyActual]?.cantidad ?? 0;

            return Align(
              alignment: isWide ? Alignment.center : Alignment.bottomCenter,
              heightFactor: isWide ? 1.0 : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: isWide
                        ? BorderRadius.circular(24)
                        : const BorderRadius.vertical(top: Radius.circular(28)),
                    border: isDark
                        ? Border.all(
                            color: AppTheme.borderDarkElevated,
                            width: 1.2,
                          )
                        : Border.all(
                            color: isWide
                                ? AppTheme.borderLight
                                : Colors.transparent,
                            width: 1.0,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.45 : 0.25,
                        ),
                        blurRadius: isWide ? 30 : 24,
                        offset: isWide
                            ? const Offset(0, 10)
                            : const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    isWide ? 20 : 14,
                    22,
                    (isWide
                        ? 24
                        : 24 + MediaQuery.of(modalCtx).viewInsets.bottom),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isWide) ...[
                          // Barra de arrastre superior
                          Center(
                            child: Container(
                              width: 46,
                              height: 5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _colorMarca,
                                    _colorMarca.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Encabezado: Volver al catálogo, Categoría y Botón Cerrar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF1E293B),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(LucideIcons.arrowLeft, size: 16),
                              label: Text(
                                'Volver',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Builder(
                                builder: (_) {
                                  final cColor = CategoryHelper.getColor(
                                    categoria,
                                    isDark,
                                  );
                                  final cIcon = CategoryHelper.getIcon(
                                    categoria,
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cColor.withValues(
                                        alpha: isDark ? 0.22 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: cColor.withValues(alpha: 0.32),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(cIcon, size: 13, color: cColor),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            categoria.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: cColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                size: 18,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              onPressed: () => Navigator.pop(modalCtx),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Fotografía Packshot en Gran Detalle (Escenario estudio limpio)
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(
                              (MediaQuery.of(modalCtx).size.height < 700 ||
                                      MediaQuery.of(modalCtx).size.width < 380)
                                  ? 4
                                  : 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                            ),
                            child: ProductImageWidget(
                              imagenUrl: imagenUrl,
                              nombre: nombre,
                              codigoBarras: codigoBarras,
                              categoria: categoria,
                              size:
                                  (MediaQuery.of(modalCtx).size.height < 700 ||
                                      MediaQuery.of(modalCtx).size.width < 380)
                                  ? 106
                                  : 160,
                              borderRadius: 18,
                              isDark: false,
                              seamless: true,
                              padding: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nombre del Producto
                        Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Badges de SKU / Marca / Disponibilidad
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            if (marca.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Marca: $marca',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            if (codigo.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SKU: $codigo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.check,
                                    size: 12,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Disponible en tienda',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_esProductoRetornable(prod))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7)
                                      .withValues(alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF0284C7)
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.bottleWine,
                                      size: 12,
                                      color: Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Botella Retornable',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFF0369A1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Precio y Banner de Promoción
                        if (tienePromoValida) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _parseColorBadge(prod['colorBadge'])
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _parseColorBadge(prod['colorBadge'])
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 15,
                                  color: _parseColorBadge(prod['colorBadge']),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${prod['badgePromocion'] ?? "OFERTA"} • ${prod['tituloPromocion'] ?? "Descuento Especial"}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _parseColorBadge(
                                        prod['colorBadge'],
                                      ),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      'S/ ${precio.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.lineThrough,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'S/ ${promoPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: _colorPromocion,
                                      ),
                                    ),
                                  ],
                                ),
                                if (descuentoPct > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _colorPromocion.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _colorPromocion.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Text(
                                      'Ahorras S/ ${(precio - promoPrice).toStringAsFixed(2)} (-$descuentoPct%)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _colorPromocion,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          Center(
                            child: Text(
                              'S/ ${precio.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        if (esPolloConPresa) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD97706)
                                    .withValues(alpha: isDark ? 0.35 : 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tieneOpcionesMultiples) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.drumstick,
                                        size: 16,
                                        color: Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'SELECCIONA TU PRESA FAVORITA',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFD97706),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: opcionesPresa.map((opt) {
                                      final isSel = seleccionPresa == opt;
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setModalState(
                                                () => seleccionPresa = opt,
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isSel
                                                    ? const Color(0xFFD97706)
                                                    : (isDark
                                                          ? const Color(
                                                              0xFF1E293B,
                                                            )
                                                          : Colors.white),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSel
                                                      ? const Color(0xFFD97706)
                                                      : (isDark
                                                            ? Colors.white12
                                                            : const Color(
                                                                0xFFCBD5E1,
                                                              )),
                                                  width: isSel ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    LucideIcons.utensils,
                                                    size: 16,
                                                    color: isSel
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.white70
                                                              : const Color(
                                                                  0xFF475569,
                                                                )),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    opt,
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: isSel
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: isSel
                                                          ? Colors.white
                                                          : (isDark
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFF1E293B,
                                                                  )),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ] else ...[
                                  // Forma clásica incluida (1/2 Pollo o Entero)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFD97706)
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.drumstick,
                                          size: 18,
                                          color: Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'FORMA CLÁSICA INCLUIDA',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(
                                                    0xFFD97706,
                                                  ),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Text(
                                                opcionesPresa.isNotEmpty
                                                    ? opcionesPresa.first
                                                    : 'Pecho y Pierna (Clásico)',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppTheme.textDark,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          LucideIcons.checkCircle2,
                                          size: 18,
                                          color: Color(0xFF059669),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Text(
                                  'Elección de Ensalada',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: GastronomiaHelper.opcionesEnsalada()
                                      .map((ens) {
                                        final isSel = seleccionEnsalada == ens;
                                        return ChoiceChip(
                                          label: Text(
                                            ens,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: isSel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSel
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF334155,
                                                          )),
                                            ),
                                          ),
                                          selected: isSel,
                                          selectedColor: const Color(
                                            0xFF059669,
                                          ),
                                          backgroundColor: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          onSelected: (val) {
                                            if (val) {
                                              setModalState(
                                                () => seleccionEnsalada = ens,
                                              );
                                            }
                                          },
                                        );
                                      })
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Guarnición de Papas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: GastronomiaHelper.opcionesPapas()
                                      .map((pap) {
                                        final isSel = seleccionPapas == pap;
                                        return ChoiceChip(
                                          label: Text(
                                            pap,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: isSel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSel
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF334155,
                                                          )),
                                            ),
                                          ),
                                          selected: isSel,
                                          selectedColor: const Color(
                                            0xFFD97706,
                                          ),
                                          backgroundColor: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          onSelected: (val) {
                                            if (val) {
                                              setModalState(
                                                () => seleccionPapas = pap,
                                              );
                                            }
                                          },
                                        );
                                      })
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: notasCtrl,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Indicaciones para cocina (ej. Piel crocante, ají extra)...',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Controles de Carrito y Selección
                        if (cantActual == 0) ...[
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _colorMarca,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                LucideIcons.shoppingBag,
                                size: 20,
                              ),
                              label: Text(
                                esPolloConPresa
                                    ? 'Agregar $seleccionPresa'
                                    : 'Agregar al Pedido',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: () {
                                final notasFinal = esPolloConPresa
                                    ? [
                                        seleccionEnsalada,
                                        seleccionPapas,
                                        if (notasCtrl.text.trim().isNotEmpty)
                                          notasCtrl.text.trim(),
                                      ].join(' • ')
                                    : null;
                                _modificarCantidad(
                                  id,
                                  1,
                                  variante: esPolloConPresa
                                      ? seleccionPresa
                                      : null,
                                  notas: notasFinal,
                                );
                                setModalState(() {});
                              },
                            ),
                          ),
                        ] else ...[
                          // Estado: Producto ya agregado, con opción rápida de "Quitar" (retroceder selección)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.checkCircle2,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    esPolloConPresa
                                        ? 'En tu pedido ($seleccionPresa): $cantActual u.'
                                        : 'En tu pedido ($cantActual ${cantActual == 1 ? "unidad" : "unidades"})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 14,
                                  ),
                                  label: Text(
                                    'Quitar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onPressed: () {
                                    _modificarCantidad(
                                      id,
                                      -cantActual,
                                      variante: esPolloConPresa
                                          ? seleccionPresa
                                          : null,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Fila con Stepper [-] [cant] [+] y Botón Ver Pedido
                          Row(
                            children: [
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.minus,
                                        size: 16,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Disminuir',
                                      onPressed: () {
                                        _modificarCantidad(
                                          id,
                                          -1,
                                          variante: esPolloConPresa
                                              ? seleccionPresa
                                              : null,
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        '$cantActual',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.plus,
                                        size: 16,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Aumentar',
                                      onPressed: () {
                                        final notasFinal = esPolloConPresa
                                            ? [
                                                seleccionEnsalada,
                                                seleccionPapas,
                                                if (notasCtrl.text
                                                    .trim()
                                                    .isNotEmpty)
                                                  notasCtrl.text.trim(),
                                              ].join(' • ')
                                            : null;
                                        _modificarCantidad(
                                          id,
                                          1,
                                          variante: esPolloConPresa
                                              ? seleccionPresa
                                              : null,
                                          notas: notasFinal,
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _colorMarca,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.shoppingCart,
                                      size: 17,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Ver Pedido ($_totalUnidadesCarrito)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(modalCtx);
                                      _mostrarCarritoModal();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Botón para Seguir Comprando en el Catálogo
                          SizedBox(
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF1E293B),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(LucideIcons.arrowLeft, size: 16),
                              label: Text(
                                _textoSeguirExplorando,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarCarritoModal() {
    if (_carrito.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notasCtrl = _notasPedidoCtrl;

    AdaptiveModal.show(
      context: context,
      maxWidth: 580,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isWide = ResponsiveLayout.isTabletOrLarger(modalCtx);
            final mediaQuery = MediaQuery.of(modalCtx);

            if (_carrito.isEmpty) {
              return Align(
                alignment: isWide ? Alignment.center : Alignment.bottomCenter,
                heightFactor: isWide ? 1.0 : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: isWide
                          ? BorderRadius.circular(24)
                          : const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                      border: isDark
                          ? Border.all(
                              color: AppTheme.borderDarkElevated,
                              width: 1.2,
                            )
                          : Border.all(
                              color: isWide
                                  ? AppTheme.borderLight
                                  : Colors.transparent,
                              width: 1.0,
                            ),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _esGastronomico
                              ? LucideIcons.utensils
                              : LucideIcons.shoppingBag,
                          size: 48,
                          color: _colorMarca,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _esGastronomico
                              ? 'Tu orden está vacía'
                              : 'Tu pedido está vacío',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _textoCarritoVacio,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _colorMarca,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                            child: Text(_textoVolverCatalogo),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final cartItemIds = _carrito.keys.toList();

            return Align(
              alignment: isWide ? Alignment.center : Alignment.bottomCenter,
              heightFactor: isWide ? 1.0 : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  height: mediaQuery.size.height * (isWide ? 0.88 : 0.85),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: isWide
                        ? BorderRadius.circular(24)
                        : const BorderRadius.vertical(top: Radius.circular(28)),
                    border: isDark
                        ? Border.all(
                            color: AppTheme.borderDarkElevated,
                            width: 1.2,
                          )
                        : Border.all(
                            color: isWide
                                ? AppTheme.borderLight
                                : Colors.transparent,
                            width: 1.0,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.45 : 0.25,
                        ),
                        blurRadius: isWide ? 30 : 24,
                        offset: isWide
                            ? const Offset(0, 10)
                            : const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Barra de arrastre superior solo en móvil
                      if (!isWide) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 16),

                      // Encabezado: Mi Pedido, Vaciar Pedido y Cerrar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _colorMarca.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                LucideIcons.shoppingCart,
                                size: 20,
                                color: _colorMarca,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _tituloCarrito,
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isDark
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _colorMarca,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? (_esGastronomico ? "ítem" : "prod") : (_esGastronomico ? "ítems" : "prods")}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _bodega['nombreComercial']?.toString() ??
                                        'Tienda',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón Vaciar Pedido (retroceder selección de todo)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(LucideIcons.trash2, size: 15),
                              label: Text(
                                'Vaciar',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: () {
                                _vaciarCarrito();
                                setModalState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                size: 20,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Lista de Productos en el Carrito
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: cartItemIds.length,
                          separatorBuilder: (_, _) => const Divider(height: 16),
                          itemBuilder: (context, idx) {
                            final key = cartItemIds[idx];
                            final item = _carrito[key]!;
                            final id = item.idProducto;
                            final cant = item.cantidad;
                            final prod =
                                _productosPorId[id.toString()] ??
                                const <String, dynamic>{};

                            final String nombre =
                                prod['nombre']?.toString() ?? 'Producto';
                            final String marca =
                                prod['marca']?.toString() ?? '';
                            final String imagenUrl =
                                prod['imagenUrl']?.toString() ?? '';
                            final String categoria =
                                prod['categoria']?.toString() ?? '';
                            final double regular = (prod['precioVenta'] is num)
                                ? (prod['precioVenta'] as num).toDouble()
                                : 0.0;
                            final double promo =
                                (prod['precioPromocional'] is num)
                                ? (prod['precioPromocional'] as num).toDouble()
                                : regular;
                            final bool tienePromo =
                                prod['tienePromocion'] == true && promo > 0;
                            final double precioFinal = tienePromo
                                ? promo
                                : regular;
                            final double subtotal = precioFinal * cant;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Thumbnail Packshot
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ProductImageWidget(
                                    imagenUrl: imagenUrl,
                                    nombre: nombre,
                                    categoria: categoria,
                                    size: 52,
                                    borderRadius: 10,
                                    isDark: isDark,
                                    padding: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Detalles
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_esProductoRetornable(prod) ||
                                          item.variante != null ||
                                          (item.notas != null &&
                                              item.notas!.isNotEmpty)) ...[
                                        const SizedBox(height: 2),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: [
                                            if (_esProductoRetornable(prod))
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0284C7)
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.22
                                                            : 0.12,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF0284C7,
                                                    ).withValues(alpha: 0.35),
                                                    width: 0.7,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.bottleWine,
                                                      size: 9.5,
                                                      color: Color(0xFF0284C7),
                                                    ),
                                                    const SizedBox(width: 2.5),
                                                    Text(
                                                      'Retornable',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF38BDF8,
                                                              )
                                                            : const Color(
                                                                0xFF0369A1,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (item.variante != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706)
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.25
                                                            : 0.15,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFD97706,
                                                    ).withValues(alpha: 0.5),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.drumstick,
                                                      size: 10,
                                                      color: Color(0xFFD97706),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      item.variante!,
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: const Color(
                                                              0xFFD97706,
                                                            ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (item.notas != null &&
                                                item.notas!.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: (isDark
                                                      ? Colors.grey[800]
                                                      : Colors.grey[200])!,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.notas!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? Colors.grey[300]
                                                            : Colors.grey[700],
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (marca.isNotEmpty) ...[
                                            Text(
                                              marca,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFF1F5F9,
                                                          )
                                                        : const Color(
                                                            0xFF1E293B,
                                                          ),
                                                  ),
                                            ),
                                            Text(
                                              '•',
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF334155),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                          if (tienePromo) ...[
                                            Text(
                                              'S/ ${regular.toStringAsFixed(2)}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color: isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                            Text(
                                              'S/ ${precioFinal.toStringAsFixed(2)} c/u',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _colorPromocion,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              'S/ ${precioFinal.toStringAsFixed(2)} c/u',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? const Color(0xFFF1F5F9)
                                                    : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Subtotal: S/ ${subtotal.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Stepper [-] [cant] [+]
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        icon: const Icon(
                                          LucideIcons.minus,
                                          size: 14,
                                        ),
                                        onPressed: () {
                                          _modificarCantidad(
                                            id,
                                            -1,
                                            variante: item.variante,
                                          );
                                          setModalState(() {});
                                        },
                                      ),
                                      Text(
                                        '$cant',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        icon: const Icon(
                                          LucideIcons.plus,
                                          size: 14,
                                        ),
                                        onPressed: () {
                                          _modificarCantidad(
                                            id,
                                            1,
                                            variante: item.variante,
                                          );
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Botón Eliminar / Retroceder Selección de este producto
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  tooltip: _esGastronomico
                                      ? 'Quitar de la orden'
                                      : 'Quitar del pedido',
                                  onPressed: () {
                                    _modificarCantidad(
                                      id,
                                      -cant,
                                      variante: item.variante,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Asistente Interactivo de Botellas Retornables
                      Builder(
                        builder: (_) {
                          if (_totalBotellasRetornables == 0) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF082F49)
                                        .withValues(alpha: 0.50)
                                  : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: isDark ? 0.45 : 0.35),
                                width: 1.0,
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
                                        color: const Color(0xFF0284C7)
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        LucideIcons.bottleWine,
                                        size: 16,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Envases Retornables ($_totalBotellasRetornables ${_totalBotellasRetornables == 1 ? "botella" : "botellas"})',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? const Color(0xFF7DD3FC)
                                                  : const Color(0xFF0369A1),
                                            ),
                                          ),
                                          Text(
                                            '¿Cuentas con envases vacíos para entregar al recibir?',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFFBAE6FD)
                                                  : const Color(0xFF075985),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Opción 1: Tengo envases vacíos (S/ 0.00 canje)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setModalState(() {
                                            _dejarGarantiaBotellas = false;
                                          });
                                          setState(() {});
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !_dejarGarantiaBotellas
                                                ? const Color(0xFF0284C7)
                                                : (isDark
                                                      ? const Color(0xFF0F172A)
                                                      : Colors.white),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: !_dejarGarantiaBotellas
                                                  ? const Color(0xFF0284C7)
                                                  : (isDark
                                                        ? const Color(
                                                            0xFF334155,
                                                          )
                                                        : const Color(
                                                            0xFFCBD5E1,
                                                          )),
                                              width: 1.2,
                                            ),
                                            boxShadow: !_dejarGarantiaBotellas
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF0284C7,
                                                      ).withValues(alpha: 0.25),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                !_dejarGarantiaBotellas
                                                    ? LucideIcons.checkCircle2
                                                    : LucideIcons.circle,
                                                size: 13,
                                                color: !_dejarGarantiaBotellas
                                                    ? Colors.white
                                                    : (isDark
                                                          ? Colors.white60
                                                          : const Color(
                                                              0xFF64748B,
                                                            )),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Canje (S/ 0.00)',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        !_dejarGarantiaBotellas
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A,
                                                                )),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Opción 2: Dejar garantía (+S/ 2.00 c/u)
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setModalState(() {
                                            _dejarGarantiaBotellas = true;
                                          });
                                          setState(() {});
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _dejarGarantiaBotellas
                                                ? const Color(0xFFD97706)
                                                : (isDark
                                                      ? const Color(0xFF0F172A)
                                                      : Colors.white),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: _dejarGarantiaBotellas
                                                  ? const Color(0xFFD97706)
                                                  : (isDark
                                                        ? const Color(
                                                            0xFF334155,
                                                          )
                                                        : const Color(
                                                            0xFFCBD5E1,
                                                          )),
                                              width: 1.2,
                                            ),
                                            boxShadow: _dejarGarantiaBotellas
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFFD97706,
                                                      ).withValues(alpha: 0.25),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _dejarGarantiaBotellas
                                                    ? LucideIcons.checkCircle2
                                                    : LucideIcons.circle,
                                                size: 13,
                                                color: _dejarGarantiaBotellas
                                                    ? Colors.white
                                                    : (isDark
                                                          ? Colors.white60
                                                          : const Color(
                                                              0xFF64748B,
                                                            )),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Garantía (+S/ 2.00)',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        _dejarGarantiaBotellas
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A,
                                                                )),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Campo Opcional de Indicaciones / Notas
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        child: TextField(
                          controller: notasCtrl,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: _metodoPagoSeleccionado == 'EFECTIVO'
                                ? '¿Con cuánto pagas? (ej. Billete de 50 para vuelto)'
                                : _hintNotasPedido,
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                            prefixIcon: Icon(
                              LucideIcons.fileText,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : _colorMarca,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Selector Visual de Método de Pago
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Método de Pago',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildMetodoPagoChip(
                                  label: 'Yape',
                                  metodo: 'YAPE',
                                  icon: LucideIcons.smartphone,
                                  accentColor: const Color(0xFF7C3AED),
                                  isDark: isDark,
                                  setModalState: setModalState,
                                ),
                                const SizedBox(width: 6),
                                _buildMetodoPagoChip(
                                  label: 'Plin',
                                  metodo: 'PLIN',
                                  icon: LucideIcons.zap,
                                  accentColor: const Color(0xFF0284C7),
                                  isDark: isDark,
                                  setModalState: setModalState,
                                ),
                                const SizedBox(width: 6),
                                _buildMetodoPagoChip(
                                  label: 'Efectivo',
                                  metodo: 'EFECTIVO',
                                  icon: LucideIcons.banknote,
                                  accentColor: const Color(0xFF16A34A),
                                  isDark: isDark,
                                  setModalState: setModalState,
                                ),
                                const SizedBox(width: 6),
                                _buildMetodoPagoChip(
                                  label: 'Tarjeta',
                                  metodo: 'TARJETA',
                                  icon: LucideIcons.creditCard,
                                  accentColor: const Color(0xFFEA580C),
                                  isDark: isDark,
                                  setModalState: setModalState,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Resumen Financiero y Acciones Inferiores
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_totalAhorroCarrito > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '🎁 Ahorro en Promociones:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _colorPromocion,
                                    ),
                                  ),
                                  Text(
                                    '- S/ ${_totalAhorroCarrito.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: _colorPromocion,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (_dejarGarantiaBotellas &&
                                _totalBotellasRetornables > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.bottleWine,
                                        size: 13,
                                        color: Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Garantía Envases ($_totalBotellasRetornables x S/ 2.00):',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '+ S/ ${_montoGarantiaBotellas.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'TOTAL ESTIMADO:',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'S/ ${_totalMontoFinalConGarantia.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Botones: Seguir Comprando y WhatsApp
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFF1E293B),
                                      side: BorderSide(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(modalCtx),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '← Seguir',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.send,
                                      size: 17,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Pedir por WhatsApp',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      final notas = notasCtrl.text;
                                      Navigator.pop(modalCtx);
                                      _enviarPedidoWhatsApp(notas);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildMetodoPagoChip({
    required String label,
    required String metodo,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required void Function(void Function()) setModalState,
  }) {
    final bool isSelected = _metodoPagoSeleccionado == metodo;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setModalState(() {
            _metodoPagoSeleccionado = metodo;
          });
          setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.25 : 0.14)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.20),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingOrderBar(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet =
        isPhysicalTablet ||
        (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: _colorMarca.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? _colorMarca.withValues(alpha: 0.35)
                : _colorMarca.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 14,
              vertical: isTablet ? 14 : 10,
            ),
            child: Row(
              children: [
                // Área interactiva del Carrito (tocar abre el modal del pedido)
                Expanded(
                  child: InkWell(
                    onTap: _mostrarCarritoModal,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isTablet ? 10 : 8),
                                decoration: BoxDecoration(
                                  color: _colorMarca.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  LucideIcons.shoppingBag,
                                  size: isTablet ? 20 : 18,
                                  color: _colorMarca,
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _colorMarca,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_totalUnidadesCarrito',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                                        '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? (_esGastronomico ? "ítem" : "producto") : (_esGastronomico ? "ítems" : "productos")}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      LucideIcons.chevronUp,
                                      size: 13,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : const Color(0xFF334155),
                                    ),
                                  ],
                                ),
                                Text(
                                  'S/ ${_totalMontoFinalConGarantia.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isTablet ? 21 : 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_totalAhorroCarrito > 0)
                                  Text(
                                    'Ahorras S/ ${_totalAhorroCarrito.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _colorPromocion,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                if (isTablet) ...[
                  // En pantallas tablet hay espacio para ambos botones completos
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _colorMarcaTexto(isDark),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(LucideIcons.shoppingCart, size: 16),
                    label: Text(
                      'Ver Pedido',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _mostrarCarritoModal,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(LucideIcons.send, size: 18),
                    label: Text(
                      'Pedir por WhatsApp',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: _isEnviandoPedido
                        ? null
                        : () => _enviarPedidoWhatsApp(),
                  ),
                ] else ...[
                  // En móviles: Botón directo para Ver Pedido y finalizar por WhatsApp
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorMarcaProfundo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(LucideIcons.shoppingBag, size: 16),
                    label: Text(
                      'Ver Pedido',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: _mostrarCarritoModal,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogoDeviceConfig {
  final int crossAxisCount;
  final double childAspectRatio;
  final double maxImageSize;
  final double categoriaFontSize;
  final double nombreFontSize;
  final double precioFontSize;
  final double botonHeight;
  final double botonFontSize;
  final double botonIconSize;
  final double cardPadding;
  final double gridSpacing;
  final bool isTablet;

  const _CatalogoDeviceConfig({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.maxImageSize,
    required this.categoriaFontSize,
    required this.nombreFontSize,
    required this.precioFontSize,
    required this.botonHeight,
    required this.botonFontSize,
    required this.botonIconSize,
    required this.cardPadding,
    required this.gridSpacing,
    required this.isTablet,
  });
}

class _StoryConfig {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String? directCategory;
  final List<String> keywords;

  const _StoryConfig({
    required this.label,
    required this.icon,
    required this.gradient,
    this.directCategory,
    this.keywords = const [],
  });
}

class _ResolvedStory {
  final _StoryConfig config;
  final String targetCategory;

  const _ResolvedStory({required this.config, required this.targetCategory});
}
