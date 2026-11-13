import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Controlador y animador del efecto de transición de tema con el Isotipo oficial de CajaYa
/// (Fluid C-Velocity Swoosh Theme Wave).
///
/// Simula una onda líquida que dibuja el trazo estilizado en forma de "C" blanca de CajaYa,
/// expandiéndose con giro espiral dinámico y aros concéntricos cristalinos desde el botón,
/// de forma 100% transparente y sin nublar ni tapar el contenido de la pantalla.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso para evitar dobles clics accidentales.
  static bool get isAnimating => _isAnimating;

  /// Dispara la transición con el isotipo de CajaYa desde [origin] expandiéndose por toda la pantalla.
  ///
  /// La pantalla permanece 100% visible, transparente y nítida en todo momento.
  /// El cambio de tema se efectúa al instante y el isotipo recorre la pantalla.
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customRippleColor,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    if (_isAnimating) return;

    final overlayState = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.of(context).size;

    // Calcular el radio máximo necesario para cubrir la esquina más lejana desde el origen
    final double maxRadius = _calcularRadioMaximo(origin, screenSize);

    // Color del resplandor de la onda según el modo de destino
    final Color rippleColor = customRippleColor ??
        (targetIsDark
            ? const Color(0xFF38BDF8) // Aqua zafiro luminoso para onda hacia oscuro
            : const Color(0xFF2563EB)); // Cobalto oficial CajaYa para onda hacia claro

    _isAnimating = true;

    // Disparamos el cambio de tema de inmediato para que la UI responda instantáneamente
    await onToggleTheme();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CajaYaSwooshOverlayWidget(
        origin: origin,
        maxRadius: maxRadius,
        rippleColor: rippleColor,
        targetIsDark: targetIsDark,
        duration: duration,
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
        30.0;
  }
}

/// Widget interno insertado en el Overlay que gestiona la animación de la onda del isotipo CajaYa.
class _CajaYaSwooshOverlayWidget extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color rippleColor;
  final bool targetIsDark;
  final Duration duration;
  final VoidCallback onCompleted;

  const _CajaYaSwooshOverlayWidget({
    required this.origin,
    required this.maxRadius,
    required this.rippleColor,
    required this.targetIsDark,
    required this.duration,
    required this.onCompleted,
  });

  @override
  State<_CajaYaSwooshOverlayWidget> createState() =>
      _CajaYaSwooshOverlayWidgetState();
}

