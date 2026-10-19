import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'secure_storage_service.dart';

/// Servicio Híbrido de Seguridad POS (PIN Numérico + Biometría en Hardware)
class LockService {
  static final LockService _instance = LockService._internal();
  factory LockService() => _instance;
  LockService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool isLocked = false;

  static const String _pinKey = 'pos_lock_pin';
  static const String _autoLockEnabledKey = 'pos_auto_lock_enabled';
  static const String _inactivityMinutesKey = 'pos_inactivity_minutes';

  /// Comprueba si el bloqueo automático está activado (por defecto sí)
  Future<bool> isAutoLockEnabled() async {
    final val = await SecureStorageService.read(_autoLockEnabledKey);
    return val != 'false';
  }

  Future<void> setAutoLockEnabled(bool enabled) async {
    await SecureStorageService.write(_autoLockEnabledKey, enabled ? 'true' : 'false');
  }

  /// Minutos de inactividad antes de bloquear (por defecto 5 min)
  Future<int> getInactivityMinutes() async {
    final val = await SecureStorageService.read(_inactivityMinutesKey);
    return int.tryParse(val ?? '5') ?? 5;
  }

  Future<void> setInactivityMinutes(int minutes) async {
    await SecureStorageService.write(_inactivityMinutesKey, minutes.toString());
  }

  /// Verifica si el usuario ya configuró su PIN de 4 dígitos
  Future<bool> hasPin() async {
    final pin = await SecureStorageService.read(_pinKey);
    return pin != null && pin.length == 4;
  }

  /// Guarda el PIN de 4 dígitos de forma cifrada en Android Keystore
  Future<void> savePin(String pin) async {
    if (pin.length != 4) return;
    await SecureStorageService.write(_pinKey, pin);
  }

  static const int maxFailedAttempts = 5;
  static const int cooldownDurationSeconds = 30;

  int _failedPinAttempts = 0;
  DateTime? _blockedUntil;

  int get failedAttempts => _failedPinAttempts;

  /// Retorna los segundos restantes de bloqueo por demasiados intentos de PIN fallidos
  int get remainingBlockedSeconds {
    if (_blockedUntil == null) return 0;
    final diff = _blockedUntil!.difference(DateTime.now()).inSeconds;
    if (diff <= 0) {
      _blockedUntil = null;
      _failedPinAttempts = 0;
      return 0;
    }
    return diff;
  }

  bool get isPinBlocked => remainingBlockedSeconds > 0;

  /// Valida el PIN ingresado contra el almacenado en Keystore con protección anti-fuerza bruta
  Future<bool> verifyPin(String enteredPin) async {
    if (isPinBlocked) return false;

    final storedPin = await SecureStorageService.read(_pinKey);
    final isValid = storedPin != null && storedPin == enteredPin;

    if (isValid) {
      _failedPinAttempts = 0;
      _blockedUntil = null;
      return true;
    } else {
      _failedPinAttempts++;
      if (_failedPinAttempts >= maxFailedAttempts) {
        // Bloqueo temporal por 30 segundos tras 5 intentos fallidos
        _blockedUntil = DateTime.now().add(const Duration(seconds: cooldownDurationSeconds));
      }
      return false;
    }
  }

  /// Elimina el PIN configurado y resetea intentos
  Future<void> removePin() async {
    _failedPinAttempts = 0;
    _blockedUntil = null;
    await SecureStorageService.delete(_pinKey);
  }

  /// Comprueba si el dispositivo soporta sensor de huella o biometría
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Autentica usando sensor biométrico o huella dactilar
  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Confirma tu huella digital para desbloquear la caja',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
