import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bodega_mobile/main.dart';
import 'package:bodega_mobile/core/theme_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const BodegaApp(),
      ),
    );
    expect(find.byType(BodegaApp), findsOneWidget);
  });
}
