import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/mixins/config_high_score_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.lowerIsBetter});
  final bool lowerIsBetter;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ConfigHighScoreMixin<_Probe> {
  @override
  String get highScoreGameId => 'probe';
  @override
  Map<String, dynamic> get highScoreConfig => {'size': 4.0};
  @override
  bool get highScoreLowerIsBetter => widget.lowerIsBetter;
  @override
  Widget build(BuildContext context) => Text('best=${bestScore ?? '--'}');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no stored score -> null; lower-is-better keeps the minimum', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Probe(lowerIsBetter: true)));
    final state = tester.state<_ProbeState>(find.byType(_Probe));

    expect(await tester.runAsync(state.loadBestScore), isNull);
    expect(await tester.runAsync(() => state.submitScore(20)), isTrue);
    expect(await tester.runAsync(() => state.submitScore(30)), isFalse);
    expect(await tester.runAsync(() => state.submitScore(12)), isTrue);
    expect(state.bestScore, 12);
    expect(await tester.runAsync(state.loadBestScore), 12);
  });

  testWidgets('higher-is-better keeps the maximum; non-positive scores ignored', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Probe(lowerIsBetter: false)));
    final state = tester.state<_ProbeState>(find.byType(_Probe));

    expect(await tester.runAsync(() => state.submitScore(0)), isFalse);
    expect(await tester.runAsync(() => state.submitScore(5)), isTrue);
    expect(await tester.runAsync(() => state.submitScore(3)), isFalse);
    expect(await tester.runAsync(state.loadBestScore), 5);
  });
}
