import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/menu_screen.dart';
import 'package:gridmind/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = {
  'phone': Size(360, 640),
  'tablet': Size(600, 800),
  'desktop': Size(1024, 640),
};

Widget _app(Widget home, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent, brightness: b),
      ),
      home: home,
    );

// Real screens, each size rendered in light and dark (one PNG per screen x size).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'telemetry_consent_answered': true,
        'walkthrough_seen__app_intro': true,
      }));

  final screens = <String, Widget Function()>{
    'menu': () => const MenuScreen(),
    'settings': () => const SettingsScreen(),
  };

  for (final screen in screens.entries) {
    for (final size in _sizes.entries) {
      goldenTest(
        '${screen.key} @ ${size.key}',
        fileName: '${screen.key}_${size.key}',
        tags: ['golden'],
        constraints: BoxConstraints.tight(
            Size(size.value.width * 2 + 40, size.value.height + 40)),
        builder: () => GoldenTestGroup(
          columns: 2,
          scenarioConstraints: BoxConstraints.tight(size.value),
          children: [
            for (final b in Brightness.values)
              GoldenTestScenario(
                name: b.name,
                child: _app(screen.value(), b),
              ),
          ],
        ),
      );
    }
  }
}
