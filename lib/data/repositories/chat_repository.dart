import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/factory/dio_factory.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: YAML files must be added to pubspec.yaml assets manually per persona.
// File naming: assets/characters/character_{persona.id}.yaml
// If YAML feature causes issues, disable via Settings toggle — no code changes needed.
// Reminder counter is global (resets on any chat entry), not per-chat.
// Future improvement: per-branch counter in SQLite.

/// Handles DeepSeek API calls for chat completions and SQLite message persistence.
/// No streaming. No content filtering — explicit content is allowed.
/// DeepSeek 'deepseek-chat' model handles explicit / NSFW content.
class ChatRepository {
  final Dio _dio;
  final DatabaseHelper _db;
  final SharedPreferences _prefs;

  ChatRepository._({required Dio dio, required DatabaseHelper db, required SharedPreferences prefs})
      : _dio = dio,
        _db = db,
        _prefs = prefs;

  /// Factory constructor — must be called with [create()] to get an instance.
  static Future<ChatRepository> create({Dio? dio, DatabaseHelper? db}) async {
    final prefs = await SharedPreferences.getInstance();
    return ChatRepository._(
      dio: dio ?? DioFactory.create(),
      db: db ?? DatabaseHelper.instance,
      prefs: prefs,
    );
  }

  // ── REMINDER COUNTER ───────────────────────────────────────────────────

  Future<void> setReminderCounter(int value) async {
    await _prefs.setInt('reminder_counter', value);
    debugPrint('[Reminder] Counter set to $value');
  }

  int _getReminderCounter() => _prefs.getInt('reminder_counter') ?? 0;

  void _setReminderCounter(int value) =>
      _prefs.setInt('reminder_counter', value);

  // /// Resets the reminder counter to 0. Call on chat init.
  // void resetReminderCounter() {
  //   _setReminderCounter(0);
  //   debugPrint('[Reminder] Counter reset to 0');
  // }

  // ── SINGLE PERSONA CHAT ────────────────────────────────────────────────

  /// Sends the conversation history to DeepSeek for a single-persona chat.
  ///
  /// System prompt = persona.description + persona.behavior (if set),
  /// unless YAML override is enabled and a matching YAML file exists.
  /// The first assistant message is persona.greeting.
  Future<String> sendMessage({
    required List<ChatMessageModel> history,
    required PersonaEntity persona,
    required int maxTokens,
  }) async {
    try {
      final reminderEnabled =
          _prefs.getBool('settings_reminder_enabled') ?? true;
      final reminderInterval =
          _prefs.getInt('settings_reminder_interval') ?? 10;

      final systemPrompt = await _buildSingleSystemPrompt(persona);
      final messages = await _buildApiMessages(
        systemPrompt,
        history,
        persona,
        reminderEnabled: reminderEnabled,
        reminderInterval: reminderInterval,
        behaviorReminder: persona.behavior,
      );

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
      log(
          'DioException in sendMessage: ${e.message} | response: ${e.response?.data}',
          name: 'API_ERROR');
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
      final reminderEnabled =
          _prefs.getBool('settings_reminder_enabled') ?? true;
      final reminderInterval =
          _prefs.getInt('settings_reminder_interval') ?? 10;

      // Combined behavior for the reminder — all personas' behaviors joined.
      final behaviorReminder =
          personas.map((p) => p.behavior ?? '').where((b) => b.isNotEmpty).join(' ');

      final systemPrompt = _buildMultiSystemPrompt(personas, behavior);
      final messages = await _buildApiMessagesMulti(
        systemPrompt,
        history,
        reminderEnabled: reminderEnabled,
        reminderInterval: reminderInterval,
        behaviorReminder: behaviorReminder,
      );

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
      log(
          'DioException in sendMultiMessage: ${e.message} | response: ${e.response?.data}',
          name: 'API_ERROR');
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

  /// Tries to load a YAML profile for [persona] from assets.
  /// Returns the file content as a String, or null if not found.
  Future<String?> _buildYamlSystemPrompt(PersonaEntity persona) async {
    try {
      final content = await rootBundle
          .loadString('assets/characters/character_${persona.id}.yaml');
      return content;
    } catch (_) {
      return null;
    }
  }

  /// SINGLE: system = YAML profile (if enabled + exists) OR
  /// persona.description + '\n' + persona.behavior (if set).
  Future<String> _buildSingleSystemPrompt(PersonaEntity persona) async {
    final yamlEnabled =
        _prefs.getBool('settings_yaml_persona_enabled') ?? false;

    if (yamlEnabled) {
      final yaml = await _buildYamlSystemPrompt(persona);
      if (yaml != null) {
        debugPrint('[YAML] Using YAML profile for ${persona.name}');
        return yaml;
      }
    }

    // Fallback: description + behavior.
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

  /// Converts chat history into the OpenAI-compatible messages format (single persona).
  /// First message prepends persona.greeting as an assistant message.
  /// Appends a reminder system message every [reminderInterval] calls if enabled.
  Future<List<Map<String, String>>> _buildApiMessages(
    String systemPrompt,
    List<ChatMessageModel> history,
    PersonaEntity persona, {
    required bool reminderEnabled,
    required int reminderInterval,
    String? behaviorReminder,
  }) async {
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

    // ── Reminder injection ───────────────────────────────────────────────
    if (reminderEnabled &&
        behaviorReminder != null &&
        behaviorReminder.isNotEmpty) {
      final counter = _getReminderCounter() + 1;
      _setReminderCounter(counter);
      debugPrint('[Reminder] Counter: $counter / $reminderInterval');
      if (counter >= reminderInterval) {
        _setReminderCounter(0);
        final reminderText =
            'Помни свою личность и поведение: $behaviorReminder\n';
        messages.add({'role': 'system', 'content': reminderText});
        debugPrint('[Reminder] Injected reminder for counter=$counter: $reminderText');
      }
    }

    return messages;
  }

  /// Converts multi-chat history into OpenAI-compatible messages.
  /// Appends a reminder system message every [reminderInterval] calls if enabled.
  Future<List<Map<String, String>>> _buildApiMessagesMulti(
    String systemPrompt,
    List<ChatMessageModel> history, {
    required bool reminderEnabled,
    required int reminderInterval,
    String? behaviorReminder,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in history) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.isUser
            ? msg.content
            : '[${msg.senderName}]: ${msg.content}',
      });
    }

    // ── Reminder injection ───────────────────────────────────────────────
    if (reminderEnabled &&
        behaviorReminder != null &&
        behaviorReminder.isNotEmpty) {
      final counter = _getReminderCounter() + 1;
      _setReminderCounter(counter);
      debugPrint('[Reminder] Counter: $counter / $reminderInterval');
      if (counter >= reminderInterval) {
        _setReminderCounter(0);
        final reminderText =
            'Помни свою личность и поведение: $behaviorReminder\n'
            'Не теряй тон, не морализируй, не отказывай в consensual интиме без причины.\n'
            'Описывай ощущения и действия подробно.';
        messages.add({'role': 'system', 'content': reminderText});
        debugPrint('[Reminder] Injected reminder for counter=$counter');
      }
    }

    return messages;
  }
}
