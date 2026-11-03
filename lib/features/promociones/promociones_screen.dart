import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/widgets/plan_upgrade_modal.dart';
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
  String _filtroEstado = 'TODAS'; // TODAS, ACTIVAS, PAUSADAS

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
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
      final promos = await _service.obtenerPromociones();
      final sugs = await _service.obtenerSugerenciasHuesos();
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
      return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.isPro) {
      return _buildBloqueoPro(isDark);
    }

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
                    color: AppTheme.brandPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              widget.nombreBodega,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _cargarDatos,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brandPrimary,
          unselectedLabelColor: isDark
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF1E293B),
          indicatorColor: AppTheme.brandPrimary,
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
                  const Icon(
                    LucideIcons.sparkles,
                    size: 15,
                    color: AppTheme.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text('Combos Huesos (${_sugerencias.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabPromociones(isDark),
                _buildTabSugerenciasHuesos(isDark),
              ],
            ),
    );
  }

  Widget _buildTabPromociones(bool isDark) {
    var filtradas = _promociones.where((p) {
      if (_filtroEstado == 'ACTIVAS' && !p.activo) return false;
      if (_filtroEstado == 'PAUSADAS' && p.activo) return false;
      if (_filtroTexto.isNotEmpty) {
        final q = _filtroTexto.toLowerCase();
        return p.titulo.toLowerCase().contains(q) ||
            p.descripcion.toLowerCase().contains(q) ||
            (p.categoriaObjetivo?.toLowerCase().contains(q) ?? false) ||
            (p.marcaObjetivo?.toLowerCase().contains(q) ?? false) ||
            (p.nombreProductoPrincipal?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de impacto en catálogo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.globe,
                    color: AppTheme.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visibles en tu Catálogo Online',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tus clientes verán estas promociones destacadas en banners y etiquetas con precios tachados.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
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
          const SizedBox(height: 14),

          // Buscador y filtros de estado
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar promoción...',
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _filtroTexto = v),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filtroEstado,
                    dropdownColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'TODAS',
                        child: Text('Todas', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'ACTIVAS',
                        child: Text('Activas', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'PAUSADAS',
                        child: Text('Pausadas', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filtroEstado = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (filtradas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.tag,
                      size: 48,
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes promociones registradas',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea tu primera promoción para atraer más clientes a tu catálogo online.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Crear Primera Promoción'),
                      onPressed: () => CrearPromocionSheet.show(
                        context,
                        onSaved: _cargarDatos,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtradas.map((promo) => _buildPromoCard(promo, isDark)),
        ],
      ),
    );
  }

  Widget _buildPromoCard(Promocion p, bool isDark) {
    final badgeColor = _parseColor(p.colorBadge);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: p.activo
              ? badgeColor.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: p.activo ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card: Badge + Scope chip + Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.badgeTexto,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                activeTrackColor: const Color(0xFF16A34A)
                    .withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF16A34A),
                onChanged: (val) async {
                  await _service.cambiarEstado(p.idPromocion, val);
                  _cargarDatos();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Título y Descripción
          Text(
            p.titulo,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          if (p.descripcion.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              p.descripcion,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildVigenciaRow(p, isDark),
          const SizedBox(height: 10),

          // Footer info + Actions
          Row(
            children: [
              if (p.valorDescuento > 0 ||
                  p.tipoPromocion == 'DOS_POR_UNO' ||
                  p.tipoPromocion == 'TRES_POR_DOS')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.tipoPromocion == 'TRES_POR_DOS'
                        ? '🎁 3x2 (LLEVA 3 PAGA 2)'
                        : p.tipoPromocion == 'DOS_POR_UNO'
                        ? '🎁 2x1 (LLEVA 2 PAGA 1)'
                        : p.tipoPromocion == 'PORCENTAJE'
                        ? '-${p.valorDescuento.toStringAsFixed(0)}% OFF'
                        : '-S/ ${p.valorDescuento.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 16),
                onPressed: () {
                  CrearPromocionSheet.show(
                    context,
                    promocionEdit: p,
                    onSaved: _cargarDatos,
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Eliminar Promoción?'),
                      content: Text(
                        'Esta promoción dejará de aplicarse en tu catálogo digital.',
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
        ],
      ),
    );
  }

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
    Color estadoColor = const Color(0xFF16A34A);
    Color estadoBg = const Color(0xFF16A34A).withValues(alpha: 0.12);

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
      estadoColor = const Color(0xFFDC2626);
      estadoBg = const Color(0xFFDC2626).withValues(alpha: 0.12);
    } else if (dtFin != null && dtFin.difference(today).inDays <= 2) {
      final diasRestantes = dtFin.difference(today).inDays;
      estadoVigencia = diasRestantes == 0
          ? 'Termina hoy'
          : (diasRestantes == 1 ? 'Termina mañana' : 'Termina en 2 días');
      estadoColor = const Color(0xFFD97706);
      estadoBg = const Color(0xFFD97706).withValues(alpha: 0.12);
    } else {
      estadoVigencia = 'En curso';
      estadoColor = const Color(0xFF16A34A);
      estadoBg = const Color(0xFF16A34A).withValues(alpha: 0.12);
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

  Widget _buildTabSugerenciasHuesos(bool isDark) {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Inteligente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2436), const Color(0xFF0F172A)]
                    : [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF262E44)
                    : const Color(0xFF2563EB).withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descongelamiento Táctico de Mercadería',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CajaYa analiza tus productos hueso (capital inmovilizado) y propone combinarlos con tus productos estrella para acelerar ventas y recuperar liquidez sin pérdidas.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_sugerencias.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle2,
                      size: 48,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¡Excelente Rotación!',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No tienes productos estancados por más de 30 días. Tu inventario está circulando de forma saludable.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
            ..._sugerencias.map((sug) => _buildSugerenciaCard(sug, isDark)),
        ],
      ),
    );
  }

  Widget _buildSugerenciaCard(SugerenciaComboHueso sug, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2436) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262E44) : const Color(0xFFE2E8F0),
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
          // Header: Badge combo + Capital Inmovilizado Alert
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sug.badgeSugerido,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626)
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'S/ ${sug.capitalInmovilizado.toStringAsFixed(2)} inmovilizados',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título del Combo
          Text(
            sug.tituloSugerido,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Razón Estratégica
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D31) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFFBFDBFE),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.lightbulb,
                  size: 16,
                  color: AppTheme.brandPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sug.razonEstrategica,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E3A8A),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comparación Visual: Hueso + Estrella
          Row(
            children: [
              // Hueso
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141724)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRODUCTO HUESO',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sug.nombreHueso,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Stock: ${sug.stockHueso.toInt()} un. • Costo: S/ ${sug.costoHueso.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: AppTheme.brandPrimary,
                ),
              ),
              // Estrella
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141724)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALTA ROTACIÓN',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sug.nombreEstrella,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Precio Reg.: S/ ${sug.precioRegularEstrella.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Precio regular vs Precio Combo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Regular: S/ ${sug.precioRegularTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'S/ ${sug.precioComboSugerido.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(LucideIcons.sparkles, size: 15),
                label: Text(
                  'Crear Promo en 1 Clic',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
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
                  'Mejorar a Plan PRO (S/ 100 /mes)',
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
