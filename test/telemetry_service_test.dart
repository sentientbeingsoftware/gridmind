import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridmind/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MockClient extends http.BaseClient {
  int postCallCount = 0;
  int lastStatusCode = 201;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    postCallCount++;
    lastHeaders = request.headers;
    
    if (request is http.Request) {
      lastBody = request.body;
    }

    final bodyBytes = utf8.encode('{"status":"success","message":"Processed successfully"}');
    return http.StreamedResponse(
      Stream.value(bodyBytes),
      lastStatusCode,
      contentLength: bodyBytes.length,
    );
  }
}

void main() {
  late MockClient mockClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockClient();
    // Inject the mock client into the TelemetryService singleton
    TelemetryService.httpClient = mockClient;
  });

  group('TelemetryService Tests', () {
    test('starts disabled (opt-in) by default with an empty queue', () async {
      final service = TelemetryService();
      expect(await service.isEnabled(), isFalse);
      expect(await service.getQueue(), isEmpty);
    });

    test('logging an event adds it to the queue when enabled', () async {
      final service = TelemetryService();
      await service.setEnabled(true);

      await service.logGameSession(
        gameId: 'test_game',
        startTime: DateTime.now().subtract(const Duration(seconds: 30)),
        durationSeconds: 30,
        status: 'victory',
        config: {'size': 4.0},
      );

      final queue = await service.getQueue();
      expect(queue.length, 1);
      expect(queue.first['gameId'], 'test_game');
      expect(queue.first['durationSeconds'], 30);
      expect(queue.first['status'], 'victory');
      expect(queue.first['config']['size'], 4.0);
    });

    test('logging an event does not add to queue when disabled', () async {
      final service = TelemetryService();
      await service.setEnabled(true);

      // Enqueue one event first
      await service.logGameSession(
        gameId: 'test_game_1',
        startTime: DateTime.now(),
        durationSeconds: 10,
        status: 'quit',
        config: {},
      );
      expect((await service.getQueue()).length, 1);

      // Disable telemetry
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);

      // Queue should have been cleared automatically on disabling
      expect(await service.getQueue(), isEmpty);

      // Logging another event should do nothing
      await service.logGameSession(
        gameId: 'test_game_2',
        startTime: DateTime.now(),
        durationSeconds: 15,
        status: 'victory',
        config: {},
      );
      expect(await service.getQueue(), isEmpty);
    });

    test('reaching batch limit (5 events) automatically flushes the queue', () async {
      final service = TelemetryService();
      await service.setEnabled(true);
      await service.clearQueue();

      // Reset call count
      mockClient.postCallCount = 0;

      // Log 4 events
      for (int i = 0; i < 4; i++) {
        await service.logGameSession(
          gameId: 'game_$i',
          startTime: DateTime.now(),
          durationSeconds: 10,
          status: 'quit',
          config: {},
        );
      }
      expect((await service.getQueue()).length, 4);
      expect(mockClient.postCallCount, 0);

      // Log the 5th event -> should trigger flush and clear the local queue
      await service.logGameSession(
        gameId: 'game_4',
        startTime: DateTime.now(),
        durationSeconds: 10,
        status: 'quit',
        config: {},
      );

      // Locally the queue is cleared
      expect(await service.getQueue(), isEmpty);

      // Mock client should have captured the HTTP post request
      expect(mockClient.postCallCount, 1);
      expect(mockClient.lastHeaders?['Content-Type'], 'application/json');
      expect(mockClient.lastHeaders?['Authorization'], startsWith('Bearer '));

      final bodyData = json.decode(mockClient.lastBody!) as Map<String, dynamic>;
      expect(bodyData['app_id'], 'Gridmind');
      expect((bodyData['events'] as List).length, 5);
      expect((bodyData['events'] as List)[4]['gameId'], 'game_4');
    });

    Future<void> logN(TelemetryService service, int n) async {
      for (var i = 0; i < n; i++) {
        await service.logGameSession(
          gameId: 'g$i',
          startTime: DateTime.now(),
          durationSeconds: 1,
          status: 'quit',
          config: {},
        );
      }
    }

    test('flushPending sends a queue smaller than the batch size', () async {
      final service = TelemetryService();
      await service.setEnabled(true);
      await service.clearQueue();
      mockClient.postCallCount = 0;

      await logN(service, 2);
      expect(mockClient.postCallCount, 0);

      await service.flushPending();
      expect(mockClient.postCallCount, 1);
      expect(await service.getQueue(), isEmpty);
    });

    test('flushPending does nothing when disabled or empty', () async {
      final service = TelemetryService();
      await service.setEnabled(false);
      mockClient.postCallCount = 0;
      await service.flushPending();
      expect(mockClient.postCallCount, 0);

      await service.setEnabled(true);
      await service.flushPending();
      expect(mockClient.postCallCount, 0);
    });

    test('failed flush keeps events, backs off event-triggered retries, flushPending recovers', () async {
      final service = TelemetryService();
      var clock = DateTime(2026, 1, 1, 12);
      service.now = () => clock;
      await service.setEnabled(true);
      await service.clearQueue();
      mockClient
        ..postCallCount = 0
        ..lastStatusCode = 500;

      await logN(service, 5); // 5th event triggers a flush that fails
      expect(mockClient.postCallCount, 1);
      expect((await service.getQueue()).length, 5);

      await logN(service, 1); // within backoff: no new POST
      expect(mockClient.postCallCount, 1);

      clock = clock.add(const Duration(seconds: 61));
      mockClient.lastStatusCode = 201;
      await logN(service, 1); // backoff elapsed: retries and succeeds
      expect(mockClient.postCallCount, 2);
      expect(await service.getQueue(), isEmpty);

      service.now = DateTime.now;
    });
  });
}
