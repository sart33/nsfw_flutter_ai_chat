import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';

import '../factory/deep_seek_connector.dart';

/// Service that compresses long chat histories into concise summaries.
/// Uses DeepSeek API with a specialized system prompt.
class SummarizationService {
  SummarizationService();
  factory SummarizationService.create() => SummarizationService();

  static const _systemPrompt =
      'You are a roleplay history compression assistant. '
      'Compress the chat history into 5-8 short precise sentences. Preserve: '
      'current location and time of day, '
      'appearance clothing and state of all characters, '
      'key emotions and relationships between characters, '
      'recent important actions and events, '
      'significant details such as items mood state. '
      'Do not invent anything new. Do not continue the plot. Facts only. '
      'Respond in the same language the user messages are written in. '
      'Response: ONLY the summary, one paragraph, maximum 200 words.';

  /// Compresses a list of chat messages into a concise summary.
  ///
  /// Throws [SummarizationException] on any API or network error.
  Future<String> summarize(
      List<ChatMessageModel> messages,
      String model,
      ) async {
    final historyText =
    messages.map((m) => '${m.senderName}: ${m.content}').join('\n');

    final String content;
    try {
      content = await DeepSeekConnector.instance.callChat(
        messages: [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': historyText},
        ],
        model: model,
        maxTokens: 300,
        temperature: 0.3,
      );
    } catch (e) {
      // сеть/API → заворачиваем, чтобы _checkAndSummarize гасил единообразно
      throw SummarizationException(e.toString());
    }

    final trimmed = content.trim();
    const minLength = 80; // короче — считаем мусором
    if (trimmed.isEmpty || trimmed.length < minLength) {
      throw SummarizationException('summary_too_short');
    }
    return trimmed;
  }
}