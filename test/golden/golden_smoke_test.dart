import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Multi-config scenarios: add widgets under test as scenarios.
void main() {
  goldenTest(
    'golden framework smoke',
    fileName: 'golden_smoke',
    builder: () => GoldenTestGroup(
      scenarioConstraints: const BoxConstraints(maxWidth: 200),
      children: [
        for (final scale in [1.0, 1.5, 2.0])
          GoldenTestScenario(
            name: 'text x$scale',
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Text('GridMind'),
            ),
          ),
      ],
    ),
  );
}
