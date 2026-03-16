import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/config/chat_constants.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/data/repositories/chat_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';

/// Chat state — persisted in SQLite per branch.
class ChatState {
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final AppException? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    AppException? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Manages chat messages for a specific branch with SQLite persistence.
class ChatNotifier extends StateNotifier<ChatState> {
  /// Lazily initialised after [init] — non-null after first call to init().
  ChatRepository? _chatRepo;

  /// Optional override used in tests. When provided, skips async creation.
  final ChatRepository? _chatRepoOverride;

  final BranchRepository _branchRepo;
  final String _branchId;

  ChatNotifier({
    required String branchId,
    ChatRepository? chatRepo,
    BranchRepository? branchRepo,
  })  : _branchId = branchId,
        _chatRepoOverride = chatRepo,
        _branchRepo = branchRepo ?? BranchRepository(),
        super(const ChatState());

  // ── SAFE REPO ACCESSOR ─────────────────────────────────────────────────

  /// Returns a ready [ChatRepository]. Creates one (async) if not yet initialised.
  Future<ChatRepository> _repo() async {
    if (_chatRepo != null) return _chatRepo!;
    _chatRepo = _chatRepoOverride ?? await ChatRepository.create();
    return _chatRepo!;
  }

  // ── INIT ───────────────────────────────────────────────────────────────

  /// Loads history from DB. If empty and [greeting] is provided,
  /// inserts it as the first AI message.
  Future<void> init({
    String? greeting,
    String? personaId,
    String? personaName,
    bool isMulti = false,
  }) async {
    try {
      // Ensure repository is ready and reset the reminder counter.
      final repo = await _repo();
      final prefs = await SharedPreferences.getInstance();
      final interval = prefs.getInt('settings_reminder_interval') ?? 10;
      await repo.setReminderCounter(interval - 1);
      debugPrint('[Reminder] Counter set to ${interval - 1} on chat init');
      debugPrint('[Reminder] Counter reset on chat init');

      final history = await repo.loadHistory(_branchId);
      if (history.isNotEmpty) {
        state = state.copyWith(messages: history);
        return;
      }

      // Empty branch — insert greeting if available.
      if (greeting != null && greeting.isNotEmpty) {
        final msg = ChatMessageModel(
          id: const Uuid().v4(),
          personaId: isMulti ? null : personaId,
          senderName: isMulti
              ? ChatConstants.systemSender
              : (personaName ?? ChatConstants.aiSender),
          content: greeting,
          isUser: false,
        );
        await repo.saveMessage(msg, _branchId);
        state = state.copyWith(messages: [msg]);

        // Update branch preview with greeting.
        await _branchRepo.updatePreview(
          _branchId,
          greeting.length > 80 ? '${greeting.substring(0, 80)}…' : greeting,
        );
      }
    } catch (e) {
      debugPrint('[ChatNotifier] init error: $e');
      state = state.copyWith(
        error: e is AppException ? e : HistoryException(e.toString()),
      );
    }
  }

  // ── SEND (SINGLE) ──────────────────────────────────────────────────────

