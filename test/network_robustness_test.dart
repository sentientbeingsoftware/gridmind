import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/feedback_service.dart';
import 'package:gridmind/services/telemetry_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _event(String id) => jsonEncode({
      'gameId': id,
      'startTime': '2026-01-01T00:00:00.000',
      'durationSeconds': 1,
      'status': 'quit',
      'config': <String, dynamic>{},
      'timestamp': '2026-01-01T00:00:01.000',
    });

void main() {
  group('Telemetry backoff', () {
    final service = TelemetryService();
    late int posts;
    late int status;
    late Map<String, String> headers;
    late DateTime clock;

    Future<void> flushEvent() async {
      await service.logGameSession(
        gameId: 'g',
        startTime: clock,
        durationSeconds: 1,
        status: 'quit',
        config: {},
      );
    }

    setUp(() async {
      posts = 0;
      status = 500;
      headers = {};
      clock = DateTime.utc(2026, 1, 1, 12);
      service.now = () => clock;
      SharedPreferences.setMockInitialValues({
        'telemetry_enabled': true,
        'telemetry_queue': [_event('seed')],
      });
      TelemetryService.httpClient = MockClient((r) async {
        posts++;
        return http.Response('{}', status, headers: headers);
      });
      // Reset internal backoff: a successful flush clears it.
      status = 200;
      await service.flushPending();
      posts = 0;
      status = 500;
    });
    tearDown(() => service.now = DateTime.now);

    Future<void> fiveEvents() async {
      for (var i = 0; i < 5; i++) {
        await flushEvent();
      }
    }

    test('Retry-After seconds on 429 extends the wait', () async {
      status = 429;
      headers = {'retry-after': '600'};
      await fiveEvents();
      expect(posts, 1);
      clock = clock.add(const Duration(seconds: 599));
      await flushEvent();
      expect(posts, 1);
      clock = clock.add(const Duration(seconds: 2));
      await flushEvent();
      expect(posts, 2);
    });

    test('Retry-After HTTP-date on 503 is honoured', () async {
      status = 503;
      headers = {'retry-after': HttpDate.format(clock.add(const Duration(minutes: 5)))};
      await fiveEvents();
      clock = clock.add(const Duration(minutes: 4));
      await flushEvent();
      expect(posts, 1);
      clock = clock.add(const Duration(minutes: 2));
      await flushEvent();
      expect(posts, 2);
    });

    test('Retry-After is capped at one hour', () async {
      status = 429;
      headers = {'retry-after': '999999'};
      await fiveEvents();
      clock = clock.add(const Duration(hours: 1, seconds: 1));
      await flushEvent();
      expect(posts, 2);
    });

    test('no header: 60 s floor', () async {
      status = 429;
      await fiveEvents();
      clock = clock.add(const Duration(seconds: 59));
      await flushEvent();
      expect(posts, 1);
      clock = clock.add(const Duration(seconds: 2));
      await flushEvent();
      expect(posts, 2);
    });

    test('401 keeps the batch queued', () async {
      status = 401;
      await fiveEvents();
      expect((await service.getQueue()).length, 5);
    });

    test('400 drops the batch', () async {
      status = 400;
      await fiveEvents();
      expect(await service.getQueue(), isEmpty);
    });

    test('backoff doubles per failure and resets on success', () async {
      await fiveEvents(); // failure 1 -> 60 s
      clock = clock.add(const Duration(seconds: 61));
      await flushEvent(); // failure 2 -> 120 s
      expect(posts, 2);
      clock = clock.add(const Duration(seconds: 61));
      await flushEvent(); // still backing off
      expect(posts, 2);
      clock = clock.add(const Duration(seconds: 60));
      status = 200;
      await flushEvent(); // retries and succeeds, resets
      expect(posts, 3);
      status = 500;
      await fiveEvents(); // fresh failure: back to 60 s
      final before = posts;
      clock = clock.add(const Duration(seconds: 61));
      await flushEvent();
      expect(posts, before + 1);
    });
  });

  group('Telemetry flush', () {
    late int posts;
    late int status;
    late List<dynamic> lastEvents;
    final service = TelemetryService();

    Future<void> seed(List<String> queue) async {
      SharedPreferences.setMockInitialValues({
        'telemetry_enabled': true,
        'telemetry_queue': queue,
      });
    }

    setUp(() {
      posts = 0;
      status = 200;
      lastEvents = [];
      service.now = DateTime.now;
      TelemetryService.httpClient = MockClient((request) async {
        posts++;
        lastEvents = (jsonDecode(request.body) as Map)['events'] as List;
        return http.Response('{}', status);
      });
    });

    for (final code in [400, 413, 422]) {
      test('HTTP $code discards the batch instead of retrying it forever', () async {
        await seed([_event('a'), _event('b')]);
        status = code;

        await service.flushPending();

        expect(posts, 1);
        expect(await service.getQueue(), isEmpty);
      });
    }

    for (final code in [401, 403, 408, 429, 500, 503]) {
      test('HTTP $code keeps the batch for a later retry', () async {
        await seed([_event('a'), _event('b')]);
        status = code;

        await service.flushPending();

        expect(posts, 1);
        expect((await service.getQueue()).length, 2);
      });
    }

    test('a rejected batch does not start the failure backoff', () async {
      await seed([_event('a')]);
      status = 422;
      await service.flushPending();

      // Next events must still be able to trigger a batch flush right away.
      status = 200;
      SharedPreferences.setMockInitialValues({'telemetry_enabled': true});
      for (var i = 0; i < 5; i++) {
        await service.logGameSession(
          gameId: 'g$i',
          startTime: DateTime.now(),
          durationSeconds: 1,
          status: 'quit',
          config: {},
        );
      }
      expect(posts, 2);
    });

    test('a corrupt queue entry is skipped; valid events still send', () async {
      await seed(['{not json', _event('good'), '"just a string"']);

      await service.flushPending();

      expect(posts, 1);
      expect(lastEvents.length, 1);
      expect((lastEvents.single as Map)['gameId'], 'good');
      expect(await service.getQueue(), isEmpty);
    });

    test('a queue of only corrupt entries is cleared without a request', () async {
      await seed(['{', 'nope']);

      await service.flushPending();

      expect(posts, 0);
      expect(await service.getQueue(), isEmpty);
      expect((await SharedPreferences.getInstance()).getStringList('telemetry_queue'), isNull);
    });

    test('getQueue tolerates corrupt entries', () async {
      await seed(['{', _event('ok')]);

      final queue = await service.getQueue();

      expect(queue.map((e) => e['gameId']), ['ok']);
    });
  });

  group('FeedbackService', () {
    Future<FeedbackResponse> submit(FeedbackService s) =>
        s.submitFeedback(title: 't', body: 'b', feedbackType: 'Bug Report');

    test('a request that never completes fails with a friendly timeout message', () async {
      final hang = Completer<http.Response>();
      final service = FeedbackService(
        client: MockClient((_) => hang.future),
        timeout: const Duration(milliseconds: 50),
      );

      final result = await submit(service);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('too long'));
      expect(result.errorMessage, isNot(contains('TimeoutException')));
    });

    test('non-string "detail" on 401/502 is reported, not mistaken for a network error', () async {
      for (final code in [401, 502]) {
        final service = FeedbackService(
          client: MockClient((_) async => http.Response(
                jsonEncode({'detail': ['bad', 'token']}),
                code,
              )),
        );

        final result = await submit(service);

        expect(result.isSuccess, isFalse, reason: '$code');
        expect(result.errorMessage, isNot(contains('Network connection failed')), reason: '$code');
        expect(result.errorMessage, contains('bad'), reason: '$code');
      }
    });

    test('missing "detail" falls back to the default message', () async {
      final service = FeedbackService(client: MockClient((_) async => http.Response('{}', 401)));

      expect((await submit(service)).errorMessage, 'Unauthorized request.');
    });
  });
}