class _CajaYaSwooshOverlayWidgetState extends State<_CajaYaSwooshOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Curva expansiva ágil y orgánica: nace rápido como una gota y se propaga naturalmente
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Desvanecimiento suave en el tramo final
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

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
            painter: _CajaYaSwooshThemePainter(
              center: widget.origin,
              progress: progress,
              maxRadius: widget.maxRadius,
              rippleColor: widget.rippleColor,
              targetIsDark: widget.targetIsDark,
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

/// Pintor que dibuja el trazo estilizado del Isotipo CajaYa (Fluid C-Velocity Swoosh)
/// expandiéndose en espiral líquida transparente sin nublar la pantalla.
class _CajaYaSwooshThemePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color rippleColor;
  final bool targetIsDark;
  final double opacity;

  _CajaYaSwooshThemePainter({
    required this.center,
    required this.progress,
    required this.maxRadius,
    required this.rippleColor,
    required this.targetIsDark,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || opacity <= 0.0) return;

    final currentRadius = maxRadius * progress;
    final waveFade = (1.0 - (progress * 0.45)).clamp(0.0, 1.0) * opacity;
    if (waveFade <= 0.01) return;

    // 1. Aro exterior de acompañamiento acuoso (fino y cristalino)
    final ringPaint = Paint()
      ..color = rippleColor.withValues(alpha: (0.35 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 2.0 * (1.0 - (progress * 0.45)));
    canvas.drawCircle(center, currentRadius, ringPaint);

    // 2. Trazo y silueta de la "C" fluida de CajaYa (Swoosh Icon)
    const baseSize = 80.0;
    // Escala del isotipo: nace cerca del botón y se expande cubriendo la pantalla
    final iconScale = 0.25 + (progress * (maxRadius / (baseSize * 0.42)));
    final rotationAngle = progress * 0.42 * (targetIsDark ? 1.0 : -1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.scale(iconScale);
    canvas.translate(-baseSize * 0.52, -baseSize * 0.56);

    final swooshPath = _crearCajaYaPath(baseSize);

    // Capa A: Relleno traslúcido cristalino del icono de CajaYa (ultra tenue, 100% visible el fondo)
    final fillAlpha = (0.06 * (1.0 - (progress * 0.65))).clamp(0.0, 1.0) * opacity;
    if (fillAlpha > 0.005) {
      final fillPaint = Paint()
        ..color = (targetIsDark ? const Color(0xFF38BDF8) : Colors.white)
            .withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(swooshPath, fillPaint);
    }

    // Capa B: Halo cobalto / aqua exterior del isotipo CajaYa
    final haloStroke = math.max(0.8, 3.2 * (1.0 - (progress * 0.45)));
    final haloPaint = Paint()
      ..color = rippleColor.withValues(alpha: (0.55 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = haloStroke;
    canvas.drawPath(swooshPath, haloPaint);

    // Capa C: Silueta blanca nítida del icono CajaYa (exacta al icono blanco oficial)
    final whiteStroke = math.max(0.6, 1.6 * (1.0 - (progress * 0.45)));
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.75 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = whiteStroke;
    canvas.drawPath(swooshPath, whitePaint);

    canvas.restore();

    // 3. Eco secundario del icono de CajaYa (estela que sigue al swoosh principal)
    if (progress > 0.14) {
      final secProgress = ((progress - 0.14) / 0.86).clamp(0.0, 1.0);
      final secScale = iconScale * 0.84;
      final secRotation = rotationAngle - (0.12 * (targetIsDark ? 1.0 : -1.0));
      final secFade = (1.0 - secProgress).clamp(0.0, 1.0) * waveFade * 0.45;

      if (secFade > 0.01) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(secRotation);
        canvas.scale(secScale);
        canvas.translate(-baseSize * 0.52, -baseSize * 0.56);

        final secPaint = Paint()
          ..color = rippleColor.withValues(alpha: secFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
        canvas.drawPath(swooshPath, secPaint);

        canvas.restore();
      }
    }
  }

  /// Isotipo Oficial Definitivo CajaYa: "Fluid C-Velocity Swoosh"
  static Path _crearCajaYaPath(double size) {
    final w = size;
    final h = size;
    return Path()
      ..moveTo(w * 0.64, h * 0.35)
      ..cubicTo(w * 0.52, h * 0.21, w * 0.36, h * 0.21, w * 0.26, h * 0.34)
      ..cubicTo(w * 0.15, h * 0.48, w * 0.15, h * 0.69, w * 0.27, h * 0.82)
      ..cubicTo(w * 0.38, h * 0.92, w * 0.54, h * 0.89, w * 0.66, h * 0.76)
      ..cubicTo(w * 0.74, h * 0.66, w * 0.84, h * 0.48, w * 0.90, h * 0.30)
      ..cubicTo(w * 0.79, h * 0.46, w * 0.68, h * 0.63, w * 0.57, h * 0.71)
      ..cubicTo(w * 0.47, h * 0.79, w * 0.36, h * 0.76, w * 0.31, h * 0.65)
      ..cubicTo(w * 0.26, h * 0.54, w * 0.30, h * 0.41, w * 0.42, h * 0.35)
      ..cubicTo(w * 0.49, h * 0.31, w * 0.57, h * 0.32, w * 0.64, h * 0.35)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _CajaYaSwooshThemePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.center != center ||
        oldDelegate.targetIsDark != targetIsDark;
  }
}

/// Botón estilizado reutilizable que dispara la animación del isotipo CajaYa automáticamente.
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
              duration: const Duration(milliseconds: 250),
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
