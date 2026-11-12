import 'package:bodega_mobile/core/configuracion_ticket_service.dart';
import 'package:bodega_mobile/core/native_bluetooth_printer_service.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';
import 'package:bodega_mobile/features/ventas/hardware_mostrador_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cajaya.pos/bluetooth_printer');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NativeBluetoothPrinterService.debugIsAndroidOverride = null;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NativeBluetoothPrinterService.debugIsAndroidOverride = null;
    await ConfiguracionTicketService.guardar(const ConfiguracionTicket());
  });

  group('Impresión Bluetooth Nativa Android (SPP sin RawBT)', () {
    test('ConfiguracionTicket serializa y deserializa campos Bluetooth con retrocompatibilidad', () {
      const original = ConfiguracionTicket(
        modoConexion: 'bluetooth_nativo',
        bluetoothDeviceName: 'InnerPrinter 58mm',
        bluetoothDeviceAddress: '00:11:22:33:44:55',
      );

      final json = original.toJson();
      expect(json['modoConexion'], equals('bluetooth_nativo'));
      expect(json['bluetoothDeviceName'], equals('InnerPrinter 58mm'));
      expect(json['bluetoothDeviceAddress'], equals('00:11:22:33:44:55'));

      final parsed = ConfiguracionTicket.fromJson(json);
      expect(parsed.modoConexion, equals('bluetooth_nativo'));
      expect(parsed.bluetoothDeviceName, equals('InnerPrinter 58mm'));
      expect(parsed.bluetoothDeviceAddress, equals('00:11:22:33:44:55'));

      // JSON antiguo sin claves Bluetooth no falla
      final legacy = ConfiguracionTicket.fromJson({'modoConexion': 'rawbt'});
      expect(legacy.modoConexion, equals('rawbt'));
      expect(legacy.bluetoothDeviceName, isEmpty);
      expect(legacy.bluetoothDeviceAddress, isEmpty);
    });

    test('NativeBluetoothPrinterService lista dispositivos vinculados vía MethodChannel en Android', () async {
      NativeBluetoothPrinterService.debugIsAndroidOverride = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'getBondedDevices') {
              return [
                {'name': 'Xprinter XP-58IIH', 'address': 'AA:BB:CC:11:22:33'},
                {'name': 'Sin MAC', 'address': '   '},
              ];
            }
            return null;
          });

      final devices =
          await NativeBluetoothPrinterService.listarImpresorasVinculadas();
      expect(devices, hasLength(1));
      expect(devices.first.name, equals('Xprinter XP-58IIH'));
      expect(devices.first.address, equals('AA:BB:CC:11:22:33'));
    });

    test(
      'NativeBluetoothPrinterService protege plataformas no Android',
      () async {
        NativeBluetoothPrinterService.debugIsAndroidOverride = false;

        final devices =
            await NativeBluetoothPrinterService.listarImpresorasVinculadas();
        expect(devices, isEmpty);

        await expectLater(
          NativeBluetoothPrinterService.imprimirBytes('AA:BB:CC:11:22:33', [
            1,
            2,
          ]),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'BT_UNSUPPORTED_PLATFORM',
            ),
          ),
        );
      },
    );

    test('ThermalTicketService valida plataforma y dirección antes de imprimir en bluetooth_nativo', () async {
      NativeBluetoothPrinterService.debugIsAndroidOverride = false;
      const desktopCfg = ConfiguracionTicket(
        modoConexion: 'bluetooth_nativo',
        bluetoothDeviceAddress: 'AA:BB:CC:11:22:33',
      );
      final nonAndroidRes = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: const [0x1B, 0x40],
        receiptText: 'TEST',
        config: desktopCfg,
      );
      expect(nonAndroidRes.exito, isFalse);
      expect(nonAndroidRes.necesitaRawBt, isFalse);
      expect(nonAndroidRes.mensaje, contains('Android'));

      NativeBluetoothPrinterService.debugIsAndroidOverride = true;
      const missingAddrCfg = ConfiguracionTicket(
        modoConexion: 'bluetooth_nativo',
      );
      final missingAddrRes = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: const [0x1B, 0x40],
        receiptText: 'TEST',
        config: missingAddrCfg,
      );
      expect(missingAddrRes.exito, isFalse);
      expect(missingAddrRes.mensaje, contains('Selecciona primero'));
    });

    test('ThermalTicketService envía bytes ESC/POS y reporta errores nativos en bluetooth_nativo', () async {
      NativeBluetoothPrinterService.debugIsAndroidOverride = true;

      String? capturedAddress;
      Uint8List? capturedBytes;
      bool shouldFail = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'printBytes') {
              if (shouldFail) {
                throw PlatformException(
                  code: 'BT_IO_ERROR',
                  message: 'No se pudo conectar con la ticketera.',
                );
              }
              final args = Map<String, dynamic>.from(call.arguments as Map);
              capturedAddress = args['address'] as String?;
              capturedBytes = args['bytes'] as Uint8List?;
              return true;
            }
            return null;
          });

      const cfg = ConfiguracionTicket(
        modoConexion: 'bluetooth_nativo',
        bluetoothDeviceName: 'POS-58',
        bluetoothDeviceAddress: '11:22:33:44:55:66',
      );

      final okRes = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: const [0x1B, 0x40, 0x41],
        receiptText: 'A',
        config: cfg,
      );
      expect(okRes.exito, isTrue);
      expect(okRes.mensaje, contains('POS-58'));
      expect(capturedAddress, equals('11:22:33:44:55:66'));
      expect(capturedBytes, equals(Uint8List.fromList([0x1B, 0x40, 0x41])));

      shouldFail = true;
      final errRes = await ThermalTicketService.imprimirTicketDirecto(
        escPosBytes: const [0x1B, 0x40],
        receiptText: 'A',
        config: cfg,
      );
      expect(errRes.exito, isFalse);
      expect(errRes.mensaje, contains('No se pudo conectar'));
    });

    testWidgets(
      'HardwareMostradorModal permite activar Bluetooth Nativo y elegir ticketera vinculada',
      (WidgetTester tester) async {
        NativeBluetoothPrinterService.debugIsAndroidOverride = true;
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'getBondedDevices') {
                return [
                  {
                    'name': 'Ticketera Bodega BT',
                    'address': 'DE:AD:BE:EF:00:01',
                  },
                ];
              }
              return null;
            });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => HardwareMostradorModal.show(ctx),
                    child: const Text('Abrir Hardware'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Hardware'));
        await tester.pumpAndSettle();

        final btCard = find.textContaining('Bluetooth Nativo Android');
        await tester.ensureVisible(btCard);
        await tester.tap(btCard);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('bluetooth_scan_button')), findsOneWidget);
        expect(find.text('Ticketera Bodega BT'), findsOneWidget);
        expect(find.text('DE:AD:BE:EF:00:01'), findsOneWidget);

        await tester.ensureVisible(find.text('Ticketera Bodega BT'));
        await tester.tap(find.text('Ticketera Bodega BT'));
        await tester.pumpAndSettle();

        expect(
          ConfiguracionTicketService.actual.modoConexion,
          equals('bluetooth_nativo'),
        );
        expect(
          ConfiguracionTicketService.actual.bluetoothDeviceName,
          equals('Ticketera Bodega BT'),
        );
        expect(
          ConfiguracionTicketService.actual.bluetoothDeviceAddress,
          equals('DE:AD:BE:EF:00:01'),
        );
        expect(find.text('ACTIVA'), findsOneWidget);
      },
    );
  });
}
