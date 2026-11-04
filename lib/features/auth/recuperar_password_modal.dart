import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'auth_service.dart';
import '../../core/theme.dart';

class RecuperarPasswordModal extends StatefulWidget {
  final String? initialIdentificador;

  const RecuperarPasswordModal({super.key, this.initialIdentificador});

  static Future<String?> show(
    BuildContext context, {
    String? initialIdentificador,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecuperarPasswordModal(
        initialIdentificador: initialIdentificador,
      ),
    );
  }

  @override
  State<RecuperarPasswordModal> createState() => _RecuperarPasswordModalState();
}

class _RecuperarPasswordModalState extends State<RecuperarPasswordModal> {
  final _authService = AuthService();

  // Paso actual: 0 = Identificador, 1 = Código OTP, 2 = Nueva Contraseña, 3 = Éxito
  int _step = 0;

  final _identificadorController = TextEditingController();
  final _codigoController = TextEditingController();
  final _nuevaPasswordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  String _emailEnmascarado = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Temporizadores para OTP
  Timer? _countdownTimer;
  int _secondsRemaining = 900; // 15 minutos
  int _resendCooldown = 60; // 60 segundos antes de permitir reenvío

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentificador != null &&
        widget.initialIdentificador!.trim().isNotEmpty) {
      _identificadorController.text = widget.initialIdentificador!.trim();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _identificadorController.dispose();
    _codigoController.dispose();
    _nuevaPasswordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = 900;
    _resendCooldown = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        }
        if (_resendCooldown > 0) {
          _resendCooldown--;
        }
      });
    });
  }

  String _formatTime(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // ---------------------------------------------------------------------------
  // Paso 1: Solicitar Código OTP
  // ---------------------------------------------------------------------------
  Future<void> _enviarCodigo() async {
    final id = _identificadorController.text.trim();
    if (id.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu usuario o correo electrónico.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await _authService.solicitarRecuperacionPassword(id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (res['sinEmail'] == true) {
        setState(() {
          _errorMessage = res['mensaje'] ?? 'La cuenta no tiene un correo configurado.';
        });
        return;
      }
      setState(() {
        _emailEnmascarado = res['emailEnmascarado'] ?? '';
        _step = 1;
        _errorMessage = '';
      });
      _startTimer();
    } else {
      setState(() {
        _errorMessage = res['mensaje'] ?? 'No se pudo procesar la solicitud.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Paso 2: Verificar Código OTP
  // ---------------------------------------------------------------------------
  Future<void> _verificarCodigo() async {
    final id = _identificadorController.text.trim();
    final codigo = _codigoController.text.trim();

    if (codigo.length != 6) {
      setState(() => _errorMessage = 'El código debe tener exactamente 6 dígitos.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await _authService.verificarCodigoRecuperacion(id, codigo);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() {
        _step = 2;
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = res['mensaje'] ?? 'Código incorrecto o expirado.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Paso 3: Restablecer Contraseña
  // ---------------------------------------------------------------------------
  Future<void> _restablecerPassword() async {
    final id = _identificadorController.text.trim();
    final codigo = _codigoController.text.trim();
    final pass = _nuevaPasswordController.text.trim();
    final confirm = _confirmarPasswordController.text.trim();

    if (pass.length < 4) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 4 caracteres.');
      return;
    }

    if (pass != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await _authService.restablecerPasswordConCodigo(
      identificador: id,
      codigo: codigo,
      nuevaPassword: pass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _countdownTimer?.cancel();
      setState(() {
        _step = 3;
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = res['mensaje'] ?? 'No se pudo restablecer la contraseña.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(
        top: 40,
        bottom: bottomInset,
      ),
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Encabezado con Ícono y Título
              _buildHeader(isDark),
              const SizedBox(height: 20),

              // Mensaje de Error si existe
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Contenido dinámico según el paso
              if (_step == 0) _buildPaso1Identificacion(isDark),
              if (_step == 1) _buildPaso2CodigoOtp(isDark),
              if (_step == 2) _buildPaso3NuevaPassword(isDark),
              if (_step == 3) _buildPaso4Exito(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    switch (_step) {
      case 1:
        icon = LucideIcons.mailCheck;
        iconColor = AppTheme.accentGreen;
        title = 'Ingresa el Código de Seguridad';
        subtitle = _emailEnmascarado.isNotEmpty
            ? 'Enviamos un código de 6 dígitos a $_emailEnmascarado'
            : 'Revisa tu bandeja de entrada o spam para ver el código.';
        break;
      case 2:
        icon = LucideIcons.lockKeyhole;
        iconColor = AppTheme.brandPrimary;
        title = 'Crea tu Nueva Contraseña';
        subtitle = 'Escribe tu nueva clave segura para volver a entrar a tu bodega.';
        break;
      case 3:
        icon = LucideIcons.circleCheckBig;
        iconColor = AppTheme.accentGreen;
        title = '¡Contraseña Restablecida!';
        subtitle = 'Tu acceso ha sido actualizado exitosamente.';
        break;
      default:
        icon = LucideIcons.keyRound;
        iconColor = AppTheme.brandPrimary;
        title = '¿Olvidaste tu Contraseña?';
        subtitle = 'Ingresa tu usuario o correo electrónico para enviarte un código de recuperación.';
        break;
    }

    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets: Paso 1
  // ---------------------------------------------------------------------------
  Widget _buildPaso1Identificacion(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Usuario o Correo Electrónico',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _identificadorController,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. bodega-karliz o micorreo@gmail.com',
            prefixIcon: const Icon(LucideIcons.userCheck, size: 19),
            filled: true,
            fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          onFieldSubmitted: (_) => _enviarCodigo(),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _enviarCodigo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.send, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'ENVIAR CÓDIGO DE SEGURIDAD',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar y volver al login',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets: Paso 2
  // ---------------------------------------------------------------------------
  Widget _buildPaso2CodigoOtp(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Caja de temporizador
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.clock,
                size: 16,
                color: _secondsRemaining > 60 ? AppTheme.accentGreen : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'El código expira en: ${_formatTime(_secondsRemaining)}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _secondsRemaining > 60
                      ? (isDark ? Colors.white : AppTheme.textDark)
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Código de 6 Dígitos',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codigoController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: GoogleFonts.jetBrainsMono(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              letterSpacing: 10,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          onChanged: (val) {
            if (val.trim().length == 6) {
              _verificarCodigo();
            }
          },
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verificarCodigo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.check, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'VERIFICAR CÓDIGO',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Reenviar código / Cambiar identificador
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                _countdownTimer?.cancel();
                setState(() => _step = 0);
              },
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: Text(
                'Cambiar usuario',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _resendCooldown == 0 && !_isLoading ? _enviarCodigo : null,
              child: Text(
                _resendCooldown > 0
                    ? 'Reenviar en ${_resendCooldown}s'
                    : 'Reenviar código',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _resendCooldown == 0
                      ? AppTheme.brandPrimary
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets: Paso 3
  // ---------------------------------------------------------------------------
  Widget _buildPaso3NuevaPassword(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nueva Contraseña',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nuevaPasswordController,
          obscureText: _obscurePassword,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Mínimo 4 caracteres (recomendado 8+)',
            prefixIcon: const Icon(LucideIcons.lock, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Confirmar Nueva Contraseña',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textDarkSecondary : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmarPasswordController,
          obscureText: _obscureConfirm,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Repite tu nueva contraseña',
            prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onFieldSubmitted: (_) => _restablecerPassword(),
        ),
        const SizedBox(height: 22),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _restablecerPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.save, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'RESTABLECER CONTRASEÑA',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets: Paso 4 (Éxito)
  // ---------------------------------------------------------------------------
  Widget _buildPaso4Exito(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Tu contraseña se ha cambiado correctamente. Todas las sesiones activas anteriores han sido revocadas por seguridad.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF14532D),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(_identificadorController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.logIn, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'INICIAR SESIÓN AHORA',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
