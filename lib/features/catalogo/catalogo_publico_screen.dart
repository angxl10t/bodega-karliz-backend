import 'dart:convert';
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo.')),
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
    final nombreBodega = _bodega['nombreComercial']?.toString() ?? 'Bodega';
    final lema = _bodega['lemaComercial']?.toString() ?? '';
    final direccion = _bodega['direccion']?.toString() ?? '';
    final prods = _productosFiltrados;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Banner Superior de la Tienda
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(LucideIcons.store, size: 26, color: AppTheme.brandPrimary),
                    ),
                    const SizedBox(width: 14),
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
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppTheme.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PRO ONLINE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
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
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          if (direccion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(LucideIcons.mapPin, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    direccion,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Buscador
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _filtroBusqueda = val),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar productos, abarrotes, bebidas...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.brandPrimary),
                    suffixIcon: _filtroBusqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _filtroBusqueda = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildCategoriaChip('TODAS', 'Todos (${_productos.length})', isDark),
                ..._categorias.map((c) => _buildCategoriaChip(c, c, isDark)),
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
                  Icon(LucideIcons.shoppingBag, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron productos',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prueba con otro término de búsqueda o categoría.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.crossAxisExtent;
                int crossAxisCount = 2;
                if (width >= 1050) {
                  crossAxisCount = 4;
                } else if (width >= 700) {
                  crossAxisCount = 3;
                }

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildProductoCard(prods[index], isDark),
                    childCount: prods.length,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoriaChip(String key, String label, bool isDark) {
    final isSelected = _categoriaSeleccionada.toUpperCase() == key.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.brandPrimary,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isSelected
              ? AppTheme.brandPrimary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _categoriaSeleccionada = key);
        },
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> prod, bool isDark) {
    final int id = (prod['idProducto'] is int) ? prod['idProducto'] as int : int.parse(prod['idProducto'].toString());
    final String nombre = prod['nombre']?.toString() ?? 'Producto';
    final String categoria = prod['categoria']?.toString() ?? 'General';
    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final double precio = (prod['precioVenta'] is num) ? (prod['precioVenta'] as num).toDouble() : 0.0;
    final int cantidadEnCarrito = _carrito[id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cantidadEnCarrito > 0
              ? AppTheme.brandPrimary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: cantidadEnCarrito > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del Producto
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: ProductImageWidget(
                  imagenUrl: imagenUrl,
                  categoria: categoria,
                  size: 72,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // Datos del Producto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    categoria,
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nombre,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'S/ ${precio.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brandPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Botón / Selector de Cantidad
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: cantidadEnCarrito == 0
                ? SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _modificarCantidad(id, 1),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: Text(
                        'Agregar',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                : Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                          icon: const Icon(LucideIcons.minus, size: 14, color: AppTheme.brandPrimary),
                          onPressed: () => _modificarCantidad(id, -1),
                        ),
                        Text(
                          '$cantidadEnCarrito',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                          icon: const Icon(LucideIcons.plus, size: 14, color: AppTheme.brandPrimary),
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

  Widget _buildFloatingOrderBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'S/ ${_totalMontoCarrito.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(LucideIcons.send, size: 18),
              label: Text(
                'Pedir por WhatsApp',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              onPressed: _enviarPedidoWhatsApp,
            ),
          ],
        ),
      ),
    );
  }
}
