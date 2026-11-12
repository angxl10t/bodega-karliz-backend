import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Representa una impresora térmica Bluetooth clásica (SPP) vinculada en Android.
class BluetoothPrinterDevice {
  final String name;
  final String address;

  const BluetoothPrinterDevice({required this.name, required this.address});

  factory BluetoothPrinterDevice.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothPrinterDevice(
      name: (map['name']?.toString() ?? 'Impresora Bluetooth').trim(),
      address: (map['address']?.toString() ?? '').trim(),
    );
  }
}

/// Puente multiplataforma hacia el canal nativo Android `com.cajaya.pos/bluetooth_printer`
/// para descubrir dispositivos vinculados e imprimir bytes ESC/POS directamente vía RFCOMM.
class NativeBluetoothPrinterService {
  NativeBluetoothPrinterService._();

  static const MethodChannel _channel = MethodChannel(
    'com.cajaya.pos/bluetooth_printer',
  );

  @visibleForTesting
  static bool? debugIsAndroidOverride;

  static bool get isSupportedPlatform {
    if (debugIsAndroidOverride != null) {
      return debugIsAndroidOverride!;
    }
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  /// Lista los dispositivos Bluetooth previamente vinculados en Ajustes de Android.
  static Future<List<BluetoothPrinterDevice>>
  listarImpresorasVinculadas() async {
    if (!isSupportedPlatform) {
      return const [];
    }

    final rawList = await _channel.invokeMethod<List<dynamic>>(
      'getBondedDevices',
    );
    if (rawList == null) {
      return const [];
    }

    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map(BluetoothPrinterDevice.fromMap)
        .where((d) => d.address.isNotEmpty)
        .toList();
  }

  /// Envía bytes ESC/POS crudos directamente a la impresora Bluetooth indicada.
  static Future<void> imprimirBytes(
    String address,
    List<int> escPosBytes,
  ) async {
    if (!isSupportedPlatform) {
      throw PlatformException(
        code: 'BT_UNSUPPORTED_PLATFORM',
        message: 'La impresión Bluetooth nativa directa solo está disponible en Android.',
      );
    }

    await _channel.invokeMethod<bool>('printBytes', {
      'address': address.trim(),
      'bytes': Uint8List.fromList(escPosBytes),
    });
  }
}
