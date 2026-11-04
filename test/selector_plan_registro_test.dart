import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/features/auth/registro_bodega_sheet.dart';
import 'package:bodega_mobile/features/auth/selector_plan_registro_modal.dart';

void main() {
  group('SelectorPlanRegistroModal Tests', () {
    testWidgets('Renderiza modal con Plan PRO 1 mes gratis por defecto y comparativa completa', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? planResultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  planResultado = await SelectorPlanRegistroModal.show(ctx);
                },
                child: const Text('Abrir Selector'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      // Verificar encabezado y banner
      expect(find.text('Elige el Plan para tu Bodega'), findsOneWidget);
      expect(find.textContaining('Tu Primer Mes es 100% GRATIS'), findsOneWidget);

      // Verificar tarjetas de planes
      expect(find.text('Plan Minimarket PRO'), findsOneWidget);
      expect(find.text('Plan Bodega Básico'), findsOneWidget);
      expect(find.text('S/ 0.00'), findsOneWidget);
      expect(find.text('S/ 50.00'), findsOneWidget);

      // Verificar diferencias clave en la tabla
      expect(find.text('Capacidad de Productos en Inventario'), findsOneWidget);
      expect(find.text('Catálogo Web Online Oficial Propio'), findsOneWidget);
      expect(find.text('Kit Viralidad & Marketing de Barrio'), findsOneWidget);
      expect(find.text('Dashboard BI & Rotación ABC'), findsOneWidget);
      expect(find.text('Detector de Mercadería Hueso'), findsOneWidget);
      expect(find.text('Auditoría Ciega de Caja'), findsOneWidget);

      // Botón de confirmación por defecto en PRO
      expect(find.text('CONFIRMAR PLAN PRO (1 MES GRATIS)'), findsOneWidget);

      // Confirmar selección por defecto (PRO)
      await tester.tap(find.text('CONFIRMAR PLAN PRO (1 MES GRATIS)'));
      await tester.pumpAndSettle();

      expect(planResultado, 'PRO');
    });

    testWidgets('Permite cambiar a Plan Bodega Básico y retornar BASICO', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? planResultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  planResultado = await SelectorPlanRegistroModal.show(ctx);
                },
                child: const Text('Abrir Selector'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      // Cambiar a Plan Bodega Básico pulsando su tarjeta
      await tester.ensureVisible(find.text('Plan Bodega Básico'));
      await tester.tap(find.text('Plan Bodega Básico'));
      await tester.pumpAndSettle();

      // El botón debe actualizar su texto a Plan Básico
      expect(find.text('CONFIRMAR PLAN BÁSICO (S/ 50 / MES)'), findsOneWidget);

      // Confirmar selección
      await tester.tap(find.text('CONFIRMAR PLAN BÁSICO (S/ 50 / MES)'));
      await tester.pumpAndSettle();

      expect(planResultado, 'BASICO');
    });
  });

  group('RegistroBodegaSheet - Integración con Selector de Planes', () {
    testWidgets('Muestra por defecto Plan PRO 1 mes gratis y abre modal comparativo al pulsar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 1200,
              width: 800,
              child: RegistroBodegaSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar título del formulario de registro
      expect(find.text('Registrar mi Negocio'), findsOneWidget);

      // Verificar tarjeta de plan preseleccionado (PRO 1 mes gratis)
      expect(find.text('Plan Minimarket PRO'), findsOneWidget);
      expect(find.textContaining('1 MES GRATIS (30 DÍAS) • SELECCIONADO'), findsOneWidget);
      expect(find.text('VER TODAS LAS DIFERENCIAS DE LOS PLANES'), findsOneWidget);

      // Botón principal de registro con 1 mes gratis
      expect(find.text('CREAR BODEGA & EMPEZAR (1 MES GRATIS)'), findsOneWidget);

      // Pulsar para abrir el modal comparativo
      await tester.ensureVisible(find.text('VER TODAS LAS DIFERENCIAS DE LOS PLANES'));
      await tester.tap(find.text('VER TODAS LAS DIFERENCIAS DE LOS PLANES'));
      await tester.pumpAndSettle();

      // El modal de planes se despliega sobre el formulario
      expect(find.text('Elige el Plan para tu Bodega'), findsOneWidget);
      expect(find.text('COMPARATIVA DETALLADA DE FUNCIONES'), findsOneWidget);

      // Cambiar a Plan Básico dentro del modal
      await tester.ensureVisible(find.text('Plan Bodega Básico'));
      await tester.tap(find.text('Plan Bodega Básico'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONFIRMAR PLAN BÁSICO (S/ 50 / MES)'));
      await tester.pumpAndSettle();

      // De vuelta en el formulario de registro, ahora el plan es Básico
      expect(find.textContaining('PLAN BÁSICO SELECCIONADO'), findsOneWidget);
      expect(find.text('CREAR BODEGA (PLAN BÁSICO)'), findsOneWidget);
    });
  });
}
