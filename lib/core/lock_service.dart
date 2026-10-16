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

  /// Valida el PIN ingresado contra el almacenado en Keystore
  Future<bool> verifyPin(String enteredPin) async {
    final storedPin = await SecureStorageService.read(_pinKey);
    return storedPin != null && storedPin == enteredPin;
  }

  /// Elimina el PIN configurado
  Future<void> removePin() async {
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
