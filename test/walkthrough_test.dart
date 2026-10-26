import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridmind/models/game_metadata.dart';
import 'package:gridmind/screens/base_setup_screen.dart';
import 'package:gridmind/services/app_persistence_service.dart';

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

  test('default steps fall back to description', () {
    final g = GameMetadata(
        id: 'x', title: 't', description: 'D', icon: Icons.star,
        category: 'c', configOptions: [], gameBuilder: (c, cfg) => const SizedBox());
    expect(g.walkthroughSteps.first, 'D');
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
}
