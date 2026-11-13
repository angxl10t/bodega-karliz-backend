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

import '../../core/api_constants.dart';
import '../../core/cajaya_vectors.dart';
import '../../core/marca_detector_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';
import 'pedido_web_service.dart';

class CatalogoPublicoScreen extends StatefulWidget {
  final String tiendaSlug;
  final http.Client? httpClient;

  const CatalogoPublicoScreen({
    super.key,
    required this.tiendaSlug,
    this.httpClient,
  });

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
  int _ofertasCount = 0;
  List<String> _categorias = [];
  List<Map<String, dynamic>> _promociones = [];
  String _categoriaSeleccionada = 'TODAS';
  String _filtroBusqueda = '';
  List<Map<String, dynamic>> _cachedProductosFiltrados = [];
  Timer? _searchDebounce;

  // Carrito de compras: {idProducto: cantidad}
  final Map<int, int> _carrito = {};
  bool _isEnviandoPedido = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _notasPedidoCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _notasPedidoCtrl.dispose();
    if (widget.httpClient == null) {
      _client.close();
    }
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/public/catalogo?tienda=${Uri.encodeComponent(widget.tiendaSlug)}',
      );
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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

        final rawPromos = (data['promociones'] as List<dynamic>?) ?? [];
        final promosList = rawPromos
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final prodsById = <String, Map<String, dynamic>>{};
        int ofertas = 0;
        for (final p in prodsList) {
          final idStr = p['idProducto']?.toString();
          if (idStr != null && idStr.isNotEmpty) {
            prodsById[idStr] = p;
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
            _ofertasCount = ofertas;
            _categorias = catsList;
            _promociones = promosList;
            _recomputeProductosFiltrados();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                'No se pudo cargar el catálogo de la bodega (Código ${resp.statusCode}).';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión al cargar el catálogo: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _productosFiltrados =>
      _cachedProductosFiltrados;

  void _recomputeProductosFiltrados() {
    final catUpper = _categoriaSeleccionada.toUpperCase();
    final query = _filtroBusqueda.trim();
    final queryLower = query.toLowerCase();

    _cachedProductosFiltrados = _productos.where((p) {
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
  }

  double get _totalAhorroCarrito {
    double ahorro = 0.0;
    _carrito.forEach((id, cant) {
      final prod = _productosPorId[id.toString()] ?? const <String, dynamic>{};
      if (prod['tienePromocion'] == true) {
        final double regular = (prod['precioVenta'] is num)
            ? (prod['precioVenta'] as num).toDouble()
            : 0.0;
        final double promo = (prod['precioPromocional'] is num)
            ? (prod['precioPromocional'] as num).toDouble()
            : regular;
        if (regular > promo) {
          ahorro += ((regular - promo) * cant);
        }
      }
    });
    return ahorro;
  }

  int get _totalUnidadesCarrito {
    return _carrito.values.fold(0, (acc, c) => acc + c);
  }

  double get _totalMontoCarrito {
    double total = 0.0;
    _carrito.forEach((id, cant) {
      final prod = _productosPorId[id.toString()] ?? const <String, dynamic>{};
      final double regular = (prod['precioVenta'] is num)
          ? (prod['precioVenta'] as num).toDouble()
          : 0.0;
      final double promo = (prod['precioPromocional'] is num)
          ? (prod['precioPromocional'] as num).toDouble()
          : regular;
      final double precio = (prod['tienePromocion'] == true && promo > 0)
          ? promo
          : regular;
      total += (precio * cant);
    });
    return total;
  }

  void _modificarCantidad(int idProducto, int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      final actual = _carrito[idProducto] ?? 0;
      final nuevo = actual + delta;
      if (nuevo <= 0) {
        _carrito.remove(idProducto);
      } else {
        _carrito[idProducto] = nuevo;
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
      buffer.writeln('*Pedido $codigoShort - $nombreBodega*');
      if (notas != null && notas.trim().isNotEmpty) {
        buffer.writeln('Cliente: ${notas.trim()}');
      }
      buffer.writeln('--------------------------------');

      final List<PedidoWebItem> itemsParaBandeja = [];

      _carrito.forEach((id, cant) {
        final prod =
            _productosPorId[id.toString()] ?? const <String, dynamic>{};
        final nombre = prod['nombre']?.toString() ?? 'Producto';
        final double regular = (prod['precioVenta'] is num)
            ? (prod['precioVenta'] as num).toDouble()
            : 0.0;
        final double promo = (prod['precioPromocional'] is num)
            ? (prod['precioPromocional'] as num).toDouble()
            : regular;
        final bool tienePromo = prod['tienePromocion'] == true && promo > 0;
        final double precioFinal = tienePromo ? promo : regular;
        final subtotal = precioFinal * cant;
        final badge = tienePromo
            ? (prod['badgePromocion']?.toString() ?? 'PROMO')
            : null;

        itemsParaBandeja.add(
          PedidoWebItem(
            idProducto:
                (prod['idProducto'] as num?)?.toInt() ??
                int.tryParse(id.toString()) ??
                0,
            nombre: nombre,
            cantidad: cant.toDouble(),
            precioUnitario: precioFinal,
            subtotal: subtotal,
            badge: badge,
          ),
        );

        if (tienePromo) {
          buffer.writeln(
            '• ${cant}x $nombre - S/ ${subtotal.toStringAsFixed(2)} ($badge)',
          );
        } else {
          buffer.writeln(
            '• ${cant}x $nombre - S/ ${subtotal.toStringAsFixed(2)}',
          );
        }
      });

      buffer.writeln('--------------------------------');
      buffer.writeln(
        '*Total a Pagar: S/ ${_totalMontoCarrito.toStringAsFixed(2)}*',
      );
      if (_totalAhorroCarrito > 0) {
        buffer.writeln(
          'Descuento web aplicado: -S/ ${_totalAhorroCarrito.toStringAsFixed(2)}',
        );
      }
      final bool incluyeRetornables = _carrito.keys.any((id) {
        final p = _productosPorId[id.toString()] ?? const <String, dynamic>{};
        return _esProductoRetornable(p);
      });
      if (incluyeRetornables) {
        buffer.writeln('(Incluye botellas retornables)');
      }
      buffer.writeln('');
      buffer.writeln('¿Me confirman disponibilidad para recoger?');

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
        total: _totalMontoCarrito,
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
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _colorMarca.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.store,
                color: _colorMarca,
                size: 20,
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
                          _bodega['nombreComercial']?.toString() ??
                              'CajaYa POS',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_esPro) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          LucideIcons.badgeCheck,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Catálogo Online de Productos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Actualizar',
            onPressed: _cargarCatalogo,
          ),
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
                _mensajeNoPro ?? 'El catálogo online "Mi Bodega Online" para recepción de pedidos digitales por WhatsApp está disponible de forma exclusiva para tiendas con Suscripción PRO en CajaYa Cloud POS.',
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
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : _colorMarca,
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
    if (hex == null) return const Color(0xFFEF4444);
    try {
      final s = hex.toString().replaceAll('#', '0xFF');
      return Color(int.parse(s));
    } catch (_) {
      return const Color(0xFFEF4444);
    }
  }

  Widget _buildPromocionesHeroBanner(bool isDark, bool isTablet) {
    if (_promociones.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(
        isTablet ? 20 : 16,
        0,
        isTablet ? 20 : 16,
        isTablet ? 12 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 16,
                color: _colorMarca,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OFERTAS Y PROMOCIONES ACTIVAS',
                  style: GoogleFonts.outfit(
                    fontSize: isTablet ? 12 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isTablet ? 0.8 : 0.5,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : _colorMarca,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isTablet ? 140 : 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _promociones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final pm = _promociones[i];
                final color = _parseColorBadge(pm['colorBadge']);
                final titulo = pm['titulo']?.toString() ?? 'Oferta Especial';
                final desc = pm['descripcion']?.toString() ?? '';
                final badge = pm['badgeTexto']?.toString() ?? '🔥 OFERTA';
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: isTablet ? 300 : 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                color.withValues(alpha: 0.25),
                                const Color(0xFF1E293B),
                              ]
                            : [color.withValues(alpha: 0.12), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: _colorMarca,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: isTablet ? 14.5 : 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            desc.isNotEmpty ? desc : 'Aprovecha este descuento exclusivo disponible en tienda.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isTablet ? 11.5 : 11,
                              color: isDark
                                  ? AppTheme.textDarkSecondary
                                  : AppTheme.textMuted,
                            ),
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

  Widget _buildCatalogoProView(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet =
        isPhysicalTablet ||
        (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);

    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'Bodega';
    final lema = _bodega['lemaComercial']?.toString() ?? '';
    final direccion = _bodega['direccion']?.toString() ?? '';
    final prods = _productosFiltrados;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Banner Superior de la Tienda
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 16,
                  isTablet ? 18 : 14,
                  isTablet ? 20 : 16,
                  10,
                ),
                padding: EdgeInsets.all(isTablet ? 22 : 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [Colors.white, const Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            color: _colorMarca.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              isTablet ? 16 : 14,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.store,
                            size: isTablet ? 30 : 26,
                            color: _colorMarca,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      nombreBodega,
                                      style: GoogleFonts.outfit(
                                        fontSize: isTablet ? 22 : 19,
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 8 : 6,
                                      vertical: isTablet ? 3 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PRO ONLINE',
                                      style: GoogleFonts.outfit(
                                        fontSize: isTablet ? 11 : 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (lema.isNotEmpty)
                                Text(
                                  lema,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 13.5 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textDarkSecondary
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              if (direccion.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.mapPin,
                                      size: isTablet ? 14 : 12,
                                      color: isDark
                                          ? const Color(0xFF93C5FD)
                                          : _colorMarca,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        direccion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: isTablet ? 12.5 : 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFFF1F5F9)
                                              : const Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_bodega['telefono'] != null &&
                                  _bodega['telefono']
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final rawT = _bodega['telefono']
                                        .toString()
                                        .trim();
                                    final l = rawT.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    );
                                    final tf =
                                        (l.length == 9 && l.startsWith('9'))
                                        ? '51$l'
                                        : (l.startsWith('51') ? l : '51$l');
                                    final msg = Uri.encodeComponent(
                                      '¡Hola *$nombreBodega*! 👋 Quisiera hacerles una consulta sobre su catálogo online.',
                                    );
                                    final uri = Uri.parse(
                                      'https://wa.me/$tf?text=$msg',
                                    );
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 10 : 8,
                                      vertical: isTablet ? 4 : 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF16A34A)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.messageCircle,
                                          size: 13,
                                          color: Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'WhatsApp: ${_bodega['telefono']}',
                                            style: GoogleFonts.outfit(
                                              fontSize: isTablet ? 12 : 11,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF16A34A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 16 : 14),

                    // Buscador
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
                        fontSize: isTablet ? 15 : 13.5,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar productos, abarrotes, bebidas...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 14 : 13,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: isTablet ? 20 : 18,
                          color: _colorMarca,
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
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 14,
                          vertical: isTablet ? 14 : 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 14,
                          ),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 14,
                          ),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
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

            // Filtros de Categoría Horizontales
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 8 : 6,
                ),
                child: Row(
                  children: [
                    _buildCategoriaChip(
                      'TODAS',
                      'Todos (${_productos.length})',
                      isDark,
                      isTablet,
                    ),
                    if (_ofertasCount > 0)
                      _buildCategoriaChip(
                        'OFERTAS',
                        '🔥 Ofertas ($_ofertasCount)',
                        isDark,
                        isTablet,
                        esOferta: true,
                      ),
                    ..._categorias.map(
                      (c) => _buildCategoriaChip(c, c, isDark, isTablet),
                    ),
                  ],
                ),
              ),
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
                        LucideIcons.shoppingBag,
                        size: isTablet ? 48 : 40,
                        color: AppTheme.getAdaptiveMutedText(isDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron productos',
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
                        'Prueba con otro término de búsqueda o categoría.',
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
            '$nombreBodega • Catálogo Digital Oficial',
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

  Widget _buildCategoriaChip(
    String key,
    String label,
    bool isDark,
    bool isTablet, {
    bool esOferta = false,
  }) {
    final isSelected =
        _categoriaSeleccionada.toUpperCase() == key.toUpperCase();
    final chipColor = esOferta
        ? const Color(0xFF1D4ED8)
        : _colorMarca;

    return Padding(
      padding: EdgeInsets.only(right: isTablet ? 10 : 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isTablet ? 13.5 : 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (esOferta
                      ? (isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1D4ED8))
                      : (isDark ? Colors.white : const Color(0xFF0F172A))),
          ),
        ),
        padding: isTablet
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : EdgeInsets.zero,
        selected: isSelected,
        selectedColor: chipColor,
        backgroundColor: isDark
            ? (esOferta
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                  : const Color(0xFF1E2436))
            : (esOferta ? const Color(0xFFEFF6FF) : Colors.white),
        side: BorderSide(
          color: isSelected
              ? chipColor
              : (esOferta
                    ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                    : (isDark
                          ? const Color(0xFF262E44)
                          : const Color(0xFFCBD5E1))),
          width: isSelected ? 1.4 : 1.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() {
            _categoriaSeleccionada = key;
            _recomputeProductosFiltrados();
          });
        },
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
    final int id = (prod['idProducto'] is int)
        ? prod['idProducto'] as int
        : int.parse(prod['idProducto'].toString());
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : 0.0;
    final int cantidadEnCarrito = _carrito[id] ?? 0;
    final bool isTablet = config.isTablet;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        border: Border.all(
          color: cantidadEnCarrito > 0
              ? _colorMarca
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: cantidadEnCarrito > 0 ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 3),
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
                    // Imagen del Producto adaptativa y ampliada
                    Expanded(
                      flex: 3,
                      child: Container(
                        margin: EdgeInsets.all(isTablet ? 10 : 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
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
                                    (availableMax * 0.88).clamp(
                                      64.0,
                                      config.maxImageSize,
                                    );
                                return Center(
                                  child: ProductImageWidget(
                                    imagenUrl: imagenUrl,
                                    nombre: nombre,
                                    codigoBarras: codigoBarras,
                                    categoria: categoria,
                                    size: effectiveSize,
                                    borderRadius: isTablet ? 16 : 14,
                                    isDark: isDark,
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
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _parseColorBadge(prod['colorBadge']),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _parseColorBadge(
                                          prod['colorBadge'],
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    prod['badgePromocion']?.toString() ??
                                        '🔥 OFERTA',
                                    style: GoogleFonts.outfit(
                                      fontSize: isTablet ? 11 : 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
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
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
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

                    // Datos del Producto (Categoría, Título, Precio)
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
                                  horizontal: isTablet ? 8 : 6,
                                  vertical: isTablet ? 3 : 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF262E44)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(
                                    isTablet ? 7 : 5,
                                  ),
                                ),
                                child: Text(
                                  categoria,
                                  style: GoogleFonts.outfit(
                                    fontSize: config.categoriaFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF0F172A),
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
                                      isTablet ? 7 : 5,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.3),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.wine,
                                        size: 9.5,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 2.5),
                                      Text(
                                        'Retornable',
                                        style: GoogleFonts.outfit(
                                          fontSize:
                                              (config.categoriaFontSize * 0.95)
                                                  .clamp(8.5, 11.0),
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isTablet ? 5 : 3),
                          Text(
                            nombre,
                            style: GoogleFonts.outfit(
                              fontSize: config.nombreFontSize,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                              height: 1.22,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          if (prod['tienePromocion'] == true &&
                              prod['precioPromocional'] != null &&
                              (prod['precioPromocional'] as num).toDouble() <
                                  precio) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: config.precioFontSize * 0.74,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'S/ ${(prod['precioPromocional'] as num).toDouble().toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: config.precioFontSize,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'S/ ${precio.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: config.precioFontSize,
                                fontWeight: FontWeight.w900,
                                color: _colorMarca,
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

          // Botón / Selector de Cantidad
          Padding(
            padding: EdgeInsets.fromLTRB(
              config.cardPadding,
              isTablet ? 6 : 3,
              config.cardPadding,
              config.cardPadding,
            ),
            child: cantidadEnCarrito == 0
                ? SizedBox(
                    height: config.botonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorMarca,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 12 : 10,
                          ),
                        ),
                      ),
                      onPressed: () => _modificarCantidad(id, 1),
                      icon: Icon(LucideIcons.plus, size: config.botonIconSize),
                      label: Text(
                        'Agregar',
                        style: GoogleFonts.outfit(
                          fontSize: config.botonFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: config.botonHeight,
                    decoration: BoxDecoration(
                      color: _colorMarca.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                      border: Border.all(
                        color: _colorMarca.withValues(alpha: 0.3),
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
                            color: _colorMarca,
                          ),
                          onPressed: () => _modificarCantidad(id, -1),
                        ),
                        Text(
                          '$cantidadEnCarrito',
                          style: GoogleFonts.outfit(
                            fontSize: config.botonFontSize + 1,
                            fontWeight: FontWeight.w900,
                            color: _colorMarca,
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
                            color: _colorMarca,
                          ),
                          onPressed: () => _modificarCantidad(id, 1),
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
    final int id = (prod['idProducto'] is int)
        ? prod['idProducto'] as int
        : int.parse(prod['idProducto'].toString());
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String marca = prod['marca']?.toString() ?? '';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final int cantActual = _carrito[id] ?? 0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    14,
                    22,
                    24 + MediaQuery.of(modalCtx).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Barra de arrastre superior
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _colorMarca.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoria.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _colorMarca,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
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

                        // Fotografía Packshot en Gran Detalle
                        Center(
                          child: ProductImageWidget(
                            imagenUrl: imagenUrl,
                            nombre: nombre,
                            codigoBarras: codigoBarras,
                            categoria: categoria,
                            size:
                                (MediaQuery.of(modalCtx).size.height < 700 ||
                                    MediaQuery.of(modalCtx).size.width < 380)
                                ? 120
                                : 160,
                            borderRadius: 24,
                            isDark: isDark,
                            padding: 8,
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Precio y Banner de Promoción
                        if (prod['tienePromocion'] == true &&
                            prod['precioPromocional'] != null &&
                            (prod['precioPromocional'] as num).toDouble() <
                                precio) ...[
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'S/ ${(prod['precioPromocional'] as num).toDouble().toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
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
                                color: _colorMarca,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

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
                                'Agregar al Pedido',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: () {
                                _modificarCantidad(id, 1);
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
                                    'En tu pedido ($cantActual ${cantActual == 1 ? "unidad" : "unidades"})',
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
                                    _modificarCantidad(id, -cantActual);
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
                                        _modificarCantidad(id, -1);
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
                                        _modificarCantidad(id, 1);
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
                                      backgroundColor: const Color(0xFF16A34A),
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
                                'Seguir Comprando en el Catálogo',
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final mediaQuery = MediaQuery.of(modalCtx);

            if (_carrito.isEmpty) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.shoppingBag,
                          size: 48,
                          color: _colorMarca,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tu pedido está vacío',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Agrega productos desde el catálogo para enviar tu pedido por WhatsApp.',
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
                            child: const Text('Volver al Catálogo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final cartItemIds = _carrito.keys.toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  height: mediaQuery.size.height * 0.85,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Barra de arrastre superior
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

                      // Encabezado: Mi Pedido, Vaciar Pedido y Cerrar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.shoppingCart,
                                size: 20,
                                color: Color(0xFF16A34A),
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
                                          'Mi Pedido',
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
                                          color: const Color(0xFF16A34A),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? "prod" : "prods"}',
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
                            final id = cartItemIds[idx];
                            final cant = _carrito[id] ?? 0;
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
                                                color: const Color(0xFF16A34A),
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
                                          _modificarCantidad(id, -1);
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
                                          _modificarCantidad(id, 1);
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
                                  tooltip: 'Quitar del pedido',
                                  onPressed: () {
                                    _modificarCantidad(id, -cant);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // Campo Opcional de Indicaciones / Notas
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: notasCtrl,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Indicaciones (ej. mi hijo recogerá en 15 min, paso a las 6pm...)',
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
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                  Text(
                                    '- S/ ${_totalAhorroCarrito.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF16A34A),
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
                                  'S/ ${_totalMontoCarrito.toStringAsFixed(2)}',
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
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                                  color: _colorMarca.withValues(
                                    alpha: 0.12,
                                  ),
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
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
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
                                        '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? 'producto' : 'productos'}',
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
                                  'S/ ${_totalMontoCarrito.toStringAsFixed(2)}',
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
                                      color: const Color(0xFF16A34A),
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
                      foregroundColor: isDark
                          ? Colors.white
                          : _colorMarca,
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
                      backgroundColor: const Color(0xFF16A34A),
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
