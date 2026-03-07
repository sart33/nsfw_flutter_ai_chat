import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/data/repositories/chat_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';

/// Chat state — persisted in SQLite per branch.
class ChatState {
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Manages chat messages for a specific branch with SQLite persistence.
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _chatRepo;
  final BranchRepository _branchRepo;
  final String _branchId;

  ChatNotifier({
    required String branchId,
    ChatRepository? chatRepo,
    BranchRepository? branchRepo,
  })  : _branchId = branchId,
        _chatRepo = chatRepo ?? ChatRepository(),
        _branchRepo = branchRepo ?? BranchRepository(),
        super(const ChatState());

  /// Loads history from DB. If empty and [greeting] is provided,
  /// inserts it as the first AI message.
  Future<void> init({
    String? greeting,
    String? personaId,
    String? personaName,
    bool isMulti = false,
  }) async {
    try {
      final history = await _chatRepo.loadHistory(_branchId);
      if (history.isNotEmpty) {
        state = state.copyWith(messages: history);
        return;
      }

      // Empty branch — insert greeting if available.
      if (greeting != null && greeting.isNotEmpty) {
        final msg = ChatMessageModel(
          id: const Uuid().v4(),
          personaId: isMulti ? null : personaId,
          senderName: isMulti ? 'Система' : (personaName ?? 'AI'),
          content: greeting,
          isUser: false,
        );
        await _chatRepo.saveMessage(msg, _branchId);
        state = state.copyWith(messages: [msg]);

        // Update branch preview with greeting.
        await _branchRepo.updatePreview(
          _branchId,
          greeting.length > 80 ? '${greeting.substring(0, 80)}…' : greeting,
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Ошибка загрузки истории');
    }
  }

  /// Send a user message in a single-persona chat.
  Future<void> sendMessage({
    required String content,
    required PersonaEntity persona,
    required int maxTokens,
    bool skipSave = false
  }) async {
    if (!skipSave) {
      // Add user message.
      final userMsg = ChatMessageModel(
        id: const Uuid().v4(),
        senderName: 'Вы',
        content: content,
        isUser: true,
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
        error: null,
      );
      log('sendMessage: saving userMsg, message count before=${state.messages
          .length}', name: 'PROVIDER');
      await _chatRepo.saveMessage(userMsg, _branchId);
      log('sendMessage: userMsg saved, message count after=${state.messages
          .length}', name: 'PROVIDER');
    }

    state = state.copyWith(isLoading: true, error: null);

    // Update preview if this is the first user message.
      if (state.messages
          .where((m) => m.isUser)
          .length == 1) {
        await _branchRepo.updatePreview(
          _branchId,
          content.length > 80 ? '${content.substring(0, 80)}…' : content,
        );
      }

      try {
        final reply = await _chatRepo.sendMessage(
          history: state.messages,
          persona: persona,
          maxTokens: maxTokens,
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
        log('sendMessage: saving aiMsg, message count before=${state.messages
            .length}', name: 'PROVIDER');
        await _chatRepo.saveMessage(aiMsg, _branchId);
        log('sendMessage: aiMsg saved, message count after=${state.messages
            .length}', name: 'PROVIDER');
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'Ошибка API',
        );
      }
    }



  /// Send a user message in a multi-persona chat.
  Future<void> sendMultiMessage({
    required String content,
    required List<PersonaEntity> personas,
    required String behavior,
    required int maxTokens,
    bool skipSave = false
  }) async {
    if (!skipSave) {
      final userMsg = ChatMessageModel(
        id: const Uuid().v4(),
        senderName: 'Вы',
        content: content,
        isUser: true,
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
        error: null,
      );
      await _chatRepo.saveMessage(userMsg, _branchId);
    }

    state = state.copyWith(isLoading: true, error: null);

    // Update preview if this is the first user message.
      if (state.messages
          .where((m) => m.isUser)
          .length == 1) {
        await _branchRepo.updatePreview(
          _branchId,
          content.length > 80 ? '${content.substring(0, 80)}…' : content,
        );
      }

      try {
        final reply = await _chatRepo.sendMultiMessage(
          history: state.messages,
          personas: personas,
          behavior: behavior,
          maxTokens: maxTokens * personas.length,
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
        await _chatRepo.saveMessage(aiMsg, _branchId);
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'Ошибка API',
        );
      }
    }


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
    // Find message index.
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    // Update the message content.
    final updated = state.messages[idx].copyWith(content: newContent);
    final newMessages = List<ChatMessageModel>.from(state.messages);
    newMessages[idx] = updated;
    await _chatRepo.updateMessage(messageId, newContent);

    // Check if next message is AI — if so, delete it and all after, then regen.
    if (idx + 1 < newMessages.length && !newMessages[idx + 1].isUser) {
      final nextId = newMessages[idx + 1].id;
      await _chatRepo.deleteMessageAndAfter(nextId, _branchId);
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

  /// Clear error state (called after showing toast).
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Delete a message and all messages after it (cascade).
  Future<void> deleteMessage(String messageId) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    await _chatRepo.deleteMessageAndAfter(messageId, _branchId);
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
    // Find the last AI message.
    final lastAiIdx =
        state.messages.lastIndexWhere((m) => !m.isUser);
    if (lastAiIdx < 0) return;

    final lastAiMsg = state.messages[lastAiIdx];
    await _chatRepo.deleteMessageAndAfter(lastAiMsg.id, _branchId);
    final trimmed = state.messages.sublist(0, lastAiIdx);
    state = state.copyWith(messages: trimmed, error: null);

    if (persona != null) {
      // Don't re-add user message — it's still in state.
      // Just call API and add AI response.
      state = state.copyWith(isLoading: true);
      try {
        final reply = await _chatRepo.sendMessage(
          history: state.messages,
          persona: persona,
          maxTokens: maxTokens,
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
        await _chatRepo.saveMessage(aiMsg, _branchId);
      } catch (e) {
        state = state.copyWith(isLoading: false, error: 'Ошибка API');
      }
    } else if (personas != null && behavior != null) {
      state = state.copyWith(isLoading: true);
      try {
        final reply = await _chatRepo.sendMultiMessage(
          history: state.messages,
          personas: personas,
          behavior: behavior,
          maxTokens: maxTokens * personas.length,
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
        await _chatRepo.saveMessage(aiMsg, _branchId);
      } catch (e) {
        state = state.copyWith(isLoading: false, error: 'Ошибка API');
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
    if (state.messages.isEmpty) return;

    // Remove the last user message to resend it.
    final lastUserMsg = state.messages.lastWhere((m) => m.isUser);
    await _chatRepo.deleteMessageAndAfter(lastUserMsg.id, _branchId);
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

  // ── HELPERS ────────────────────────────────────────────────────────────

  String _extractSenderName(String reply, List<PersonaEntity> personas) {
    for (final p in personas) {
      if (reply.startsWith('[${p.name}]:') || reply.startsWith('${p.name}:')) {
        return p.name;
      }
    }
    return personas.isNotEmpty ? personas.first.name : 'AI';
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
