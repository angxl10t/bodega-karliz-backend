import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Controlador y animador del efecto "Gota de Agua Líquida" (Water Ripple Shockwave).
///
/// Simula la onda expansiva transparente generada por una gota al tocar la superficie:
/// aros concéntricos cristalinos de agua nítidos y 100% transparentes con tensión
/// superficial y refracción, SIN ningún tipo de relleno, difuminado ni nublado que
/// tape o nuble la visibilidad de la pantalla.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso para evitar dobles clics accidentales.
  static bool get isAnimating => _isAnimating;

  /// Dispara la onda líquida desde [origin] expandiéndose por toda la pantalla.
  ///
  /// La pantalla permanece 100% visible, transparente y nítida en todo momento.
  /// El cambio de tema se efectúa al instante y los aros recorren la pantalla.
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customRippleColor,
    Duration duration = const Duration(milliseconds: 380),
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
            : const Color(0xFF2563EB)); // Cobalto cristalino para onda hacia claro

    _isAnimating = true;

    // Disparamos el cambio de tema de inmediato para que la UI responda instantáneamente
    await onToggleTheme();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _WaterDropOverlayWidget(
        origin: origin,
        maxRadius: maxRadius,
        rippleColor: rippleColor,
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
        20.0;
  }
}

/// Widget interno insertado en el Overlay que gestiona la animación de la onda de agua.
class _WaterDropOverlayWidget extends StatefulWidget {
  final Offset origin;
  final double maxRadius;
  final Color rippleColor;
  final Duration duration;
  final VoidCallback onCompleted;

  const _WaterDropOverlayWidget({
    required this.origin,
    required this.maxRadius,
    required this.rippleColor,
    required this.duration,
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _expandAnimation.value;
          final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);

          return CustomPaint(
            size: Size.infinite,
            painter: _WaterDropRipplePainter(
              center: widget.origin,
              progress: progress,
              maxRadius: widget.maxRadius,
              rippleColor: widget.rippleColor,
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

/// Pintor 100% cristalino y translúcido de onda líquida (Clean Ripple Rings).
///
/// Dibuja aros de onda de agua transparentes SIN relleno ni blur, garantizando
/// que todo el contenido de la pantalla permanezca perfectamente visible y nítido.
class _WaterDropRipplePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color rippleColor;
  final double opacity;

  _WaterDropRipplePainter({
    required this.center,
    required this.progress,
    required this.maxRadius,
    required this.rippleColor,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || opacity <= 0.0) return;

    final currentRadius = maxRadius * progress;

    // Desvanecimiento de la onda a medida que se propaga hacia los bordes
    final waveFade = (1.0 - (progress * 0.50)).clamp(0.0, 1.0) * opacity;
    if (waveFade <= 0.01) return;

    // 1. Anillo primario de la onda de agua (aro fino cristalino, 100% transparente)
    final mainRingPaint = Paint()
      ..color = rippleColor.withValues(alpha: (0.50 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 2.2 * (1.0 - (progress * 0.4)));

    canvas.drawCircle(center, currentRadius, mainRingPaint);

    // 2. Filamento de refracción luminosa (brillo blanco nítido, sin blur)
    final lightRefractionPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.45 * waveFade).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(
      center,
      math.max(0.0, currentRadius - 1.5),
      lightRefractionPaint,
    );

    // 3. Onda secundaria concéntrica (eco líquido característico de gotas de agua)
    if (progress > 0.12) {
      final secProgress = ((progress - 0.12) / 0.88).clamp(0.0, 1.0);
      final secRadius = currentRadius * 0.84;
      final secFade = (1.0 - secProgress).clamp(0.0, 1.0) * waveFade * 0.40;

      if (secFade > 0.01) {
        final secPaint = Paint()
          ..color = rippleColor.withValues(alpha: secFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 1.6 * (1.0 - (secProgress * 0.4)));

        canvas.drawCircle(center, secRadius, secPaint);
      }
    }

    // 4. Tercer micro-anillo concéntrico (eco sutil de gota)
    if (progress > 0.28) {
      final thirdProgress = ((progress - 0.28) / 0.72).clamp(0.0, 1.0);
      final thirdRadius = currentRadius * 0.68;
      final thirdFade = (1.0 - thirdProgress).clamp(0.0, 1.0) * waveFade * 0.25;

      if (thirdFade > 0.01) {
        final thirdPaint = Paint()
          ..color = rippleColor.withValues(alpha: thirdFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        canvas.drawCircle(center, thirdRadius, thirdPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaterDropRipplePainter oldDelegate) {
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
