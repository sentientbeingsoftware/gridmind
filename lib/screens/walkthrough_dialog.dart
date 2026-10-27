import 'package:flutter/material.dart';
import '../models/game_metadata.dart';
import '../services/app_persistence_service.dart';

const String kAppIntroWalkthroughId = '_app_intro';

const List<String> kAppIntroSteps = [
  'Pick your board rules on any game setup screen, then tap Start Game.',
  'Your best score is saved per rule set - try beating it!',
];

/// Shows the app-wide intro walkthrough once at first launch, or on demand
/// from Settings.
Future<void> showAppIntroDialog(
  BuildContext context, {
  AppPersistenceService? persistence,
}) async {
  final svc = persistence ?? AppPersistenceService();
  final introGame = GameMetadata(
    id: kAppIntroWalkthroughId,
    title: 'Welcome to GridMind',
    description: kAppIntroSteps.first,
    icon: Icons.grid_view_rounded,
    category: '',
    configOptions: const [],
    gameBuilder: (ctx, cfg) => const SizedBox.shrink(),
    walkthrough: kAppIntroSteps,
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WalkthroughDialog(
      game: introGame,
      headerTitle: 'Welcome to GridMind',
    ),
  );
  await svc.setWalkthroughSeen(kAppIntroWalkthroughId);
}

/// Shows the app-wide intro walkthrough only if it has not been seen yet.
Future<void> maybeShowAppIntro(BuildContext context) async {
  final svc = AppPersistenceService();
  if (await svc.hasSeenWalkthrough(kAppIntroWalkthroughId)) return;
  if (!context.mounted) return;
  await showAppIntroDialog(context, persistence: svc);
}

/// Paged "How to play" walkthrough. Marks the game's walkthrough as seen
/// when closed (finished or skipped).
Future<void> showWalkthroughDialog(
  BuildContext context,
  GameMetadata game, {
  AppPersistenceService? persistence,
}) async {
  final svc = persistence ?? AppPersistenceService();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WalkthroughDialog(game: game),
  );
  await svc.setWalkthroughSeen(game.id);
}

/// Shows the walkthrough only if it has not been seen yet.
Future<void> maybeShowWalkthrough(BuildContext context, GameMetadata game) async {
  final svc = AppPersistenceService();
  if (await svc.hasSeenWalkthrough(game.id)) return;
  if (!context.mounted) return;
  await showWalkthroughDialog(context, game, persistence: svc);
}

class _WalkthroughDialog extends StatefulWidget {
  final GameMetadata game;
  final String? headerTitle;
  const _WalkthroughDialog({required this.game, this.headerTitle});

  @override
  State<_WalkthroughDialog> createState() => _WalkthroughDialogState();
}

class _WalkthroughDialogState extends State<_WalkthroughDialog> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final steps = widget.game.walkthroughSteps;
    final last = _step == steps.length - 1;
    return AlertDialog(
      key: const Key('walkthrough_dialog'),
      title: Row(children: [
        Icon(widget.game.icon),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.headerTitle ?? 'How to play: ${widget.game.title}')),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${_step + 1} of ${steps.length}',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(steps[_step]),
        ],
      ),
      actions: [
        if (!last)
          TextButton(
            key: const Key('walkthrough_skip'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Back'),
          ),
        FilledButton(
          key: const Key('walkthrough_next'),
          onPressed: last
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step++),
          child: Text(last ? 'Got it' : 'Next'),
        ),
      ],
    );
  }
}
