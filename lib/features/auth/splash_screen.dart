import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';

/// Pantalla de bienvenida (Splash Screen) ultra-fluida para CajaYa POS.
///
/// Diseñada bajo los lineamientos oficiales de `cajaya-brand-ui-ux` y `ui-ux-design-system`:
/// - Entrada suave y orgánica a 60/120 FPS (700ms).
/// - Respiración viva continua en bucle infinito (`easeInOutSine`) que evita la sensación
///   de pantalla congelada mientras las llamadas de red se resuelven en segundo plano.
/// - Resplandor ambiental dinámico con micro-shimmer de progreso elegante.
/// - Carga asíncrona paralela y transición de salida coordinada con fundido suave.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _exitController;
  late final AnimationController _shimmerController;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _glowPulseAnim;
  late final Animation<double> _exitFadeAnim;
  late final Animation<double> _exitScaleAnim;

  @override
  void initState() {
    super.initState();

    // 1. Controlador de Entrada Inicial (700ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnim = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0), // Resorte suave natural
      ),
    );

    // 2. Controlador de Respiración Orgánica Continua (Bucle Infinito a 2200ms)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseAnim = Tween<double>(begin: 0.988, end: 1.022).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _glowPulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 3. Controlador de Shimmer de Carga (1500ms en bucle)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 4. Controlador de Transición de Salida (320ms)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _exitScaleAnim = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );

    // Iniciar entrada o enganchar de inmediato si es Web para evitar doble escala
    if (kIsWeb) {
      _entranceController.value = 1.0;
      _pulseController.repeat(reverse: true);
    } else {
      _entranceController.forward().then((_) {
        if (mounted) {
          _pulseController.repeat(reverse: true);
        }
      });
    }

    // Iniciar precalentamiento y navegación paralela
    AuthService().precalentarServidor();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    try {
      // Tiempo mínimo de apreciación de marca para evitar parpadeos (1000ms)
      final minDuration = Future.delayed(const Duration(milliseconds: 1000));
      final authFuture = AuthService().isLoggedIn();

      // Ejecutar en paralelo la espera mínima y la comprobación de sesión
      final results = await Future.wait([minDuration, authFuture]);
      final isLoggedIn = results[1] as bool;

      if (!mounted) return;

      String destinationRoute = '/login';

      if (isLoggedIn) {
        try {
          // Obtener permisos, tema y rol en paralelo
          final permisosFuture = PermisosCajeroService.obtenerPermisos();
          final colorFuture = AuthService().getColorPrimario();
          final roleFuture = AuthService().getUserRole();

          final details = await Future.wait([
            permisosFuture,
            colorFuture,
            roleFuture,
          ]);
          final colorHex = details[1] as String;
          final role = details[2] as String;

          if (colorHex.isNotEmpty && mounted) {
            context.read<ThemeProvider>().setAccentColorFromHex(colorHex);
          }

          if (role.toUpperCase() == 'SUPERADMIN') {
            destinationRoute = '/superadmin';
          } else {
            destinationRoute = '/home';
          }
        } catch (_) {
          destinationRoute = '/home';
        }
      }

      if (!mounted) return;

      // Disolver suavemente la pantalla antes de la transición de ruta
      await _exitController.forward();
      if (mounted) {
        context.go(destinationRoute);
      }
    } catch (_) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Resplandor Ambiental con Respiración Orgánica Continua
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowScale = _entranceController.isCompleted
                      ? _glowPulseAnim.value
                      : _fadeAnim.value;
                  return Transform.scale(
                    scale: glowScale,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isDark
                              ? [
                                  AppTheme.brandPrimary.withValues(alpha: 0.22),
                                  const Color(0xFF06B6D4)
                                      .withValues(alpha: 0.08),
                                  Colors.transparent,
                                ]
                              : [
                                  AppTheme.brandPrimary.withValues(alpha: 0.10),
                                  const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.04),
                                  Colors.transparent,
                                ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Logotipo Central Protagónico (Con respiración y transición de salida)
          Center(
            child: FadeTransition(
              opacity: _exitFadeAnim,
              child: ScaleTransition(
                scale: _exitScaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final currentScale = _entranceController.isCompleted
                            ? _pulseAnim.value
                            : 1.0;
                        return Transform.scale(
                          scale: currentScale,
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Palabra "CajaYa" con Gradiente Exclusivo
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              if (isDark) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFF60A5FA), // Light Sky Blue
                                    Color(0xFF38BDF8), // Electric Cyan
                                    Color(0xFFBAE6FD), // Diamond Highlight
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              }
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF1D4ED8), // Deep Cobalt
                                  Color(0xFF2563EB), // Electric Cobalt
                                  Color(0xFF06B6D4), // Cyan Glow
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            child: Text(
                              'CajaYa',
                              style:
                                  GoogleFonts.outfit(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    color: Colors.white,
                                  ).copyWith(
                                    fontFamily: 'Outfit',
                                    fontFamilyFallback: const [
                                      'Outfit',
                                      'sans-serif',
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Insignia "POS" Elegante
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? const [
                                        Color(0xFF38BDF8),
                                        Color(0xFF2563EB),
                                      ]
                                    : const [
                                        Color(0xFF2563EB),
                                        Color(0xFF1D4ED8),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isDark
                                              ? const Color(0xFF38BDF8)
                                              : AppTheme.brandPrimary)
                                          .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'POS',
                              style:
                                  GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: isDark
                                        ? AppTheme.bgDark
                                        : Colors.white,
                                  ).copyWith(
                                    fontFamily: 'Outfit',
                                    fontFamilyFallback: const [
                                      'Outfit',
                                      'sans-serif',
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Micro-Indicador Shimmer de Conexión (Retroalimentación activa sin freeze)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: FadeTransition(
                opacity: _exitFadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pista de Shimmer
                    Container(
                      width: 110,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) {
                          return FractionallySizedBox(
                            alignment: Alignment(
                              -1.5 + (_shimmerController.value * 3.0),
                              0.0,
                            ),
                            widthFactor: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    isDark
                                        ? const Color(0xFF38BDF8)
                                        : AppTheme.brandPrimary,
                                    isDark
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF06B6D4),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Iniciando terminal...',
                      style:
                          GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textDarkSecondary
                                : const Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ).copyWith(
                            fontFamily: 'PlusJakartaSans',
                            fontFamilyFallback: const [
                              'PlusJakartaSans',
                              'sans-serif',
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
