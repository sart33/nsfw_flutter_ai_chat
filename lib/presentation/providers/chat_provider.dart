import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/config/chat_constants.dart';
import 'package:nsfw_chat/core/enums/quick_action_type.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/prompt_cleaner_service.dart';
import 'package:nsfw_chat/core/services/scene_extractor_service.dart';
import 'package:nsfw_chat/core/services/chat_image_service.dart';
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
  final int verifyingCount;
  final List<PersonaEntity> failedPersonas;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.verifyingCount = 0,
    this.failedPersonas = const [],
  });

  bool get isVerifying => verifyingCount > 0;
  bool get verificationFailed => failedPersonas.isNotEmpty;

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    AppException? error,
    int? verifyingCount,
    List<PersonaEntity>? failedPersonas,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        verifyingCount: verifyingCount ?? this.verifyingCount,
        failedPersonas: failedPersonas ?? this.failedPersonas,
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
  final Ref _ref; // добавить поле


  ChatNotifier({
    required String branchId,
    required Ref ref,
    ChatRepository? chatRepo,
    BranchRepository? branchRepo,
  })  : _ref = ref,
        _branchId = branchId,
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

  // ── AGE VERIFICATION ───────────────────────────────────────────────────
  void resetVerification() {
    state = state.copyWith(failedPersonas: [], verifyingCount: 0);
  }
  /// Verifies persona age if needed. Runs in background, non-blocking UI.
  /// If persona.ageVerified is true, returns immediately.
  /// Otherwise: sets isVerifying: true, checks for minor signals,
  /// and updates database on success.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> verifyPersonaIfNeeded(PersonaEntity persona) async {
    if (persona.ageVerified) return;
    if (state.failedPersonas.any((p) => p.id == persona.id)) return;
    if (_disposed) return;

    state = state.copyWith(verifyingCount: state.verifyingCount + 1);

    try {
      final combinedText = [
        persona.description,
        persona.behavior ?? '',
        persona.greeting,
      ].where((s) => s.isNotEmpty).join('\n\n');

      final result = await PromptCleanerService.instance
          .checkForMinorSignals(combinedText);

      if (_disposed) return;

      if (result.hasConflict && (result.severity == 'high' || result.severity == 'medium')) {
        state = state.copyWith(
          verifyingCount: state.verifyingCount - 1,
          failedPersonas: state.failedPersonas.any((p) => p.id == persona.id)
              ? state.failedPersonas
              : [...state.failedPersonas, persona],
          error: const AgeVerificationException(),
        );
        return;
      }

      await DatabaseHelper.instance.setPersonaAgeVerified(persona.id, true);

      if (_disposed) return;
      _ref.read(personaProvider.notifier).markAgeVerified(persona.id);
      state = state.copyWith(verifyingCount: state.verifyingCount - 1);

      PromptCleanerService.instance
          .cleanAndSave(persona.id, persona.description)
          .catchError((_) {});
    } on PromptCleanerException catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        verifyingCount: state.verifyingCount - 1,
        error: PromptCleanerChatException(e),
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(verifyingCount: state.verifyingCount - 1);
    }
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────────────────

  Future<void> _saveHiddenReset(String content) async {
    final repo = await _repo();
    final hidden = ChatMessageModel(
      id: const Uuid().v4(),
      senderName: 'hidden',
      content: content,
      isUser: false,
      isHidden: true,
    );
    await repo.saveMessage(hidden, _branchId);
    state = state.copyWith(
      messages: [...state.messages, hidden],
    );
  }

  // ── SEND (SINGLE) ──────────────────────────────────────────────────────

  /// Send a user message in a single-persona chat.
  Future<void> sendMessage({
    required String content,
    required PersonaEntity persona,
    required int maxTokens,
    bool skipSave = false,
    bool isQuickAction = false,
    QuickActionType quickActionType = QuickActionType.none,
    String? hiddenResetContent,
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
      final suppressHidden = quickActionType == QuickActionType.moreDetails || 
                            quickActionType == QuickActionType.shorter;
      final reply = await repo.sendMessage(
        history: state.messages,
        persona: persona,
        maxTokens: maxTokens,
        branchId: _branchId,
        suppressHidden: suppressHidden,
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
      
      // Save hidden reset message if provided (after AI message is saved)
      if (hiddenResetContent != null && hiddenResetContent.isNotEmpty) {
        await _saveHiddenReset(hiddenResetContent);
      }
      
      // Update branch preview and timestamp
      final previewText = reply.length > 100 ? '${reply.substring(0, 100)}…' : reply;
      await _branchRepo.updatePreview(_branchId, previewText);
      await _branchRepo.touchTimestamp(_branchId);
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
    QuickActionType quickActionType = QuickActionType.none,
    String? hiddenResetContent,
  }) async {
    final repo = await _repo();
    debugPrint('[ChatNotifier] sendMultiMessage called with content="$content", behavior="$behavior"');
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
      final suppressHidden = quickActionType == QuickActionType.moreDetails || 
                            quickActionType == QuickActionType.shorter;
      final reply = await repo.sendMultiMessage(
        history: state.messages,
        personas: personas,
        behavior: behavior,
        maxTokens: effectiveTokens,
        branchId: _branchId,
        suppressHidden: suppressHidden,
      );

      final parsed = _parseMultiReply(reply, personas);
      final newMessages = <ChatMessageModel>[];
      for (final entry in parsed) {
        final msg = ChatMessageModel(
          id: const Uuid().v4(),
          senderName: entry.senderName,
          content: entry.content,
          isUser: false,
        );
        newMessages.add(msg);
        await repo.saveMessage(msg, _branchId);
      }
      state = state.copyWith(
        messages: [...state.messages, ...newMessages],
        isLoading: false,
      );
      
      // Save hidden reset message if provided (after AI messages are saved)
      if (hiddenResetContent != null && hiddenResetContent.isNotEmpty) {
        await _saveHiddenReset(hiddenResetContent);
      }
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
      // Also delete summary blocks after this point since history changed.
      await repo.deleteSummaryBlocksAfter(_branchId, newMessages.length);

      // Regenerate AI response.
      if (persona != null) {
        await sendMessage(
          content: updated.content,
          persona: persona,
          maxTokens: maxTokens,
          skipSave: true, // Don't save user message again.
          quickActionType: QuickActionType.none,
        );
      } else if (personas != null && behavior != null) {
        await sendMultiMessage(
          content: updated.content,
          personas: personas,
          behavior: behavior,
          maxTokens: maxTokens,
          skipSave: true, // Don't save user message again.
          quickActionType: QuickActionType.none,
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
    // Also delete summary blocks after this point since history changed.
    await repo.deleteSummaryBlocksAfter(_branchId, newMessages.length);

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
          suppressHidden: false,
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
        
        // Update branch preview and timestamp
        final previewText = reply.length > 100 ? '${reply.substring(0, 100)}…' : reply;
        await _branchRepo.updatePreview(_branchId, previewText);
        await _branchRepo.touchTimestamp(_branchId);
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
          suppressHidden: false,
        );
        final parsed = _parseMultiReply(reply, personas);
        final newMessages = <ChatMessageModel>[];
        for (final entry in parsed) {
          final msg = ChatMessageModel(
            id: const Uuid().v4(),
            senderName: entry.senderName,
            content: entry.content,
            isUser: false,
          );
          newMessages.add(msg);
          await repo.saveMessage(msg, _branchId);
        }
        state = state.copyWith(
          messages: [...state.messages, ...newMessages],
          isLoading: false,
        );
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
        quickActionType: QuickActionType.none,
      );
    } else if (personas != null && behavior != null) {
      await sendMultiMessage(
        content: lastUserMsg.content,
        personas: personas,
        behavior: behavior,
        maxTokens: maxTokens,
        quickActionType: QuickActionType.none,
      );
    }
  }

  /// Generate image from current scene context.
  /// If regen=true: deletes last image message first, then regenerates.
  Future<void> generateSceneImage({
    required PersonaEntity persona,
    bool regen = false,
  }) async {
    // If regenerating: find and remove last image message
    if (regen) {
      final lastImgIdx = state.messages
          .lastIndexWhere((m) => m.imageLocalPath != null);
      if (lastImgIdx >= 0) {
        final lastImgMsg = state.messages[lastImgIdx];

        // Delete file from disk
        try {
          final f = File(lastImgMsg.imageLocalPath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}

        // Delete from DB
        final repo = await _repo();
        await repo.deleteMessage(lastImgMsg.id);

        // Remove from state
        final updated = List<ChatMessageModel>.from(state.messages)
          ..removeAt(lastImgIdx);
        state = state.copyWith(messages: updated);
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Extract scene from last 8 messages
      final scene = await SceneExtractorService.instance.extractScene(
        branchId: _branchId,
        messages: state.messages,
      );

      // Generate image (no DB insert here — done below)
      final localPath = await ChatImageService.instance.generateFromScene(
        personaId: persona.id,
        personaName: persona.name,
        branchId: _branchId,
        scene: scene,
        regen: regen,
      );

      // Save image message to DB and state
      final repo = await _repo();
      final imgMsg = ChatMessageModel(
        id: const Uuid().v4(),
        personaId: persona.id,
        senderName: persona.name,
        content: '',
        isUser: false,
        imageLocalPath: localPath,
      );
      await repo.saveMessage(imgMsg, _branchId);
      state = state.copyWith(
        messages: [...state.messages, imgMsg],
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] generateSceneImage error: $e');
      final msg = e.toString().replaceFirst('Exception', '');
      state = state.copyWith(
        isLoading: false,
        error: e is AppException
            ? e
            : GenerationException(msg),
      );
    }
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────────────────

  /// Parses a multi-persona reply into separate sender-name/content pairs.
  /// Returns a list of records in the order they appear in the reply.
  List<({String senderName, String content})> _parseMultiReply(
      String reply,
      List<PersonaEntity> personas,
      ) {
    final nameAlts = personas.map((p) => RegExp.escape(p.name)).join('|');
    final pattern = RegExp(
      r'^\s*(?:\[(?:' + nameAlts + r')\]|(?:' + nameAlts + r'))\s*:\s*',
      multiLine: true,
    );

    final matches = pattern.allMatches(reply).toList();
    if (matches.isEmpty) {
      return [(
      senderName: personas.isNotEmpty ? personas.first.name : ChatConstants.aiSender,
      content: reply.trim(),
      )];
    }

    final result = <({String senderName, String content})>[];
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final rawName = match.group(0)!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll(':', '')
          .trim();

      final senderName = personas
          .where((p) => p.name == rawName)
          .firstOrNull
          ?.name ?? rawName;

      final contentStart = match.end;
      final contentEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : reply.length;

      final content = reply.substring(contentStart, contentEnd).trim();
      if (content.isNotEmpty) {
        result.add((senderName: senderName, content: content));
      }
    }
    return result;
  }
}

/// Family provider: one [ChatNotifier] per branchId.
final chatProvider =
StateNotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
      (ref, branchId) => ChatNotifier(branchId: branchId, ref: ref),
);
