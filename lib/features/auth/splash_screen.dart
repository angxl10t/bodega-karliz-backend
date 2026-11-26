import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/web_loader.dart';

/// Pantalla de bienvenida (Splash Screen) ultra-fluida para CajaYa POS.
///
/// Implementa la **Variante 1: Empuje Cinético Escalonado con Ícono Real y Tiempo Fijo de 1.8s**:
/// - Ícono real oficial en 3D (`assets/images/cajaya_icon.png`).
/// - Aparición centrada del ícono y posterior desplazamiento a la izquierda.
/// - Empuje cinético desenmascarado de la frase 'CajaYa POS' hacia la derecha.
/// - Píldora 'POS' con micro-asentamiento elástico.
/// - Tiempo fijo exacto garantizado de 1.8 segundos, desacoplado de la red.
/// - Desvanecimiento cruzado suave hacia el Punto de Venta o Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _exitController;
  late final AnimationController _shimmerController;

  // Animaciones de entrada coreografiadas
  late final Animation<double> _glowFadeAnim;
  late final Animation<double> _iconScaleAnim;
  late final Animation<double> _iconFadeAnim;
  late final Animation<double> _maskWidthAnim;
  late final Animation<Offset> _textPushAnim;
  late final Animation<double> _textFadeAnim;
  late final Animation<double> _posScaleAnim;

  // Animación de salida (fade out limpio de 250ms sin zoom)
  late final Animation<double> _exitFadeAnim;

  @override
  void initState() {
    super.initState();

    // 1. Controlador de Entrada Coreografiada (1100ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _glowFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    // Entrada del Ícono Real al centro (0ms - 400ms)
    _iconScaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutBack),
      ),
    );

    _iconFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOut),
      ),
    );

    // Apertura de la máscara de desenmascaramiento (400ms - 950ms)
    _maskWidthAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.36, 0.86, curve: Curves.easeInOutCubic),
      ),
    );

    // Empuje cinético del texto hacia la derecha
    _textPushAnim =
        Tween<Offset>(
          begin: const Offset(-0.85, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.36, 0.86, curve: Curves.easeOutCubic),
          ),
        );

    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.36, 0.65, curve: Curves.easeOut),
      ),
    );

    // Micro-asentamiento magnético para la píldora "POS"
    _posScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.10),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.10, end: 1.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.72, 1.0, curve: Curves.easeInOut),
          ),
        );

    // 2. Controlador de Shimmer de Carga (1400ms en bucle)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 3. Controlador de Transición de Salida (250ms - fade out limpio)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    // En Web, index.html garantiza los 1.8s exactos de presencia de marca.
    // Flutter se prepara en paralelo sin demora doble.
    if (kIsWeb) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }

    // Iniciar precalentamiento y navegación paralela con reloj determinista de 1.8s
    AuthService().precalentarServidor();
    _navigateNextDeterministic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/cajaya_icon.png'), context);
  }

  /// Navegación con tiempo fijo exacto de 1.8 segundos (1,800 ms)
  Future<void> _navigateNextDeterministic() async {
    try {
      final authFuture = AuthService().isLoggedIn();

      if (kIsWeb) {
        // En Web, index.html mantiene el lockup de marca por los 1.8s requeridos.
        // Flutter resuelve autenticación, permisos y tema en segundo plano.
        final isLoggedIn = await authFuture;

        if (!mounted) return;

        String destinationRoute = '/login';

        if (isLoggedIn) {
          try {
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

        // Disolver loader HTML y navegar de inmediato a la ruta destino
        dismissWebLoader();
        if (mounted) {
          context.go(destinationRoute);
        }
        return;
      }

      // En Móvil Nativo o Desktop (sin HTML loader): reloj determinista de 1.8s
      // 1,550 ms de presencia de marca + 250 ms de fade-out = 1,800 ms exactos (1.8s)
      final fixedDuration = Future.delayed(const Duration(milliseconds: 1550));
      final results = await Future.wait([fixedDuration, authFuture]);
      final isLoggedIn = results[1] as bool;

      if (!mounted) return;

      String destinationRoute = '/login';

      if (isLoggedIn) {
        try {
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
      if (kIsWeb) {
        dismissWebLoader();
      }
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      dismissWebLoader();
    }
    _entranceController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark ||
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    // En Web, index.html ya ejecuta la animación cinemática 100% GPU en su propio lienzo.
    // Mantener un lienzo limpio en Flutter elimina el doble logo desfasado y el salto de 40px en Safari iOS.
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : Colors.white,
        body: const SizedBox.expand(),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Resplandor Ambiental Estático (Firme, sin vaivén ni latidos)
          Positioned.fill(
            child: Center(
              child: FadeTransition(
                opacity: _glowFadeAnim,
                child: Container(
                  width: 290,
                  height: 290,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? [
                              AppTheme.brandPrimary.withValues(alpha: 0.22),
                              const Color(0xFF06B6D4).withValues(alpha: 0.06),
                              Colors.transparent,
                            ]
                          : [
                              AppTheme.brandPrimary.withValues(alpha: 0.10),
                              const Color(0xFF38BDF8).withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Lockup Central Protagónico: Ícono Real 3D + Empuje de "CajaYa POS"
          Center(
            child: FadeTransition(
              opacity: _exitFadeAnim,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícono Real Oficial del App (54x54) con entrada suave
                  FadeTransition(
                    opacity: _iconFadeAnim,
                    child: ScaleTransition(
                      scale: _iconScaleAnim,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isDark
                                          ? const Color(0xFF38BDF8)
                                          : AppTheme.brandPrimary)
                                      .withValues(alpha: 0.40),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/images/cajaya_icon.png',
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Máscara de Desborde que se abre hacia la derecha
                  AnimatedBuilder(
                    animation: _maskWidthAnim,
                    builder: (context, child) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: _maskWidthAnim.value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: SlideTransition(
                        position: _textPushAnim,
                        child: FadeTransition(
                          opacity: _textFadeAnim,
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
                                        Color(0xFF60A5FA),
                                        Color(0xFF38BDF8),
                                        Color(0xFFBAE6FD),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds);
                                  }
                                  return const LinearGradient(
                                    colors: [
                                      Color(0xFF1D4ED8),
                                      Color(0xFF2563EB),
                                      Color(0xFF06B6D4),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  'CajaYa',
                                  style:
                                      GoogleFonts.outfit(
                                        fontSize: 48,
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

                              // Insignia "POS" con micro-asentamiento
                              ScaleTransition(
                                scale: _posScaleAnim,
                                child: Container(
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Micro-Indicador Shimmer de Conexión
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _exitFadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFF64748B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment(
                            (_shimmerController.value * 2.8) - 1.4,
                            0,
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
        ],
      ),
    );
  }
}