  /// Send a user message in a single-persona chat.
  Future<void> sendMessage({
    required String content,
    required PersonaEntity persona,
    required int maxTokens,
    bool skipSave = false,
    bool isQuickAction = false,
  }) async {
    final repo = await _repo();

    if (!skipSave) {
      // Add user message.
      final userMsg = ChatMessageModel(
        id: const Uuid().v4(),
        senderName: ChatConstants.userSender,
        content: content,
        isUser: true,
        isQuickAction: isQuickAction,
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
        error: null,
      );
      log(
          'sendMessage: saving userMsg, message count before=${state.messages.length}',
          name: 'PROVIDER');
      await repo.saveMessage(userMsg, _branchId);
      log(
          'sendMessage: userMsg saved, message count after=${state.messages.length}',
          name: 'PROVIDER');
    }

    state = state.copyWith(isLoading: true, error: null);

    // Update preview if this is the first user message.
    if (state.messages.where((m) => m.isUser).length == 1) {
      await _branchRepo.updatePreview(
        _branchId,
        content.length > 80 ? '${content.substring(0, 80)}…' : content,
      );
    }

    try {
      final reply = await repo.sendMessage(
        history: state.messages,
        persona: persona,
        maxTokens: maxTokens,
        branchId: _branchId,
      );

      final aiMsg = ChatMessageModel(
        id: const Uuid().v4(),
        personaId: persona.id,
        senderName: persona.name,
        content: reply,
        isUser: false,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
      log(
          'sendMessage: saving aiMsg, message count before=${state.messages.length}',
          name: 'PROVIDER');
      await repo.saveMessage(aiMsg, _branchId);
      log(
          'sendMessage: aiMsg saved, message count after=${state.messages.length}',
          name: 'PROVIDER');
    } catch (e) {
      debugPrint('[ChatNotifier] sendMessage error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e is AppException ? e : ApiException(e.toString()),
      );
    }
  }

  // ── SEND (MULTI) ───────────────────────────────────────────────────────

  /// Send a user message in a multi-persona chat.
  Future<void> sendMultiMessage({
    required String content,
    required List<PersonaEntity> personas,
    required String behavior,
    required int maxTokens,
    bool skipSave = false,
    bool isQuickAction = false,
  }) async {
    final repo = await _repo();

    if (!skipSave) {
      final userMsg = ChatMessageModel(
        id: const Uuid().v4(),
        senderName: ChatConstants.userSender,
        content: content,
        isUser: true,
        isQuickAction: isQuickAction,
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
        error: null,
      );
      await repo.saveMessage(userMsg, _branchId);
    }

    state = state.copyWith(isLoading: true, error: null);

    // Update preview if this is the first user message.
    if (state.messages.where((m) => m.isUser).length == 1) {
      await _branchRepo.updatePreview(
        _branchId,
        content.length > 80 ? '${content.substring(0, 80)}…' : content,
      );
    }
    final effectiveTokens = (maxTokens * personas.length).clamp(1, 8192);

    try {
      final reply = await repo.sendMultiMessage(
        history: state.messages,
        personas: personas,
        behavior: behavior,
        maxTokens: effectiveTokens,
        branchId: _branchId,
      );

      final aiMsg = ChatMessageModel(
        id: const Uuid().v4(),
        senderName: _extractSenderName(reply, personas),
        content: _extractContent(reply),
        isUser: false,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
      await repo.saveMessage(aiMsg, _branchId);
    } catch (e) {
      debugPrint('[ChatNotifier] sendMultiMessage error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e is AppException ? e : ApiException(e.toString()),
      );
    }
  }

  // ── EDIT ───────────────────────────────────────────────────────────────

  /// Edit a message in the conversation.
  /// If the next message is AI, deletes it and all after, then regenerates.
  Future<void> editMessage({
    required String messageId,
    required String newContent,
    PersonaEntity? persona,
    List<PersonaEntity>? personas,
    String? behavior,
    required int maxTokens,
  }) async {
    final repo = await _repo();

    // Find message index.
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    // Update the message content.
    final updated = state.messages[idx].copyWith(content: newContent);
    final newMessages = List<ChatMessageModel>.from(state.messages);
    newMessages[idx] = updated;
    await repo.updateMessage(messageId, newContent);

    // Check if next message is AI — if so, delete it and all after, then regen.
    if (idx + 1 < newMessages.length && !newMessages[idx + 1].isUser) {
      final nextId = newMessages[idx + 1].id;
      await repo.deleteMessageAndAfter(nextId, _branchId);
      newMessages.removeRange(idx + 1, newMessages.length);
      state = state.copyWith(messages: newMessages);

      // Regenerate AI response.
      if (persona != null) {
        await sendMessage(
          content: updated.content,
          persona: persona,
          maxTokens: maxTokens,
          skipSave: true, // Don't save user message again.
        );
      } else if (personas != null && behavior != null) {
        await sendMultiMessage(
          content: updated.content,
          personas: personas,
          behavior: behavior,
          maxTokens: maxTokens,
          skipSave: true, // Don't save user message again.
        );
      }
    } else {
      state = state.copyWith(messages: newMessages);
    }
  }

  // ── HELPERS ────────────────────────────────────────────────────────────

  /// Clear error state (called after showing toast).
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Delete a message and all messages after it (cascade).
  Future<void> deleteMessage(String messageId) async {
    final repo = await _repo();
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    await repo.deleteMessageAndAfter(messageId, _branchId);
    final newMessages = state.messages.sublist(0, idx);
    state = state.copyWith(messages: newMessages);
  }

  /// Regenerate the last AI message.
  Future<void> regenLastAI({
    PersonaEntity? persona,
    List<PersonaEntity>? personas,
    String? behavior,
    required int maxTokens,
  }) async {
    final repo = await _repo();

    // Find the last AI message.
    final lastAiIdx = state.messages.lastIndexWhere((m) => !m.isUser);
    if (lastAiIdx < 0) return;

    final lastAiMsg = state.messages[lastAiIdx];
    await repo.deleteMessageAndAfter(lastAiMsg.id, _branchId);
    final trimmed = state.messages.sublist(0, lastAiIdx);
    state = state.copyWith(messages: trimmed, error: null);

    if (persona != null) {
      state = state.copyWith(isLoading: true);
      try {
        final reply = await repo.sendMessage(
          history: state.messages,
          persona: persona,
          maxTokens: maxTokens,
          branchId: _branchId,
        );
        final aiMsg = ChatMessageModel(
          id: const Uuid().v4(),
          personaId: persona.id,
          senderName: persona.name,
          content: reply,
          isUser: false,
        );
        state = state.copyWith(
          messages: [...state.messages, aiMsg],
          isLoading: false,
        );
        await repo.saveMessage(aiMsg, _branchId);
      } catch (e) {
        debugPrint('[ChatNotifier] regenLastAI (single) error: $e');
        state = state.copyWith(
          isLoading: false,
          error: e is AppException ? e : ApiException(e.toString()),
        );
      }
    } else if (personas != null && behavior != null) {
      state = state.copyWith(isLoading: true);
      final effectiveTokens = (maxTokens * personas.length).clamp(1, 8192);

      try {
        final reply = await repo.sendMultiMessage(
          history: state.messages,
          personas: personas,
          behavior: behavior,
          maxTokens: effectiveTokens,
          branchId: _branchId,
        );
        final aiMsg = ChatMessageModel(
          id: const Uuid().v4(),
          senderName: _extractSenderName(reply, personas),
          content: _extractContent(reply),
          isUser: false,
        );
        state = state.copyWith(
          messages: [...state.messages, aiMsg],
          isLoading: false,
        );
        await repo.saveMessage(aiMsg, _branchId);
      } catch (e) {
        debugPrint('[ChatNotifier] regenLastAI (multi) error: $e');
        state = state.copyWith(
          isLoading: false,
          error: e is AppException ? e : ApiException(e.toString()),
        );
      }
    }
  }

  /// Retry the last failed message.
  Future<void> retry({
    PersonaEntity? persona,
    List<PersonaEntity>? personas,
    String? behavior,
    required int maxTokens,
  }) async {
    final repo = await _repo();
    if (state.messages.isEmpty) return;

    // Remove the last user message to resend it.
    final lastUserMsg = state.messages.lastWhere((m) => m.isUser);
    await repo.deleteMessageAndAfter(lastUserMsg.id, _branchId);
    final trimmed = state.messages.sublist(
      0,
      state.messages.lastIndexOf(lastUserMsg),
    );
    state = state.copyWith(messages: trimmed, error: null);

    if (persona != null) {
      await sendMessage(
        content: lastUserMsg.content,
        persona: persona,
        maxTokens: maxTokens,
      );
    } else if (personas != null && behavior != null) {
      await sendMultiMessage(
        content: lastUserMsg.content,
        personas: personas,
        behavior: behavior,
        maxTokens: maxTokens,
      );
    }
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────────────────

  String _extractSenderName(String reply, List<PersonaEntity> personas) {
    for (final p in personas) {
      if (reply.startsWith('[${p.name}]:') || reply.startsWith('${p.name}:')) {
        return p.name;
      }
    }
    return personas.isNotEmpty ? personas.first.name : ChatConstants.aiSender;
  }

  String _extractContent(String reply) {
    final colonIndex = reply.indexOf(':');
    if (colonIndex > 0 && colonIndex < 30) {
      return reply.substring(colonIndex + 1).trim();
    }
    return reply;
  }
}

/// Family provider: one [ChatNotifier] per branchId.
final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, branchId) => ChatNotifier(branchId: branchId),
);
