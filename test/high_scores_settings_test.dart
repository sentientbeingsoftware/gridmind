import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default config exactly as BaseSetupScreen builds it.
Map<String, dynamic> _defaults(String id) {
  final game = GameRegistry.games.firstWhere((g) => g.id == id);
  return {for (final o in game.configOptions) o.key: o.defaultValue};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings High Scores shows Word Search (config-based key)', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final svc = AppPersistenceService();
    // Same shape the Word Search screen writes (setup defaults, doubles).
    await svc.updateConfigHighScore('wordsearch', _defaults('wordsearch'), 42);
    await svc.updateConfigHighScore('simon', _defaults('simon'), 5);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Simon Game'), findsOneWidget);
    expect(find.text('Word Search'), findsOneWidget);
  });

  testWidgets('every config-based game with a score on default config is listed', (tester) async {
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final svc = AppPersistenceService();
    final ids = GameRegistry.games
        .map((g) => g.id)
        .where((id) => id != 'slideandsolve')
        .toList();
    for (final id in ids) {
      await svc.updateConfigHighScore(id, _defaults(id), 7);
    }
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    for (final id in ids) {
      final title = GameRegistry.games.firstWhere((g) => g.id == id).title;
      expect(find.text(title), findsWidgets, reason: id);
    }
  });
}
