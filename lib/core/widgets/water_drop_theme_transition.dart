import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Transición oficial de tema de CajaYa basada en la formación de la "C":
///
/// El bañado de color se arma desde la parte derecha de la "C" y gira hacia la izquierda,
/// acompañando la formación en tiempo real del trazo del isotipo de CajaYa con una
/// cabeza luminosa y un barrido angular translúcido que tiñe la pantalla con el nuevo
/// tema SIN tapar ni ocultar los elementos de la interfaz.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso para evitar dobles clics accidentales.
  static bool get isAnimating => _isAnimating;

  /// Dispara la transición de tema en abanico girando desde la derecha hacia la izquierda.
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customRippleColor,
    Duration duration = const Duration(milliseconds: 520),
  }) async {
    if (_isAnimating) return;

    final overlayState = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.of(context).size;

    // Calcular el radio máximo necesario para cubrir la esquina más lejana desde el origen
    final double maxRadius = _calcularRadioMaximo(origin, screenSize);

    // Colores del bañado según el modo de destino
    final Color themeColor = targetIsDark
        ? const Color(0xFF1E3A8A) // Azul zafiro cobalto nocturno
        : const Color(0xFF93C5FD); // Azul cielo perla luminoso

    final Color accentColor = customRippleColor ??
        (targetIsDark
            ? const Color(0xFF38BDF8) // Aqua zafiro luminoso
            : const Color(0xFF2563EB)); // Cobalto oficial CajaYa

    _isAnimating = true;

    // Disparamos el cambio de tema de inmediato para que la UI responda instantáneamente
    await onToggleTheme();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CajaYaSweepThemeOverlay(
        origin: origin,
        maxRadius: maxRadius,
        themeColor: themeColor,
        accentColor: accentColor,
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
        50.0;
  }
}

/// Overlay que ejecuta la animación del barrido angular de derecha a izquierda formando la "C".
class _CajaYaSweepThemeOverlay extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color themeColor;
  final Color accentColor;
  final bool targetIsDark;
  final Duration duration;
  final VoidCallback onCompleted;

  const _CajaYaSweepThemeOverlay({
    required this.origin,
    required this.maxRadius,
    required this.themeColor,
    required this.accentColor,
    required this.targetIsDark,
    required this.duration,
    required this.onCompleted,
  });

  @override
  State<_CajaYaSweepThemeOverlay> createState() =>
      _CajaYaSweepThemeOverlayState();
}

