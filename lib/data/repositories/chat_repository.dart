import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/summarization_service.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/factory/deep_seek_connector.dart';

// NOTE: YAML files must be added to pubspec.yaml assets manually per persona.
// File naming: assets/characters/character_{persona.id}.yaml
// If YAML feature causes issues, disable via Settings toggle — no code changes needed.
// Reminder counter is global (resets on any chat entry), not per-chat.
// Future improvement: per-branch counter in SQLite.

/// Handles DeepSeek API calls for chat completions and SQLite message persistence.
/// No streaming. No content filtering — explicit content is allowed.
/// DeepSeek 'deepseek-chat' model handles explicit / NSFW content.
class ChatRepository {
  final DatabaseHelper _db;
  final SharedPreferences _prefs;
  final SummarizationService _summarizationService;

  ChatRepository._({
    required DatabaseHelper db,
    required SharedPreferences prefs,
    required SummarizationService summarizationService,
  })  : _db = db,
        _prefs = prefs,
        _summarizationService = summarizationService;

  /// Factory constructor — must be called with [create()] to get an instance.
  static Future<ChatRepository> create({DatabaseHelper? db}) async {
    final prefs = await SharedPreferences.getInstance();
    return ChatRepository._(
      db: db ?? DatabaseHelper.instance,
      prefs: prefs,
      summarizationService: SummarizationService.create(),
    );
  }


    // ── REMINDER COUNTER ───────────────────────────────────────────────────

  Future<void> setReminderCounter(int value) async {
    await _prefs.setInt('reminder_counter', value);
  }

  int _getReminderCounter() => _prefs.getInt('reminder_counter') ?? 0;

  void _setReminderCounter(int value) =>
      _prefs.setInt('reminder_counter', value);



  // ── SUMMARIZATION ──────────────────────────────────────────────────────

  /// Checks if summarization should run and triggers it if needed.
  /// Never throws — catches all errors silently.
  Future<void> _checkAndSummarize(
    String branchId,
    List<ChatMessageModel> allMessages,
    bool summarizationEnabled,
    int threshold,
  ) async {
    if (!summarizationEnabled) return;

    final alreadyCovered = await _db.getCoveredMessageCount(branchId);
    final newMessages = allMessages.length - alreadyCovered;


    if (newMessages < threshold) return;

    final toSummarize = allMessages.sublist(
      alreadyCovered,
      alreadyCovered + threshold > allMessages.length
          ? allMessages.length
          : alreadyCovered + threshold,
    );
    if (toSummarize.isEmpty) return;

    try {
      final summary = await _summarizationService.summarize(
        toSummarize,
        AppConfig.deepSeekV4FlashModel,
      );

      final nextBlockNumber = await _db.getNextBlockNumber(branchId);
      final blockId =
          '${branchId}_summary_${DateTime.now().millisecondsSinceEpoch}';
      final messagesCovered = alreadyCovered + toSummarize.length;

      await _db.insertSummaryBlock(
        blockId, branchId, nextBlockNumber, summary,
        DateTime.now().millisecondsSinceEpoch, messagesCovered,
      );
    } on SummarizationException catch (_) {
      // summary_too_short — не сохраняем, не сдвигаем covered, повтор при след. sendMessage
    } catch (e) {
      // прочее тоже гасим молча — фон
    }
  }

  /// Builds API messages with optional summary injection from segmented memory.
  Future<List<Map<String, dynamic>>> _buildMessagesWithSummary(
      String branchId,
      String systemPrompt,
      List<ChatMessageModel> history, {
        bool suppressHidden = false,
        int maxBlocks = 4,

      }) async {
    final summaryBlocks  = await _db.getSummaryBlocks(branchId, limit: maxBlocks);
    final covered = await _db.getCoveredMessageCount(branchId);

    // Keep only the most recent [maxBlocks] summary blocks to avoid hitting token limits.

    final messages = <Map<String, dynamic>>[];
    messages.add({'role': 'system', 'content': systemPrompt});

    // ── Inject all summary blocks in order ──
    if (summaryBlocks.isNotEmpty) {
      final summaryText = summaryBlocks
          .map((b) => b['summary_text'] as String)
          .join('\n\n');
      messages.add({
        'role': 'assistant',
        'content': '[Summary of previous conversation:]\n$summaryText',
      });
    }

    // ── Include only messages not yet covered by summaries ──
    final toInclude = summaryBlocks.isNotEmpty
        ? (covered < history.length ? history.sublist(covered) : <ChatMessageModel>[])
        : history;

    messages.addAll(toInclude.map((m) {
      if (m.isHidden && suppressHidden) return null;
      if (m.isHidden) return {'role': 'assistant', 'content': m.content};
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      };
    }).whereType<Map<String, dynamic>>());

