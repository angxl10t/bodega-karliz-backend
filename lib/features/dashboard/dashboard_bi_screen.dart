import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/product_image_widget.dart';
import 'dashboard_bi_model.dart';
import 'dashboard_bi_service.dart';

class DashboardBiScreen extends StatefulWidget {
  final DashboardBiService? service;
  const DashboardBiScreen({super.key, this.service});

  @override
  State<DashboardBiScreen> createState() => _DashboardBiScreenState();
}

class _DashboardBiScreenState extends State<DashboardBiScreen> {
  late final DashboardBiService _biService = widget.service ?? DashboardBiService();
  int _diasSeleccionados = 30;
  bool _cargando = true;
  String? _error;
  DashboardBiData? _data;
  int _tabRotacion = 0; // 0 = Estrellas, 1 = Huesos
  int? _horaSeleccionada;
  final TextEditingController _searchController = TextEditingController();
  String _filtroTexto = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final res = await _biService.obtenerDashboardBi(dias: _diasSeleccionados);
      if (mounted) {
        setState(() {
          _data = res;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los datos de analítica.';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _exportarCsv() async {
    if (_data == null) return;
    final exito = await _biService.exportarInformeCsv(_data!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exito
              ? 'Informe BI exportado y descargado exitosamente.'
              : 'Informe BI copiado al portapapeles.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCanvas = isDark ? AppTheme.bgDark : AppTheme.bgLight;

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: bgCanvas,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: canPop
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                tooltip: 'Regresar',
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        titleSpacing: canPop ? 0 : 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analítica de Negocio & BI',
              style: AppTheme.headingStyle(
                size: 18,
                weight: FontWeight.w800,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Rentabilidad real, rotación de productos y horas pico',
              style: AppTheme.bodyStyle(
                size: 11.5,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Informe CSV',
            icon: const Icon(LucideIcons.fileSpreadsheet, color: AppTheme.brandPrimary),
            onPressed: _data != null ? _exportarCsv : null,
          ),
          IconButton(
            tooltip: 'Actualizar Datos',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _cargarDatos,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: AppTheme.brandPrimary,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
            : _error != null
                ? _buildErrorView(isDark)
                : _buildDashboardContent(isDark),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.circleAlert, size: 56, color: AppTheme.alertRed),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error desconocido',
              style: AppTheme.headingStyle(
                size: 15,
                weight: FontWeight.w700,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDatos,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDark) {
    final data = _data!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de Rango Temporal
          _buildPeriodSelector(isDark),
          const SizedBox(height: 16),

          // Tarjetas de Rentabilidad y Métricas Clave (KPIs)
          _buildRentabilidadSection(data, isDark),
          const SizedBox(height: 20),

          // Mapa de Calor de Horarios Pico (24 Horas)
          _buildHorariosPicoSection(data, isDark),
          const SizedBox(height: 20),

          // Reporte de Rotación: Estrellas vs Huesos
          _buildRotacionSection(data, isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final opciones = [
      {'dias': 1, 'label': 'Hoy'},
      {'dias': 7, 'label': '7 Días'},
      {'dias': 30, 'label': '30 Días'},
      {'dias': 90, 'label': '90 Días'},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Row(
        children: opciones.map((op) {
          final int dias = op['dias'] as int;
          final String label = op['label'] as String;
          final bool activo = _diasSeleccionados == dias;

          return Expanded(
            child: InkWell(
              onTap: () {
                if (_diasSeleccionados != dias) {
                  setState(() => _diasSeleccionados = dias);
                  _cargarDatos();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppTheme.brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: activo
                      ? [
                          BoxShadow(
                            color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                    color: activo
                        ? Colors.white
                        : (isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRentabilidadSection(DashboardBiData data, bool isDark) {
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.trendingUp, size: 20, color: AppTheme.brandPrimary),
            const SizedBox(width: 8),
            Text(
              'Métricas de Rentabilidad Real',
              style: AppTheme.headingStyle(
                size: 15,
                weight: FontWeight.w700,
                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid o fila responsiva de KPIs
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;

            final cardMargen = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Margen Bruto de Ganancia',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${data.porcentajeMargenBruto >= 0 ? "+" : ""}${data.porcentajeMargenBruto.toStringAsFixed(1)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'S/ ${data.margenBrutoSoles.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Mini barra de Costo vs Ganancia
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (data.totalCostos > 0 ? (data.totalCostos / (data.totalVentas > 0 ? data.totalVentas : 1) * 100).toInt() : 70).clamp(5, 95),
                            child: Container(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                          ),
                          Expanded(
                            flex: (data.margenBrutoSoles > 0 ? (data.margenBrutoSoles / (data.totalVentas > 0 ? data.totalVentas : 1) * 100).toInt() : 30).clamp(5, 95),
                            child: Container(color: AppTheme.brandPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Venta: S/ ${data.totalVentas.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        'Costo: S/ ${data.totalCostos.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final cardTicket = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ticket Promedio',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                        ),
                      ),
                      const Icon(LucideIcons.receipt, size: 18, color: AppTheme.brandPrimary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'S/ ${data.ticketPromedioPeriodo.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.bgDark : AppTheme.surfaceTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              'S/ ${data.ticketPromedioHoy.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 20, color: borderColor),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Últimos 7 días',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              'S/ ${data.ticketPromedioSemanal.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
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

            final cardHuesoKpi = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Capital Inmovilizado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${data.totalProductosHueso} productos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.alertRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'S/ ${data.totalCapitalInmovilizado.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.alertRed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dinero en góndola sin rotación. Revisa la pestaña "Huesos" para liquidar o armar combos.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: cardMargen),
                  const SizedBox(width: 12),
                  Expanded(child: cardTicket),
                  const SizedBox(width: 12),
                  Expanded(child: cardHuesoKpi),
                ],
              );
            } else {
              return Column(
                children: [
                  cardMargen,
                  const SizedBox(height: 12),
                  cardTicket,
                  const SizedBox(height: 12),
                  cardHuesoKpi,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildHorariosPicoSection(DashboardBiData data, bool isDark) {
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    // Calcular máximo para escala visual
    int maxTickets = 1;
    for (final hp in data.distribucionHoraria) {
      if (hp.cantidadTickets > maxTickets) maxTickets = hp.cantidadTickets;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.flame, size: 20, color: AppTheme.warningAmber),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Mapa de Calor de Horarios Pico',
                        style: AppTheme.headingStyle(
                          size: 15,
                          weight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '24 Horas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Afluencia de clientes por hora del día para optimizar turnos y abastecimiento.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),

          // Gráfico de Barras 24 Horas
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.distribucionHoraria.map((hp) {
                final double ratio = hp.cantidadTickets / maxTickets;
                final double barHeight = (ratio * 95).clamp(4.0, 95.0);
                final bool isSelected = _horaSeleccionada == hp.hora;

                Color barColor;
                if (hp.esPico) {
                  barColor = AppTheme.warningAmber;
                } else if (hp.cantidadTickets > 0) {
                  barColor = AppTheme.brandPrimary;
                } else {
                  barColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
                }

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _horaSeleccionada = isSelected ? null : hp.hora;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.brandPrimary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${hp.cantidadTickets}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : barColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              boxShadow: hp.esPico
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.warningAmber.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, -1),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hp.hora % 3 == 0 ? '${hp.hora}h' : '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Detalle de la hora seleccionada (si el usuario tocó una barra)
          if (_horaSeleccionada != null) ...[
            Builder(
              builder: (context) {
                final selectedHp = data.distribucionHoraria.firstWhere(
                  (h) => h.hora == _horaSeleccionada,
                  orElse: () => data.distribucionHoraria[0],
                );
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 18, color: AppTheme.brandPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${selectedHp.etiquetaHora}: ${selectedHp.cantidadTickets} tickets vendidos • Total: S/ ${selectedHp.totalVentas.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (selectedHp.esPico)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningAmber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'HORA PICO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          // Tarjeta con recomendación y horario pico detectado
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgDark : AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderTint),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.sparkles, size: 20, color: AppTheme.brandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hora Pico Máxima: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            data.horaPicoMaxima,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.warningAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.recomendacionTurnos,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                          height: 1.3,
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

  Widget _buildRotacionSection(DashboardBiData data, bool isDark) {
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.arrowUpDown, size: 20, color: AppTheme.brandPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Reporte de Rotación Táctico',
                        style: AppTheme.headingStyle(
                          size: 15,
                          weight: FontWeight.w700,
                          color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pestañas Segmentadas: Estrellas ⭐ vs Huesos 🦴
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tabRotacion = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tabRotacion == 0 ? AppTheme.brandPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text(
                            'Estrellas (${data.productosEstrella.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _tabRotacion == 0 ? FontWeight.w800 : FontWeight.w600,
                              color: _tabRotacion == 0
                                  ? Colors.white
                                  : (isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tabRotacion = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tabRotacion == 1 ? AppTheme.alertRed : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.archive, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Huesos (${data.productosHueso.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: _tabRotacion == 1 ? FontWeight.w800 : FontWeight.w600,
                              color: _tabRotacion == 1
                                  ? Colors.white
                                  : (isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buscador rápido en la lista
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _filtroTexto = val.trim().toLowerCase()),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
            ),
            decoration: InputDecoration(
              hintText: _tabRotacion == 0
                  ? 'Buscar producto estrella...'
                  : 'Buscar producto hueso...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
              ),
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _filtroTexto.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filtroTexto = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.brandPrimary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
            ),
          ),
          const SizedBox(height: 14),

          // Lista de Productos según la pestaña seleccionada
          if (_tabRotacion == 0)
            _buildListaEstrellas(data, isDark)
          else
            _buildListaHuesos(data, isDark),
        ],
      ),
    );
  }

  Widget _buildListaEstrellas(DashboardBiData data, bool isDark) {
    var estrellas = data.productosEstrella;
    if (_filtroTexto.isNotEmpty) {
      estrellas = estrellas
          .where((e) =>
              e.nombre.toLowerCase().contains(_filtroTexto) ||
              (e.codigo?.toLowerCase().contains(_filtroTexto) ?? false) ||
              e.categoria.toLowerCase().contains(_filtroTexto))
          .toList();
    }

    if (estrellas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.1),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(LucideIcons.sparkles, size: 24, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Aún sin productos estrella en este periodo',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Conforme cobres en el POS, aquí se listarán los productos con mayor margen bruto y frecuencia de venta.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: estrellas.length,
      separatorBuilder: (_, index) => Divider(
        height: 16,
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      ),
      itemBuilder: (context, index) {
        final item = estrellas[index];
        final rank = index + 1;

        return Row(
          children: [
            // Medalla de ranking
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber
                    : rank == 2
                        ? const Color(0xFF94A3B8)
                        : rank == 3
                            ? const Color(0xFFB45309)
                            : (isDark ? AppTheme.borderDark : AppTheme.bgLight),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? Colors.black : (isDark ? Colors.white : AppTheme.textDark),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Foto Packshot
            ProductImageWidget(
              imagenUrl: item.imagenUrl,
              categoria: item.categoria,
              size: 42,
              borderRadius: 10,
              isDark: isDark,
            ),
            const SizedBox(width: 12),

            // Datos del Producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.unidadesVendidas.toStringAsFixed(0)} unidades vendidas • ${item.categoria}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Ganancia Neta y Margen
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ S/ ${item.margenBrutoSoles.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentGreen,
                  ),
                ),
                Text(
                  '${item.porcentajeMargen.toStringAsFixed(1)}% margen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildListaHuesos(DashboardBiData data, bool isDark) {
    var huesos = data.productosHueso;
    if (_filtroTexto.isNotEmpty) {
      huesos = huesos
          .where((h) =>
              h.nombre.toLowerCase().contains(_filtroTexto) ||
              (h.codigo?.toLowerCase().contains(_filtroTexto) ?? false) ||
              h.categoria.toLowerCase().contains(_filtroTexto))
          .toList();
    }

    if (huesos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                  border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.35 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(LucideIcons.shieldCheck, size: 24, color: AppTheme.accentGreen),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¡Rotación Óptima! Cero productos inmovilizados',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No tienes mercadería estancada por más de 30 días. Todo tu capital invertido está circulando con fluidez.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: huesos.length,
      separatorBuilder: (_, index) => Divider(
        height: 16,
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      ),
      itemBuilder: (context, index) {
        final item = huesos[index];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Foto Packshot
                  ProductImageWidget(
                    imagenUrl: item.imagenUrl,
                    categoria: item.categoria,
                    size: 42,
                    borderRadius: 10,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),

                  // Nombre y Stock
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkPrimary : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stock: ${item.stockActual.toStringAsFixed(0)} un. • Costo: S/ ${item.precioCosto.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Capital Congelado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${item.capitalInmovilizado.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.alertRed,
                        ),
                      ),
                      Text(
                        'congelados',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkSecondary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Chip de Recomendación Táctica
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.warningAmber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.lightbulb, size: 12, color: AppTheme.warningAmber),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.accionRecomendada,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warningAmber,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.diasSinVentas}+ días sin ventas',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
