import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Controlador y animador del efecto "Gota de Agua Líquida" (Circular Water Ripple Reveal).
///
/// Simula una gota que cae en el botón de cambio de tema y genera una onda expansiva
/// concéntrica con tensión superficial y eco líquido que cubre toda la pantalla del
/// navegador o dispositivo, alternando el modo oscuro/claro de forma fluida y orgánica.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso para evitar dobles clics accidentales.
  static bool get isAnimating => _isAnimating;

  /// Dispara el efecto de la gota de agua desde [origin] cubriendo toda la pantalla.
  ///
  /// [context]: BuildContext con acceso al [Overlay].
  /// [origin]: Coordenadas globales (Offset) del centro del botón o punto de impacto.
  /// [targetIsDark]: Si el tema de destino será Modo Oscuro (`true`) o Modo Claro (`false`).
  /// [onToggleTheme]: Callback que ejecuta el cambio real de estado (ej: `themeProvider.toggleTheme()`).
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customTargetColor,
    Duration duration = const Duration(milliseconds: 650),
  }) async {
    if (_isAnimating) return;

    final overlayState = Overlay.of(context, rootOverlay: true);

    final screenSize = MediaQuery.of(context).size;

    // Calcular el radio máximo necesario para cubrir la esquina más lejana desde el origen
    final double maxRadius = _calcularRadioMaximo(origin, screenSize);

    // Colores basados en el tema de destino
    final Color targetBg = customTargetColor ??
        (targetIsDark ? AppTheme.bgDark : AppTheme.bgLight);
    final Color rippleColor = targetIsDark
        ? const Color(0xFF38BDF8) // Aqua zafiro luminoso para onda hacia oscuro
        : const Color(0xFF60A5FA); // Brillo perla cobalto para onda hacia claro

    _isAnimating = true;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _WaterDropOverlayWidget(
        origin: origin,
        maxRadius: maxRadius,
        targetColor: targetBg,
        rippleColor: rippleColor,
        duration: duration,
        onToggleReady: () async {
          await onToggleTheme();
        },
        onCompleted: () {
          try {
            entry.remove();
          } catch (_) {}
          _isAnimating = false;
        },
      ),
    );

    overlayState.insert(entry);
  }

  /// Calcula la distancia Euclidiana a la esquina más lejana más un margen de seguridad.
  static double _calcularRadioMaximo(Offset origin, Size size) {
    final dTopLeft = math.sqrt(
      math.pow(origin.dx, 2) + math.pow(origin.dy, 2),
    );
    final dTopRight = math.sqrt(
      math.pow(size.width - origin.dx, 2) + math.pow(origin.dy, 2),
    );
    final dBottomLeft = math.sqrt(
      math.pow(origin.dx, 2) + math.pow(size.height - origin.dy, 2),
    );
    final dBottomRight = math.sqrt(
      math.pow(size.width - origin.dx, 2) +
          math.pow(size.height - origin.dy, 2),
    );

    return math.max(
          math.max(dTopLeft, dTopRight),
          math.max(dBottomLeft, dBottomRight),
        ) +
        40.0;
  }
}

/// Widget interno insertado en el Overlay que gestiona el Ticker y la pintura.
class _WaterDropOverlayWidget extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color targetColor;
  final Color rippleColor;
  final Duration duration;
  final Future<void> Function() onToggleReady;
  final VoidCallback onCompleted;

  const _WaterDropOverlayWidget({
    required this.origin,
    required this.maxRadius,
    required this.targetColor,
    required this.rippleColor,
    required this.duration,
    required this.onToggleReady,
    required this.onCompleted,
  });

  @override
  State<_WaterDropOverlayWidget> createState() =>
      _WaterDropOverlayWidgetState();
}

