import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Servicio centralizado de sonido y retroalimentación auditiva para Bodega KARLIZ.
/// Produce el característico "BEEP" de escáner de caja de supermercado con ultra-baja latencia.
class KarlizSoundService {
  KarlizSoundService._();
  static final KarlizSoundService instance = KarlizSoundService._();

  AudioPlayer? _beepPlayer;
  AudioPlayer? _errorPlayer;
  bool _isInitialized = false;

  /// Inicializa los reproductores de sonido con modo de baja latencia para respuestas inmediatas.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _beepPlayer = AudioPlayer();
      await _beepPlayer!.setPlayerMode(PlayerMode.lowLatency);
      await _beepPlayer!.setReleaseMode(ReleaseMode.stop);

      _errorPlayer = AudioPlayer();
      await _errorPlayer!.setPlayerMode(PlayerMode.lowLatency);
      await _errorPlayer!.setReleaseMode(ReleaseMode.stop);

      _isInitialized = true;
    } catch (_) {
      // Si el dispositivo tiene restricciones, continuará con haptics
    }
  }

  /// Emite el sonido de escáner POS exitoso y retroalimentación háptica.
  Future<void> playBarcodeBeep() async {
    // Retroalimentación háptica y clic del sistema inmediatos
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    try {
      if (_beepPlayer == null) {
        await init();
      }
      await _beepPlayer?.stop();
      await _beepPlayer?.play(
        AssetSource('audio/barcode_beep.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Fallback silencioso
    }
  }

  /// Emite sonido de error o advertencia (producto no encontrado, sin stock, etc.)
  Future<void> playErrorBeep() async {
    HapticFeedback.heavyImpact();

    try {
      if (_errorPlayer == null) {
        await init();
      }
      await _errorPlayer?.stop();
      await _errorPlayer?.play(
        AssetSource('audio/error_beep.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Fallback silencioso
    }
  }

  /// Libera recursos al cerrar
  void dispose() {
    _beepPlayer?.dispose();
    _errorPlayer?.dispose();
    _beepPlayer = null;
    _errorPlayer = null;
    _isInitialized = false;
  }
}
