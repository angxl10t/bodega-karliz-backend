import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'registro_bodega_sheet.dart';
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/cajaya_vectors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// Bandera activada por ApiClient cuando el servidor retorna 401 (token expirado)
  static bool sessionExpiredFlag = false;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isColdStarting = false;
  Timer? _coldStartTimer;
  bool _obscurePassword = true;
  bool _keepMeSignedIn = true;
  String _errorMessage = '';
  bool _sessionExpiredNotice = false;

  @override
  void initState() {
    super.initState();
    if (LoginScreen.sessionExpiredFlag) {
      _sessionExpiredNotice = true;
      LoginScreen.sessionExpiredFlag = false;
    }
    // Pre-calienta el servidor en segundo plano si estaba suspendido en la nube
    _authService.precalentarServidor();
    // Limpia cualquier residuo de sesión anterior al abrir el login
    SecureStorageService.clearAuth();
  }

  @override
  void dispose() {
    _coldStartTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Por favor ingresa usuario y contraseña');
      return;
    }

    setState(() {
      _isLoading = true;
      _isColdStarting = false;
      _errorMessage = '';
    });

    _coldStartTimer?.cancel();
    _coldStartTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isLoading) {
        setState(() => _isColdStarting = true);
      }
    });

    final result = await _authService.login(user, pass);
    _coldStartTimer?.cancel();

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        final colorHex = await _authService.getColorPrimario();
        if (mounted && colorHex.isNotEmpty) {
          context.read<ThemeProvider>().setAccentColorFromHex(colorHex);
        }
        final role = await _authService.getUserRole();
        if (mounted) {
          if (role.toUpperCase() == 'SUPERADMIN') {
            context.go('/superadmin');
          } else {
            context.go('/home');
          }
        }
      } else {
        setState(() => _errorMessage = result.errorMessage ?? 'Usuario o contraseña incorrectos');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 850;

                if (isDesktop) {
                  return Row(
                    children: [
                      // ============================================
                      // PANEL IZQUIERDO: SHOWCASE DE MARCA Y VALOR B2B
                      // ============================================
                      Expanded(
                        flex: 5,
                        child: Container(
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDark : const Color(0xFFF1F5F9),
                            border: Border(
                              right: BorderSide(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                          // Glow ambiental sutil en esquina superior izquierda
                          Positioned(
                            top: -100,
                            left: -100,
                            child: Container(
                              width: 360,
                              height: 360,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppTheme.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 480),
                                child: _buildBrandShowcase(context, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ============================================
                  // PANEL DERECHO: FORMULARIO DE ACCESO Y ACCIONES
                  // ============================================
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLoginForm(context, isDark, isDesktop: true),
                              const SizedBox(height: 18),
                              _buildCloudConnectionBadge(context, isDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // ============================================
            // VISTA MÓVIL / PANTALLAS ANGOSTAS (< 850)
            // ============================================
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildMobileBrandHeader(context, isDark),
                      const SizedBox(height: 18),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: CajaYaHeroGraphic(width: 320, height: 160),
                      ),
                      const SizedBox(height: 20),
                      _buildLoginForm(context, isDark, isDesktop: false),
                      const SizedBox(height: 16),
                      _buildCloudConnectionBadge(context, isDark),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Selector manual de tema (Modo Claro Pro <-> Warm Titanium)
        Positioned(
          top: 14,
          right: 16,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.white,
              foregroundColor: isDark ? const Color(0xFFFACC15) : const Color(0xFF475569),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(38, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  width: 1,
                ),
              ),
              elevation: 1,
            ),
            tooltip: isDark
                ? 'Cambiar a Modo Claro Pro (Porcelana)'
                : 'Cambiar a Modo Oscuro (Warm Titanium)',
            icon: Icon(
              isDark ? LucideIcons.sun : LucideIcons.moon,
              size: 18,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.read<ThemeProvider>().toggleTheme();
            },
          ),
        ),
      ],
    ),
  ),
);
  }

  // ============================================
  // BRAND SHOWCASE PARA PANTALLAS GRANDES (DESKTOP)
  // ============================================
  Widget _buildBrandShowcase(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Mark + Cloud POS Pill
        Row(
          children: [
            const CajaYaLogoMark(size: 42),
            const SizedBox(width: 12),
            Text(
              'CajaYa',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : AppTheme.brandInk,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.brandPrimary.withValues(alpha: 0.2)
                    : AppTheme.surfaceTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppTheme.brandPrimary.withValues(alpha: 0.4)
                      : AppTheme.borderTint,
                ),
              ),
              child: Text(
                'CLOUD POS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),

        // Titular de impacto
        Text(
          'El Punto de Venta más rápido para tu negocio',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.25,
            color: isDark ? Colors.white : AppTheme.brandInk,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Control total de inventario, ventas multi-cajero, arqueos de caja y emisión de tickets en tiempo real.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.5,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
          ),
        ),

        const SizedBox(height: 24),

        // Gráfico Hero B2B con contenedor estilizado
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark.withValues(alpha: 0.7) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? AppTheme.brandPrimary.withValues(alpha: 0.25)
                    : AppTheme.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: isDark ? 0.16 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const CajaYaHeroGraphic(width: 340, height: 170),
          ),
        ),

        const SizedBox(height: 26),

        // Características destacadas
        _buildShowcaseFeature(
          icon: LucideIcons.zap,
          title: 'Ventas en < 3 segundos',
          desc: 'Escaneo con código de barras y cobro rápido con Yape, Plin o Efectivo.',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildShowcaseFeature(
          icon: LucideIcons.users,
          title: 'Multi-cajero con control de roles',
          desc: 'Gestiona turnos, auditoría de cajeros y arqueos de caja protegidos.',
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _buildShowcaseFeature(
          icon: LucideIcons.receipt,
          title: 'Tickets térmicos y boletas',
          desc: 'Impresión Bluetooth/USB de 58mm y 80mm con identidad comercial de tu tienda.',
          isDark: isDark,
        ),

        const SizedBox(height: 24),

        // Footer Trust Badge
        Row(
          children: [
            const Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.accentGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tus ventas e inventario 100% protegidos y respaldados',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShowcaseFeature({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7.5),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.brandPrimary.withValues(alpha: 0.18)
                : AppTheme.surfaceTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? AppTheme.brandPrimary.withValues(alpha: 0.35)
                  : AppTheme.borderTint,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.brandInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // CABECERA MARCA PARA MÓVIL
  // ============================================
  Widget _buildMobileBrandHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CajaYaLogoMark(size: 38),
        const SizedBox(width: 10),
        Text(
          'CajaYa',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : AppTheme.brandInk,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.brandPrimary.withValues(alpha: 0.2)
                : AppTheme.surfaceTint,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? AppTheme.brandPrimary.withValues(alpha: 0.4)
                  : AppTheme.borderTint,
            ),
          ),
          child: Text(
            'CLOUD POS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // FORMULARIO PRINCIPAL DE ACCESO
  // ============================================
  Widget _buildLoginForm(BuildContext context, bool isDark, {required bool isDesktop}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 28 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido a tu Punto de Venta',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.brandInk,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Control de Inventario, Ventas & Caja en Tiempo Real',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
            ),
          ),

          if (_sessionExpiredNotice) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: isDark ? 0.15 : 1.0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.shieldAlert, size: 20, color: Colors.amber.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu sesión o turno expiró por seguridad. Ingresa tus credenciales para continuar.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Campo 1: Usuario
          Text(
            'USUARIO / OPERADOR',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            cursorColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkPrimary : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              hintText: 'admin',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
              ),
              prefixIcon: Icon(
                LucideIcons.user,
                size: 18,
                color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                  width: 1.8,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          const SizedBox(height: 14),

          // Campo 2: Contraseña
          Text(
            'CONTRASEÑA',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            cursorColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkPrimary : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
              hintText: '••••••',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
              ),
              prefixIcon: Icon(
                LucideIcons.lock,
                size: 18,
                color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                  width: 1.8,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          // Error Banner
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppTheme.alertRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.alertRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Mantener sesión
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _keepMeSignedIn = !_keepMeSignedIn),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _keepMeSignedIn ? AppTheme.brandPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _keepMeSignedIn ? AppTheme.brandPrimary : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: _keepMeSignedIn
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recordar dispositivo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón Ingresar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('INGRESAR AL SISTEMA'),
            ),
          ),

          if (_isLoading && _isColdStarting) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Despertando servidor en la nube... Esto puede tomar unos segundos si estuvo inactivo.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Opción de Registro para Nuevas Bodegas (SaaS Onboarding)
          Center(
            child: InkWell(
              onTap: () => RegistroBodegaSheet.show(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.store,
                        size: 15,
                        color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '¿Tienes un negocio? ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Registra tu bodega gratis',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                          decoration: TextDecoration.underline,
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

  // ============================================
  // FOOTER & COPYRIGHT B2B
  // ============================================
  Widget _buildCloudConnectionBadge(BuildContext context, bool isDark) {
    return GestureDetector(
      onLongPress: kDebugMode ? _configurarServidor : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '© 2026 CajaYa Cloud POS • Todos los derechos reservados',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _configurarServidor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController(text: ApiConstants.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.network, color: AppTheme.brandPrimary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Servidor Backend',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.brandInk,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dirección API en la nube (requiere HTTPS):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? AppTheme.textDarkPrimary : const Color(0xFF0F172A),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
                hintText: ApiConstants.defaultBaseUrl,
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctrl.text = ApiConstants.defaultBaseUrl,
            child: const Text('Restablecer'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              if (newUrl.isEmpty) return;

              final uri = Uri.tryParse(newUrl);
              if (uri == null || !uri.hasScheme) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL inválida. Debe incluir https://'),
                    backgroundColor: AppTheme.alertRed,
                  ),
                );
                return;
              }

              // Seguridad: Forzar HTTPS excepto en localhost de desarrollo
              final isLocal = newUrl.contains('localhost') || newUrl.contains('127.0.0.1') || newUrl.contains('192.168.');
              if (!newUrl.startsWith('https://') && !isLocal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por seguridad, el servidor debe usar cifrado seguro HTTPS.'),
                    backgroundColor: AppTheme.alertRed,
                  ),
                );
                return;
              }

              await ApiConstants.setBaseUrl(newUrl);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }
}
