import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/screens/custom_palette_dialog.dart';

void main() {
  Future<void> pump(WidgetTester t, List<Color> init, void Function(Future<List<Color>?>) cap) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) => TextButton(onPressed: () => cap(showCustomPaletteEditor(c, init)), child: const Text('go'))),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
  }

  testWidgets('hex entry, reset and save', (t) async {
    late Future<List<Color>?> res;
    await pump(t, List.of(kDefaultCustomPalette), (f) => res = f);
    await t.enterText(find.byType(TextField), '#00ff00');
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((await res)![0], const Color(0xFF00FF00));
  });

  testWidgets('reset restores default for selected swatch', (t) async {
    late Future<List<Color>?> res;
    await pump(t, List.of(kDefaultCustomPalette), (f) => res = f);
    await t.enterText(find.byType(TextField), '123456');
    await t.pump();
    await t.tap(find.text('Reset color'));
    await t.pump();
    expect(find.widgetWithText(TextField, 'F44336'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((await res)![0].toARGB32(), kDefaultCustomPalette[0].toARGB32());
  });

  testWidgets('contrast guard warns for low-contrast swatch', (t) async {
    await pump(t, List.of(kDefaultCustomPalette), (_) {});
    expect(find.textContaining('Color 1 is hard'), findsNothing);
    await t.enterText(find.byType(TextField), 'FFFFFF');
    await t.pump();
    expect(find.text('Color 1 is hard to see on the background.'), findsOneWidget);
  });
}
