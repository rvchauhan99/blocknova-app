// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blocknova_app/main.dart';
import 'package:blocknova_app/platform_services/analytics/analytics_service.dart';
import 'package:blocknova_app/theme/blastnova_brand.dart';

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('Bootstrap shows splash then home', (WidgetTester tester) async {
    await tester.pumpWidget(BlockNovaApp(analytics: DebugAnalyticsService()));

    expect(find.text(BlastNovaBrand.kBrandWordmark), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();

    expect(find.text('PLAY'), findsOneWidget);
  });
}
