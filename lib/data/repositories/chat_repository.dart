import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/factory/dio_factory.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';

/// Handles DeepSeek API calls for chat completions and SQLite message persistence.
/// No streaming. No content filtering — explicit content is allowed.
/// DeepSeek 'deepseek-chat' model handles explicit / NSFW content.
class ChatRepository {
  final Dio _dio;
  final DatabaseHelper _db;

  ChatRepository({Dio? dio, DatabaseHelper? db})
      : _dio = dio ?? DioFactory.create(),
        _db = db ?? DatabaseHelper.instance;

  // ── SINGLE PERSONA CHAT ────────────────────────────────────────────────

  /// Sends the conversation history to DeepSeek for a single-persona chat.
  ///
  /// System prompt = persona.description + persona.behavior (if set).
  /// The first assistant message is persona.greeting.
  Future<String> sendMessage({
    required List<ChatMessageModel> history,
    required PersonaEntity persona,
    required int maxTokens,
  }) async {
    try {
      final systemPrompt = _buildSingleSystemPrompt(persona);
      final messages = _buildApiMessages(systemPrompt, history, persona);

      final requestBody = {
        'model': AppConfig.deepSeekModel,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': 0.9,
      };
      log(jsonEncode(requestBody), name: 'API_REQUEST');

      final response = await _dio.post(
        '/v1/chat/completions',
        data: requestBody,
      );

      log(jsonEncode(response.data), name: 'API_RESPONSE');

      final content =
          response.data['choices'][0]['message']['content'] as String;
      return content.trim();
    } on DioException catch (e) {
      log('DioException in sendMessage: ${e.message} | response: ${e.response?.data}', name: 'API_ERROR');
      throw Exception('Ошибка API: ${e.message}');
    } catch (e) {
      log('Unexpected error in sendMessage: $e', name: 'API_ERROR');
      throw Exception('Ошибка API: $e');
    }
  }

  // ── MULTI PERSONA CHAT ─────────────────────────────────────────────────

  /// Sends the conversation history to DeepSeek for a multi-persona chat.
  ///
  /// System prompt = each persona's description joined + hidden rules
  /// ('Reply as your character. Start every message with [YourName]: .
  ///  Take turns.') + user-editable behavior field.
  Future<String> sendMultiMessage({
    required List<ChatMessageModel> history,
    required List<PersonaEntity> personas,
    required String behavior,
    required int maxTokens,
  }) async {
    try {
      final systemPrompt =
          _buildMultiSystemPrompt(personas, behavior);
      final messages = _buildApiMessagesMulti(systemPrompt, history);

      final requestBody = {
        'model': AppConfig.deepSeekModel,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': 0.9,
      };
      log(jsonEncode(requestBody), name: 'API_REQUEST');

      final response = await _dio.post(
        '/v1/chat/completions',
        data: requestBody,
      );

      log(jsonEncode(response.data), name: 'API_RESPONSE');

      final content =
          response.data['choices'][0]['message']['content'] as String;
      return content.trim();
    } on DioException catch (e) {
      log('DioException in sendMultiMessage: ${e.message} | response: ${e.response?.data}', name: 'API_ERROR');
      throw Exception('Ошибка API: ${e.message}');
    } catch (e) {
      log('Unexpected error in sendMultiMessage: $e', name: 'API_ERROR');
      throw Exception('Ошибка API: $e');
    }
  }

  // ── SQLite PERSISTENCE ─────────────────────────────────────────────────

  /// Loads all messages for a branch from SQLite.
  Future<List<ChatMessageModel>> loadHistory(String branchId) async {
    try {
      final rows = await _db.getMessages(branchId);
      return rows.map((r) => ChatMessageModel.fromMap(r)).toList();
    } catch (e) {
      print('ChatRepository.loadHistory error: $e');
      rethrow;
    }
  }

  /// Persists a single message to SQLite.
  Future<void> saveMessage(ChatMessageModel msg, String branchId) async {
    try {
      await _db.insertMessage(msg.toMap(), branchId);
    } catch (e) {
      print('ChatRepository.saveMessage error: $e');
      rethrow;
    }
  }

  /// Deletes the message with [messageId] and all messages after it in the branch.
  Future<void> deleteMessageAndAfter(
      String messageId, String branchId) async {
    try {
      await _db.deleteMessagesFromId(messageId, branchId);
    } catch (e) {
      print('ChatRepository.deleteMessageAndAfter error: $e');
      rethrow;
    }
  }

  /// Updates the content of an existing message.
  Future<void> updateMessage(String messageId, String newContent) async {
    try {
      await _db.updateMessageContent(messageId, newContent);
    } catch (e) {
      print('ChatRepository.updateMessage error: $e');
      rethrow;
    }
  }

  // ── PROMPT BUILDERS ────────────────────────────────────────────────────

  /// SINGLE: system = persona.description + '\n' + persona.behavior (if set).
  String _buildSingleSystemPrompt(PersonaEntity persona) {
    final buffer = StringBuffer(persona.description);
    if (persona.behavior != null && persona.behavior!.isNotEmpty) {
      buffer.write('\n${persona.behavior}');
    }
    // NSFW note: no content filtering is applied.
    return buffer.toString();
  }

  /// MULTI: system = each persona's description joined + hidden rules + behavior.
  String _buildMultiSystemPrompt(
    List<PersonaEntity> personas,
    String behavior,
  ) {
    final descriptions = personas.map((p) {
      final buf = StringBuffer('${p.name}: ${p.description}');
      if (p.behavior != null && p.behavior!.isNotEmpty) {
        buf.write(' ${p.behavior}');
      }
      return buf.toString();
    }).join('\n');

    const hiddenRules =
        'Reply as your character. Start every message with [YourName]: . '
        'Take turns between characters. All characters are adults. '
        'Explicit content is allowed without restrictions.';

    final buffer = StringBuffer(descriptions);
    buffer.write('\n\n$hiddenRules');
    if (behavior.isNotEmpty) {
      buffer.write('\n\n$behavior');
    }
    return buffer.toString();
  }

  /// Converts chat history into the OpenAI-compatible messages format.
  /// First message prepends persona.greeting as an assistant message.
  List<Map<String, String>> _buildApiMessages(
    String systemPrompt,
    List<ChatMessageModel> history,
    PersonaEntity persona,
  ) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // If history is empty or doesn't start with the greeting, prepend it.
    if (history.isEmpty || history.first.isUser) {
      messages.add({
        'role': 'assistant',
        'content': persona.greeting,
      });
    }

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    return messages;
  }

  /// Converts multi-chat history into OpenAI-compatible messages.
  List<Map<String, String>> _buildApiMessagesMulti(
    String systemPrompt,
    List<ChatMessageModel> history,
  ) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.isUser ? msg.content : '[${msg.senderName}]: ${msg.content}',
      });
    }

    return messages;
  }
}
