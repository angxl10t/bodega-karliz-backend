import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_constants.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';

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
  List<String> _categorias = [];
  String _categoriaSeleccionada = 'TODAS';
  String _filtroBusqueda = '';

  // Carrito de compras: {idProducto: cantidad}
  final Map<int, int> _carrito = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
      final uri = Uri.parse('${ApiConstants.baseUrl}/public/catalogo?tienda=${Uri.encodeComponent(widget.tiendaSlug)}');
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final bodegaMap = (data['bodega'] as Map<String, dynamic>?) ?? {};
        final bool esPro = data['esPro'] == true;
        final String? msg = data['mensaje'] as String?;
        final rawProds = (data['productos'] as List<dynamic>?) ?? [];
        final prodsList = rawProds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final rawCats = (data['categorias'] as List<dynamic>?) ?? [];
        final catsList = rawCats.map((e) => e.toString()).toList();

        if (mounted) {
          setState(() {
            _bodega = bodegaMap;
            _esPro = esPro;
            _mensajeNoPro = msg;
            _productos = prodsList;
            _categorias = catsList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'No se pudo cargar el catálogo de la bodega (Código ${resp.statusCode}).';
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

  List<Map<String, dynamic>> get _productosFiltrados {
    return _productos.where((p) {
      final matchesCat = _categoriaSeleccionada == 'TODAS' ||
          (p['categoria']?.toString().toUpperCase() == _categoriaSeleccionada.toUpperCase());
      final query = _filtroBusqueda.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          (p['nombre']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['codigo']?.toString().toLowerCase().contains(query) ?? false) ||
          (p['marca']?.toString().toLowerCase().contains(query) ?? false);
      return matchesCat && matchesQuery;
    }).toList();
  }

  int get _totalUnidadesCarrito {
    return _carrito.values.fold(0, (acc, c) => acc + c);
  }

  double get _totalMontoCarrito {
    double total = 0.0;
    _carrito.forEach((id, cant) {
      final prod = _productos.firstWhere((p) => p['idProducto'] == id, orElse: () => {});
      final double precio = (prod['precioVenta'] is num) ? (prod['precioVenta'] as num).toDouble() : 0.0;
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

  Future<void> _enviarPedidoWhatsApp() async {
    if (_carrito.isEmpty) return;

    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'la Bodega';
    final rawTelefono = _bodega['telefono']?.toString().trim() ?? '';
    final limpio = rawTelefono.replaceAll(RegExp(r'[^0-9]'), '');

    String telefonoFinal = '';
    if (limpio.length == 9 && limpio.startsWith('9')) {
      telefonoFinal = '51$limpio';
    } else if (limpio.length >= 9) {
      telefonoFinal = limpio.startsWith('51') ? limpio : '51$limpio';
    }

    final buffer = StringBuffer();
    buffer.writeln('¡Hola *$nombreBodega*! 👋');
    buffer.writeln('Quisiera realizar el siguiente pedido desde su catálogo digital:');
    buffer.writeln('');

    int index = 1;
    _carrito.forEach((id, cant) {
      final prod = _productos.firstWhere((p) => p['idProducto'] == id, orElse: () => {});
      final nombre = prod['nombre']?.toString() ?? 'Producto';
      final double precio = (prod['precioVenta'] is num) ? (prod['precioVenta'] as num).toDouble() : 0.0;
      final subtotal = precio * cant;
      buffer.writeln('$index. $cant x *$nombre* - S/ ${subtotal.toStringAsFixed(2)}');
      index++;
    });

    buffer.writeln('');
    buffer.writeln('*TOTAL ESTIMADO: S/ ${_totalMontoCarrito.toStringAsFixed(2)}*');
    buffer.writeln('');
    buffer.writeln('Por favor indíquenme si lo tienen listo para recogerlo o coordinar entrega. ¡Muchas gracias!');

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
            content: Text('¡Pedido copiado al portapapeles! Puedes pegarlo directamente en WhatsApp.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.store, color: AppTheme.brandPrimary, size: 20),
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
                          _bodega['nombreComercial']?.toString() ?? 'CajaYa POS',
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
                        const Icon(LucideIcons.badgeCheck, size: 16, color: Color(0xFF059669)),
                      ],
                    ],
                  ),
                  Text(
                    'Catálogo Online de Productos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
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
      bottomNavigationBar: _esPro && _carrito.isNotEmpty ? _buildFloatingOrderBar(isDark) : null,
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.brandPrimary),
            SizedBox(height: 16),
            Text('Cargando catálogo en vivo...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
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
                child: const Icon(LucideIcons.circleAlert, color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Catálogo no disponible',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'Esta bodega';
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
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                child: const Icon(LucideIcons.lock, color: Color(0xFFD97706), size: 40),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    'El catálogo online "Mi Bodega Online" para recepción de pedidos digitales por WhatsApp está disponible de forma exclusiva para tiendas con Suscripción PRO en CajaYa Cloud POS.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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
                      const Icon(LucideIcons.mapPin, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          direccion,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                      const Icon(LucideIcons.phone, size: 15, color: Color(0xFF059669)),
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

  Widget _buildCatalogoProView(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet = isPhysicalTablet || (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);

    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'Bodega';
    final lema = _bodega['lemaComercial']?.toString() ?? '';
    final direccion = _bodega['direccion']?.toString() ?? '';
    final prods = _productosFiltrados;

    return Center(
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
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
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
                            color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                          ),
                          child: Icon(LucideIcons.store, size: isTablet ? 30 : 26, color: AppTheme.brandPrimary),
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
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 6, vertical: isTablet ? 3 : 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.15),
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
                                    color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              if (direccion.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(LucideIcons.mapPin, size: isTablet ? 14 : 12, color: const Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        direccion,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: isTablet ? 12.5 : 11.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_bodega['telefono'] != null && _bodega['telefono'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final rawT = _bodega['telefono'].toString().trim();
                                    final l = rawT.replaceAll(RegExp(r'[^0-9]'), '');
                                    final tf = (l.length == 9 && l.startsWith('9')) ? '51$l' : (l.startsWith('51') ? l : '51$l');
                                    final msg = Uri.encodeComponent('¡Hola *$nombreBodega*! 👋 Quisiera hacerles una consulta sobre su catálogo online.');
                                    final uri = Uri.parse('https://wa.me/$tf?text=$msg');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 8, vertical: isTablet ? 4 : 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.messageCircle, size: 13, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'WhatsApp: ${_bodega['telefono']}',
                                          style: GoogleFonts.outfit(
                                            fontSize: isTablet ? 12 : 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF16A34A),
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
                      onChanged: (val) => setState(() => _filtroBusqueda = val),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isTablet ? 15 : 13.5,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar productos, abarrotes, bebidas...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 14 : 13,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(LucideIcons.search, size: isTablet ? 20 : 18, color: AppTheme.brandPrimary),
                        suffixIcon: _filtroBusqueda.isNotEmpty
                            ? IconButton(
                                icon: Icon(LucideIcons.x, size: isTablet ? 18 : 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _filtroBusqueda = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 14, vertical: isTablet ? 14 : 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    _buildCategoriaChip('TODAS', 'Todos (${_productos.length})', isDark, isTablet),
                    ..._categorias.map((c) => _buildCategoriaChip(c, c, isDark, isTablet)),
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
                      Icon(LucideIcons.shoppingBag, size: isTablet ? 48 : 40, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron productos',
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prueba con otro término de búsqueda o categoría.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 13 : 12,
                          color: const Color(0xFF94A3B8),
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
                      100,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: config.crossAxisCount,
                        childAspectRatio: config.childAspectRatio,
                        crossAxisSpacing: config.gridSpacing,
                        mainAxisSpacing: config.gridSpacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildProductoCard(prods[index], isDark, config),
                        childCount: prods.length,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  _CatalogoDeviceConfig _getDeviceConfig(BuildContext context, double width) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isLandscape = mediaQuery.orientation == Orientation.landscape;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTabletDevice = isPhysicalTablet || (width >= 650 && mediaQuery.size.height >= 550);

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

  Widget _buildCategoriaChip(String key, String label, bool isDark, bool isTablet) {
    final isSelected = _categoriaSeleccionada.toUpperCase() == key.toUpperCase();

    return Padding(
      padding: EdgeInsets.only(right: isTablet ? 10 : 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isTablet ? 13.5 : 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
        padding: isTablet ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2) : EdgeInsets.zero,
        selected: isSelected,
        selectedColor: AppTheme.brandPrimary,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isSelected
              ? AppTheme.brandPrimary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTablet ? 14 : 12)),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _categoriaSeleccionada = key);
        },
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> prod, bool isDark, _CatalogoDeviceConfig config) {
    final int id = (prod['idProducto'] is int) ? prod['idProducto'] as int : int.parse(prod['idProducto'].toString());
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num) ? (prod['precioVenta'] as num).toDouble() : 0.0;
    final int cantidadEnCarrito = _carrito[id] ?? 0;
    final bool isTablet = config.isTablet;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        border: Border.all(
          color: cantidadEnCarrito > 0
              ? AppTheme.brandPrimary
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(isTablet ? 20 : 18)),
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
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
              ),
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  final availableMax = math.min(boxConstraints.maxWidth, boxConstraints.maxHeight);
                  final double effectiveSize = (availableMax * 0.88).clamp(64.0, config.maxImageSize);
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
            ),
          ),

          // Datos del Producto (Categoría, Título, Precio)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: config.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 8 : 6,
                    vertical: isTablet ? 3 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(isTablet ? 7 : 5),
                  ),
                  child: Text(
                    categoria,
                    style: GoogleFonts.outfit(
                      fontSize: config.categoriaFontSize,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                Text(
                  'S/ ${precio.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: config.precioFontSize,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brandPrimary,
                  ),
                ),
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
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
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
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                      border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: config.botonHeight, minHeight: config.botonHeight),
                          icon: Icon(LucideIcons.minus, size: config.botonIconSize, color: AppTheme.brandPrimary),
                          onPressed: () => _modificarCantidad(id, -1),
                        ),
                        Text(
                          '$cantidadEnCarrito',
                          style: GoogleFonts.outfit(
                            fontSize: config.botonFontSize + 1,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: config.botonHeight, minHeight: config.botonHeight),
                          icon: Icon(LucideIcons.plus, size: config.botonIconSize, color: AppTheme.brandPrimary),
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
    final int id = (prod['idProducto'] is int) ? prod['idProducto'] as int : int.parse(prod['idProducto'].toString());
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String marca = prod['marca']?.toString() ?? '';
    final String codigo = prod['codigo']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? codigo;
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num) ? (prod['precioVenta'] as num).toDouble() : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int cantActual = _carrito[id] ?? 0;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(22, 14, 22, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
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
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Encabezado: Categoría y Botón Cerrar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              categoria.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(LucideIcons.x, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => Navigator.pop(ctx),
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
                          size: 160,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Marca: $marca',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ),
                          if (codigo.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SKU: $codigo',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.check, size: 12, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  'Disponible en tienda',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Precio Grande
                      Center(
                        child: Text(
                          'S/ ${precio.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Controles de Carrito
                      Row(
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.minus, size: 16),
                                  onPressed: cantActual > 0
                                      ? () {
                                          _modificarCantidad(id, -1);
                                          setModalState(() {});
                                        }
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    '$cantActual',
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.plus, size: 16),
                                  onPressed: () {
                                    _modificarCantidad(id, 1);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cantActual > 0 ? const Color(0xFF16A34A) : AppTheme.brandPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                icon: Icon(cantActual > 0 ? LucideIcons.check : LucideIcons.shoppingBag, size: 18),
                                label: Text(
                                  cantActual > 0 ? 'En Pedido ($cantActual)' : 'Agregar al Pedido',
                                  style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800),
                                ),
                                onPressed: () {
                                  if (cantActual == 0) {
                                    _modificarCantidad(id, 1);
                                  }
                                  Navigator.pop(ctx);
                                },
                              ),
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
        );
      },
    );
  }

  Widget _buildFloatingOrderBar(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet = isPhysicalTablet || (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? 'producto' : 'productos'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isTablet ? 13 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'S/ ${_totalMontoCarrito.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 22 : 19,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A), // Verde WhatsApp
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 26 : 18,
                      vertical: isTablet ? 16 : 14,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTablet ? 16 : 14)),
                  ),
                  icon: Icon(LucideIcons.send, size: isTablet ? 20 : 18),
                  label: Text(
                    'Pedir por WhatsApp',
                    style: GoogleFonts.outfit(fontSize: isTablet ? 15.5 : 14, fontWeight: FontWeight.w900),
                  ),
                  onPressed: _enviarPedidoWhatsApp,
                ),
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