class _WaterDropOverlayWidgetState extends State<_WaterDropOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  bool _toggled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Curva expansiva fluida (acelera y se propaga naturalmente como onda en el agua)
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.88, curve: Curves.easeInOutCubic),
    );

    // Fade out suave al final para desvanecer el overlay
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
    );

    _controller.addListener(() {
      // Disparamos el toggle de tema cuando la gota ya cubrió la mayor parte de la pantalla
      if (!_toggled && _controller.value >= 0.80) {
        _toggled = true;
        widget.onToggleReady();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _expandAnimation.value;
          final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);

          return CustomPaint(
            size: Size.infinite,
            painter: _WaterDropPainter(
              center: widget.origin,
              progress: progress,
              maxRadius: widget.maxRadius,
              baseColor: widget.targetColor,
              rippleColor: widget.rippleColor,
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

/// Pintor CustomPainter que dibuja el frente de la gota, su masa líquida y las ondas de choque.
class _WaterDropPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color baseColor;
  final Color rippleColor;
  final double opacity;

  _WaterDropPainter({
    required this.center,
    required this.progress,
    required this.maxRadius,
    required this.baseColor,
    required this.rippleColor,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || opacity <= 0.0) return;

    final currentRadius = maxRadius * progress;

    // 1. Cuerpo principal de la gota (Masa líquida expansiva con el nuevo tema)
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius, fillPaint);

    // 2. Tensión superficial y onda de choque en el borde de la gota (Ripple Wave)
    final rippleFade = (1.0 - (progress * 0.65)).clamp(0.0, 1.0) * opacity;
    if (rippleFade > 0.02) {
      // Halo exterior brillante tipo agua difuminada
      final haloPaint = Paint()
        ..color = rippleColor.withValues(alpha: (0.45 * rippleFade).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 + (1.0 - progress) * 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawCircle(center, currentRadius, haloPaint);

      // Cresta nítida de la gota (reflejo de luz acuosa)
      final crestPaint = Paint()
        ..color = Colors.white.withValues(alpha: (0.50 * rippleFade).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;

      canvas.drawCircle(center, currentRadius, crestPaint);

      // 3. Onda secundaria concéntrica (Eco líquido característico de gotas de agua)
      if (progress > 0.12) {
        final secProgress = ((progress - 0.12) / 0.88).clamp(0.0, 1.0);
        final secRadius = currentRadius * 0.86;
        final secFade = (1.0 - secProgress).clamp(0.0, 1.0) * rippleFade * 0.6;

        if (secFade > 0.02) {
          final secondaryPaint = Paint()
            ..color = rippleColor.withValues(alpha: secFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0;

          canvas.drawCircle(center, secRadius, secondaryPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaterDropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.center != center;
  }
}

/// Botón estilizado reutilizable que dispara la animación de gota de agua automáticamente.
class WaterDropThemeButton extends StatelessWidget {
  final bool isDark;
  final Future<void> Function() onToggle;
  final String? tooltip;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VisualDensity visualDensity;

  const WaterDropThemeButton({
    super.key,
    required this.isDark,
    required this.onToggle,
    this.tooltip,
    this.iconSize = 18.0,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(8.0),
    this.borderRadius = 12.0,
    this.visualDensity = VisualDensity.standard,
  });

  void _handleTap(BuildContext context) {
    HapticFeedback.selectionClick();

    // Obtener la posición global exacta del botón
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox != null
        ? renderBox.localToGlobal(renderBox.size.center(Offset.zero))
        : MediaQuery.of(context).size.center(Offset.zero);

    WaterDropThemeTransition.animate(
      context,
      origin: origin,
      targetIsDark: !isDark,
      onToggleTheme: onToggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTooltip = tooltip ??
        (isDark
            ? 'Cambiar a Modo Claro Pro'
            : 'Cambiar a Modo Oscuro Titanium');

    return Tooltip(
      message: effectiveTooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ??
                  (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ??
                    (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                width: 1.0,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? LucideIcons.sun : LucideIcons.moon,
                key: ValueKey<bool>(isDark),
                size: iconSize,
                color: iconColor ??
                    (isDark
                        ? const Color(0xFFFBBF24) // Ámbar dorado para el Sol
                        : const Color(0xFF6366F1)), // Índigo crepuscular para la Luna
              ),
            ),
          ),
        ),
      ),
    );
  }
}
