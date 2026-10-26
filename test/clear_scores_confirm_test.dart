import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int> _simonScore() {
  final game = GameRegistry.games.firstWhere((g) => g.id == 'simon');
  final config = game.resolveConfig(null);
  return AppPersistenceService().getConfigHighScore('simon', config);
}

Future<void> _openSettingsAndTapClear(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final game = GameRegistry.games.firstWhere((g) => g.id == 'simon');
  await AppPersistenceService()
      .updateConfigHighScore('simon', game.resolveConfig(null), 9);

  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Clear All High Scores'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping clear asks first and Cancel keeps scores', (tester) async {
    await _openSettingsAndTapClear(tester);

    expect(find.text('Clear all high scores?'), findsOneWidget);
    expect(await _simonScore(), 9, reason: 'nothing deleted before confirming');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear all high scores?'), findsNothing);
    expect(await _simonScore(), 9);
    expect(find.text('All high scores cleared.'), findsNothing);
  });

  testWidgets('confirming deletes the scores', (tester) async {
    await _openSettingsAndTapClear(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(await _simonScore(), 0);
    expect(find.text('All high scores cleared.'), findsOneWidget);
  });
}
