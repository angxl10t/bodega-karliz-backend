import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import '../../core/cajaya_vectors.dart';
import '../../core/permisos_cajero_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';

/// Pantalla de bienvenida (Splash Screen) ultra-fluida para CajaYa POS.
///
/// Implementa la Opción 2 (Isotipo C-Check + Revelado de Texto Fijo):
/// - Isotipo oficial CajaYa (`CajaYaLogoMark`) con entrada de giro y escala sutil.
/// - Revelado tipográfico de 'CajaYa POS' con deslizamiento y opacidad sincronizada.
/// - CERO latidos ni rebotes continuos (escala 1.0x firme e inmutable).
/// - Resplandor ambiental estático y elegante que no compite en escala.
/// - Sincronización perfecta con el cargador Web (sin doble escala).
/// - Micro-indicador de progreso inferior fluido ('Iniciando terminal...').
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
  late final Animation<double> _iconRotationAnim;
  late final Animation<double> _iconFadeAnim;
  late final Animation<double> _textFadeAnim;
  late final Animation<Offset> _textSlideAnim;

  // Animación de salida (solo fade out limpio sin zoom de salida)
  late final Animation<double> _exitFadeAnim;

  @override
  void initState() {
    super.initState();

    // 1. Controlador de Entrada Coreografiada (600ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _glowFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );

    // Entrada del Isotipo (escala sutil 0.72 a 1.0 y rotación -0.08 a 0)
    _iconScaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _iconRotationAnim = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _iconFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    // Revelado del Texto "CajaYa POS" (deslizamiento suave y fade sincronizado)
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.28, 0.85, curve: Curves.easeOut),
      ),
    );

    _textSlideAnim =
        Tween<Offset>(
          begin: const Offset(-0.06, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.28, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    // 2. Controlador de Shimmer de Carga (1500ms en bucle)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 3. Controlador de Transición de Salida (280ms - fade out limpio)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    // En Web, si el HTML ya reprodujo la entrada, fijar directamente en 1.0 para continuidad perfecta
    if (kIsWeb) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
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
          // 1. Resplandor Ambiental Estático (Firme, sin vaivén ni latidos)
          Positioned.fill(
            child: Center(
              child: FadeTransition(
                opacity: _glowFadeAnim,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? [
                              AppTheme.brandPrimary.withValues(alpha: 0.20),
                              const Color(0xFF06B6D4).withValues(alpha: 0.07),
                              Colors.transparent,
                            ]
                          : [
                              AppTheme.brandPrimary.withValues(alpha: 0.09),
                              const Color(0xFF38BDF8).withValues(alpha: 0.03),
                              Colors.transparent,
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Logotipo Central Protagónico: Isotipo C-Check + Texto Fijo (Opción 2)
          Center(
            child: FadeTransition(
              opacity: _exitFadeAnim,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Isotipo Vectorial con escala y giro de entrada
                  FadeTransition(
                    opacity: _iconFadeAnim,
                    child: ScaleTransition(
                      scale: _iconScaleAnim,
                      child: RotationTransition(
                        turns: _iconRotationAnim,
                        child: const CajaYaLogoMark(size: 46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Texto "CajaYa" y píldora "POS" revelados con deslizamiento suave
                  FadeTransition(
                    opacity: _textFadeAnim,
                    child: SlideTransition(
                      position: _textSlideAnim,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                ],
              ),
            ),
          ),

          // 3. Micro-Indicador Shimmer de Conexión (Retroalimentación activa)
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
