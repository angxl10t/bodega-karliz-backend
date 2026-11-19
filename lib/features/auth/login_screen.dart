import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';
import 'recuperar_password_modal.dart';
import 'registro_bodega_sheet.dart';
import '../../core/api_constants.dart';
import '../../core/secure_storage_service.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/widgets/water_drop_theme_transition.dart';
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
  final _codigoTiendaCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isColdStarting = false;
  Timer? _coldStartTimer;
  bool _obscurePassword = true;
  bool _keepMeSignedIn = true;
  String _errorMessage = '';
  bool _sessionExpiredNotice = false;
  bool _isLoginPressed = false;

  // Estado para Modo Cajero con PIN en terminal vinculada
  bool _isCajeroPinMode = false;
  String _enteredPin = '';
  String? _terminalIdBodega;
  String? _terminalNombreBodega;
  List<Map<String, dynamic>> _cajerosTerminal = [];
  int? _selectedIdUsuario;
  String? _selectedCajeroNombre;
  bool _mostrarCambioTienda = false;

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
    _cargarInfoTerminal();
  }

  void _cargarInfoTerminal() {
    AuthService.getTerminalIdBodega().then((id) {
      if (id != null && id.isNotEmpty && mounted) {
        setState(() => _terminalIdBodega = id);
        AuthService.getTerminalNombreBodega().then((nom) {
          if (nom != null && mounted) {
            setState(() => _terminalNombreBodega = nom);
          }
        });
        _authService.obtenerCajerosTerminal(id).then((cajeros) {
          if (mounted && cajeros.isNotEmpty) {
            setState(() {
              _cajerosTerminal = cajeros;
              _selectedIdUsuario = cajeros.first['idUsuario'] as int?;
              _selectedCajeroNombre =
                  cajeros.first['nombreCompleto'] as String?;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _coldStartTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _codigoTiendaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      HapticFeedback.mediumImpact();
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
        HapticFeedback.lightImpact();
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
        HapticFeedback.heavyImpact();
        setState(
          () => _errorMessage =
              result.errorMessage ?? 'Usuario o contraseña incorrectos',
        );
      }
    }
  }

  Future<void> _abrirModalRecuperarPassword() async {
    final recoveredUsername = await RecuperarPasswordModal.show(
      context,
      initialIdentificador: _usernameController.text.trim(),
    );
    if (recoveredUsername != null && recoveredUsername.isNotEmpty && mounted) {
      setState(() {
        _usernameController.text = recoveredUsername;
        _passwordController.clear();
        _errorMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Contraseña restablecida! Ingresa con tu nueva clave.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _pressPinDigit(String digit) {
    if (_isLoading) return;
    if (_enteredPin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });
    if (_enteredPin.length == 4) {
      _loginCajero();
    }
  }

  void _deletePinDigit() {
    if (_isLoading) return;
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _clearPin() {
    if (_isLoading) return;
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = '';
      _errorMessage = '';
    });
  }

  Future<void> _loginCajero() async {
    if (_terminalIdBodega == null || _terminalIdBodega!.isEmpty) {
      setState(
        () => _errorMessage =
            'Por favor vincula esta terminal al ID de tu negocio.',
      );
      HapticFeedback.heavyImpact();
      return;
    }
    if (_selectedIdUsuario == null) {
      setState(
        () => _errorMessage = 'Por favor selecciona tu perfil de cajero.',
      );
      HapticFeedback.heavyImpact();
      return;
    }
    if (_enteredPin.length < 4) {
      setState(() => _errorMessage = 'Ingresa los 4 dígitos de tu PIN.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await _authService.loginCajero(
      idBodega: _terminalIdBodega,
      idUsuario: _selectedIdUsuario,
      pin: _enteredPin,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        HapticFeedback.lightImpact();
        final colorHex = await _authService.getColorPrimario();
        if (mounted && colorHex.isNotEmpty) {
          context.read<ThemeProvider>().setAccentColorFromHex(colorHex);
        }
        if (mounted) {
          context.go('/home');
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage =
              result.errorMessage ?? 'PIN incorrecto. Intenta de nuevo.';
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _vincularTienda() async {
    final codigo = _codigoTiendaCtrl.text.trim();
    if (codigo.isEmpty) return;
    final id = int.tryParse(codigo);
    if (id == null) {
      setState(() => _errorMessage = 'El ID de negocio debe ser numérico.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final cajeros = await _authService.obtenerCajerosTerminal(codigo);
      if (mounted) {
        if (cajeros.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'No se encontraron cajeros activos para el local #$codigo';
          });
        } else {
          await AuthService.vincularTerminal(
            idBodega: codigo,
            nombreBodega: 'Local #$codigo',
          );
          setState(() {
            _isLoading = false;
            _terminalIdBodega = codigo;
            _terminalNombreBodega = 'Local #$codigo';
            _cajerosTerminal = cajeros;
            _selectedIdUsuario = cajeros.first['idUsuario'] as int?;
            _selectedCajeroNombre = cajeros.first['nombreCompleto'] as String?;
            _mostrarCambioTienda = false;
            _errorMessage = '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al vincular con el servidor: $e';
        });
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
                            color: isDark
                                ? AppTheme.cardDark
                                : const Color(0xFFF1F5F9),
                            border: Border(
                              right: BorderSide(
                                color: isDark
                                    ? AppTheme.borderDark
                                    : AppTheme.borderLight,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Iluminación ambiental contenida y sutil (estética B2B sobria)
                              Positioned(
                                top: -120,
                                left: -120,
                                child: Container(
                                  width: 420,
                                  height: 420,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppTheme.brandPrimary.withValues(
                                          alpha: isDark ? 0.09 : 0.04,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 32,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 28,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLoginForm(
                                    context,
                                    isDark,
                                    isDesktop: true,
                                  ),
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
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
              child: WaterDropThemeButton(
                isDark: isDark,
                onToggle: () => context.read<ThemeProvider>().toggleTheme(),
                iconSize: 18,
                padding: const EdgeInsets.all(8),
                borderRadius: 12,
                backgroundColor: isDark
                    ? AppTheme.cardDarkElevated
                    : Colors.white,
                borderColor: isDark
                    ? AppTheme.borderDark
                    : AppTheme.borderLight,
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
            color: isDark
                ? AppTheme.textDarkSecondary
                : const Color(0xFF334155),
          ),
        ),

        const SizedBox(height: 24),

        // Gráfico Hero B2B con contenedor estilizado
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.cardDark.withValues(alpha: 0.7)
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? AppTheme.brandPrimary.withValues(alpha: 0.25)
                    : AppTheme.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(
                    alpha: isDark ? 0.16 : 0.06,
                  ),
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
            const Icon(
              LucideIcons.shieldCheck,
              size: 16,
              color: AppTheme.accentGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tus ventas e inventario 100% protegidos y respaldados',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF334155),
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
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF334155),
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
  Widget _buildLoginForm(
    BuildContext context,
    bool isDark, {
    required bool isDesktop,
  }) {
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
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF334155),
            ),
          ),

          if (_sessionExpiredNotice) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(
                  alpha: isDark ? 0.15 : 1.0,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.amber.shade600.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.shieldAlert,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu sesión o turno expiró por seguridad. Ingresa tus credenciales para continuar.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _buildModeTabs(isDark),
          const SizedBox(height: 16),

          if (!_isCajeroPinMode) ...[
            // Campo 1: Usuario
            Text(
              'USUARIO / OPERADOR',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              cursorColor: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16, // Previene auto-zoom molesto en navegadores móviles (iOS Safari)
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textDarkPrimary
                    : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF1F5F9),
                hintText: 'Ingresa tu usuario',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.getAdaptiveHintText(isDark),
                ),
                prefixIcon: Icon(
                  LucideIcons.user,
                  size: 18,
                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                    width: 1.8,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
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
                fontSize: 16, // Previene auto-zoom molesto en navegadores móviles (iOS Safari)
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.textDarkPrimary
                    : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? AppTheme.cardDarkSunken
                    : const Color(0xFFF1F5F9),
                hintText: '••••••',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.getAdaptiveHintText(isDark),
                ),
                prefixIcon: Icon(
                  LucideIcons.lock,
                  size: 18,
                  color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                ),
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      key: ValueKey<bool>(_obscurePassword),
                      size: 18,
                      color: isDark
                          ? AppTheme.textDarkSecondary
                          : const Color(0xFF334155),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.borderDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.brandLight : AppTheme.brandPrimary,
                    width: 1.8,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            // Error Banner con transición animada suave
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _errorMessage.isNotEmpty
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _errorMessage.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.alertRed.withValues(
                              alpha: isDark ? 0.4 : 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.alertCircle,
                              color: AppTheme.alertRed,
                              size: 16,
                            ),
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
                    )
                  : const SizedBox.shrink(),
              secondChild: const SizedBox.shrink(),
            ),

            const SizedBox(height: 14),

            // Mantener sesión con micro-animación de resorte y feedback táctil
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _keepMeSignedIn = !_keepMeSignedIn);
              },
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _keepMeSignedIn
                          ? AppTheme.brandPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _keepMeSignedIn
                            ? AppTheme.brandPrimary
                            : (isDark
                                  ? AppTheme.borderDarkElevated
                                  : const Color(0xFFCBD5E1)),
                        width: 1.5,
                      ),
                    ),
                    child: AnimatedScale(
                      scale: _keepMeSignedIn ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recordar dispositivo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppTheme.getAdaptiveMutedText(isDark),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Enlace ¿Olvidaste tu contraseña?
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _abrirModalRecuperarPassword();
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.brandLight
                          : AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón Ingresar con respuesta física táctil (escala en press) y desvanecimiento suave
            Listener(
              onPointerDown: (_) {
                if (!_isLoading) {
                  HapticFeedback.lightImpact();
                  setState(() => _isLoginPressed = true);
                }
              },
              onPointerUp: (_) {
                if (_isLoginPressed) {
                  setState(() => _isLoginPressed = false);
                }
              },
              onPointerCancel: (_) {
                if (_isLoginPressed) {
                  setState(() => _isLoginPressed = false);
                }
              },
              child: AnimatedScale(
                scale: _isLoginPressed && !_isLoading ? 0.98 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'INGRESAR AL SISTEMA',
                              key: ValueKey('text'),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // Banner de Servidor en Frío con transición animada
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _isLoading && _isColdStarting
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB)
                        .withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Despertando servidor en la nube... Espera un momento.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ] else ...[
            _buildCajeroPinSection(context, isDark),
          ],

          const SizedBox(height: 18),

          // Opción de Registro para Nuevas Bodegas (SaaS Onboarding)
          Center(
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: () {
                HapticFeedback.lightImpact();
                RegistroBodegaSheet.show(context);
              },
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
                        color: isDark
                            ? AppTheme.brandLight
                            : AppTheme.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '¿Tienes un negocio? ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Registra tu bodega gratis',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.brandLight
                              : AppTheme.brandPrimary,
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

  Widget _buildModeTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTabItem(
              title: 'Dueño / Admin',
              icon: LucideIcons.shieldCheck,
              isSelected: !_isCajeroPinMode,
              isDark: isDark,
              onTap: () {
                if (_isCajeroPinMode) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isCajeroPinMode = false;
                    _errorMessage = '';
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeTabItem(
              title: 'Cajero (PIN)',
              icon: LucideIcons.keyRound,
              isSelected: _isCajeroPinMode,
              isDark: isDark,
              onTap: () {
                if (!_isCajeroPinMode) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isCajeroPinMode = true;
                    _errorMessage = '';
                    _enteredPin = '';
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.cardDarkElevated : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? (isDark ? AppTheme.brandLight : AppTheme.brandPrimary)
                      : (isDark
                            ? AppTheme.textDarkSecondary
                            : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : AppTheme.brandInk)
                        : (isDark
                              ? AppTheme.textDarkSecondary
                              : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCajeroPinSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Terminal vinculada badge o input de vinculación
        if (_terminalIdBodega != null && !_mostrarCambioTienda) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.brandPrimary.withValues(alpha: 0.15)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppTheme.brandPrimary.withValues(alpha: 0.35)
                    : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.store,
                    size: 16,
                    color: AppTheme.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _terminalNombreBodega ?? 'Terminal #$_terminalIdBodega',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.brandInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Local ID: $_terminalIdBodega • Vinculada',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _mostrarCambioTienda = true);
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Cambiar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.brandLight
                          : AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.link,
                          size: 15,
                          color: isDark
                              ? AppTheme.brandLight
                              : AppTheme.brandPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Vincular Terminal',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.brandInk,
                          ),
                        ),
                      ],
                    ),
                    if (_terminalIdBodega != null)
                      InkWell(
                        onTap: () =>
                            setState(() => _mostrarCambioTienda = false),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoTiendaCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.textDarkPrimary
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ingresa ID de tu local (ej: 1)',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.getAdaptiveHintText(isDark),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.cardDarkElevated
                              : Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppTheme.borderDark
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _vincularTienda,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        'Vincular',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // 2. Selector de Perfil de Cajero
        if (_cajerosTerminal.isNotEmpty) ...[
          Text(
            'SELECCIONA TU CAJERO',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cajerosTerminal.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final c = _cajerosTerminal[idx];
                final id = c['idUsuario'] as int?;
                final nombre = c['nombreCompleto'] as String? ?? 'Cajero';
                final isSelected = _selectedIdUsuario == id;
                final initial = nombre.isNotEmpty
                    ? nombre[0].toUpperCase()
                    : 'C';

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedIdUsuario = id;
                      _selectedCajeroNombre = nombre;
                      _enteredPin = '';
                      _errorMessage = '';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                                ? AppTheme.brandPrimary.withValues(alpha: 0.25)
                                : const Color(0xFFEFF6FF))
                          : (isDark
                                ? AppTheme.cardDarkSunken
                                : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isDark
                                  ? AppTheme.brandLight
                                  : AppTheme.brandPrimary)
                            : (isDark
                                  ? AppTheme.borderDark
                                  : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected
                              ? AppTheme.brandPrimary
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                          child: Text(
                            initial,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white
                                        : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.brandInk,
                              ),
                            ),
                            Text(
                              'Cajero',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.textDarkSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ] else if (_terminalIdBodega != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: isDark ? 0.15 : 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 16,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay cajeros registrados en este local. Ingresa como Dueño para crear uno.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3. Indicador de PIN (4 puntos)
        Center(
          child: Text(
            _selectedCajeroNombre != null
                ? 'PIN de acceso para $_selectedCajeroNombre'
                : 'Ingresa tu PIN de 4 dígitos',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textDarkSecondary
                  : const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? (isDark ? AppTheme.brandLight : AppTheme.brandPrimary)
                    : Colors.transparent,
                border: Border.all(
                  color: _errorMessage.isNotEmpty
                      ? AppTheme.alertRed
                      : (filled
                            ? (isDark
                                  ? AppTheme.brandLight
                                  : AppTheme.brandPrimary)
                            : (isDark
                                  ? AppTheme.borderDarkElevated
                                  : const Color(0xFFCBD5E1))),
                  width: 2,
                ),
              ),
            );
          }),
        ),

        // Error Banner animado
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeInCubic,
          crossFadeState: _errorMessage.isNotEmpty
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _errorMessage.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.alertRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          secondChild: const SizedBox.shrink(),
        ),

        if (_isLoading) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppTheme.brandPrimary,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // 4. Teclado Numérico Ergonómico 3x4
        _buildKeypadGrid(isDark),
      ],
    );
  }

  Widget _buildKeypadGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKeypadButton('1', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('2', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('3', isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildKeypadButton('4', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('5', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('6', isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildKeypadButton('7', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('8', isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('9', isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildKeypadActionButton(
                label: 'C',
                icon: null,
                isDark: isDark,
                onTap: _clearPin,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildKeypadButton('0', isDark)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKeypadActionButton(
                label: null,
                icon: LucideIcons.delete,
                isDark: isDark,
                onTap: _deletePinDigit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit, bool isDark) {
    return Material(
      color: isDark ? AppTheme.cardDarkSunken : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _isLoading ? null : () => _pressPinDigit(digit),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.brandInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadActionButton({
    String? label,
    IconData? icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                )
              : Text(
                  label ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textDarkSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
        ),
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
              color: AppTheme.getAdaptiveHintText(isDark),
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
            const Icon(
              LucideIcons.network,
              color: AppTheme.brandPrimary,
              size: 20,
            ),
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
                color: isDark
                    ? AppTheme.textDarkSecondary
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: GoogleFonts.plusJakartaSans(
                color: isDark
                    ? AppTheme.textDarkPrimary
                    : const Color(0xFF0F172A),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? AppTheme.cardDarkElevated
                    : const Color(0xFFF1F5F9),
                hintText: ApiConstants.defaultBaseUrl,
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: isDark
                      ? AppTheme.textDarkSecondary
                      : const Color(0xFF64748B),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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
              final isLocal =
                  newUrl.contains('localhost') ||
                  newUrl.contains('127.0.0.1') ||
                  newUrl.contains('192.168.');
              if (!newUrl.startsWith('https://') && !isLocal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por seguridad, el servidor debe usar cifrado seguro HTTPS.',
                    ),
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
