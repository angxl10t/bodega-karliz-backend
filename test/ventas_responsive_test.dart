import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodega_mobile/core/responsive_layout.dart';

void main() {
  group('ResponsiveLayout Breakpoint & Builder Tests', () {
    testWidgets('ResponsiveBuilder renders mobile layout on small width (< 650dp)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (ctx, constraints) => const Text('VISTA_MOVIL'),
              tablet: (ctx, constraints) => const Text('VISTA_TABLET'),
            ),
          ),
        ),
      );

      expect(find.text('VISTA_MOVIL'), findsOneWidget);
      expect(find.text('VISTA_TABLET'), findsNothing);
    });

    testWidgets('ResponsiveBuilder renders tablet layout on wider width (>= 650dp)', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (ctx, constraints) => const Text('VISTA_MOVIL'),
              tablet: (ctx, constraints) => const Text('VISTA_TABLET'),
            ),
          ),
        ),
      );

      expect(find.text('VISTA_TABLET'), findsOneWidget);
      expect(find.text('VISTA_MOVIL'), findsNothing);
    });

    testWidgets('ResponsiveLayout detects physical tablet (shortestSide >= 600) and landscape', (tester) async {
      // Configuración de tablet 10 pulgadas en orientación horizontal (1280 x 800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late bool isTabletDetected;
      late bool isLandscapeDetected;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              isTabletDetected = ResponsiveLayout.isPhysicalTablet(ctx);
              isLandscapeDetected = ResponsiveLayout.isLandscape(ctx);
              return Container();
            },
          ),
        ),
      );

      expect(isTabletDetected, isTrue);
      expect(isLandscapeDetected, isTrue);
    });

    testWidgets('ResponsiveLayout detects smartphone (shortestSide < 600) in portrait', (tester) async {
      // Smartphone estándar en orientación vertical (390 x 844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late bool isTabletDetected;
      late bool isLandscapeDetected;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              isTabletDetected = ResponsiveLayout.isPhysicalTablet(ctx);
              isLandscapeDetected = ResponsiveLayout.isLandscape(ctx);
              return Container();
            },
          ),
        ),
      );

      expect(isTabletDetected, isFalse);
      expect(isLandscapeDetected, isFalse);
    });
  });
}
