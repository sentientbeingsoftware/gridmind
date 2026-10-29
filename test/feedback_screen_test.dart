import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gridmind/screens/feedback_screen.dart';
import 'package:gridmind/services/feedback_service.dart';

void main() {
  group('FeedbackService Unit Tests', () {
    test('submitFeedback returns success on 201 Created', () async {
      // Arrange
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://error.jeremyclark.foo/v1/feedback');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], startsWith('Bearer '));
        expect(request.headers['Content-Type'], 'application/json');

        final payload = jsonDecode(request.body);
        expect(payload['app_id'], 'Gridmind');
        expect(payload['title'], '[Bug Report] App crashed');

        return http.Response(
          jsonEncode({
            'issue_number': 42,
            'issue_url': 'https://github.com/sentientbeingsoftware/gridmind/issues/42'
          }),
          201,
        );
      });

      final service = FeedbackService(client: mockClient);

      // Act
      final result = await service.submitFeedback(
        title: 'App crashed',
        body: 'Details of the crash',
        feedbackType: 'Bug Report',
      );

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.issueNumber, 42);
      expect(result.issueUrl, 'https://github.com/sentientbeingsoftware/gridmind/issues/42');
      expect(result.errorMessage, isEmpty);
    });

    test('submitFeedback includes email in telemetry and final body', () async {
      // Arrange
      final mockClient = MockClient((request) async {
        final payload = jsonDecode(request.body);
        expect(payload['telemetry']['email'], 'user@example.com');
        expect(payload['body'], isNot(contains('user@example.com')));
        expect(payload['device_model'], isNot(contains('localhost')));

        return http.Response(
          jsonEncode({
            'issue_number': 42,
            'issue_url': 'https://github.com/sentientbeingsoftware/gridmind/issues/42'
          }),
          201,
        );
      });

      final service = FeedbackService(client: mockClient);

      // Act
      final result = await service.submitFeedback(
        title: 'App crashed',
        body: 'Details of the crash',
        feedbackType: 'Bug Report',
        email: 'user@example.com',
      );

      // Assert
      expect(result.isSuccess, isTrue);
    });

    test('submitFeedback explains a 429 rate limit in plain words', () async {
      final service = FeedbackService(
        client: MockClient((_) async => http.Response(jsonEncode({'detail': 'Rate limit exceeded'}), 429, headers: {'retry-after': '3600'})),
      );
      final result = await service.submitFeedback(title: 'x', body: 'y', feedbackType: 'Bug Report');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Too many feedback messages'));
      expect(result.errorMessage, isNot(contains('429')));
    });

    test('submitFeedback returns failure on 401 Unauthorized', () async {
      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid API Key'}),
          401,
        );
      });
      final service = FeedbackService(client: mockClient);

      // Act
      final result = await service.submitFeedback(
        title: 'App crashed',
        body: 'Details',
        feedbackType: 'Bug Report',
      );

      // Assert
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Invalid API Key');
    });

    test('submitFeedback handles 422 validation failure', () async {
      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': [
              {
                'type': 'string_too_short',
                'loc': ['body', 'title'],
                'msg': 'String should have at least 1 character',
                'input': ''
              }
            ]
          }),
          422,
        );
      });
      final service = FeedbackService(client: mockClient);

      // Act
      final result = await service.submitFeedback(
        title: '',
        body: 'Details',
        feedbackType: 'Bug Report',
      );

      // Assert
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('body.title: String should have at least 1 character'));
    });
  });

  group('FeedbackScreen Widget Tests', () {
    final Map<String, dynamic> testDiagnostics = {
      'simon_high_score': 10,
      'theme_mode': 'ThemeMode.dark',
    };

    testWidgets('renders all form input fields and submit button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackScreen(diagnostics: testDiagnostics),
        ),
      );

      expect(find.widgetWithText(AppBar, 'Submit Feedback'), findsOneWidget);
      expect(find.text('Summary / Title'), findsOneWidget);
      expect(find.text('Email Address (Optional)'), findsOneWidget);
      expect(find.text('Details / Description'), findsOneWidget);
      expect(find.text('Bug Report'), findsOneWidget);
      expect(find.text('Feature Request'), findsOneWidget);
      expect(find.text('Suggestion'), findsOneWidget);
      expect(find.text('Attach diagnostic metadata'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('warns that feedback becomes a public GitHub issue', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackScreen(diagnostics: testDiagnostics),
        ),
      );

      expect(find.text('Public GitHub issue'), findsOneWidget);
      expect(
        find.textContaining('github.com/sentientbeingsoftware/gridmind'),
        findsOneWidget,
      );
      expect(find.textContaining('Anyone can read it'), findsOneWidget);
      expect(find.textContaining('do not include personal information'), findsWidgets);
      expect(find.textContaining('Your optional email address is never posted'), findsOneWidget);
      expect(find.textContaining('Not posted publicly'), findsOneWidget);
      expect(find.textContaining('visible in the public issue'), findsNothing);
    });

    testWidgets('validation triggers error on empty submission', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackScreen(diagnostics: testDiagnostics),
        ),
      );

      // Tap submit immediately
      final submitButton = find.byType(ElevatedButton);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a summary title'), findsOneWidget);
      expect(find.text('Please enter detailed feedback details'), findsOneWidget);
    });

    testWidgets('validation triggers error on invalid email address', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackScreen(diagnostics: testDiagnostics),
        ),
      );

      // Enter invalid email
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address (Optional)'), 'not-an-email');

      // Tap submit
      final submitButton = find.byType(ElevatedButton);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('successful submission transitions to success view without GitHub button', (tester) async {
      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'issue_number': 101,
            'issue_url': 'https://github.com/sentientbeingsoftware/gridmind/issues/101'
          }),
          201,
        );
      });
      final mockService = FeedbackService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackScreen(
            diagnostics: testDiagnostics,
            feedbackService: mockService,
          ),
        ),
      );

      // Act
      // Enter values
      await tester.enterText(find.widgetWithText(TextFormField, 'Summary / Title'), 'My Issue');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address (Optional)'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Details / Description'), 'My long description');
      
      // Select Suggestion chip
      await tester.tap(find.text('Suggestion'));
      await tester.pumpAndSettle();

      // Submit
      final submitButton2 = find.byType(ElevatedButton);
      await tester.ensureVisible(submitButton2);
      await tester.tap(submitButton2);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Feedback Submitted!'), findsOneWidget);
      expect(find.text('Issue #101'), findsOneWidget);
      expect(find.text('View Issue on GitHub'), findsNothing); // verified removed
      expect(find.text('Submit Another Report'), findsOneWidget);
      expect(find.text('Back to Settings'), findsOneWidget);
    });
  });
}
