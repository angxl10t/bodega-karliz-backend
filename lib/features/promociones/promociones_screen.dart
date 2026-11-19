import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/widgets/plan_upgrade_modal.dart';
import '../../core/widgets/product_image_widget.dart';
import 'crear_promocion_sheet.dart';
import 'promocion_model.dart';
import 'promocion_service.dart';

class PromocionesScreen extends StatefulWidget {
  final bool isPro;
  final String nombreBodega;
  final VoidCallback? onPlanUpdated;
  final int initialTab; // 0 = Promos, 1 = Sugerencias Huesos

  const PromocionesScreen({
    super.key,
    required this.isPro,
    required this.nombreBodega,
    this.onPlanUpdated,
    this.initialTab = 0,
  });

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PromocionService _service = PromocionService();

  List<Promocion> _promociones = [];
  List<SugerenciaComboHueso> _sugerencias = [];
  bool _cargando = true;
  String _filtroTexto = '';
  String _filtroTipo = 'ALL'; // ALL, COMBOS, DESCUENTOS, DOS_POR_UNO, PAUSADAS

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    if (widget.isPro) {
      _cargarDatos();
    } else {
      _cargando = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final (promos, sugs) = await (
        _service.obtenerPromociones(),
        _service.obtenerSugerenciasHuesos(),
      ).wait;
      if (mounted) {
        setState(() {
          _promociones = promos;
          _sugerencias = sugs;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (!widget.isPro) {
      return _buildBloqueoPro(isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                LucideIcons.arrowLeft,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Promociones y Descuentos',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.nombreBodega,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Sincronizar Datos',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: _cargarDatos,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text(
                    'NUEVA',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () {
                    CrearPromocionSheet.show(context, onSaved: _cargarDatos);
                  },
                ),
              ),
            ],
            bottom: isWide
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? AppTheme.borderDark
                                : AppTheme.borderLight,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: primaryColor,
                        unselectedLabelColor: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        indicatorColor: primaryColor,
                        indicatorWeight: 3,
                        labelStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.tag, size: 15),
                                const SizedBox(width: 6),
                                Text('Promociones (${_promociones.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.sparkles,
                                  size: 15,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 6),
                                Text('Combos Huesos (${_sugerencias.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          body: _cargando
              ? const Center(child: CircularProgressIndicator())
              : (isWide
                    ? RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          children: [
                            _buildCockpitKpis(isDark, primaryColor, true),
                            const SizedBox(height: 18),
                            _buildWideCockpitContent(isDark, primaryColor),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: _buildCockpitKpis(
                              isDark,
                              primaryColor,
                              false,
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildTabPromocionesList(isDark, primaryColor),
                                _buildTabSugerenciasList(isDark, primaryColor),
                              ],
                            ),
                          ),
                        ],
                      )),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // COCKPIT TOP KPIS BAR
  // ---------------------------------------------------------------------------
  Widget _buildCockpitKpis(bool isDark, Color brandColor, bool isWide) {
    final activas = _promociones.where((p) => p.activo).length;
    final total = _promociones.length;
    final capitalHueso = _sugerencias.fold<double>(
      0.0,
      (acc, s) => acc + s.capitalInmovilizado,
    );
    final countHuesos = _sugerencias.length;

    // Ahorro promedio calculado
    double ahorroPromedio = 16.5;
    if (_sugerencias.isNotEmpty) {
      final sumPct = _sugerencias.fold<double>(
        0.0,
        (acc, s) => acc + s.porcentajeDescuentoSugerido,
      );
      ahorroPromedio = sumPct / _sugerencias.length;
    }

    final kpis = [
      _KpiData(
        title: 'Promociones Activas',
        value: '$activas activas',
        badgeText: '$total en total',
        badgeColor: const Color(0xFF10B981),
        icon: LucideIcons.tag,
        iconBg: isDark ? const Color(0xFF1E2E4A) : const Color(0xFFEFF6FF),
        iconColor: brandColor,
      ),
      _KpiData(
        title: 'Capital en Huesos Detectado',
        value: 'S/ ${capitalHueso.toStringAsFixed(2)}',
        badgeText: '$countHuesos productos estancados',
        badgeColor: const Color(0xFFEF4444),
        icon: LucideIcons.alertTriangle,
        iconBg: isDark ? const Color(0xFF3B171E) : const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFEF4444),
      ),
      _KpiData(
        title: 'Ahorro Promedio Ofrecido',
        value: '${ahorroPromedio.toStringAsFixed(1)}% OFF',
        badgeText: 'Visible en web y POS',
        badgeColor: const Color(0xFF10B981),
        icon: LucideIcons.badgePercent,
        iconBg: isDark ? const Color(0xFF063B2C) : const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
      ),
      _KpiData(
        title: 'Impacto en Rotación',
        value: '+2.8x Más Rápido',
        badgeText: 'Despacho táctico en caja',
        badgeColor: const Color(0xFF8B5CF6),
        icon: LucideIcons.sparkles,
        iconBg: isDark ? const Color(0xFF281845) : const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF8B5CF6),
      ),
    ];

