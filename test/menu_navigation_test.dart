import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gridmind/main.dart';

void main() {
  group('MenuScreen Navigation Tests', () {
    testWidgets('renders MenuScreen and buttons', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.text('Simon Game'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    // Add navigation tap tests for buttons
  });
}
