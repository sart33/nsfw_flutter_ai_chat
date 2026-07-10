import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../config/app_config.dart';
import 'dio_factory.dart';

class DeepSeekConnector {
  DeepSeekConnector._();
  static final DeepSeekConnector instance = DeepSeekConnector._();

  static const String _baseUrl = '${AppConfig.deepSeekBaseUrl}/chat/completions';
  static const String _defaultModel = AppConfig.deepSeekV4FlashModel;

  /// Единственный реальный вход в API. Принимает готовый список сообщений.
  /// Все обёртки ниже сводятся сюда.
  Future<String> _call({
    required List<Map<String, dynamic>> messages,
    String? model,
    bool reasoning = true,
    String reasoningEffort = 'high',
    int maxTokens = 3000,
    double? temperature,
    bool jsonResponse = false,
    bool throwOnTruncation = true,
  }) async {
    final apiKey = await AppConfig.getDeepSeekApiKey();
    if (apiKey.isEmpty) throw const DeepSeekApiException('key_not_set');
    final dio = DioFactory.create();

    final body = <String, dynamic>{
      'model': model ?? _defaultModel,
      'max_tokens': maxTokens,
      'thinking': {'type': reasoning ? 'enabled' : 'disabled'},
      'stream': false,
      'messages': messages,
    };
    if (reasoning) {
      body['reasoning_effort'] = reasoningEffort;
    } else if (temperature != null) {
      body['temperature'] = temperature;
    }
    if (jsonResponse) {
      body['response_format'] = const {'type': 'json_object'};
    }

    assert(() {
      log(jsonEncode(body), name: 'DEEPSEEK_REQUEST');
      return true;
    }());

    late final Response response;
    try {
      response = await dio.post(
        _baseUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          validateStatus: (_) => true,
        ),
        data: body,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.error is SocketException) {
        throw const NetworkException();
      }
      rethrow;
    }

    if (response.statusCode == 401) throw const DeepSeekApiException('key_invalid');
    if (response.statusCode == 402) throw const DeepSeekApiException('insufficient_balance');
    if (response.statusCode == 504 || response.statusCode == 503) {
      throw const DeepSeekApiException('service_unavailable');
    }
    if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 500) >= 300) {
      throw DeepSeekApiException('http_error', statusCode: response.statusCode);
    }

    assert(() {
      log(jsonEncode(response.data), name: 'DEEPSEEK_RESPONSE');
      return true;
    }());

    final choice = (response.data['choices'] as List).first;
    if (throwOnTruncation && choice['finish_reason'] == 'length') {
      throw const DeepSeekApiException('response_truncated');
    }
    return (choice['message']['content'] as String).trim();
  }

  /// Одиночный запрос: инструкция (system) + данные (user).
  /// [prompt] — инструкция, едет в system-роль.
  /// [input]  — пользовательские данные, едут в user-роль.
  Future<String> callDeepSeek({
    required String prompt,
    required String input,
    String? model,
    bool reasoning = true,
    String reasoningEffort = 'high',
    int maxTokens = 3000,
    double? temperature,
    bool jsonResponse = false,
  }) =>
      _call(
        messages: [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': input},
        ],
        model: model,
        reasoning: reasoning,
        reasoningEffort: reasoningEffort,
        maxTokens: maxTokens,
        temperature: temperature,
        jsonResponse: jsonResponse,
      );

  /// Чат с готовой историей (single/multi/суммаризация).
  /// Thinking off, обрезку не считаем ошибкой — показываем что есть.
  Future<String> callChat({
    required List<Map<String, dynamic>> messages,
    String? model,
    required int maxTokens,
    double? temperature,
    bool jsonResponse = false,
  }) =>
      _call(
        messages: messages,
        model: model,
        reasoning: false,
        maxTokens: maxTokens,
        temperature: temperature,
        jsonResponse: jsonResponse,
        throwOnTruncation: false,
      );

  /// Снимает возможные ```json ... ``` обёртки и парсит в Map.
  Map<String, dynamic> parseJson(String raw, {required String context}) {
    try {
      final cleaned = raw
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      assert(() {
        log('JSON parse error in $context: $e\nRaw: $raw', name: 'DEEPSEEK');
        return true;
      }());
      rethrow;
    }
  }
}