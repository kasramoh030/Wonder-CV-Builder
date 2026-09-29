import 'package:cv_pro/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The app reads its settings from SharedPreferences on first frame;
    // supplying an in-memory store keeps the widget test hermetic.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boots into onboarding on a fresh install', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CvProApp()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // A first-run user must never see the dashboard before onboarding.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Build a CV'), findsWidgets);
  });

  testWidgets('renders without overflow at a small phone size', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: CvProApp()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
