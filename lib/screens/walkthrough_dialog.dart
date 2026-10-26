import 'package:flutter/material.dart';
import '../models/game_metadata.dart';
import '../services/app_persistence_service.dart';

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
  const _WalkthroughDialog({required this.game});

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
        Expanded(child: Text('How to play: ${widget.game.title}')),
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
