import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'auth_service.dart';
import 'karliz_mascot_data.dart';
import 'registro_bodega_sheet.dart';
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';

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
    // Limpia cualquier residuo de sesión anterior al abrir el login
    SecureStorageService.clearAuth();
  }

  @override
  void dispose() {
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
      _errorMessage = '';
    });

    final result = await _authService.login(user, pass);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        context.go('/home');
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // ============================================
                  // CABECERA REBRANDEADA: LOGO & MARCA
                  // ============================================
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const KarlizLogoMark(size: 38),
                      const SizedBox(width: 10),
                      Text(
                        'KARLIZ',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                          'MARKET POS',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Ilustración Familiar Familia Garcia Cueva
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.memory(
                        kKarlizFamilyMascotBytes,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/images/karliz_mascot.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ============================================
                  // TARJETA ELEVADA DE LOGIN
                  // ============================================
                  Container(
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenidos Familia Garcia Cueva',
                          style: GoogleFonts.outfit(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.brandInk,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistema de Control & Caja • Bodega KARLIZ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppTheme.textMuted,
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
                            color: isDark ? Colors.white70 : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          cursorColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            hintText: 'admin',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              LucideIcons.user,
                              size: 18,
                              color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                            color: isDark ? Colors.white70 : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          cursorColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            hintText: '••••••',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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

                        const SizedBox(height: 18),

                        // Opción de Registro para Nuevas Bodegas (SaaS Onboarding)
                        Center(
                          child: InkWell(
                            onTap: () => RegistroBodegaSheet.show(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Conexión Cloud (Protegido: Mantener presionado para configuración técnica)
                  Center(
                    child: Tooltip(
                      message: 'Mantén presionado para configuración técnica avanzada',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onLongPress: _solicitarClaveParaServidor,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'En la nube: Render Live',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.settings, size: 12, color: AppTheme.textMuted),
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
        ),
      ),
    );
  }

  void _solicitarClaveParaServidor() {
    if (kReleaseMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servidor protegido: Conexión cifrada a la nube oficial de Bodega KARLIZ.'),
          backgroundColor: AppTheme.brandPrimary,
        ),
      );
      return;
    }
    // Solo disponible en modo desarrollo / debug local
    _configurarServidor();
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
                color: isDark ? Colors.white70 : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                hintText: 'https://bodega-karliz-backend.onrender.com/api',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
