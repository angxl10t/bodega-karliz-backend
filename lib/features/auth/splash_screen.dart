import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import '../../core/theme.dart';

/// Pantalla de bienvenida (Splash Screen) profesional inspirada en el minimalismo
/// de alta gama de Rappi: fondo prístino, tipografía de marca protagónica con gradiente
/// vibrante y micro-animación fluida sin distractores ni barras de carga toscas.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Entrada suave de opacidad
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    // Entrada con rebote sutil y natural
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Respiración orgánica suave en bucle
    _pulseAnim = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _animController.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Breve tiempo de apreciación de marca (1.6s) para una experiencia rápida y fluida
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final isLoggedIn = await AuthService().isLoggedIn();
    if (mounted) {
      if (isLoggedIn) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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
          // 1. Resplandor Ambiental únicamente en modo oscuro
          if (isDark)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.5 - 130,
              left: MediaQuery.of(context).size.width * 0.5 - 130,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.brandPrimary.withValues(alpha: 0.22),
                      const Color(0xFF06B6D4).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

          // 2. Logotipo Central Protagónico (Estilo Rappi Minimalista)
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animController.value >= 0.7 ? _pulseAnim.value : 1.0,
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
                          style: GoogleFonts.outfit(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Insignia "POS" Elegante
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF38BDF8), Color(0xFF2563EB)]
                                : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF38BDF8) : AppTheme.brandPrimary)
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'POS',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: isDark ? const Color(0xFF0B0F19) : Colors.white,
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
    );
  }
}