    return messages;
  }

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
    required String branchId,
    bool suppressHidden = false,
  }) async {
    try {
      final reminderEnabled = _prefs.getBool('settings_reminder_enabled') ?? true;
      final reminderInterval = _prefs.getInt('settings_reminder_interval') ?? 10;
      final summarizationEnabled = _prefs.getBool('settings_summarization_enabled') ?? true;
      final threshold = _prefs.getInt('settings_summarization_threshold') ?? 50;

      final systemPrompt = await _buildSingleSystemPrompt(persona);
      final maxBlocks = _prefs.getInt('settings_summary_max_blocks') ?? 4;
      final messages = await _buildMessagesWithSummary(
        branchId, systemPrompt, history,
        suppressHidden: suppressHidden, maxBlocks: maxBlocks,
      );

      if (history.isEmpty || history.first.isUser) {
        messages.insert(1, {'role': 'assistant', 'content': persona.greeting});
      }

      if (reminderEnabled && persona.behavior != null && persona.behavior!.isNotEmpty) {
        final counter = _getReminderCounter() + 1;
        _setReminderCounter(counter);
        if (counter >= reminderInterval) {
          _setReminderCounter(0);
          messages.add({
            'role': 'system',
            'content': 'Remember your identity and behavior: ${persona.behavior}\n',
          });
        }
      }

      final temperature = _prefs.getDouble('generation_temperature') ?? 0.9;

      final content = await DeepSeekConnector.instance.callChat(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      unawaited(_checkAndSummarize(branchId, history, summarizationEnabled, threshold));
      return content;
    } catch (e) {
      if (e is DeepSeekApiException || e is NetworkException) rethrow;
      throw const DeepSeekApiException('invalid_response');
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
    required String branchId,
    bool suppressHidden = false,
    String? directorContext,
  }) async {
    try {
      final reminderEnabled = _prefs.getBool('settings_reminder_enabled') ?? true;
      final reminderInterval = _prefs.getInt('settings_reminder_interval') ?? 10;
      final summarizationEnabled = _prefs.getBool('settings_summarization_enabled') ?? true;
      final threshold = _prefs.getInt('settings_summarization_threshold') ?? 50;

      final behaviorReminder = personas
          .map((p) => p.behavior ?? '')
          .where((b) => b.isNotEmpty)
          .join(' ');

      final systemPrompt = _buildMultiSystemPrompt(personas, behavior);
      final maxBlocks = _prefs.getInt('settings_summary_max_blocks') ?? 4;

      final messages = await _buildMessagesWithSummary(
        branchId, systemPrompt, history,
        suppressHidden: suppressHidden, maxBlocks: maxBlocks,
      );

      // Format multi-persona messages with [Name]: prefix
      for (int i = 1; i < messages.length; i++) {
        final msg = messages[i];
        if (msg['role'] == 'assistant') {
          final originalMsg = history[i - 1]; // -1 because messages[0] is system
          msg['content'] = '[${originalMsg.senderName}]: ${msg['content']}';
        }
      }

      // ── Reminder injection ──
      if (reminderEnabled && behaviorReminder.isNotEmpty) {
        final counter = _getReminderCounter() + 1;
        _setReminderCounter(counter);
        if (counter >= reminderInterval) {
          _setReminderCounter(0);
          messages.add({
            'role': 'system',
            'content': 'Remember your identity and behavior: $behaviorReminder\n',
          });
        }
      }

      final temperature = _prefs.getDouble('generation_temperature') ?? 0.9;

      final content = await DeepSeekConnector.instance.callChat(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      unawaited(_checkAndSummarize(branchId, history, summarizationEnabled, threshold));
      return content;
    } catch (e) {
      if (e is DeepSeekApiException || e is NetworkException) rethrow;
      throw const DeepSeekApiException('invalid_response');
    }
  }

  // ── SQLite PERSISTENCE ─────────────────────────────────────────────────

  /// Loads all messages for a branch from SQLite.
  Future<List<ChatMessageModel>> loadHistory(String branchId) async {
    try {
      final rows = await _db.getMessages(branchId);
      return rows.map((r) => ChatMessageModel.fromMap(r)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Persists a single message to SQLite.
  Future<void> saveMessage(ChatMessageModel msg, String branchId) async {
    try {
      await _db.insertMessage(msg.toMap(), branchId);
    } catch (e) {
      rethrow;
    }
  }
  /// Deletes all summary blocks for [branchId] that cover messages after [messageCount].
  Future<void> deleteSummaryBlocksAfter(String branchId, int messageCount) async {
    try {
      await _db.deleteSummaryBlocksAfter(branchId, messageCount);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes the message with [messageId] and all messages after it in the branch.
  Future<void> deleteMessageAndAfter(
      String messageId, String branchId) async {
    try {
      await _db.deleteMessagesFromId(messageId, branchId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a single message by its ID.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _db.deleteMessage(messageId);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the content of an existing message.
  Future<void> updateMessage(String messageId, String newContent) async {
    try {
      await _db.updateMessageContent(messageId, newContent);
    } catch (e) {
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
    } catch (e) {
      return null;
    }
  }

  /// Builds system prompt for single persona chat.
  /// Uses YAML if available and enabled, otherwise uses description + behavior.
  Future<String> _buildSingleSystemPrompt(PersonaEntity persona) async {
    final yamlEnabled = _prefs.getBool('settings_yaml_enabled') ?? false;
    
    if (yamlEnabled) {
      final yamlContent = await _buildYamlSystemPrompt(persona);
      if (yamlContent != null && yamlContent.isNotEmpty) {
        return yamlContent;
      }
    }
    
    final description = persona.description;
    final behavior = persona.behavior ?? '';
    
    final prompt = StringBuffer();
    prompt.write(description);
    if (behavior.isNotEmpty) {
      prompt.write('\n\n');
      prompt.write(behavior);
    }
    
    return prompt.toString();
  }

  /// Builds system prompt for multi-persona chat.
  /// Combines all personas' descriptions and adds multi-chat rules.
  String _buildMultiSystemPrompt(List<PersonaEntity> personas, String behavior) {
    final prompt = StringBuffer();
    
    // Add each persona's description
    for (final persona in personas) {
      prompt.write('${persona.name}: ${persona.description}\n\n');
    }
    
    // Add multi-chat rules
    prompt.write('''
Reply as your character. Start every message with [YourName]: .

''');
    
    // Add user-defined behavior if provided
    if (behavior.isNotEmpty) {
      prompt.write('\n');
      prompt.write(behavior);
    }
    
    return prompt.toString();
  }
}