    if (isWide) {
      return Row(
        children: kpis.map((kpi) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildKpiCard(kpi, isDark),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: kpis.map((kpi) {
          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12),
            child: _buildKpiCard(kpi, isDark),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiCard(_KpiData kpi, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kpi.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(kpi.icon, size: 20, color: kpi.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kpi.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: kpi.badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        kpi.badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: kpi.badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDE 2-COLUMN COCKPIT (Desktop / Tablet)
  // ---------------------------------------------------------------------------
  Widget _buildWideCockpitContent(bool isDark, Color brandColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Catálogo de Promociones (Flex 12)
        Expanded(
          flex: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Ofertas y Descuentos en Vigencia',
                '${_promociones.length} Configurada${_promociones.length == 1 ? "" : "s"}',
                LucideIcons.tags,
                brandColor,
                isDark,
              ),
              const SizedBox(height: 12),
              _buildFiltrosBar(isDark, brandColor),
              const SizedBox(height: 12),
              _buildSearchInput(isDark, brandColor),
              const SizedBox(height: 16),
              _buildPromocionesListContent(isDark, brandColor),
            ],
          ),
        ),

        const SizedBox(width: 24),

        // Columna Derecha: Motor de Combos Hueso IA (Flex 9)
        Expanded(
          flex: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Motor Inteligente "Combos Hueso"',
                'IA Activa',
                LucideIcons.sparkles,
                const Color(0xFF8B5CF6),
                isDark,
              ),
              const SizedBox(height: 12),
              _buildBannerCombosHueso(isDark, brandColor),
              const SizedBox(height: 16),
              _buildSugerenciasListContent(isDark, brandColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    String tag,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS & SEARCH INPUT
  // ---------------------------------------------------------------------------
  Widget _buildFiltrosBar(bool isDark, Color brandColor) {
    final combosCount = _promociones
        .where((p) => p.tipoPromocion == 'COMBO_HUESO' || p.alcance == 'COMBO')
        .length;
    final descuentosCount = _promociones
        .where(
          (p) =>
              p.tipoPromocion == 'PORCENTAJE' ||
              p.tipoPromocion == 'MONTO_FIJO',
        )
        .length;
    final dosPorUnoCount = _promociones
        .where(
          (p) =>
              p.tipoPromocion == 'DOS_POR_UNO' ||
              p.tipoPromocion == 'TRES_POR_DOS',
        )
        .length;
    final pausadasCount = _promociones.where((p) => !p.activo).length;

    final options = [
      {'key': 'ALL', 'label': 'Todas (${_promociones.length})'},
      {'key': 'COMBOS', 'label': 'Combos Dúo ($combosCount)'},
      {'key': 'DESCUENTOS', 'label': 'Descuentos % ($descuentosCount)'},
      {'key': 'DOS_POR_UNO', 'label': '2x1 / 3x2 ($dosPorUnoCount)'},
      {'key': 'PAUSADAS', 'label': 'Pausadas ($pausadasCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((opt) {
          final isSelected = _filtroTipo == opt['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _filtroTipo = opt['key']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandColor
                      : (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFFFFFFF)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? brandColor
                        : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  opt['label']!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchInput(bool isDark, Color brandColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por producto, marca o categoría objetivo...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          suffixIcon: _filtroTexto.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 14),
                  onPressed: () => setState(() => _filtroTexto = ''),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
        onChanged: (v) => setState(() => _filtroTexto = v),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROMOCIONES LIST CONTENT
  // ---------------------------------------------------------------------------
  List<Promocion> _obtenerPromosFiltradas() {
    return _promociones.where((p) {
      if (_filtroTipo == 'COMBOS' &&
          p.tipoPromocion != 'COMBO_HUESO' &&
          p.alcance != 'COMBO') {
        return false;
      }
      if (_filtroTipo == 'DESCUENTOS' &&
          p.tipoPromocion != 'PORCENTAJE' &&
          p.tipoPromocion != 'MONTO_FIJO') {
        return false;
      }
      if (_filtroTipo == 'DOS_POR_UNO' &&
          p.tipoPromocion != 'DOS_POR_UNO' &&
          p.tipoPromocion != 'TRES_POR_DOS') {
        return false;
      }
      if (_filtroTipo == 'PAUSADAS' && p.activo) {
        return false;
      }

      if (_filtroTexto.isNotEmpty) {
        final q = _filtroTexto.toLowerCase();
        return p.titulo.toLowerCase().contains(q) ||
            p.descripcion.toLowerCase().contains(q) ||
            (p.categoriaObjetivo?.toLowerCase().contains(q) ?? false) ||
            (p.marcaObjetivo?.toLowerCase().contains(q) ?? false) ||
            (p.nombreProductoPrincipal?.toLowerCase().contains(q) ?? false) ||
            (p.nombreProductoSecundario?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Widget _buildTabPromocionesList(bool isDark, Color brandColor) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildFiltrosBar(isDark, brandColor),
        const SizedBox(height: 12),
        _buildSearchInput(isDark, brandColor),
        const SizedBox(height: 14),
        _buildPromocionesListContent(isDark, brandColor),
      ],
    );
  }

  Widget _buildPromocionesListContent(bool isDark, Color brandColor) {
    final filtradas = _obtenerPromosFiltradas();

    if (filtradas.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              LucideIcons.tag,
              size: 40,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontraron promociones',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _filtroTexto.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda.'
                  : 'Crea una nueva promoción para impulsar tus ventas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtradas.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPromoCard(p, isDark, brandColor),
        );
      }).toList(),
    );
  }

  Widget _buildPromoCard(Promocion p, bool isDark, Color brandColor) {
    final badgeColor = _parseColor(p.colorBadge);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.activo
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Badges + Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.badgeTexto,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.alcance == 'CATEGORIA'
                      ? 'Categoría: ${p.categoriaObjetivo ?? ""}'
                      : (p.alcance == 'MARCA'
                            ? 'Marca: ${p.marcaObjetivo ?? ""}'
                            : (p.alcance == 'COMBO'
                                  ? 'Combo Especial'
                                  : (p.nombreProductoPrincipal != null
                                        ? 'Producto: ${p.nombreProductoPrincipal}'
                                        : 'Producto Individual'))),
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : AppTheme.textDark,
                  ),
                ),
              ),
              const Spacer(),
              Switch(
                value: p.activo,
                activeTrackColor: const Color(0xFF10B981)
                    .withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) async {
                  HapticFeedback.selectionClick();
                  await _service.cambiarEstado(p.idPromocion, val);
                  _cargarDatos();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Promoción "${p.titulo}" activada'
                              : 'Promoción "${p.titulo}" pausada',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: val
                            ? const Color(0xFF10B981)
                            : const Color(0xFF64748B),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Body: Packshot + Info + Pricing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Packshot con ProductImageWidget
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ProductImageWidget(
                    imagenUrl: null,
                    nombre: p.nombreProductoPrincipal ?? p.titulo,
                    categoria: p.categoriaObjetivo,
                    size: 50,
                    borderRadius: 8,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titulo,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    if (p.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (p.precioCombo != null) ...[
                          Text(
                            'S/ ${p.precioCombo!.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: brandColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (p.valorDescuento > 0 ||
                            p.tipoPromocion == 'DOS_POR_UNO' ||
                            p.tipoPromocion == 'TRES_POR_DOS')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              p.tipoPromocion == 'TRES_POR_DOS'
                                  ? '3x2 (LLEVA 3 PAGA 2)'
                                  : p.tipoPromocion == 'DOS_POR_UNO'
                                  ? '2x1 (LLEVA 2 PAGA 1)'
                                  : p.tipoPromocion == 'PORCENTAJE'
                                  ? '-${p.valorDescuento.toStringAsFixed(0)}% OFF'
                                  : '-S/ ${p.valorDescuento.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Footer: Vigencia + Botones de Acción
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildVigenciaRow(p, isDark)),
                IconButton(
                  tooltip: 'Editar Promoción',
                  icon: const Icon(LucideIcons.pencil, size: 15),
                  onPressed: () {
                    CrearPromocionSheet.show(
                      context,
                      promocionEdit: p,
                      onSaved: _cargarDatos,
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Eliminar Promoción',
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 15,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Eliminar Promoción?'),
                        content: const Text(
                          'Esta promoción dejará de aplicarse en tu catálogo digital y en el mostrador.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.eliminarPromocion(p.idPromocion);
                      _cargarDatos();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUGERENCIAS COMBOS HUESO LIST CONTENT
  // ---------------------------------------------------------------------------
  Widget _buildBannerCombosHueso(bool isDark, Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2436), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: brandColor.withValues(alpha: isDark ? 0.25 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.sparkles, color: brandColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descongelamiento Táctico de Mercadería',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Empareja productos con más de 30 días sin rotar junto a tus líderes de venta para recuperar liquidez sin perder margen.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSugerenciasList(bool isDark, Color brandColor) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildBannerCombosHueso(isDark, brandColor),
        const SizedBox(height: 16),
        _buildSugerenciasListContent(isDark, brandColor),
      ],
    );
  }

  Widget _buildSugerenciasListContent(bool isDark, Color brandColor) {
    if (_sugerencias.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              LucideIcons.checkCircle2,
              size: 42,
              color: Color(0xFF10B981),
            ),
            const SizedBox(height: 12),
            Text(
              '¡Excelente Rotación de Inventario!',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No tienes productos estancados por más de 30 días. Tu capital está circulando de forma saludable.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _sugerencias.map((sug) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSugerenciaCard(sug, isDark, brandColor),
        );
      }).toList(),
    );
  }

  Widget _buildSugerenciaCard(
    SugerenciaComboHueso sug,
    bool isDark,
    Color brandColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: AI Badge + Capital Alert
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sug.badgeSugerido,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444)
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'S/ ${sug.capitalInmovilizado.toStringAsFixed(2)} inmovilizados',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dual Pairing Visual: Hueso (+) Estrella
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                // HUESO
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ProductImageWidget(
                          imagenUrl: sug.imagenUrlHueso,
                          nombre: sug.nombreHueso,
                          categoria: sug.categoriaHueso,
                          size: 44,
                          borderRadius: 8,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HUESO (${sug.stockHueso.toInt()} u.)',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            Text(
                              sug.nombreHueso,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                            Text(
                              'Costo S/ ${sug.costoHueso.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Conector circular +
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: brandColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.plus,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),

                // ESTRELLA
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ProductImageWidget(
                            imagenUrl: sug.imagenUrlEstrella,
                            nombre: sug.nombreEstrella,
                            categoria: sug.categoriaEstrella,
                            size: 44,
                            borderRadius: 8,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LÍDER DE VENTA',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                sug.nombreEstrella,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'Reg. S/ ${sug.precioRegularEstrella.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppTheme.textDarkSecondary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Strategy Rationale Quote Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141D2E) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: brandColor, width: 3)),
            ),
            child: Text(
              sug.razonEstrategica,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pricing & 1-Tap Activation Action
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Regular S/ ${sug.precioRegularTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'S/ ${sug.precioComboSugerido.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(LucideIcons.zap, size: 14),
                label: Text(
                  'Activar Combo en 1 Clic',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  CrearPromocionSheet.show(
                    context,
                    sugerenciaHueso: sug,
                    onSaved: () {
                      _cargarDatos();
                      _tabController.animateTo(0);
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

  // ---------------------------------------------------------------------------
  // VIGENCIA ROW HELPER
  // ---------------------------------------------------------------------------
  Widget _buildVigenciaRow(Promocion p, bool isDark) {
    if (p.fechaInicio == null && p.fechaFin == null) {
      return Row(
        children: [
          Icon(
            LucideIcons.infinity,
            size: 13,
            color: isDark ? Colors.white70 : const Color(0xFF1E293B),
          ),
          const SizedBox(width: 5),
          Text(
            'Sin fecha límite (Permanente)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? dtInicio = p.fechaInicio != null
        ? DateTime.tryParse(p.fechaInicio!)
        : null;
    DateTime? dtFin = p.fechaFin != null
        ? DateTime.tryParse(p.fechaFin!)
        : null;

    String vigenciaTexto = '';
    String estadoVigencia = '';
    Color estadoColor = const Color(0xFF10B981);
    Color estadoBg = const Color(0xFF10B981).withValues(alpha: 0.12);

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    if (dtInicio != null && dtFin != null) {
      vigenciaTexto = '${fmt(dtInicio)} al ${fmt(dtFin)}';
    } else if (dtInicio != null) {
      vigenciaTexto = 'Desde el ${fmt(dtInicio)}';
    } else if (dtFin != null) {
      vigenciaTexto = 'Hasta el ${fmt(dtFin)}';
    }

    if (dtInicio != null && dtInicio.isAfter(today)) {
      final diasFaltantes = dtInicio.difference(today).inDays;
      estadoVigencia = diasFaltantes == 1
          ? 'Inicia mañana'
          : 'Inicia en $diasFaltantes días';
      estadoColor = const Color(0xFF2563EB);
      estadoBg = const Color(0xFF2563EB).withValues(alpha: 0.12);
    } else if (dtFin != null && dtFin.isBefore(today)) {
      estadoVigencia = 'Expirada';
      estadoColor = const Color(0xFFEF4444);
      estadoBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
    } else if (dtFin != null && dtFin.difference(today).inDays <= 2) {
      final diasRestantes = dtFin.difference(today).inDays;
      estadoVigencia = diasRestantes == 0
          ? 'Termina hoy'
          : (diasRestantes == 1 ? 'Termina mañana' : 'Termina en 2 días');
      estadoColor = const Color(0xFFD97706);
      estadoBg = const Color(0xFFD97706).withValues(alpha: 0.12);
    } else {
      estadoVigencia = 'En curso';
      estadoColor = const Color(0xFF10B981);
      estadoBg = const Color(0xFF10B981).withValues(alpha: 0.12);
    }

    return Row(
      children: [
        Icon(
          LucideIcons.calendarDays,
          size: 13,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
        const SizedBox(width: 5),
        Text(
          vigenciaTexto,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark ? Colors.white : AppTheme.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: estadoBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            estadoVigencia,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: estadoColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PRO UPGRADE BLOCK SCREEN
  // ---------------------------------------------------------------------------
  Widget _buildBloqueoPro(bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Promociones PRO'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.lock,
                  size: 40,
                  color: AppTheme.brandPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Módulo Exclusivo Plan Minimarket PRO',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aplica descuentos estratégicos por marcas, categorías o combos antiestancamiento para multiplicar las ventas de tu catálogo digital online.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(LucideIcons.sparkles, size: 18),
                label: Text(
                  'Mejorar a Plan PRO (S/ 79 /mes)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  PlanUpgradeModal.show(
                    context,
                    featureName: 'Panel de Promociones y Combos',
                    featureDescription: 'Configura descuentos por categorías, marcas o productos y usa sugerencias de combos para liquidar productos hueso en tu catálogo online.',
                    icon: LucideIcons.tag,
                    onPlanUpdated: () {
                      widget.onPlanUpdated?.call();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _KpiData({
    required this.title,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
}
