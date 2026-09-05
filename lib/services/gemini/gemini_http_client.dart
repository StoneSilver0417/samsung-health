import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'gemini_dto.dart';

class GeminiNotConfiguredException implements Exception {
  const GeminiNotConfiguredException();

  @override
  String toString() => 'Gemini API 키가 설정되지 않았습니다';
}

/// Gemini REST API 통신 및 재시도/지수백오프 처리를 담당하는 HTTP 엔진.
class GeminiHttpEngine {
  static const defaultModel = 'gemini-3.6-flash';
  static const defaultMaxAttempts = 3;
  static const retryableStatusCodes = {429, 500, 502, 503, 504};
  static const defaultTimeout = Duration(seconds: 60);

  final http.Client? _client;
  final Future<void> Function(Duration) _delay;
  final String _model;
  final int _maxAttempts;
  final Duration _timeout;

  GeminiHttpEngine({
    http.Client? client,
    Future<void> Function(Duration)? delay,
    String model = defaultModel,
    int maxAttempts = defaultMaxAttempts,
    Duration timeout = defaultTimeout,
  })  : _client = client,
        _delay = delay ?? Future<void>.delayed,
        _model = model,
        _maxAttempts = maxAttempts,
        _timeout = timeout;

  /// [request]를 전송하고 응답 DTO를 반환한다.
  Future<GeminiGenerateResponseDto> generate({
    required String apiKey,
    required GeminiGenerateRequestDto request,
  }) async {
    if (apiKey.isEmpty) throw const GeminiNotConfiguredException();

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );
    final body = request.toRawJson();

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final headers = {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        };
        final reqFuture = _client == null
            ? http.post(uri, headers: headers, body: body)
            : _client.post(uri, headers: headers, body: body);
        final res = await reqFuture.timeout(_timeout);

        if (res.statusCode == 200) {
          final decoded = utf8.decode(res.bodyBytes);
          return GeminiGenerateResponseDto.fromRawJson(decoded);
        }

        final canRetry = retryableStatusCodes.contains(res.statusCode);
        if (!canRetry || attempt == _maxAttempts) {
          if (res.statusCode == 503) {
            throw Exception('Gemini 서버가 일시적으로 혼잡합니다. 잠시 후 다시 시도하세요.');
          }
          throw Exception('Gemini 요청 실패 (${res.statusCode}): ${res.body}');
        }
      } on TimeoutException {
        if (attempt == _maxAttempts) {
          throw Exception('Gemini 응답 시간 초과 (60초). 잠시 후 다시 시도해주세요.');
        }
      } on SocketException catch (e) {
        if (attempt == _maxAttempts) {
          throw Exception('네트워크 연결 오류: ${e.message}');
        }
      } on http.ClientException catch (e) {
        if (attempt == _maxAttempts) {
          throw Exception('네트워크 요청 실패: ${e.message}');
        }
      }

      // 503/429 또는 일시적 네트워크 오류 시 1초, 2초 간격으로 재시도한다.
      await _delay(Duration(seconds: attempt));
    }

    throw StateError('Gemini 요청 재시도 흐름이 비정상적으로 종료되었습니다');
  }
}
