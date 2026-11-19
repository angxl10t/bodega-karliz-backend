import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cajaya_vectors.dart';
import '../../../core/gastronomia_helper.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/product_image_widget.dart';
import '../catalogo_publico_screen.dart';

/// Vista de Vitrina Web y Carta Digital Gastronómica
/// Inspirada en la estética culinaria premium de restaurantes peruanos como "La Leña",
/// integrando la identidad de marca, control y tecnología de CajaYa Cloud POS.
class CatalogoGastronomicoView extends StatefulWidget {
  final Map<String, dynamic> bodega;
  final List<Map<String, dynamic>> productos;
  final int totalProductosCount;
  final List<String> categorias;
  final String categoriaSeleccionada;
  final ValueChanged<String> onSeleccionarCategoria;
  final Map<String, int> conteoPorCategoria;
  final int ofertasCount;
  final String filtroBusqueda;
  final TextEditingController searchController;
  final ValueChanged<String> onBuscar;
  final VoidCallback onLimpiarBusqueda;
  final String ordenSeleccionado;
  final ValueChanged<String> onCambiarOrden;
  final List<Map<String, dynamic>> promociones;
  final Map<String, ItemCarritoPublico> carrito;
  final int Function(int idProducto) cantidadDeProductoEnCarrito;
  final void Function(Map<String, dynamic> prod) onAgregarProducto;
  final void Function(int idProducto, int delta) onModificarCantidad;
  final void Function(Map<String, dynamic> prod) onVerDetalleProducto;
  final Color colorMarca;
  final Color colorPromocion;
  final bool isDark;
  final String modalidadEntrega; // 'DELIVERY' | 'RECOJO'
  final ValueChanged<String> onCambiarModalidad;
  final VoidCallback onVerCarrito;
  final VoidCallback onActualizarCatalogo;

  const CatalogoGastronomicoView({
    super.key,
    required this.bodega,
    required this.productos,
    required this.totalProductosCount,
    required this.categorias,
    required this.categoriaSeleccionada,
    required this.onSeleccionarCategoria,
    required this.conteoPorCategoria,
    required this.ofertasCount,
    required this.filtroBusqueda,
    required this.searchController,
    required this.onBuscar,
    required this.onLimpiarBusqueda,
    required this.ordenSeleccionado,
    required this.onCambiarOrden,
    required this.promociones,
    required this.carrito,
    required this.cantidadDeProductoEnCarrito,
    required this.onAgregarProducto,
    required this.onModificarCantidad,
    required this.onVerDetalleProducto,
    required this.colorMarca,
    required this.colorPromocion,
    required this.isDark,
    required this.modalidadEntrega,
    required this.onCambiarModalidad,
    required this.onVerCarrito,
    required this.onActualizarCatalogo,
  });

  @override
  State<CatalogoGastronomicoView> createState() =>
      _CatalogoGastronomicoViewState();
}

class _CatalogoGastronomicoViewState extends State<CatalogoGastronomicoView> {
  final ScrollController _catScrollCtrl = ScrollController();

  String get _giroNegocio =>
      (widget.bodega['giroNegocio']?.toString() ?? 'POLLERIA').toUpperCase();

  bool get _esPolleria => _giroNegocio == 'POLLERIA';
  bool get _esChifa => _giroNegocio == 'CHIFA';
  bool get _esFastFood => _giroNegocio.contains('FAST');
  bool get _esRestaurante => _giroNegocio == 'RESTAURANTE';

  String get _badgeTipoCatalogo {
    if (_esPolleria) return 'POLLERÍA PRO';
    if (_esChifa) return 'CHIFA PRO';
    if (_esFastFood) return 'FAST FOOD PRO';
    if (_esRestaurante) return 'RESTAURANTE PRO';
    return 'CARTA PRO';
  }

