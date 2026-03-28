import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';
import '../../util/config/app_config.dart';
import '../ai_provider.dart';

/// AI provider backed by the OpenRouter API.
///
/// OpenRouter exposes an OpenAI-compatible `/v1/chat/completions` endpoint
/// that routes to many upstream models (Claude, GPT, Gemini, etc.).
///
/// The API key is resolved in priority order:
/// 1. `System.openrouterApiKey` (persisted in the local database)
/// 2. `AppConfig.openrouterApiKey` (compile-time `--dart-define`)
///
/// Required HTTP headers per OpenRouter docs:
/// - `HTTP-Referer` — your app URL (for analytics/abuse prevention)
/// - `X-Title` — human-readable app name shown in OpenRouter dashboard
class OpenRouterProvider implements AiProvider {
  OpenRouterProvider({
    http.Client? httpClient,
    this.extractionModel = defaultExtractionModel,
    this.reasoningModel = defaultReasoningModel,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// Lightweight model for fast structured extraction.
  static const defaultExtractionModel = 'anthropic/claude-haiku-4-5';

  /// Capable model for reasoning-heavy tasks.
  static const defaultReasoningModel = 'anthropic/claude-sonnet-4-5';

  /// Referer header sent with every request (OpenRouter requirement).
  static const _httpReferer = 'https://github.com/bsutton/hmb';

  /// App title shown on the OpenRouter dashboard.
  static const _appTitle = 'HMB - Handyman Manager';

  final http.Client _http;
  final String extractionModel;
  final String reasoningModel;
  final Duration timeout;

  @override
  String get name => 'OpenRouter';

  @override
  Future<bool> get isAvailable async {
    final key = await _resolveApiKey();
    return key != null && key.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // AiProvider implementation
  // ---------------------------------------------------------------------------

  @override
  Future<String?> complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
  }) async {
    final body = await _post(
      model: reasoningModel,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      temperature: temperature,
    );
    return _extractContent(body);
  }

  @override
  Future<Map<String, dynamic>?> extractJson({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.1,
  }) async {
    final body = await _post(
      model: extractionModel,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      temperature: temperature,
      responseFormat: {'type': 'json_object'},
    );
    final content = _extractContent(body);
    if (content == null) {
      return null;
    }
    final normalized = _normalizeContent(content);
    return jsonDecode(normalized) as Map<String, dynamic>;
  }

  @override
  Future<String?> analyzeImage({
    required String base64Image,
    required String mimeType,
    String prompt = 'Describe this image.',
    double temperature = 0.2,
  }) async {
    final dataUrl = 'data:$mimeType;base64,$base64Image';
    final body = await _post(
      model: reasoningModel,
      messages: [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        },
      ],
      temperature: temperature,
    );
    return _extractContent(body);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Resolve the API key: database value takes precedence over compile-time.
  Future<String?> _resolveApiKey() async {
    try {
      final system = await DaoSystem().get();
      final dbKey = system.openrouterApiKey?.trim();
      if (dbKey != null && dbKey.isNotEmpty) {
        return dbKey;
      }
    } catch (_) {
      // Database may not be available (e.g. during tests).
    }
    final compileKey = AppConfig.openrouterApiKey;
    return compileKey.isNotEmpty ? compileKey : null;
  }

  /// POST to the OpenRouter chat completions endpoint.
  Future<Map<String, dynamic>?> _post({
    required String model,
    required List<Map<String, dynamic>> messages,
    double temperature = 0.2,
    Map<String, dynamic>? responseFormat,
  }) async {
    final apiKey = await _resolveApiKey();
    if (apiKey == null) {
      return null;
    }

    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
    };
    if (responseFormat != null) {
      payload['response_format'] = responseFormat;
    }

    final response = await _http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': _httpReferer,
            'X-Title': _appTitle,
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw OpenRouterException(
        'OpenRouter API error ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Pull the assistant message content out of an OpenAI-format response.
  String? _extractContent(Map<String, dynamic>? body) {
    if (body == null) {
      return null;
    }
    final choices = body['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return null;
    }
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>;
    return message['content'] as String?;
  }

  /// Strip markdown fences and wrapping quotes that models sometimes add
  /// around JSON output.
  String _normalizeContent(String content) {
    var trimmed = content.trim();
    if (trimmed.startsWith('```')) {
      final lines = trimmed.split('\n').toList();
      if (lines.isNotEmpty && lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
        lines.removeLast();
      }
      trimmed = lines.join('\n').trim();
    }
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        trimmed = jsonDecode(trimmed) as String;
      } catch (_) {
        // fall through
      }
    }
    return trimmed;
  }
}

/// Exception thrown when the OpenRouter API returns a non-200 response.
class OpenRouterException implements Exception {
  OpenRouterException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'OpenRouterException: $message';
}
