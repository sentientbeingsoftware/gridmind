import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';

/// Shows the first-run diagnostics prompt once. Telemetry stays off unless the
/// user explicitly allows it; the choice can be changed later in Settings.
Future<void> showTelemetryConsentIfNeeded(BuildContext context) async {
  final telemetry = TelemetryService();
  if (await telemetry.hasAnsweredConsent()) return;
  if (!context.mounted) return;

  final allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.shield_outlined),
      title: const Text('Help improve GridMind?'),
      content: const Text(
        'Share anonymous game usage stats (which game, how long, win/lose and '
        'its settings). No personal data is collected. You can change this any '
        'time in Settings > Privacy.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  await telemetry.recordConsent(allowed ?? false);
}
