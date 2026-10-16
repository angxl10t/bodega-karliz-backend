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
  });
}
