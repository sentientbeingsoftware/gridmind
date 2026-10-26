import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../app_info.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  http.Client _client = http.Client();

  /// Replaces the HTTP client; intended for tests only.
  @visibleForTesting
  static set httpClient(http.Client client) => _instance._client = client;

  static const String _telemetryEnabledKey = 'telemetry_enabled';
  static const String _consentAnsweredKey = 'telemetry_consent_answered';
  static const String _telemetryQueueKey = 'telemetry_queue';
  static const int _batchLimit = 5;
  // Caps storage when the device is offline and flushes keep failing.
  static const int _maxQueueSize = 200;
  bool _flushing = false;

  // After a failed flush, event-triggered flushes pause for this long so an
  // offline device doesn't attempt a POST on every game event.
  static const Duration _retryBackoff = Duration(seconds: 60);
  DateTime? _lastFailure;

  // The server rejected the batch itself (bad request / too large / failed
  // validation), so resending the same bytes can never succeed. Everything else
  // (auth, rate limit, 5xx, network) is transient and keeps the queue.
  static const Set<int> _permanentRejections = {400, 413, 422};

  /// Test hook for the backoff clock.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  Future<bool> isEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_telemetryEnabledKey) ?? false; // opt-in
  }

  /// True once the user has answered the first-run consent prompt.
  Future<bool> hasAnsweredConsent() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_consentAnsweredKey) ?? false;
  }

  /// Stores the user's first-run answer and applies it.
  Future<void> recordConsent(bool allowed) async {
    await setEnabled(allowed);
    final prefs = await _getPrefs();
    await prefs.setBool(_consentAnsweredKey, true);
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_telemetryEnabledKey, enabled);
    if (!enabled) {
      await clearQueue();
    }
  }

  Future<void> logGameSession({
    required String gameId,
    required DateTime startTime,
    required int durationSeconds,
    required String status,
    required Map<String, dynamic> config,
  }) async {
    try {
      if (!await isEnabled()) return;

      final event = {
        'gameId': gameId,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'status': status,
        'config': config,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _enqueueEvent(event);
    } catch (e) {
      debugPrint('Telemetry logGameSession error: $e');
    }
  }

  Future<void> _enqueueEvent(Map<String, dynamic> event) async {
    try {
      final prefs = await _getPrefs();
      final queue = prefs.getStringList(_telemetryQueueKey) ?? [];
      queue.add(json.encode(event));
      if (queue.length > _maxQueueSize) {
        queue.removeRange(0, queue.length - _maxQueueSize);
      }
      await prefs.setStringList(_telemetryQueueKey, queue);

      final backingOff =
          _lastFailure != null && now().difference(_lastFailure!) < _retryBackoff;
      if (queue.length >= _batchLimit && !backingOff) {
        await _flushQueue();
      }
    } catch (e) {
      debugPrint('Telemetry _enqueueEvent error: $e');
    }
  }

  /// Sends whatever is queued, even below the batch size. Call at app start and
  /// when the app is backgrounded so small queues don't linger indefinitely.
  /// Ignores the retry backoff because it is an explicit, infrequent trigger.
  Future<void> flushPending() async {
    try {
      if (!await isEnabled()) return;
      await _flushQueue();
    } catch (e) {
      debugPrint('Telemetry flushPending error: $e');
    }
  }

  Future<void> _flushQueue() async {
    // Prevents concurrent flushes from posting the same batch twice.
    if (_flushing) return;
    _flushing = true;
    try {
      await _doFlush();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _doFlush() async {
    final prefs = await _getPrefs();
    final queue = prefs.getStringList(_telemetryQueueKey) ?? [];
    if (queue.isEmpty) return;
    final sentCount = queue.length;

    final eventsList = <dynamic>[];
    for (final raw in queue) {
      final decoded = _tryDecode(raw);
      if (decoded != null) eventsList.add(decoded);
    }
    if (eventsList.isEmpty) {
      // Nothing decodable: discard so a corrupt entry can't wedge the queue.
      await _dropSent(prefs, sentCount);
      return;
    }
    final payload = {
      'app_id': 'Gridmind',
      'app_version': kAppVersion,
      'events': eventsList,
    };

    try {
      final response = await _client.post(
        Uri.parse('https://error.jeremyclark.foo/v1/telemetry'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${const String.fromEnvironment("TELEMETRY_TOKEN")}',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastFailure = null;
        debugPrint('Telemetry flush successful: ${response.statusCode}');
        await _dropSent(prefs, sentCount);
      } else if (_permanentRejections.contains(response.statusCode)) {
        _lastFailure = null;
        debugPrint('Telemetry batch rejected (${response.statusCode}); discarding it');
        await _dropSent(prefs, sentCount);
      } else {
        _lastFailure = now();
        debugPrint('Telemetry flush failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _lastFailure = now();
      debugPrint('Telemetry connection failed: $e');
    }
  }

  /// Drops the first [sentCount] entries; events queued during the request survive.
  Future<void> _dropSent(SharedPreferences prefs, int sentCount) async {
    final current = prefs.getStringList(_telemetryQueueKey) ?? [];
    if (current.length > sentCount) {
      await prefs.setStringList(_telemetryQueueKey, current.sublist(sentCount));
    } else {
      await prefs.remove(_telemetryQueueKey);
    }
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await _getPrefs();
    final queue = prefs.getStringList(_telemetryQueueKey) ?? [];
    return [
      for (final raw in queue)
        if (_tryDecode(raw) case final event?) event,
    ];
  }

  Future<void> clearQueue() async {
    final prefs = await _getPrefs();
    await prefs.remove(_telemetryQueueKey);
  }
}
