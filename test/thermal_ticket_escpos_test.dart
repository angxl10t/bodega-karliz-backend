import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/configuracion_ticket_service.dart';
import 'package:bodega_mobile/core/thermal_ticket_service.dart';

void main() {
  group('ConfiguracionTicket & Service Tests', () {
    test('ConfiguracionTicket defaults are correct for standard 58mm mobile POS', () {
      const config = ConfiguracionTicket();
      expect(config.anchoPapel, equals(32));
      expect(config.abrirGaveta, isTrue);
      expect(config.impresionAutomatica, isFalse);
      expect(config.modoConexion, equals('rawbt'));
      expect(config.mostrarQr, isTrue);
      expect(config.tipoQr, equals('YAPE'));
      expect(config.mensajeAgradecimiento, contains('Gracias por su compra'));
    });

    test('ConfiguracionTicket serialization and deserialization cycle', () {
      const original = ConfiguracionTicket(
        anchoPapel: 48,
        abrirGaveta: false,
        impresionAutomatica: true,
        modoConexion: 'servidor_local',
        servidorLocalUrl: 'http://192.168.1.100:9100/',
        mensajeAgradecimiento: '¡Vuelva pronto!',
        mensajeSecundario: 'No se aceptan devoluciones sin ticket',
        horarioAtencion: 'Lun-Sab 8am-10pm',
        redesSociales: 'FB: @bodegakarliz',
        mostrarQr: true,
        tipoQr: 'PLIN',
        numeroQr: '987111222',
        titularQr: 'Carlos R.',
      );

      final json = original.toJson();
      final recovered = ConfiguracionTicket.fromJson(json);

      expect(recovered.anchoPapel, equals(48));
      expect(recovered.abrirGaveta, isFalse);
      expect(recovered.impresionAutomatica, isTrue);
      expect(recovered.modoConexion, equals('servidor_local'));
      expect(recovered.servidorLocalUrl, equals('http://192.168.1.100:9100/'));
      expect(recovered.mensajeAgradecimiento, equals('¡Vuelva pronto!'));
      expect(recovered.mensajeSecundario, equals('No se aceptan devoluciones sin ticket'));
      expect(recovered.horarioAtencion, equals('Lun-Sab 8am-10pm'));
      expect(recovered.redesSociales, equals('FB: @bodegakarliz'));
      expect(recovered.mostrarQr, isTrue);
      expect(recovered.tipoQr, equals('PLIN'));
      expect(recovered.numeroQr, equals('987111222'));
      expect(recovered.titularQr, equals('Carlos R.'));
    });

    test('ConfiguracionTicket copyWith updates specific fields cleanly', () {
      const initial = ConfiguracionTicket(anchoPapel: 32, abrirGaveta: true);
      final updated = initial.copyWith(anchoPapel: 48, impresionAutomatica: true);

      expect(updated.anchoPapel, equals(48));
      expect(updated.abrirGaveta, isTrue);
      expect(updated.impresionAutomatica, isTrue);
    });

    test('ConfiguracionTicketService in-memory and persistence initialization', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final config = await ConfiguracionTicketService.cargar();
      expect(config, isNotNull);
      expect(ConfiguracionTicketService.actual, isNotNull);

      await ConfiguracionTicketService.guardar(
        const ConfiguracionTicket(anchoPapel: 48, numeroQr: '999888777'),
      );
      expect(ConfiguracionTicketService.actual.anchoPapel, equals(48));
      expect(ConfiguracionTicketService.actual.numeroQr, equals('999888777'));
    });
  });

  group('ThermalTicketService ESC/POS Commands & Formatting', () {
    test('Cash Drawer kick pulse bytes comply with ESC/POS standards', () {
      final pulse = ThermalTicketService.openDrawerBytes;
      // ESC p 0 25 250 (Pin 2) y ESC p 1 25 250 (Pin 5)
      expect(pulse, containsAllInOrder([0x1B, 0x70, 0x00, 0x19, 0xFA]));
      expect(pulse, containsAllInOrder([0x1B, 0x70, 0x01, 0x19, 0xFA]));
    });

    test('Paper cut command complies with GS V standard', () {
      final cut = ThermalTicketService.cutPaperBytes;
      expect(cut, equals([0x1D, 0x56, 0x42, 0x00]));
    });

    test('generateEscPosQrBytes produces standard GS ( k Model 2 sequences', () {
      const qrData = 'https://yape.pe/p/987654321';
      final qrBytes = ThermalTicketService.generateEscPosQrBytes(qrData, moduleSize: 5);

      expect(qrBytes, isNotEmpty);
      // GS ( k Model 2 setup: 0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00
      expect(qrBytes, containsAllInOrder([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]));
      // Print QR: 0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30
      expect(qrBytes, containsAllInOrder([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]));
      // Must contain utf8 encoded data
      expect(qrBytes, containsAllInOrder(utf8.encode(qrData)));
    });

    test('Text sanitization removes non-ASCII and accents safely for CP437', () {
      const rawText = '¡Atención Bodega Ramón & Cía! ¿Cuánto cuesta el azúcar?';
      final clean = ThermalTicketService.sanitize(rawText);

      expect(clean, contains('Atencion Bodega Ramon'));
      expect(clean, contains('Cuanto cuesta el azucar'));
      expect(clean.contains('¡'), isFalse);
      expect(clean.contains('¿'), isFalse);
      expect(clean.contains('ó'), isFalse);
      expect(clean.contains('á'), isFalse);
    });

    test('Two columns helper respects 58mm (32) and 80mm (48) boundary lengths', () {
      final line58 = ThermalTicketService.twoColumns('TOTAL A PAGAR:', 'S/ 15.50', ThermalTicketService.width58mm);
      expect(line58.length, equals(32));
      expect(line58.startsWith('TOTAL A PAGAR:'), isTrue);
      expect(line58.endsWith('S/ 15.50'), isTrue);

      final line80 = ThermalTicketService.twoColumns('TOTAL A PAGAR:', 'S/ 1500.00', ThermalTicketService.width80mm);
      expect(line80.length, equals(48));
      expect(line80.startsWith('TOTAL A PAGAR:'), isTrue);
      expect(line80.endsWith('S/ 1500.00'), isTrue);
    });

    test('generateReceiptText includes custom footer and Yape QR section', () {
      const customConfig = ConfiguracionTicket(
        anchoPapel: 32,
        mensajeAgradecimiento: '¡Gracias por su lealtad!',
        mensajeSecundario: 'Garantia de 7 dias',
        horarioAtencion: 'Lun-Dom 6am-11pm',
        redesSociales: 'WhatsApp: 999 888 777',
        mostrarQr: true,
        tipoQr: 'YAPE',
        numeroQr: '999888777',
        titularQr: 'Karliz Bodega',
      );

      final text = ThermalTicketService.generateReceiptText(
        ticketId: 101,
        clienteNombre: 'Maria Ramos',
        clienteDocumento: '44556677',
        metodoPago: 'Efectivo',
        items: [
          TicketItem(nombre: 'Leche Gloria Azul', cantidad: 2, precioUnitario: 4.20, subtotal: 8.40),
        ],
        total: 8.40,
        pagadoCon: 10.00,
        vuelto: 1.60,
        nombreComercio: 'Bodega Karliz',
        configTicket: customConfig,
      );

      expect(text, contains('Bodega Karliz'));
      expect(text, contains('TOTAL A PAGAR:'));
      expect(text, contains('S/ 8.40'));
      expect(text, contains('PAGA CON YAPE ESCANEANDO:'));
      expect(text, contains('999888777'));
      expect(text, contains('Karliz Bodega'));
      expect(text, contains('[qr]999888777[/qr]'));
      expect(text, contains('Gracias por su lealtad'));
      expect(text, contains('Garantia de 7 dias'));
      expect(text, contains('Lun-Dom 6am-11pm'));
      expect(text, contains('WhatsApp: 999 888 777'));
    });

    test('generateEscPosBytes prepends cash drawer kick pulse on cash sale when enabled', () {
      const configWithDrawer = ConfiguracionTicket(
        abrirGaveta: true,
        mostrarQr: true,
        numeroQr: '987654321',
      );

      final bytesCash = ThermalTicketService.generateEscPosBytes(
        ticketId: 202,
        clienteNombre: 'Juan Perez',
        clienteDocumento: null,
        metodoPago: 'Efectivo',
        items: [
          TicketItem(nombre: 'Arroz Costeño 1kg', cantidad: 1, precioUnitario: 4.50, subtotal: 4.50),
        ],
        total: 4.50,
        configTicket: configWithDrawer,
      );

      // Los primeros bytes deben ser el pulso de apertura de cajón
      expect(bytesCash.sublist(0, 5), equals([0x1B, 0x70, 0x00, 0x19, 0xFA]));

      // Y los últimos bytes deben ser el corte de papel
      expect(bytesCash.sublist(bytesCash.length - 4), equals([0x1D, 0x56, 0x42, 0x00]));
    });

    test('generateEscPosBytes does NOT prepend cash drawer on Yape sale unless forced', () {
      const config = ConfiguracionTicket(abrirGaveta: true);

      final bytesYape = ThermalTicketService.generateEscPosBytes(
        ticketId: 203,
        clienteNombre: 'Cliente Yape',
        clienteDocumento: null,
        metodoPago: 'Yape',
        items: [
          TicketItem(nombre: 'Atun Primor', cantidad: 1, precioUnitario: 6.00, subtotal: 6.00),
        ],
        total: 6.00,
        configTicket: config,
        forzarAperturaGaveta: false,
      );

      // Comienza con ESC @ (0x1B, 0x40), no con pulso de cajón
      expect(bytesYape.sublist(0, 2), equals([0x1B, 0x40]));
    });
  });
}
