import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../../features/auth/auth_service.dart';

class _ConsejoItem {
  final String categoria;
  final String titulo;
  final String descripcion;
  final IconData icon;
  final Color color;
  final String etiqueta;

  const _ConsejoItem({
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    required this.icon,
    required this.color,
    required this.etiqueta,
  });
}

/// Modal Ejecutivo & Operativo: "Briefing del Turno"
/// Provee orientación de valor tanto a Administradores como a Cajeros
/// sin sobrecargar ni saturar permanentemente las vistas de trabajo.
class BriefingTurnoModal extends StatefulWidget {
  final String? username;
  final String? userRol;
  final String? nombreBodega;
  final Function(int tabIndex)? onNavigateTab;

  const BriefingTurnoModal({
    super.key,
    this.username,
    this.userRol,
    this.nombreBodega,
    this.onNavigateTab,
  });

  /// Abre el briefing automáticamente al iniciar sesión o turno
  static Future<void> showIfNeeded(
    BuildContext context, {
    String? username,
    String? userRol,
    String? nombreBodega,
    Function(int tabIndex)? onNavigateTab,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uname = (username != null && username.isNotEmpty)
        ? username
        : await AuthService().getUsername();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final keySilenciado = 'briefing_turno_silenciado_v2_${uname}_$todayStr';

    // Si el usuario marcó no mostrarlo más hoy, se respeta su preferencia
    final yaSilenciado = prefs.getBool(keySilenciado) ?? false;
    if (yaSilenciado) return;

    if (!context.mounted) return;

    await show(
      context,
      username: username,
      userRol: userRol,
      nombreBodega: nombreBodega,
      onNavigateTab: onNavigateTab,
    );
  }

  /// Abre el modal bajo demanda en cualquier momento (ej. desde el botón de consejos)
  static Future<void> show(
    BuildContext context, {
    String? username,
    String? userRol,
    String? nombreBodega,
    Function(int tabIndex)? onNavigateTab,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BriefingTurnoModal(
        username: username,
        userRol: userRol,
        nombreBodega: nombreBodega,
        onNavigateTab: onNavigateTab,
      ),
    );
  }

  @override
  State<BriefingTurnoModal> createState() => _BriefingTurnoModalState();
}

class _BriefingTurnoModalState extends State<BriefingTurnoModal> {
  late String _username;
  late String _userRol;
  late String _nombreBodega;
  bool _isLoading = true;
  int _currentTipIndex = 0;
  bool _noMostrarHoy = false;
  late final PageController _pageController;

  static const List<_ConsejoItem> _consejosCajero = [
    _ConsejoItem(
      categoria: 'SEGURIDAD DE COBRO',
      titulo: 'Verificación de Yape y Plin',
      descripcion:
          'Confirma siempre la notificación en el celular o el nombre del titular y monto antes de entregar productos. No te fíes sólo de capturas de pantalla de clientes desconocidos.',
      icon: LucideIcons.shieldCheck,
      color: Color(0xFF8B5CF6),
      etiqueta: 'Evita estafas de capturas falsas',
    ),
    _ConsejoItem(
      categoria: 'GESTIÓN DE CAMBIO',
      titulo: 'Sencillo para la Hora Punta',
      descripcion:
          'Asegúrate de contar con monedas de S/ 1, S/ 2 y S/ 5 al iniciar tu turno. Tener sencillo a mano agiliza el cobro y evita formar colas en momentos de alta afluencia.',
      icon: LucideIcons.coins,
      color: AppTheme.accentGreen,
      etiqueta: 'Atención rápida y sin demoras',
    ),
    _ConsejoItem(
      categoria: 'ARQUEO DE CAJA',
      titulo: 'Registra Todo Gasto al Momento',
      descripcion:
          'Si tomas dinero de caja para bolsas, pasajes o compras menores de la tienda, regístralo de inmediato en la pestaña "Caja". Así tu cuadre nocturno será 100% exacto.',
      icon: LucideIcons.receipt,
      color: AppTheme.warningAmber,
      etiqueta: 'Cero descuadres al cierre',
    ),
    _ConsejoItem(
      categoria: 'VELOCIDAD POS',
      titulo: 'Búsqueda Rápida y Escaneo',
      descripcion:
          'Escribe las primeras 2 letras del producto o usa el lector de código de barras. Pregunta al cliente si desea Ticket o Boleta con DNI antes de confirmar el cobro.',
      icon: LucideIcons.zap,
      color: AppTheme.brandPrimary,
      etiqueta: 'Venta completada en segundos',
    ),
  ];

