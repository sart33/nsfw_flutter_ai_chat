import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';

import '../config/app_config.dart';

/// Service that compresses long chat histories into concise summaries.
/// Uses DeepSeek API with a specialized system prompt.
class SummarizationService {
  final Dio _dio;

  SummarizationService({required Dio dio}) : _dio = dio;

  /// Factory constructor for convenience.
  factory SummarizationService.create({Dio? dio}) {
    return SummarizationService(dio: dio ?? Dio());
  }

  static const _systemPrompt =
      'You are a roleplay history compression assistant. '
      'Compress the chat history into 5-8 short precise sentences. Preserve: '
      'current location and time of day, '
      'appearance clothing and state of all characters, '
      'key emotions and relationships between characters, '
      'recent important actions and events, '
      'significant details such as items mood state. '
      'Do not invent anything new. Do not continue the plot. Facts only. '
      'Response: ONLY the summary, one paragraph, maximum 200 words.';

  /// Compresses a list of chat messages into a concise summary.
  ///
  /// Throws [SummarizationException] on any API or network error.
  Future<String> summarize(
    List<ChatMessageModel> messages,
    String apiKey,
    String model,
  ) async {
    try {
      // 1. Format messages
      final historyText = messages
          .map((m) => '${m.senderName}: ${m.content}')
          .join('\n');

      // 2. POST to DeepSeek API
      final requestBody = {
        'model': model,
        'max_tokens': 300,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': historyText}
        ],
      };

      final response = await _dio.post(
        '${AppConfig.deepSeekBaseUrl}/v1/chat/completions',
        data: requestBody,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );

      // 3. Extract and return summary
      final content = response.data['choices'][0]['message']['content'] as String;
      return content.trim();
    } catch (e) {
      log('Summarization failed: $e', name: 'SUMMARIZATION_ERROR');
      throw SummarizationException(e.toString());
    }
  }
}