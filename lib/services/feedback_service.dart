import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../app_info.dart';

/// Model representing the response from feedback submission
class FeedbackResponse {
  final bool isSuccess;
  final String? issueUrl;
  final int? issueNumber;
  final String errorMessage;

  FeedbackResponse({
    required this.isSuccess,
    this.issueUrl,
    this.issueNumber,
    required this.errorMessage,
  });
}

/// Service to handle sending application feedback to the proxy server
class FeedbackService {
  static const String _endpointUrl = 'https://error.jeremyclark.foo/v1/feedback';
  // Injected at build time: --dart-define=FEEDBACK_API_KEY=... (never commit the value).
  static const String _apiKey = String.fromEnvironment('FEEDBACK_API_KEY');
  static const String _appId = 'Gridmind';

  // Cache session ID for the lifecycle of the app
  static final String _sessionId = _generateUUIDv4();

  // Internal client used to make HTTP requests
  final http.Client _client;

  /// Upper bound for the whole request so the form can't spin forever on a
  /// stalled connection.
  final Duration _timeout;

  /// Creates a [FeedbackService]. Can pass a custom [client] and [timeout] for testing.
  FeedbackService({http.Client? client, Duration timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  /// Helper to generate an RFC 4122 compliant UUID v4
  static String _generateUUIDv4() {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }
    const hexDigits = '0123456789abcdef';
    final uuid = List.generate(36, (index) {
      if (index == 8 || index == 13 || index == 18 || index == 23) {
        return '-';
      }
      if (index == 14) {
        return '4'; // Version 4
      }
      final r = random.nextInt(16);
      if (index == 19) {
        return hexDigits[(r & 0x3) | 0x8]; // Variant 1
      }
      return hexDigits[r];
    });
    return uuid.join();
  }

  /// Sends feedback payload to the proxy server.
  /// Returns a [FeedbackResponse] indicating success or details of failure.
  Future<FeedbackResponse> submitFeedback({
    required String title,
    required String body,
    required String feedbackType,
    String? email,
    Map<String, dynamic>? scoresTelemetry,
  }) async {
    // 1. Determine platform and OS version safely
    String osVersion = 'Unknown OS';
    String deviceModel = 'Unknown Device';

    if (kIsWeb) {
      osVersion = 'Web Browser';
      deviceModel = 'Browser Client';
    } else {
      try {
        osVersion = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
        deviceModel = 'Native Client'; // hostname can contain the user's name
      } catch (_) {
        try {
          osVersion = Platform.operatingSystem;
        } catch (_) {
          osVersion = 'Native OS';
        }
        deviceModel = 'Mobile/Desktop Client';
      }
    }

    // 2. Format telemetry structure
    final Map<String, dynamic> telemetry = {
      'session_id': _sessionId,
      'connection_type': kIsWeb ? 'Browser Network' : 'Native Network',
    };

    if (email != null && email.trim().isNotEmpty) {
      telemetry['email'] = email.trim();
    }

    if (scoresTelemetry != null) {
      telemetry.addAll(scoresTelemetry);
    }

    // The email is sent only in the private telemetry field. The backend strips
    // it from the public issue and stores it privately for correspondence. The
    // body becomes a public GitHub issue, so it must not contain PII.
    final String finalBody = body;

    // 3. Build HTTP request payload
    final Map<String, dynamic> payload = {
      'app_id': _appId,
      'app_version': kAppVersion,
      'os_version': osVersion,
      'device_model': deviceModel,
      'title': '[$feedbackType] $title',
      'body': finalBody,
      'telemetry': telemetry,
    };

    try {
      final response = await _client.post(
        Uri.parse(_endpointUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(payload),
      ).timeout(_timeout);

      final Map<String, dynamic> responseData = _safeDecodeJson(response.body);

      if (response.statusCode == 201) {
        return FeedbackResponse(
          isSuccess: true,
          issueUrl: responseData['issue_url'] as String?,
          issueNumber: responseData['issue_number'] as int?,
          errorMessage: '',
        );
      } else if (response.statusCode == 401) {
        return FeedbackResponse(
          isSuccess: false,
          errorMessage: _detailText(responseData, 'Unauthorized request.'),
        );
      } else if (response.statusCode == 422) {
        // Validation failure
        final details = responseData['detail'];
        String msg = 'Validation error.';
        if (details is List && details.isNotEmpty) {
          final firstError = details[0];
          if (firstError is Map && firstError.containsKey('msg')) {
            msg = '${firstError['loc']?.join('.') ?? 'field'}: ${firstError['msg']}';
          }
        }
        return FeedbackResponse(
          isSuccess: false,
          errorMessage: msg,
        );
      } else if (response.statusCode == 429) {
        // The server allows 5 feedback messages per hour per IP and 50 a day overall.
        return FeedbackResponse(
          isSuccess: false,
          errorMessage: 'Too many feedback messages right now. Your text is still here; please try again in a while.',
        );
      } else if (response.statusCode == 502) {
        return FeedbackResponse(
          isSuccess: false,
          errorMessage: _detailText(responseData, 'GitHub connection failed.'),
        );
      } else {
        return FeedbackResponse(
          isSuccess: false,
          errorMessage: 'Server returned error status code: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      return FeedbackResponse(
        isSuccess: false,
        errorMessage: 'The server took too long to respond. Please try again.',
      );
    } catch (e) {
      return FeedbackResponse(
        isSuccess: false,
        errorMessage: 'Network connection failed: $e',
      );
    }
  }

  /// `detail` is a string for most errors but can be a list/object; never let
  /// a shape mismatch escape as a misleading "network" failure.
  String _detailText(Map<String, dynamic> data, String fallback) {
    final detail = data['detail'];
    return detail == null ? fallback : detail.toString();
  }

  /// Safe JSON decoding to prevent runtime crashes on unexpected strings
  Map<String, dynamic> _safeDecodeJson(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'detail': decoded.toString()};
    } catch (_) {
      return {'detail': body};
    }
  }
}