class _CajaYaSweepThemeOverlayState extends State<_CajaYaSweepThemeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sweepAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // El barrido y la formación de la C avanzan suavemente de derecha a izquierda
    _sweepAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.88, curve: Curves.easeInOutCubic),
    );

    // Desvanecimiento suave en el tramo final
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
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
          final progress = _sweepAnimation.value;
          final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);

          return CustomPaint(
            size: Size.infinite,
            painter: _CajaYaSweepThemePainter(
              center: widget.origin,
              progress: progress,
              maxRadius: widget.maxRadius,
              themeColor: widget.themeColor,
              accentColor: widget.accentColor,
              targetIsDark: widget.targetIsDark,
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

/// Pintor que genera el bañado de color naciendo desde la derecha de la "C"
/// y girando hacia la izquierda mientras dibuja la "C" de CajaYa con una cabeza de luz.
class _CajaYaSweepThemePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color themeColor;
  final Color accentColor;
  final bool targetIsDark;
  final double opacity;

  _CajaYaSweepThemePainter({
    required this.center,
    required this.progress,
    required this.maxRadius,
    required this.themeColor,
    required this.accentColor,
    required this.targetIsDark,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || opacity <= 0.0) return;

    // 1. Parámetros del barrido angular (Sweep Reveal)
    // Inicia en la parte derecha de la "C" (~ -1.0 radianes / ~-57 grados)
    const double startAngle = -1.02;
    // Gira hacia la izquierda en sentido antihorario (negativo) completando la vuelta
    final double sweepAngle = -2.0 * math.pi * progress;

    // El radio se expande desde el botón cubriendo toda la pantalla
    final double currentRadius = math.min(
      maxRadius,
      maxRadius * (0.28 + 0.72 * progress),
    );

    // 2. Bañado de color translúcido en abanico (Sweep Sector)
    // El sector cubre exactamente la zona recorrida de derecha a izquierda
    final sweepSectorPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: currentRadius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    // Relleno suave translúcido (12% a 15% de opacidad, 100% visible el fondo)
    final fillAlpha = (0.13 * (1.0 - (progress * 0.35))).clamp(0.0, 1.0) * opacity;
    if (fillAlpha > 0.005) {
      final sweepFillPaint = Paint()
        ..color = themeColor.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(sweepSectorPath, sweepFillPaint);
    }

    // Arco perimetral del barrido con resplandor
    final arcBorderPaint = Paint()
      ..color = accentColor.withValues(
        alpha: (0.45 * (1.0 - progress * 0.35)).clamp(0.0, 1.0) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 3.0 * (1.0 - progress * 0.4));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: currentRadius),
      startAngle,
      sweepAngle,
      false,
      arcBorderPaint,
    );

    // Filamento de avance en la cabeza de giro (línea radial que barre hacia la izquierda)
    final headAngle = startAngle + sweepAngle;
    final headX = center.dx + currentRadius * math.cos(headAngle);
    final headY = center.dy + currentRadius * math.sin(headAngle);
    final headEdgePaint = Paint()
      ..color = Colors.white.withValues(
        alpha: (0.50 * (1.0 - progress * 0.3)).clamp(0.0, 1.0) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 2.0 * (1.0 - progress * 0.4));
    canvas.drawLine(center, Offset(headX, headY), headEdgePaint);

    // 3. Formación en tiempo real del Isotipo Oficial "C-Check" de CajaYa
    // El trazo se forma desde la derecha de la "C" y gira hacia la izquierda
    final double iconSize = 78.0 + (progress * 32.0);
    final double cSize = iconSize * 0.62;

    // Badge squircle oficial de CajaYa en el centro
    final badgeOpacity =
        (0.85 * (1.0 - progress * 0.35)).clamp(0.0, 1.0) * opacity;
    if (badgeOpacity > 0.01) {
      final iconRect = Rect.fromCenter(
        center: center,
        width: iconSize,
        height: iconSize,
      );
      final squircleRRect = RRect.fromRectAndRadius(
        iconRect,
        Radius.circular(iconSize * 0.28),
      );

      // Sombra suave del badge
      canvas.drawRRect(
        squircleRRect.shift(const Offset(0, 3)),
        Paint()
          ..color =
              const Color(0xFF1E3A8A).withValues(alpha: 0.22 * badgeOpacity)
          ..style = PaintingStyle.fill,
      );

      // Gradiente azul cobalto / zafiro característico de CajaYa
      final badgePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(iconRect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(squircleRRect, badgePaint);

      // Borde cristalino sutil
      canvas.drawRRect(
        squircleRRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25 * badgeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Dibujado del isotipo "C" revelándose desde la derecha hacia la izquierda
    final cPath = _crearCajaYaPath(cSize);
    final cCenterline = _crearCajaYaCenterline(cSize);

    canvas.save();
    // Centramos la C con respecto al badge en el botón
    canvas.translate(
      center.dx - (cSize * 0.52),
      center.dy - (cSize * 0.56),
    );

    // Sector angular de desocultamiento de la C (sincronizado con el giro a la izquierda)
    final clampedSweep = sweepAngle.clamp(-1.999 * math.pi, -0.01);
    final cClipSector = Path()
      ..moveTo(cSize * 0.52, cSize * 0.56)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(cSize * 0.52, cSize * 0.56),
          radius: cSize * 1.5,
        ),
        startAngle,
        clampedSweep,
        false,
      )
      ..close();

    // Dibujamos el cuerpo sólido de la cinta blanca 3D de CajaYa
    canvas.save();
    if (progress < 0.98) {
      canvas.clipPath(cClipSector);
    }

    // Cuerpo blanco nítido del icono oficial
    final cFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.95 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawPath(cPath, cFillPaint);

    // Sombreado 3D satinado de la cinta
    final cStrokePaint = Paint()
      ..color = const Color(0xFF93C5FD)
          .withValues(alpha: (0.45 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(cPath, cStrokePaint);
    canvas.restore();

    // Línea guía y cabeza de luz que lidera la formación desde la derecha hacia la izquierda
    final clMetrics = cCenterline.computeMetrics().toList();
    if (clMetrics.isNotEmpty) {
      final clMetric = clMetrics.first;
      final currentLength = clMetric.length * progress.clamp(0.0, 1.0);
      final partialCenterline = clMetric.extractPath(0.0, currentLength);

      // Halo luminoso del trazo
      final strokePaint = Paint()
        ..color = Colors.white
            .withValues(alpha: (0.85 * (1.0 - progress * 0.2)).clamp(0.0, 1.0) * opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.5, 3.2 * (1.0 - progress * 0.3));
      canvas.drawPath(partialCenterline, strokePaint);

      // Cabeza luminosa / Chispa guiadora en el frente de avance
      final tangent = clMetric.getTangentForOffset(currentLength);
      if (tangent != null && progress < 0.98) {
        final headPos = tangent.position;

        // Aura cobalto
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: (0.80 * opacity).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(headPos, 6.0, glowPaint);

        // Chispa blanca brillante
        final sparklePaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(headPos, 3.0, sparklePaint);
      }
    }

    canvas.restore();
  }

  /// Trazo Oficial Definitivo: "Fluid C-Velocity Swoosh" de CajaYa
  /// Comienza en la derecha: (0.64, 0.35) y gira hacia la izquierda formando la C
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

  /// Línea media guía para el trazado de la C desde la parte derecha hacia la izquierda
  static Path _crearCajaYaCenterline(double size) {
    final w = size;
    final h = size;
    return Path()
      ..moveTo(w * 0.62, h * 0.34)
      ..cubicTo(w * 0.50, h * 0.23, w * 0.34, h * 0.23, w * 0.24, h * 0.38)
      ..cubicTo(w * 0.16, h * 0.50, w * 0.16, h * 0.68, w * 0.26, h * 0.80)
      ..cubicTo(w * 0.36, h * 0.90, w * 0.55, h * 0.88, w * 0.66, h * 0.75)
      ..cubicTo(w * 0.74, h * 0.65, w * 0.83, h * 0.48, w * 0.89, h * 0.31);
  }

  @override
  bool shouldRepaint(covariant _CajaYaSweepThemePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.center != center ||
        oldDelegate.targetIsDark != targetIsDark;
  }
}

/// Botón estilizado reutilizable que dispara la animación del barrido angular de la "C" de CajaYa.
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
