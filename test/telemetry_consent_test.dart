import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/main.dart';
import 'package:gridmind/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first launch asks; "No thanks" keeps telemetry off and is remembered', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Help improve GridMind?'), findsOneWidget);

    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    final t = TelemetryService();
    expect((await tester.runAsync(t.isEnabled)), isFalse);
    expect((await tester.runAsync(t.hasAnsweredConsent)), isTrue);

    // Relaunch: no second prompt.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Help improve GridMind?'), findsNothing);
  });

  testWidgets('"Allow" enables telemetry', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(TelemetryService().isEnabled)), isTrue);
  });
}
