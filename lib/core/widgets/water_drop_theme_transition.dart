import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Transición de tema de alto rendimiento y diseño ergonómico para CajaYa Cloud POS.
///
/// Sustituye los barridos circulares invasivos por una micro-interacción táctil
/// en el propio botón (Icon Morphing & Spring Bounce) y un cambio de tema
/// instantáneo, limpio y profesional (Silk Fade), sin bloquear la interfaz ni
/// distraer al usuario durante sus operaciones de venta.
class WaterDropThemeTransition {
  static bool _isAnimating = false;

  /// Retorna si hay una animación en curso.
  static bool get isAnimating => _isAnimating;

  /// Ejecuta la transición de tema fluida y de baja latencia.
  static Future<void> animate(
    BuildContext context, {
    required Offset origin,
    required bool targetIsDark,
    required Future<void> Function() onToggleTheme,
    Color? customRippleColor,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    HapticFeedback.lightImpact();

    // 1. Aplicamos el cambio de tema de inmediato para máxima reactividad
    await onToggleTheme();

    if (!context.mounted) return;

    // 2. Velo de seda sutil (Silk Fade) ultra-rápido y no bloqueante
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    _isAnimating = true;
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SilkFadeOverlay(
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
}

/// Overlay sedoso y ligero que suaviza el destello de contraste al cambiar de tema,
/// sin dibujar formas invasivas ni bloquear los clics del usuario.
class _SilkFadeOverlay extends StatefulWidget {
  final bool targetIsDark;
  final Duration duration;
  final VoidCallback onCompleted;

  const _SilkFadeOverlay({
    required this.targetIsDark,
    required this.duration,
    required this.onCompleted,
  });

  @override
  State<_SilkFadeOverlay> createState() => _SilkFadeOverlayState();
}

class _SilkFadeOverlayState extends State<_SilkFadeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(
      begin: 0.12,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

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
        animation: _fadeAnimation,
        builder: (context, _) {
          if (_fadeAnimation.value <= 0.0) return const SizedBox.shrink();
          return Container(
            color: (widget.targetIsDark ? Colors.black : Colors.white)
                .withValues(alpha: _fadeAnimation.value),
          );
        },
      ),
    );
  }
}

/// Botón estilizado de tema con micro-interacción cinemática (Sun/Moon Morph & Elastic Bounce).
class WaterDropThemeButton extends StatefulWidget {
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

  @override
  State<WaterDropThemeButton> createState() => _WaterDropThemeButtonState();
}

class _WaterDropThemeButtonState extends State<WaterDropThemeButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.88,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounceController.forward(from: 0.0);
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox != null
        ? renderBox.localToGlobal(renderBox.size.center(Offset.zero))
        : MediaQuery.of(context).size.center(Offset.zero);

    WaterDropThemeTransition.animate(
      context,
      origin: origin,
      targetIsDark: !widget.isDark,
      onToggleTheme: widget.onToggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final String effectiveTooltip =
        widget.tooltip ??
        (isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro');

    // Colores según el modo
    final Color defaultBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFFFFFFF);
    final Color defaultBorder = isDark
        ? (_isHovered ? const Color(0xFF475569) : const Color(0xFF334155))
        : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0));

    // Resplandor sutil (glow)
    final List<BoxShadow> shadows = [
      if (_isHovered)
        BoxShadow(
          color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFF2563EB))
              .withValues(alpha: isDark ? 0.20 : 0.15),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        )
      else
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
    ];

    return Tooltip(
      message: effectiveTooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value * (_isHovered ? 1.04 : 1.0),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              splashColor: (isDark ? Colors.amber : AppTheme.brandPrimary)
                  .withValues(alpha: 0.12),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? defaultBg,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: widget.borderColor ?? defaultBorder,
                    width: 1.0,
                  ),
                  boxShadow: shadows,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) {
                    return RotationTransition(
                      turns: Tween<double>(begin: 0.5, end: 1.0).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                    );
                  },
                  child: Icon(
                    isDark ? LucideIcons.sun : LucideIcons.moon,
                    key: ValueKey<bool>(isDark),
                    size: widget.iconSize,
                    color:
                        widget.iconColor ??
                        (isDark
                            ? const Color(0xFFFBBF24) // Ámbar dorado cálido
                            : const Color(0xFF2563EB)), // Cobalto Fintech
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
