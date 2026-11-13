import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Transición de tema oficial basada en el Icono Real de CajaYa.
///
/// Al presionar el botón de modo claro/oscuro, emerge el icono real tridimensional
/// de CajaYa desde el origen, proyectando un bañado de color translúcido con la silueta
/// de su squircle y su "C-Check" líquida, cubriendo la pantalla de forma cristalina
/// SIN tapar ni ocultar los elementos de la interfaz.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso para evitar dobles clics accidentales.
  static bool get isAnimating => _isAnimating;

  /// Dispara la transición con el icono real de CajaYa desde [origin] expandiéndose por toda la pantalla.
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customRippleColor,
    Duration duration = const Duration(milliseconds: 460),
  }) async {
    if (_isAnimating) return;

    final overlayState = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.of(context).size;

    // Precargar el icono real si no está en memoria
    try {
      precacheImage(const AssetImage('assets/images/cajaya_icon.png'), context);
    } catch (_) {}

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
      builder: (ctx) => _CajaYaRealIconThemeOverlay(
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

/// Overlay que combina el icono real de CajaYa con el bañado de ondas translúcidas.
class _CajaYaRealIconThemeOverlay extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color rippleColor;
  final bool targetIsDark;
  final Duration duration;
  final VoidCallback onCompleted;

  const _CajaYaRealIconThemeOverlay({
    required this.origin,
    required this.maxRadius,
    required this.rippleColor,
    required this.targetIsDark,
    required this.duration,
    required this.onCompleted,
  });

  @override
  State<_CajaYaRealIconThemeOverlay> createState() =>
      _CajaYaRealIconThemeOverlayState();
}

class _CajaYaRealIconThemeOverlayState
    extends State<_CajaYaRealIconThemeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconPopAnim;
  late Animation<double> _iconFadeAnim;
  late Animation<double> _waveExpandAnim;
  late Animation<double> _waveFadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 1. Aparición elástica del icono real de CajaYa (pop inicial)
    _iconPopAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
    );

    // 2. Desvanecimiento suave del icono central
    _iconFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );

    // 3. Expansión fluida del bañado de color hacia toda la pantalla
    _waveExpandAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.95, curve: Curves.easeOutCubic),
    );

    // 4. Desvanecimiento de las ondas en las esquinas
    _waveFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
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
    const double baseIconSize = 54.0;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final waveProgress = _waveExpandAnim.value;
          final waveOpacity = (1.0 - _waveFadeAnim.value).clamp(0.0, 1.0);

          final iconScale = _iconPopAnim.value;
          final iconOpacity = (1.0 - _iconFadeAnim.value).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Bañado de color translúcido con patrón de Squircle y C de CajaYa
              CustomPaint(
                size: Size.infinite,
                painter: _CajaYaRealIconPatternPainter(
                  center: widget.origin,
                  progress: waveProgress,
                  maxRadius: widget.maxRadius,
                  rippleColor: widget.rippleColor,
                  targetIsDark: widget.targetIsDark,
                  opacity: waveOpacity,
                ),
              ),

              // 2. Icono Real 3D de CajaYa que emerge elásticamente en el origen
              if (iconOpacity > 0.01 && iconScale > 0.01)
                Positioned(
                  left: widget.origin.dx - (baseIconSize / 2),
                  top: widget.origin.dy - (baseIconSize / 2),
                  width: baseIconSize,
                  height: baseIconSize,
                  child: Transform.scale(
                    scale: iconScale,
                    child: Opacity(
                      opacity: iconOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            baseIconSize * 0.28,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.rippleColor.withValues(
                                alpha: (0.45 * iconOpacity).clamp(0.0, 1.0),
                              ),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            baseIconSize * 0.28,
                          ),
                          child: Image.asset(
                            'assets/images/cajaya_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pintor que proyecta el bañado de color siguiendo el patrón squircle y "C-Check" de CajaYa.
class _CajaYaRealIconPatternPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color rippleColor;
  final bool targetIsDark;
  final double opacity;

  _CajaYaRealIconPatternPainter({
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

    // 1. Bañado en Squircle redondeado oficial de CajaYa (creciendo hacia los bordes)
    final squircleSize = currentRadius * 2.1;
    final squircleCorner = squircleSize * 0.28;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: squircleSize,
        height: squircleSize,
      ),
      Radius.circular(squircleCorner),
    );

    // Halo vítreo muy tenue del Squircle de CajaYa (ultra translúcido, 100% visible el contenido)
    final fillAlpha = (0.07 * (1.0 - (progress * 0.70))).clamp(0.0, 1.0) * opacity;
    if (fillAlpha > 0.005) {
      final fillPaint = Paint()
        ..color = (targetIsDark
                ? const Color(0xFF1E3A8A) // Azul zafiro translúcido
                : const Color(0xFF60A5FA)) // Azul cielo translúcido
            .withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);
    }

    // Borde de onda del Squircle de CajaYa
    final squircleBorderPaint = Paint()
      ..color = rippleColor.withValues(alpha: (0.45 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 2.5 * (1.0 - (progress * 0.4)));
    canvas.drawRRect(rrect, squircleBorderPaint);

    // 2. Trazo proyectado de la "C-Check" oficial de CajaYa
    const baseIconRef = 100.0;
    final iconScale = 0.25 + (progress * (maxRadius / (baseIconRef * 0.45)));
    final rotationAngle = progress * 0.38 * (targetIsDark ? 1.0 : -1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.scale(iconScale);
    canvas.translate(-baseIconRef * 0.52, -baseIconRef * 0.56);

    final swooshPath = _crearCajaYaPath(baseIconRef);

    // Filamento blanco nítido de la "C" de CajaYa
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.80 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, 1.8 * (1.0 - (progress * 0.45)));
    canvas.drawPath(swooshPath, whitePaint);

    // Halo azul cobalto exterior del trazo
    final haloPaint = Paint()
      ..color = rippleColor.withValues(alpha: (0.50 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 3.2 * (1.0 - (progress * 0.45)));
    canvas.drawPath(swooshPath, haloPaint);

    canvas.restore();

    // 3. Aro exterior concéntrico de agua cristalina
    final outerRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.35 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.8 * (1.0 - (progress * 0.5)));
    canvas.drawCircle(center, currentRadius, outerRingPaint);
  }

  /// Geometría exacta del Isotipo "Fluid C-Velocity Swoosh" oficial de CajaYa
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
  bool shouldRepaint(covariant _CajaYaRealIconPatternPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.center != center ||
        oldDelegate.targetIsDark != targetIsDark;
  }
}

/// Botón estilizado reutilizable que dispara la animación del icono real de CajaYa automáticamente.
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