  String get _subtituloEncabezado {
    if (_esPolleria) return 'Carta Digital Pollería';
    if (_esChifa) return 'Carta Digital Chifa';
    if (_esFastFood) return 'Menú Digital Fast Food';
    if (_esRestaurante) return 'Carta Digital Restaurante';
    return 'Carta Digital Gourmet';
  }

  String get _badgePrestigioFuego {
    if (_esPolleria) return 'HORNO A LA LEÑA & BRASAS AL CARBÓN';
    if (_esChifa) return 'WOK & SALTEADOS AL FUEGO VIVO';
    if (_esFastFood) return 'BROASTER CROCANTE & COMBOS AL INSTANTE';
    if (_esRestaurante) return 'COCINA PERUANA DE AUTOR & TRADICIÓN';
    return 'COCINA ARTESANAL & FUEGO VIVO';
  }

  String get _taglineEspecialidad {
    if (_esPolleria) {
      return 'Pollos dorados a la leña, papas crocantes, ensaladas frescas y cremas de la casa.';
    }
    if (_esChifa) {
      return 'Chaufas salteados al momento, tallarines saltados y especialidades en salsa oriental.';
    }
    if (_esFastFood) {
      return 'Pollo broaster extra crujiente, salchipapas clásicas y chicha morada casera.';
    }
    if (_esRestaurante) {
      return 'Platos a la carta preparados con los ingredientes más frescos del día.';
    }
    return 'Preparado al momento con el auténtico sabor y sazón tradicional.';
  }

