import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../lock_service.dart';
import '../theme.dart';
import '../../features/auth/auth_service.dart';

/// Modal de Bloqueo POS con Teclado Numérico y Huella Digital
class KarlizLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onLogout;

  const KarlizLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onLogout,
  });

  static Future<void> show(BuildContext context, {
    required VoidCallback onUnlocked,
    required VoidCallback onLogout,
  }) {
    LockService().isLocked = true;
    return showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => KarlizLockScreen(
        onUnlocked: () {
          LockService().isLocked = false;
          onUnlocked();
        },
        onLogout: () {
          LockService().isLocked = false;
          onLogout();
        },
      ),
    );
  }

  @override
  State<KarlizLockScreen> createState() => _KarlizLockScreenState();
}

class _KarlizLockScreenState extends State<KarlizLockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _username = 'Cajero';
  bool _canBiometrics = false;
  String _errorMessage = '';
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final user = await AuthService().getUsername();
    final canBio = await LockService().canCheckBiometrics();
    final remaining = LockService().remainingBlockedSeconds;
    if (mounted) {
      setState(() {
        _username = user;
        _canBiometrics = canBio;
      });
      if (remaining > 0) {
        _startCooldown(remaining);
      } else if (canBio) {
        _autenticarBiometria();
      }
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = seconds;
      _pin = '';
      _errorMessage = 'Teclado bloqueado. Espera $_cooldownSeconds s.';
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final rem = LockService().remainingBlockedSeconds;
      setState(() {
        _cooldownSeconds = rem;
        if (_cooldownSeconds <= 0) {
          timer.cancel();
          _errorMessage = '';
        } else {
          _errorMessage = 'Teclado bloqueado. Espera $_cooldownSeconds s.';
        }
      });
    });
  }

  Future<void> _autenticarBiometria() async {
    final ok = await LockService().authenticateWithBiometrics();
    if (ok && mounted) {
      _cooldownTimer?.cancel();
      HapticFeedback.mediumImpact();
      Navigator.of(context, rootNavigator: true).pop();
      widget.onUnlocked();
    }
  }

  void _onDigitPressed(String digit) {
    if (_cooldownSeconds > 0) return;
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();

    setState(() {
      _pin += digit;
      _errorMessage = '';
    });

    if (_pin.length == 4) {
      _verificarPin();
    }
  }

  void _onDeletePressed() {
    if (_cooldownSeconds > 0) return;
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = '';
    });
  }

  Future<void> _verificarPin() async {
    if (LockService().isPinBlocked) {
      _startCooldown(LockService().remainingBlockedSeconds);
      return;
    }

    final ok = await LockService().verifyPin(_pin);
    if (ok && mounted) {
      _cooldownTimer?.cancel();
      HapticFeedback.mediumImpact();
      Navigator.of(context, rootNavigator: true).pop();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);

      if (LockService().isPinBlocked) {
        _startCooldown(LockService().remainingBlockedSeconds);
      } else {
        final restantes = LockService.maxFailedAttempts - LockService().failedAttempts;
        setState(() {
          _errorMessage = restantes > 0
              ? 'PIN incorrecto. Te quedan $restantes intentos.'
              : 'PIN incorrecto. Intenta nuevamente.';
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Impide cerrar con el botón atrás de Android
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cabecera de Bloqueo
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(LucideIcons.lock, size: 30, color: AppTheme.brandPrimary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Caja Protegida',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.brandInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Turno activo de $_username',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Indicadores de PIN (4 bolitas)
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final dx = 12 * (1 - _shakeController.value) *
                                (0.5 - ((_shakeController.value * 6).floor() % 2));
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final filled = index < _pin.length;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled
                                      ? AppTheme.brandPrimary
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                                  border: Border.all(
                                    color: filled
                                        ? AppTheme.brandPrimary
                                        : (isDark ? Colors.white24 : Colors.transparent),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.alertRed,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Teclado Numérico Táctil POS (Numpad)
                    Column(
                      children: [
                        _buildRow(['1', '2', '3'], isDark),
                        const SizedBox(height: 14),
                        _buildRow(['4', '5', '6'], isDark),
                        const SizedBox(height: 14),
                        _buildRow(['7', '8', '9'], isDark),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botón de Biometría / Huella
                            _buildActionButton(
                              icon: LucideIcons.fingerprint,
                              onPressed: _canBiometrics ? _autenticarBiometria : null,
                              isDark: isDark,
                              color: _canBiometrics ? AppTheme.brandPrimary : Colors.transparent,
                            ),
                            // Tecla 0
                            _buildKeyButton('0', isDark),
                            // Tecla Borrar
                            _buildActionButton(
                              icon: LucideIcons.delete,
                              onPressed: _onDeletePressed,
                              isDark: isDark,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Pie: Opción de cerrar sesión
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.alertRed,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(LucideIcons.logOut, size: 16),
                      label: Text(
                        'Cerrar Sesión Completa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        widget.onLogout();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeyButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeyButton(String digit, bool isDark) {
    final disabled = _cooldownSeconds > 0;
    final bg = disabled
        ? (isDark ? const Color(0xFF0F141F) : const Color(0xFFE2E8F0))
        : (isDark ? const Color(0xFF141C2B) : Colors.white);
    final fg = disabled
        ? (isDark ? Colors.white30 : const Color(0xFF94A3B8))
        : (isDark ? Colors.white : AppTheme.brandInk);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            digit,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Icon(icon, size: 28, color: color),
        ),
      ),
    );
  }
}

/// Modal para Configurar o Cambiar el PIN de Caja
class ConfigurarPinModal extends StatefulWidget {
  final VoidCallback onPinGuardado;

  const ConfigurarPinModal({super.key, required this.onPinGuardado});

  static Future<void> show(BuildContext context, {required VoidCallback onPinGuardado}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfigurarPinModal(onPinGuardado: onPinGuardado),
    );
  }

  @override
  State<ConfigurarPinModal> createState() => _ConfigurarPinModalState();
}

class _ConfigurarPinModalState extends State<ConfigurarPinModal> {
  final _pinCtrl1 = TextEditingController();
  final _pinCtrl2 = TextEditingController();
  String _error = '';
  bool _guardando = false;

  @override
  void dispose() {
    _pinCtrl1.dispose();
    _pinCtrl2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final p1 = _pinCtrl1.text.trim();
    final p2 = _pinCtrl2.text.trim();

    if (p1.length != 4 || int.tryParse(p1) == null) {
      setState(() => _error = 'El PIN debe contener exactamente 4 dígitos numéricos.');
      return;
    }

    if (p1 != p2) {
      setState(() => _error = 'Los dos PINs ingresados no coinciden.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = '';
    });

    await LockService().savePin(p1);

    if (mounted) {
      Navigator.pop(context);
      widget.onPinGuardado();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN de caja configurado con éxito.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, viewInsets + 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.keyRound, size: 20, color: AppTheme.brandPrimary),
              ),
              const SizedBox(width: 12),
              Text(
                'PIN Rápido de Caja',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.brandInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresa un PIN de 4 números para desbloquear la caja rápidamente cuando esté inactiva:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinCtrl1,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: GoogleFonts.outfit(fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              labelText: 'Nuevo PIN (4 dígitos)',
              prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl2,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: GoogleFonts.outfit(fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              labelText: 'Confirma el PIN',
              prefixIcon: const Icon(LucideIcons.checkCheck, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _error,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.alertRed, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Guardar PIN', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
