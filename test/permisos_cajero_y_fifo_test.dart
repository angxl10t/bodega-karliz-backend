import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bodega_mobile/core/permisos_cajero_service.dart';
import 'package:bodega_mobile/features/auth/auth_service.dart';
import 'package:bodega_mobile/features/productos/producto_model.dart';
import 'package:bodega_mobile/features/home/permisos_cajero_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'id_bodega': '1'});
    PermisosCajeroService.resetMemory();
  });

  group('PermisosCajero - Modelo & Presets', () {
    test('Valores por defecto son seguros para un negocio estándar', () {
      const p = PermisosCajero();
      expect(p.verCostosYMargen, isFalse);
      expect(p.aplicarDescuentosManuales, isTrue);
      expect(p.anularVentasSinPin, isFalse);
      expect(p.modificarPreciosVenta, isFalse);
      expect(p.verReportesFinanzas, isFalse);
    });

    test(
      'Preset Seguridad Máxima restringe todas las operaciones sensibles',
      () {
        final p = PermisosCajero.seguridadMaxima();
        expect(p.verCostosYMargen, isFalse);
        expect(p.aplicarDescuentosManuales, isFalse);
        expect(p.anularVentasSinPin, isFalse);
        expect(p.modificarPreciosVenta, isFalse);
        expect(p.verReportesFinanzas, isFalse);
      },
    );

    test('Preset Cajero Encargado otorga mayor autonomía de mostrador', () {
      final p = PermisosCajero.cajeroEncargado();
      expect(p.verCostosYMargen, isTrue);
      expect(p.aplicarDescuentosManuales, isTrue);
      expect(p.anularVentasSinPin, isTrue);
      expect(p.modificarPreciosVenta, isTrue);
      expect(p.verReportesFinanzas, isFalse);
    });

    test('Serialización JSON y copyWith funcionan sin pérdida de datos', () {
      const p1 = PermisosCajero(
        verCostosYMargen: true,
        aplicarDescuentosManuales: false,
        anularVentasSinPin: true,
        modificarPreciosVenta: false,
        verReportesFinanzas: true,
      );
      final json = p1.toJson();
      final p2 = PermisosCajero.fromJson(json);

      expect(p2.verCostosYMargen, equals(p1.verCostosYMargen));
      expect(
        p2.aplicarDescuentosManuales,
        equals(p1.aplicarDescuentosManuales),
      );
      expect(p2.anularVentasSinPin, equals(p1.anularVentasSinPin));
      expect(p2.modificarPreciosVenta, equals(p1.modificarPreciosVenta));
      expect(p2.verReportesFinanzas, equals(p1.verReportesFinanzas));

      final p3 = p2.copyWith(verCostosYMargen: false);
      expect(p3.verCostosYMargen, isFalse);
      expect(p3.anularVentasSinPin, isTrue);
    });
  });

  group('PermisosCajeroService - Persistencia & Reglas de Rol', () {
    test(
      'Guarda y recupera permisos específicos de bodega en SharedPreferences',
      () async {
        const custom = PermisosCajero(
          verCostosYMargen: true,
          aplicarDescuentosManuales: false,
          anularVentasSinPin: true,
          modificarPreciosVenta: true,
          verReportesFinanzas: false,
        );

        await PermisosCajeroService.guardarPermisos(custom, bodegaId: '99');
        final recuperado = await PermisosCajeroService.obtenerPermisos(
          bodegaId: '99',
        );

        expect(recuperado.verCostosYMargen, isTrue);
        expect(recuperado.aplicarDescuentosManuales, isFalse);
        expect(recuperado.anularVentasSinPin, isTrue);
        expect(recuperado.modificarPreciosVenta, isTrue);
        expect(recuperado.verReportesFinanzas, isFalse);
      },
    );

    test('Administrador siempre tiene permisos totales sin importar la política de cajero', () {
      AuthService.setCachedRol('ADMIN');
      expect(PermisosCajeroService.puedeVerCostos, isTrue);
      expect(PermisosCajeroService.puedeAplicarDescuentos, isTrue);
      expect(PermisosCajeroService.puedeAnularSinPin, isTrue);
      expect(PermisosCajeroService.puedeModificarPrecios, isTrue);
      expect(PermisosCajeroService.puedeVerFinanzas, isTrue);
    });

    test(
      'Cajero respeta los permisos granulares asignados por el Admin',
      () async {
        AuthService.setCachedRol('CAJERO');
        // Con configuración por defecto:
        await PermisosCajeroService.guardarPermisos(
          const PermisosCajero(
            verCostosYMargen: false,
            aplicarDescuentosManuales: true,
            anularVentasSinPin: false,
            modificarPreciosVenta: false,
            verReportesFinanzas: false,
          ),
          bodegaId: '1',
        );

        expect(PermisosCajeroService.puedeVerCostos, isFalse);
        expect(PermisosCajeroService.puedeAplicarDescuentos, isTrue);
        expect(PermisosCajeroService.puedeAnularSinPin, isFalse);
        expect(PermisosCajeroService.puedeModificarPrecios, isFalse);
        expect(PermisosCajeroService.puedeVerFinanzas, isFalse);

        // Si el Admin activa verCostosYMargen y anularSinPin:
        await PermisosCajeroService.guardarPermisos(
          const PermisosCajero(
            verCostosYMargen: true,
            aplicarDescuentosManuales: true,
            anularVentasSinPin: true,
            modificarPreciosVenta: false,
            verReportesFinanzas: false,
          ),
          bodegaId: '1',
        );

        expect(PermisosCajeroService.puedeVerCostos, isTrue);
        expect(PermisosCajeroService.puedeAnularSinPin, isTrue);
        expect(PermisosCajeroService.puedeModificarPrecios, isFalse);
      },
    );
  });

  group('Control de Vencimiento FIFO - Lógica & Rotación de Góndola', () {
    test(
      'Clasifica correctamente lotes vencidos, críticos y en rotación FIFO',
      () {
        final now = DateTime.now();

        // Producto vencido hace 2 días
        final vencido = Producto(
          codigo: 'VENC-01',
          nombre: 'Leche Fresca Vencida',
          precioVenta: 5.50,
          stockActual: 10,
          controlaVencimiento: true,
          fechaVencimiento: now.subtract(const Duration(days: 2)),
        );

        expect(vencido.diasParaVencer! <= 0, isTrue);
        expect(
          vencido.semaforoVencimiento,
          equals(SemaforoVencimiento.critico),
        );

        // Producto crítico (vence en 3 días)
        final critico = Producto(
          codigo: 'CRIT-01',
          nombre: 'Yogurt Fresa Crítico',
          precioVenta: 7.00,
          stockActual: 6,
          controlaVencimiento: true,
          fechaVencimiento: now.add(const Duration(days: 3)),
        );

        expect(critico.diasParaVencer, inInclusiveRange(1, 7));
        expect(
          critico.semaforoVencimiento,
          equals(SemaforoVencimiento.critico),
        );

        // Producto en rotación FIFO (vence en 18 días)
        final rotacion = Producto(
          codigo: 'ROTA-01',
          nombre: 'Galletas Rellenas',
          precioVenta: 2.00,
          stockActual: 24,
          controlaVencimiento: true,
          fechaVencimiento: now.add(const Duration(days: 18)),
        );

        expect(rotacion.diasParaVencer, inInclusiveRange(8, 30));
        expect(
          rotacion.semaforoVencimiento,
          equals(SemaforoVencimiento.atencion),
        );

        // Producto vigente (> 60 días)
        final vigente = Producto(
          codigo: 'VIG-01',
          nombre: 'Conserva de Atún',
          precioVenta: 4.80,
          stockActual: 40,
          controlaVencimiento: true,
          fechaVencimiento: now.add(const Duration(days: 90)),
        );

        expect(vigente.diasParaVencer! > 30, isTrue);
        expect(
          vigente.semaforoVencimiento,
          equals(SemaforoVencimiento.vigente),
        );
      },
    );

    test('Ordenamiento FIFO sitúa primero los lotes con menor vida útil', () {
      final now = DateTime.now();
      final p1 = Producto(
        codigo: 'A',
        nombre: 'Harina (Vence en 60d)',
        precioVenta: 3.0,
        stockActual: 10,
        controlaVencimiento: true,
        fechaVencimiento: now.add(const Duration(days: 60)),
      );
      final p2 = Producto(
        codigo: 'B',
        nombre: 'Queso Fresco (Vencido)',
        precioVenta: 12.0,
        stockActual: 4,
        controlaVencimiento: true,
        fechaVencimiento: now.subtract(const Duration(days: 1)),
      );
      final p3 = Producto(
        codigo: 'C',
        nombre: 'Pan de Molde (Vence en 2d)',
        precioVenta: 6.5,
        stockActual: 8,
        controlaVencimiento: true,
        fechaVencimiento: now.add(const Duration(days: 2)),
      );
      final p4 = Producto(
        codigo: 'D',
        nombre: 'Fideos (Sin vencimiento)',
        precioVenta: 2.5,
        stockActual: 50,
        controlaVencimiento: false,
      );

      final lista = [p1, p4, p2, p3];

      // Ordenar con regla FIFO
      lista.sort((a, b) {
        final aExp = a.controlaVencimiento && a.fechaVencimiento != null;
        final bExp = b.controlaVencimiento && b.fechaVencimiento != null;
        if (aExp && !bExp) return -1;
        if (!aExp && bExp) return 1;
        if (aExp && bExp) {
          final cmp = a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
          if (cmp != 0) return cmp;
        }
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });

      // El orden FIFO estricto debe ser: Queso (vencido) -> Pan (2d) -> Harina (60d) -> Fideos (sin vencimiento)
      expect(lista[0].codigo, equals('B'));
      expect(lista[1].codigo, equals('C'));
      expect(lista[2].codigo, equals('A'));
      expect(lista[3].codigo, equals('D'));
    });
  });

  group('PermisosCajeroModal - Renderizado y Ergonomía UI', () {
    testWidgets('Muestra correctamente los 5 switches y chips de presets', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PermisosCajeroModal())),
      );

      await tester.pump();

      expect(find.text('Permisos de Cajero'), findsOneWidget);
      expect(find.text('ROL CAJERO'), findsOneWidget);
      expect(find.text('Máxima Seguridad'), findsOneWidget);
      expect(find.text('Estándar Bodega'), findsOneWidget);
      expect(find.text('Cajero Encargado'), findsOneWidget);

      expect(find.text('Ver Costos de Compra y Margen'), findsOneWidget);
      expect(find.text('Aplicar Descuentos en Mostrador'), findsOneWidget);
      expect(find.text('Anular Ventas sin PIN de Admin'), findsOneWidget);
      expect(find.text('Modificar Precios y Catálogo'), findsOneWidget);
      expect(find.text('Acceso a Finanzas y Utilidades (BI)'), findsOneWidget);

      expect(find.text('Guardar Configuración de Permisos'), findsOneWidget);
    });
  });
}
