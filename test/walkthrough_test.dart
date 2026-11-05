import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridmind/models/game_metadata.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/screens/walkthrough_dialog.dart';
import 'package:gridmind/services/app_persistence_service.dart';
import 'package:gridmind/services/game_registry.dart';

GameMetadata _game() => GameMetadata(
      id: 'wt_game',
      title: 'WT Game',
      description: 'Desc',
      icon: Icons.star,
      category: 'Test',
      configOptions: [],
      gameBuilder: (c, cfg) => const SizedBox(),
      walkthrough: const ['One', 'Two'],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persistence seen/reset', () async {
    final s = AppPersistenceService();
    expect(await s.hasSeenWalkthrough('a'), false);
    await s.setWalkthroughSeen('a');
    await s.setWalkthroughSeen('b');
    expect(await s.hasSeenWalkthrough('a'), true);
    await s.resetWalkthrough('a');
    expect(await s.hasSeenWalkthrough('a'), false);
    await s.resetAllWalkthroughs();
    expect(await s.hasSeenWalkthrough('b'), false);
  });

  test('default steps fall back to single description page', () {
    final g = GameMetadata(
        id: 'x', title: 't', description: 'D', icon: Icons.star,
        category: 'c', configOptions: [], gameBuilder: (c, cfg) => const SizedBox());
    expect(g.walkthroughSteps, ['D']);
  });

  test('keyboardHint is appended as the last step, and absent when null', () {
    GameMetadata g(String? hint) => GameMetadata(
        id: 'x', title: 't', description: 'D', icon: Icons.star, category: 'c',
        configOptions: [], gameBuilder: (c, cfg) => const SizedBox(),
        walkthrough: const ['One'], keyboardHint: hint);
    expect(g('Arrows').walkthroughSteps, ['One', 'Keyboard: Arrows']);
    expect(g(null).walkthroughSteps, ['One']);
  });

  test('exactly the six keyboard-enabled games carry a keyboard step', () {
    final withKeys = GameRegistry.games.where((g) => g.keyboardHint != null).map((g) => g.id).toSet();
    expect(withKeys, {'slideandsolve', 'collapse', 'grid_painter', 'grid_runner', 'rotate_matrix', 'gravity_shift'});
    for (final g in GameRegistry.games.where((g) => g.keyboardHint != null)) {
      expect(g.walkthroughSteps.last, startsWith('Keyboard: '), reason: g.id);
    }
  });

  testWidgets('shows on first launch once, can be reset and re-shown', (t) async {
    await t.pumpWidget(MaterialApp(home: BaseSetupScreen(game: _game())));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('walkthrough_dialog')), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    await t.tap(find.byKey(const Key('walkthrough_next')));
    await t.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
    await t.tap(find.byKey(const Key('walkthrough_next')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('walkthrough_dialog')), findsNothing);
    expect(await AppPersistenceService().hasSeenWalkthrough('wt_game'), true);

    // Reopen screen: not shown again.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home: BaseSetupScreen(game: _game())));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('walkthrough_dialog')), findsNothing);

    // Manual show.
    await t.tap(find.byKey(const Key('walkthrough_show')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('walkthrough_dialog')), findsOneWidget);
    await t.tap(find.byKey(const Key('walkthrough_skip')));
    await t.pumpAndSettle();

    // Reset.
    await t.tap(find.byKey(const Key('walkthrough_reset')));
    await t.pumpAndSettle();
    expect(await AppPersistenceService().hasSeenWalkthrough('wt_game'), false);
  });

  testWidgets('app intro shows once on first launch and can be reopened from Settings', (t) async {
    SharedPreferences.setMockInitialValues({'telemetry_consent_answered': true});
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) => maybeShowAppIntro(ctx));
          return const Scaffold(body: Text('Home'));
        },
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Welcome to GridMind'), findsOneWidget);
    await t.tap(find.byKey(const Key('walkthrough_skip')));
    await t.pumpAndSettle();
    expect(await AppPersistenceService().hasSeenWalkthrough(kAppIntroWalkthroughId), true);
  });
}