  static const List<_ConsejoItem> _consejosAdmin = [
    _ConsejoItem(
      categoria: 'LOGÍSTICA & ALMACÉN',
      titulo: 'Prevención de Quiebres de Stock',
      descripcion:
          'Los productos con stock crítico (≤ 5 unidades) aparecen señalados en tu panel. Programa órdenes de compra a distribuidores antes de la tarde para no perder ventas.',
      icon: LucideIcons.alertTriangle,
      color: AppTheme.alertRed,
      etiqueta: 'Reabastecimiento estratégico',
    ),
    _ConsejoItem(
      categoria: 'FINANZAS & TESORERÍA',
      titulo: 'Reparto de Efectivo vs Billeteras',
      descripcion:
          'Monitorea el desglose de ventas por Efectivo, Yape, Plin y Tarjeta en vivo. Esto te permite programar transferencias o depósitos bancarios de tus fondos digitales.',
      icon: LucideIcons.pieChart,
      color: AppTheme.brandPrimary,
      etiqueta: 'Control total de tesorería',
    ),
    _ConsejoItem(
      categoria: 'RENTABILIDAD REAL',
      titulo: 'Precios de Compra Actualizados',
      descripcion:
          'Al ingresar mercadería en "Compras", verifica el costo de compra unitario. De esa forma, el margen de ganancia neta calculado por CajaYa será siempre exacto.',
      icon: LucideIcons.trendingUp,
      color: AppTheme.accentGreen,
      etiqueta: 'Protección de tus márgenes',
    ),
    _ConsejoItem(
      categoria: 'CONTROL DE PÉRDIDAS',
      titulo: 'Registro de Mermas y Vencimientos',
      descripcion:
          'Registra productos rotos, vencidos o en mal estado en el Kardex como "Salida por Merma". Así tu inventario valorizado reflejará únicamente mercadería vendible.',
      icon: LucideIcons.clipboardCheck,
      color: AppTheme.infoIndigo,
      etiqueta: 'Inventario real y saneado',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _username = widget.username ?? '';
    _userRol = widget.userRol ?? '';
    _nombreBodega = widget.nombreBodega ?? '';

    if (_username.isEmpty || _userRol.isEmpty || _nombreBodega.isEmpty) {
      _cargarCredenciales();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarCredenciales() async {
    final auth = AuthService();
    final results = await Future.wait([
      auth.getUsername(),
      auth.getUserRole(),
      auth.getNombreBodega(),
    ]);
    if (mounted) {
      setState(() {
        _username = results[0];
        _userRol = results[1];
        _nombreBodega = results[2];
        _isLoading = false;
      });
    }
  }

  String _formatFechaActual() {
    final now = DateTime.now();
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final diaSemana = dias[now.weekday - 1];
    final mes = meses[now.month - 1];
    return '$diaSemana, ${now.day} de $mes';
  }

  Future<void> _guardarPreferenciaNoMostrar() async {
    if (_username.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final keySilenciado = 'briefing_turno_silenciado_v2_${_username}_$todayStr';
      if (_noMostrarHoy) {
        await prefs.setBool(keySilenciado, true);
      } else {
        await prefs.remove(keySilenciado);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cardDarkElevated : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final bool isAdmin = _userRol.toUpperCase() == 'ADMIN' || _userRol.toUpperCase() == 'SUPERADMIN';
    final List<_ConsejoItem> tips = isAdmin ? _consejosAdmin : _consejosCajero;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: isDark ? const Border(top: BorderSide(color: AppTheme.borderDarkElevated, width: 1.2)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.brandPrimary),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Manija superior de arrastre
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encabezado Principal: Identidad, Rol y Turno en Vivo
                    _buildHeader(isDark, isAdmin),
                    const SizedBox(height: 16),

                    // Barra Informativa de Estado de Turno & Gaveta
                    _buildShiftStatusBar(isDark),
                    const SizedBox(height: 18),

                    // Título de la Sección de Consejos + Indicador
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Consejos Clave de Operación',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.textDark,
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
                          '${_currentTipIndex + 1} de ${tips.length}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Carrusel Interactivo de Consejos
                    SizedBox(
                      height: 175,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: tips.length,
                        onPageChanged: (index) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentTipIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return _buildTipCard(tips[index], isDark, borderColor);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Indicadores de Puntos y Botones Prev/Next
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Paginador de bolitas
                        Row(
                          children: List.generate(tips.length, (index) {
                            final bool isActive = index == _currentTipIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 6),
                              width: isActive ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.brandPrimary
                                    : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            );
                          }),
                        ),

                        // Flechas de Navegación Rápida
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'Consejo anterior',
                              icon: Icon(
                                LucideIcons.chevronLeft,
                                color: _currentTipIndex > 0
                                    ? (isDark ? Colors.white : AppTheme.textDark)
                                    : (isDark ? Colors.white24 : Colors.black26),
                              ),
                              onPressed: _currentTipIndex > 0
                                  ? () {
                                      _pageController.previousPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  : null,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              tooltip: 'Siguiente consejo',
                              icon: Icon(
                                LucideIcons.chevronRight,
                                color: _currentTipIndex < tips.length - 1
                                    ? (isDark ? Colors.white : AppTheme.textDark)
                                    : (isDark ? Colors.white24 : Colors.black26),
                              ),
                              onPressed: _currentTipIndex < tips.length - 1
                                  ? () {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botones de Acción Inmediata según Rol
                    _buildActionButtons(isAdmin, isDark),
                    const SizedBox(height: 12),

                    // Checkbox para No Mostrar más en este turno
                    InkWell(
                      onTap: () {
                        setState(() => _noMostrarHoy = !_noMostrarHoy);
                        _guardarPreferenciaNoMostrar();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _noMostrarHoy ? LucideIcons.checkSquare : LucideIcons.square,
                              size: 16,
                              color: _noMostrarHoy
                                  ? AppTheme.brandPrimary
                                  : (isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Entendido • No mostrar automáticamente en este turno',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF475569),
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
  }

  Widget _buildHeader(bool isDark, bool isAdmin) {
    final String initial = _username.isNotEmpty ? _username[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppTheme.brandInk, const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar Inicial con Gradiente
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandPrimary, Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Datos de Bienvenida & Rol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '¡Hola, $_username! 👋',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isAdmin ? LucideIcons.shieldCheck : LucideIcons.zap,
                      size: 13,
                      color: isAdmin ? const Color(0xFF38BDF8) : AppTheme.accentGreen,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isAdmin
                            ? 'Administrador • $_nombreBodega'
                            : 'Operador de Turno POS • $_nombreBodega',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF93C5FD),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
            ),
            tooltip: 'Cerrar Briefing',
            icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStatusBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDarkElevated : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_formatFechaActual()} • Turno Activo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'En Línea',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(_ConsejoItem tip, bool isDark, Color borderColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2230) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? tip.color.withValues(alpha: 0.35) : tip.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tip.color.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tip.icon, size: 17, color: tip.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.categoria,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: tip.color,
                      ),
                    ),
                    Text(
                      tip.titulo,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              tip.descripcion,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.checkCircle2, size: 12, color: tip.color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  tip.etiqueta,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tip.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isAdmin, bool isDark) {
    if (!isAdmin) {
      // CAJERO: Prioridad absoluta en abrir el terminal POS o revisar el cuadre
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.shoppingBag, size: 18),
              label: Text(
                'Comenzar Turno en POS',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              onPressed: () async {
                await _guardarPreferenciaNoMostrar();
                if (mounted) Navigator.pop(context);
                widget.onNavigateTab?.call(1); // Tab POS
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppTheme.textDark,
                side: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(LucideIcons.banknote, size: 16),
              label: Text(
                'Verificar Sencillo & Caja',
                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                await _guardarPreferenciaNoMostrar();
                if (mounted) Navigator.pop(context);
                widget.onNavigateTab?.call(2); // Tab Caja
              },
            ),
          ),
        ],
      );
    } else {
      // ADMINISTRADOR: Continuar al Panel de Control de Métricas o ir al POS
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.layoutGrid, size: 17),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Ir al Panel',
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
                onPressed: () async {
                  await _guardarPreferenciaNoMostrar();
                  if (mounted) Navigator.pop(context);
                  widget.onNavigateTab?.call(0); // Tab Dashboard
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppTheme.textDark,
                  side: BorderSide(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(LucideIcons.shoppingBag, size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Abrir POS',
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
                onPressed: () async {
                  await _guardarPreferenciaNoMostrar();
                  if (mounted) Navigator.pop(context);
                  widget.onNavigateTab?.call(1); // Tab POS
                },
              ),
            ),
          ),
        ],
      );
    }
  }
}
