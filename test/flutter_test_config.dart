import 'dart:async';

import 'package:alchemist/alchemist.dart';

// Baselines come only from the CI variant (Ahem blocks font, host-independent);
// platform goldens are off so local OS font rendering never writes baselines.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
      ciGoldensConfig: CiGoldensConfig(enabled: true),
    ),
    run: () async => testMain(),
  );
}
