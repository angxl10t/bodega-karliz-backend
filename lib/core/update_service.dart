import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final ShorebirdUpdater? _updater = kIsWeb ? null : ShorebirdUpdater();

  bool get isShorebirdActive => !kIsWeb && (_updater?.isAvailable ?? false);

  /// Comprueba en segundo plano si hay un parche OTA disponible y lo descarga
  Future<void> checkForUpdatesInBackground() async {
    if (kIsWeb) return;
    try {
      final updater = _updater;
      if (updater == null || !updater.isAvailable) {
        debugPrint('Shorebird no está disponible en este entorno (ej. Web o Debug).');
        return;
      }

      final status = await updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('Nuevo parche Shorebird disponible. Descargando en segundo plano...');
        await updater.update();
        debugPrint('Parche de Shorebird descargado con éxito. Se aplicará en el próximo inicio.');
      }
    } catch (e) {
      debugPrint('Error al verificar actualización Shorebird: $e');
    }
  }

  /// Retorna el número de parche actual instalado
  Future<int?> getCurrentPatchNumber() async {
    if (kIsWeb) return null;
    final updater = _updater;
    if (updater == null) return null;
    try {
      if (!updater.isAvailable) return null;
      final patch = await updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Verificación manual de estado
  Future<UpdateStatus> checkManual() async {
    if (kIsWeb) return UpdateStatus.unavailable;
    final updater = _updater;
    if (updater == null) return UpdateStatus.unavailable;
    try {
      if (!updater.isAvailable) return UpdateStatus.unavailable;
      return await updater.checkForUpdate();
    } catch (_) {
      return UpdateStatus.unavailable;
    }
  }

  /// Descarga el parche disponible
  Future<bool> downloadPatch() async {
    if (kIsWeb) return false;
    final updater = _updater;
    if (updater == null) return false;
    try {
      if (!updater.isAvailable) return false;
      await updater.update();
      return true;
    } catch (_) {
      return false;
    }
  }
}