  void _scrollCategorias(double offset) {
    if (!_catScrollCtrl.hasClients) return;
    final target = (_catScrollCtrl.offset + offset).clamp(
      0.0,
      _catScrollCtrl.position.maxScrollExtent,
    );
    _catScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  IconData _iconoParaCategoria(String categoria) {
    final c = categoria.toLowerCase();
    if (c.contains('brasa') || c.contains('pollo') || c.contains('broaster')) {
      return LucideIcons.drumstick;
    }
    if (c.contains('chaufa') ||
        c.contains('arroz') ||
        c.contains('aeropuerto') ||
        c.contains('chifa')) {
      return LucideIcons.soup;
    }
    if (c.contains('tallarin') ||
        c.contains('tallarín') ||
        c.contains('pasta') ||
        c.contains('fideos')) {
      return LucideIcons.utensils;
    }
    if (c.contains('papa') ||
        c.contains('guarnicion') ||
        c.contains('guarnición') ||
        c.contains('ensalada') ||
        c.contains('porcion') ||
        c.contains('porción')) {
      return LucideIcons.salad;
    }
    if (c.contains('bebida') ||
        c.contains('gaseosa') ||
        c.contains('chicha') ||
        c.contains('jugo') ||
        c.contains('cerveza') ||
        c.contains('refresco')) {
      return LucideIcons.glassWater;
    }
    if (c.contains('crema') || c.contains('salsa') || c.contains('aji')) {
      return LucideIcons.flame;
    }
    if (c.contains('combo') ||
        c.contains('familiar') ||
        c.contains('banquete') ||
        c.contains('duo') ||
        c.contains('dúo')) {
      return LucideIcons.sparkles;
    }
    if (c.contains('postre') || c.contains('dulce')) {
      return LucideIcons.cake;
    }
    return LucideIcons.utensils;
  }

  String _generarDescripcionSugerida(String nombre, String categoria) {
    final n = nombre.toLowerCase();
    if (n.contains('1/4') || n.contains('cuarto')) {
      return 'Dorado a fuego lento al carbón y leña. Acompañado de papas fritas crujientes, ensalada y cremas.';
    }
    if (n.contains('1/2') || n.contains('medio')) {
      return 'Corte clásico de medio pollo (pecho y pierna) con abundante porción de papas y ensalada fresca.';
    }
    if (n.contains('entero') ||
        (n.contains('1 pollo') && !n.contains('1/4') && !n.contains('1/2'))) {
      return '1 Pollo entero dorado a la brasa con el auténtico sabor tradicional, papas familiares y ensalada.';
    }
    if (n.contains('mostrito')) {
      return 'La combinación perfecta: 1/4 pollo a la brasa + abundante arroz chaufa al wok y papas fritas.';
    }
    if (n.contains('broaster')) {
      return 'Presa de pollo crujiente al estilo broaster, con papas fritas doradas y todas las salsas de la casa.';
    }
    if (n.contains('chaufa') || n.contains('aeropuerto')) {
      return 'Salteado al wok al fuego vivo con cebollita china, huevo, pimientos y el secreto del maestro chifero.';
    }
    if (n.contains('chi jau kay') || n.contains('chijaukay')) {
      return 'Trozos de pollo crocante bañado en salsa de ostión tradicional con semillas de ajonjolí tostado.';
    }
    if (n.contains('tipakay') || n.contains('ti pa kay')) {
      return 'Pollo en salsa tamarindo agridulce con trozos de piña, durazno y toque oriental.';
    }
    if (n.contains('tallarin') || n.contains('tallarín')) {
      return 'Tallarines salteados al wok con verduras crujientes, sillao oriental y trozos selectos de carne.';
    }
    if (n.contains('salchipapa')) {
      return 'Abundantes papas amarillas doraditas con hot dog parrillero y todas las cremas de la casa.';
    }
    if (n.contains('chicha')) {
      return 'Elaborada artesanalmente con maíz morado, piña, manzana, canela y toques de limón fresco.';
    }
    if (n.contains('papas')) {
      return 'Papas fritas seleccionadas, crujientes por fuera y suaves por dentro con sal de maras.';
    }
    if (n.contains('salsa') || n.contains('crema') || n.contains('ají')) {
      return 'Receta casera de la casa con el toque picante y aromático exacto para acompañar tus platos.';
    }
    return 'Preparado al instante con ingredientes frescos y la sazón auténtica de la casa.';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double shortestSide = mediaQuery.size.shortestSide;
    final bool isPhysicalTablet = shortestSide >= 600;
    final bool isTablet =
        isPhysicalTablet ||
        (mediaQuery.size.width >= 650 && mediaQuery.size.height >= 550);
    final bool isShortHeight = mediaQuery.size.height < 500;
    final double screenWidth = mediaQuery.size.width;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Hero Culinario Inmersivo (La Leña Experience)
            SliverToBoxAdapter(
              child: _buildHeroGastronomico(
                context,
                isTablet: isTablet,
                isShortHeight: isShortHeight,
              ),
            ),

            // 2. Buscador Culinario & Filtros
            SliverToBoxAdapter(
              child: _buildBuscadorGastronomico(context, isTablet: isTablet),
            ),

            // 3. Carrusel de Promociones / Combos Destacados (si existen)
            if (widget.promociones.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildPromocionesHeroBanner(context, isTablet: isTablet),
              ),

            // 4. Barra de Categorías / Secciones de Carta Digital con Iconos Culinarios
            SliverToBoxAdapter(
              child: _buildCategoriasGastronomicas(context, isTablet: isTablet),
            ),

            // 5. Barra de Resultados & Ordenamiento
            SliverToBoxAdapter(
              child: _buildBarraResultados(context, isTablet: isTablet),
            ),

            // 6. Platos y Bebidas Gastronómicas
            if (widget.productos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEstadoVacio(isTablet: isTablet),
              )
            else if (screenWidth < 680)
              // Mobile Layout: Cards de restaurante horizontal (estilo delivery gourmet)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final prod = widget.productos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildPlatoHorizontalCard(
                        context,
                        prod: prod,
                        isTablet: false,
                      ),
                    );
                  }, childCount: widget.productos.length),
                ),
              )
            else
              // Tablet / Desktop Layout: Grid de alta gastronomía (2 a 3 columnas)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 16,
                  8,
                  isTablet ? 24 : 16,
                  120,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: screenWidth >= 1050 ? 3 : 2,
                    childAspectRatio: screenWidth >= 1050 ? 0.88 : 0.82,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final prod = widget.productos[index];
                    return _buildPlatoVerticalGridCard(
                      context,
                      prod: prod,
                      isTablet: isTablet,
                    );
                  }, childCount: widget.productos.length),
                ),
              ),

            // 7. Footer Oficial & Libro de Reclamaciones
            SliverToBoxAdapter(
              child: _buildFooterLegalGastronomico(context, isTablet: isTablet),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. HERO GASTRONÓMICO INMERSIVO (La Leña Experience)
  // =========================================================================
  Widget _buildHeroGastronomico(
    BuildContext context, {
    required bool isTablet,
    required bool isShortHeight,
  }) {
    final nombreBodega =
        widget.bodega['nombreComercial']?.toString() ?? 'Pollería y Brasas';
    final lema = widget.bodega['lemaComercial']?.toString() ?? '';
    final direccion = widget.bodega['direccion']?.toString() ?? '';
    final telefono = widget.bodega['telefono']?.toString() ?? '';
    final bool estaAbierto =
        widget.bodega['catalogoAbierto'] != false &&
        widget.bodega['abierto'] != false;
    final bool deliveryActivo = widget.bodega['deliveryActivo'] != false;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isTablet ? 24 : 14,
        isShortHeight ? 6 : (isTablet ? 18 : 12),
        isTablet ? 24 : 14,
        isShortHeight ? 6 : (isTablet ? 14 : 10),
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141110) : Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 28 : 22),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF2E241F)
              : const Color(0xFFEADBCE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.65)
                : const Color(0xFF451A03).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Culinario Superior con Fondo de Fuego & Brasas
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isDark
                    ? [
                        const Color(0xFF1A120E),
                        const Color(0xFF2C1810),
                        const Color(0xFF431407),
                      ]
                    : [
                        const Color(0xFF431407),
                        const Color(0xFF78350F),
                        const Color(0xFF9A3412),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Destellos y brasas de fondo
                Positioned(
                  right: -24,
                  top: -24,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  right: 50,
                  bottom: -35,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEA580C).withValues(alpha: 0.10),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isShortHeight ? 14 : (isTablet ? 28 : 16),
                    isShortHeight ? 12 : (isTablet ? 26 : 16),
                    isShortHeight ? 14 : (isTablet ? 28 : 16),
                    isShortHeight ? 12 : (isTablet ? 22 : 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Prestigio Superior (Horno a la Leña / Wok)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.45),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.flame,
                                  size: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _badgePrestigioFuego,
                                  style: GoogleFonts.outfit(
                                    fontSize: isTablet ? 11 : 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Badge Oficial PRO
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF34D399),
                                width: 0.9,
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Identidad del Restaurante (Avatar + Nombre + Tagline)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar del Local con Marco de Brasas
                          Container(
                            width: isTablet ? 72 : 54,
                            height: isTablet ? 72 : 54,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              borderRadius: BorderRadius.circular(
                                isTablet ? 20 : 16,
                              ),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.60),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                isTablet ? 18 : 14,
                              ),
                              child:
                                  (widget.bodega['logoUrl'] != null &&
                                      widget.bodega['logoUrl']
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                  ? Image.network(
                                      widget.bodega['logoUrl']
                                          .toString()
                                          .trim(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(
                                          LucideIcons.flame,
                                          size: 28,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        LucideIcons.flame,
                                        size: 28,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreBodega,
                                  style: GoogleFonts.outfit(
                                    fontSize: isTablet ? 26 : 20.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lema.isNotEmpty ? lema : _subtituloEncabezado,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 13 : 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.90),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _taglineEspecialidad,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 11.5 : 10.5,
                                    color: const Color(0xFFFED7AA),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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

          // Selector de Modalidad (Delivery vs Recojo - La Leña Signature)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 14,
              vertical: isTablet ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF1E1714)
                  : const Color(0xFFFFFBEB),
              border: Border(
                bottom: BorderSide(
                  color: widget.isDark
                      ? const Color(0xFF2C221D)
                      : const Color(0xFFFDE68A),
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '¿CÓMO DESEAS TU ORDEN?',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: widget.isDark
                            ? const Color(0xFFF97316)
                            : const Color(0xFFC2410C),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: estaAbierto
                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                            : const Color(0xFFEF4444).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: estaAbierto
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            estaAbierto
                                ? 'Abierto ahora'
                                : 'Cerrado temporalmente',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: estaAbierto
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Botones interactivos Delivery vs Recojo
                Row(
                  children: [
                    Expanded(
                      child: _buildModalidadTabButton(
                        context,
                        titulo: 'Delivery a Domicilio',
                        subtitulo: deliveryActivo ? '30 - 45 min' : 'No disp.',
                        icono: LucideIcons.bike,
                        esSeleccionado: widget.modalidadEntrega == 'DELIVERY',
                        activo: deliveryActivo,
                        onTap: () {
                          if (deliveryActivo) {
                            HapticFeedback.selectionClick();
                            widget.onCambiarModalidad('DELIVERY');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModalidadTabButton(
                        context,
                        titulo: 'Para llevar / Local',
                        subtitulo: '15 - 25 min',
                        icono: LucideIcons.store,
                        esSeleccionado: widget.modalidadEntrega == 'RECOJO',
                        activo: true,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onCambiarModalidad('RECOJO');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Píldoras de Dirección, WhatsApp y Formas de Pago
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 14,
              vertical: isTablet ? 12 : 10,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (direccion.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 13,
                        color: widget.isDark
                            ? const Color(0xFFF97316)
                            : const Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          direccion,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (telefono.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final l = telefono.replaceAll(RegExp(r'[^0-9]'), '');
                      final tf = (l.length == 9 && l.startsWith('9'))
                          ? '51$l'
                          : (l.startsWith('51') ? l : '51$l');
                      final uri = Uri.parse('https://wa.me/$tf');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF16A34A)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.messageCircle,
                            size: 12.5,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4.5),
                          Text(
                            'WhatsApp: $telefono',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.wallet,
                        size: 12,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Acepta Yape · Plin · Efectivo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalidadTabButton(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required bool esSeleccionado,
    required bool activo,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: activo ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: esSeleccionado
              ? (isDark ? const Color(0xFFEA580C) : const Color(0xFFC2410C))
              : (isDark ? const Color(0xFF141110) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: esSeleccionado
                ? const Color(0xFFEA580C)
                : (isDark ? const Color(0xFF332A24) : const Color(0xFFE2E8F0)),
            width: esSeleccionado ? 1.8 : 1.0,
          ),
          boxShadow: esSeleccionado
              ? [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icono,
              size: 17,
              color: esSeleccionado
                  ? Colors.white
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: esSeleccionado
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.textDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: esSeleccionado
                          ? const Color(0xFFFED7AA)
                          : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            if (esSeleccionado)
              const Icon(
                LucideIcons.checkCircle2,
                size: 15,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. BUSCADOR GASTRONÓMICO
  // =========================================================================
  Widget _buildBuscadorGastronomico(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 14,
        vertical: 4,
      ),
      child: TextField(
        controller: widget.searchController,
        onChanged: widget.onBuscar,
        style: GoogleFonts.plusJakartaSans(
          fontSize: isTablet ? 14 : 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: _esPolleria
              ? 'Buscar pollos a la brasa, combos, porción de papas, bebidas...'
              : (_esChifa
                    ? 'Buscar chaufas, wantanes, aeropuerto, tipakay, bebidas...'
                    : 'Buscar platos a la carta, combos, guarniciones...'),
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: isTablet ? 13 : 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 18,
            color: Color(0xFFEA580C),
          ),
          suffixIcon: widget.filtroBusqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: widget.onLimpiarBusqueda,
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF171311) : Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isTablet ? 14 : 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2E241F) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2E241F) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.8),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. CARRUSEL DE PROMOCIONES Y COMBOS (La Leña Banquets)
  // =========================================================================
  Widget _buildPromocionesHeroBanner(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    return Container(
      margin: EdgeInsets.fromLTRB(
        isTablet ? 24 : 14,
        10,
        isTablet ? 24 : 14,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 16,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(width: 6),
              Text(
                'COMBOS & ESPECIALES DEL DÍA',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: isDark
                      ? const Color(0xFFFED7AA)
                      : const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isTablet ? 144 : 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.promociones.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final pm = widget.promociones[i];
                final titulo = pm['titulo']?.toString() ?? 'Combo Especial';
                final desc = pm['descripcion']?.toString() ?? '';
                final badge = pm['badgeTexto']?.toString() ?? 'PROMO';

                return InkWell(
                  onTap: () {
                    final cat = pm['categoriaObjetivo']?.toString();
                    if (cat != null && cat.isNotEmpty) {
                      widget.onSeleccionarCategoria(cat);
                    } else {
                      widget.onSeleccionarCategoria('OFERTAS');
                    }
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: isTablet ? 320 : 275,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF381A0E), const Color(0xFF1B1411)]
                            : [const Color(0xFFFFF7ED), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFEA580C)
                            .withValues(alpha: isDark ? 0.45 : 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C)
                              .withValues(alpha: isDark ? 0.16 : 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
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
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 15,
                              color: Color(0xFFEA580C),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: isTablet ? 15 : 13.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            desc.isNotEmpty ? desc : 'Aprovecha este combo exclusivo para pedir hoy.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF64748B),
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

  // =========================================================================
  // 4. CATEGORÍAS GASTRONÓMICAS (Tabs Culinarios)
  // =========================================================================
  Widget _buildCategoriasGastronomicas(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 14,
        vertical: 8,
      ),
      child: Row(
        children: [
          if (isTablet) ...[
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
              onPressed: () => _scrollCategorias(-260),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SingleChildScrollView(
              controller: _catScrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Tab Toda la Carta
                  _buildCategoriaPill(
                    label: 'Carta',
                    categoryKey: 'TODAS',
                    icon: LucideIcons.utensils,
                    count: widget.totalProductosCount,
                    isDark: isDark,
                  ),
                  if (widget.ofertasCount > 0)
                    _buildCategoriaPill(
                      label: 'Ofertas',
                      categoryKey: 'OFERTAS',
                      icon: LucideIcons.sparkles,
                      count: widget.ofertasCount,
                      isDark: isDark,
                      esOferta: true,
                    ),
                  ...widget.categorias.map((c) {
                    return _buildCategoriaPill(
                      label: c,
                      categoryKey: c,
                      icon: _iconoParaCategoria(c),
                      count: widget.conteoPorCategoria[c.trim().toUpperCase()],
                      isDark: isDark,
                    );
                  }),
                ],
              ),
            ),
          ),
          if (isTablet) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(LucideIcons.chevronRight, size: 18),
              onPressed: () => _scrollCategorias(260),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriaPill({
    required String label,
    required String categoryKey,
    required IconData icon,
    int? count,
    required bool isDark,
    bool esOferta = false,
  }) {
    final bool isSelected = widget.categoriaSeleccionada == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onSeleccionarCategoria(categoryKey);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFC2410C),
                      Color(0xFFEA580C),
                      Color(0xFFF59E0B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF1E1714) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFEA580C)
                  : (isDark
                        ? const Color(0xFF2C221D)
                        : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (esOferta
                          ? const Color(0xFFEA580C)
                          : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B))),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.textDark),
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.25)
                        : (isDark
                              ? const Color(0xFF332A24)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 5. BARRA DE RESULTADOS & ORDENAMIENTO
  // =========================================================================
  Widget _buildBarraResultados(BuildContext context, {required bool isTablet}) {
    final isDark = widget.isDark;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.productos.length} platos y especialidades',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.ordenSeleccionado,
              dropdownColor: isDark ? const Color(0xFF1E1714) : Colors.white,
              icon: const Icon(LucideIcons.arrowUpDown, size: 14),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'DESTACADOS',
                  child: Text('Destacados'),
                ),
                DropdownMenuItem(
                  value: 'MENOR_PRECIO',
                  child: Text('Menor precio'),
                ),
                DropdownMenuItem(
                  value: 'MAYOR_PRECIO',
                  child: Text('Mayor precio'),
                ),
              ],
              onChanged: (val) {
                if (val != null) widget.onCambiarOrden(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6A. CARD DE PLATO HORIZONTAL (Mobile Delivery Style - La Leña)
  // =========================================================================
  Widget _buildPlatoHorizontalCard(
    BuildContext context, {
    required Map<String, dynamic> prod,
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    final id = (prod['idProducto'] is num)
        ? (prod['idProducto'] as num).toInt()
        : int.tryParse(prod['idProducto']?.toString() ?? '') ?? 0;
    final nombre = prod['nombre']?.toString() ?? 'Plato';
    final categoria = prod['categoria']?.toString() ?? 'Platos';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : double.tryParse(prod['precioVenta']?.toString() ?? '0') ?? 0.0;
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

    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? '';
    final bool esConPresa = GastronomiaHelper.esProductoConPresa(
      nombre,
      categoria,
    );
    final int cantidadEnCarrito = widget.cantidadDeProductoEnCarrito(id);
    final String descripcion = _generarDescripcionSugerida(nombre, categoria);

    return InkWell(
      onTap: () => widget.onVerDetalleProducto(prod),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF191412) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2C221D) : const Color(0xFFEDE4D9),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFF451A03).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lado Izquierdo: Información Culinaria, Precio y Acción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Categoría / Presa
                      Row(
                        children: [
                          if (esConPresa)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.drumstick,
                                    size: 10,
                                    color: Color(0xFFEA580C),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    nombre.toLowerCase().contains('1/2')
                                        ? 'Pecho y Pierna'
                                        : 'Elige Presa',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              categoria.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Título del Plato
                      Text(
                        nombre,
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textDark,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Descripción Culinaria Apetitosa
                      Text(
                        descripcion,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Fila de Precio & Botón de Pedir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Precios
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tienePromoValida) ...[
                              Text(
                                'S/ ${precio.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'S/ ${promoPrice.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: widget.colorPromocion,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else ...[
                              Text(
                                'S/ ${precio.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFC2410C),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón "Agregar" (con compatibilidad estricta de tests)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => widget.onAgregarProducto(prod),
                        icon: Icon(
                          esConPresa ? LucideIcons.drumstick : LucideIcons.plus,
                          size: 14,
                        ),
                        label: Text(
                          'Agregar',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Lado Derecho: Fotografía Gastronómica (Packshot Estudio)
            Stack(
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.06,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ProductImageWidget(
                    imagenUrl: imagenUrl,
                    nombre: nombre,
                    codigoBarras: codigoBarras,
                    categoria: categoria,
                    size: 110,
                    borderRadius: 16,
                    isDark: false,
                    seamless: true,
                    padding: 4,
                  ),
                ),
                if (descuentoPct > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$descuentoPct%',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (cantidadEnCarrito > 0)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'x$cantidadEnCarrito',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 6B. CARD DE PLATO VERTICAL (Tablet & Desktop Grid - La Leña)
  // =========================================================================
  Widget _buildPlatoVerticalGridCard(
    BuildContext context, {
    required Map<String, dynamic> prod,
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    final id = (prod['idProducto'] is num)
        ? (prod['idProducto'] as num).toInt()
        : int.tryParse(prod['idProducto']?.toString() ?? '') ?? 0;
    final nombre = prod['nombre']?.toString() ?? 'Plato';
    final categoria = prod['categoria']?.toString() ?? 'Platos';
    final double precio = (prod['precioVenta'] is num)
        ? (prod['precioVenta'] as num).toDouble()
        : double.tryParse(prod['precioVenta']?.toString() ?? '0') ?? 0.0;
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

    final String imagenUrl = prod['imagenUrl']?.toString() ?? '';
    final String codigoBarras = prod['codigoBarras']?.toString() ?? '';
    final bool esConPresa = GastronomiaHelper.esProductoConPresa(
      nombre,
      categoria,
    );
    final int cantidadEnCarrito = widget.cantidadDeProductoEnCarrito(id);
    final String descripcion = _generarDescripcionSugerida(nombre, categoria);

    return InkWell(
      onTap: () => widget.onVerDetalleProducto(prod),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF191412) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF2C221D) : const Color(0xFFEDE4D9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.50)
                  : const Color(0xFF451A03).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gran Fotografía de Plato Superior (Estudio Panorámico)
            Stack(
              children: [
                Container(
                  height: 170,
                  width: double.infinity,
                  color: Colors.white,
                  child: ProductImageWidget(
                    imagenUrl: imagenUrl,
                    nombre: nombre,
                    codigoBarras: codigoBarras,
                    categoria: categoria,
                    size: 160,
                    borderRadius: 0,
                    isDark: false,
                    seamless: true,
                    padding: 8,
                  ),
                ),
                if (descuentoPct > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'AHORRAS $descuentoPct%',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (esConPresa)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.drumstick,
                            size: 11,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            nombre.toLowerCase().contains('1/2')
                                ? 'Pecho y Pierna'
                                : 'Elige tu presa',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (cantidadEnCarrito > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'x$cantidadEnCarrito en orden',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Contenido y Datos Culinarios
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoria.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: isDark
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nombre,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textDark,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          descripcion,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Fila Inferior: Precios & Botón "Agregar"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (tienePromoValida) ...[
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'S/ ${promoPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: widget.colorPromocion,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text(
                                  'S/ ${precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFC2410C),
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => widget.onAgregarProducto(prod),
                          icon: Icon(
                            esConPresa
                                ? LucideIcons.drumstick
                                : LucideIcons.plus,
                            size: 15,
                          ),
                          label: Text(
                            'Agregar',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 7. ESTADO VACÍO
  // =========================================================================
  Widget _buildEstadoVacio({required bool isTablet}) {
    final isDark = widget.isDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.drumstick,
                color: Color(0xFFEA580C),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron platos ni bebidas',
              style: GoogleFonts.outfit(
                fontSize: isTablet ? 19 : 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba buscando con otro término o seleccionando otra sección de la carta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isTablet ? 13 : 12,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 8. FOOTER LEGAL & SELLO CAJAYA
  // =========================================================================
  Widget _buildFooterLegalGastronomico(
    BuildContext context, {
    required bool isTablet,
  }) {
    final isDark = widget.isDark;
    final nombreBodega =
        widget.bodega['nombreComercial']?.toString() ?? 'CajaYa Cloud POS';
    final int? idBodega = widget.bodega['idBodega'] is int
        ? widget.bodega['idBodega']
        : int.tryParse(widget.bodega['idBodega']?.toString() ?? '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141110) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E241F) : const Color(0xFFFDE68A),
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
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$nombreBodega • Carta Digital Oficial Gastronómica',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                color: isDark ? const Color(0xFF1E1714) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF332A24)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.bookOpen,
                    size: 15,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Libro de Reclamaciones Virtual (INDECOPI)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textDark,
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
}
