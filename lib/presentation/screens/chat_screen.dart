import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/gallery_fullscreen_screen.dart';
import 'package:nsfw_chat/presentation/widgets/chat_bubble.dart';

/// Chat screen — works for both single-persona and multi-preset chats.
///
/// Args received via constructor:
///   [branchId]       — required, identifies the conversation branch
///   [entityId]       — the persona or preset id (used with [isMulti])
///   [isMulti]        — false = single persona chat, true = multi-preset chat
///   [greeting]       — initial greeting text (injected if branch is empty)
///   [title]          — display name for AppBar (persona name or preset name)
///
/// NSFW: explicit content expected — no filtering in UI layer.
class ChatScreen extends ConsumerStatefulWidget {
  final String branchId;
  final String entityId;
  final bool isMulti;
  final String greeting;
  final String title;

  const ChatScreen({
    super.key,
    required this.branchId,
    required this.entityId,
    this.isMulti = false,
    this.greeting = '',
    this.title = 'Чат',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _initialized = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Resolved persona / multi-preset data ──────────────────────────────

  PersonaEntity? _singlePersona;
  List<PersonaEntity> _multiPersonas = [];
  String _multiBehavior = '';

  /// Resolves persona(s) from providers. Called inside build().
  void _resolveEntities(WidgetRef ref) {
    final personas = ref.watch(personaProvider);

    if (!widget.isMulti) {
      _singlePersona =
          personas.where((p) => p.id == widget.entityId).firstOrNull;
    } else {
      final preset = ref
          .watch(multiPresetProvider)
          .where((p) => p.id == widget.entityId)
          .firstOrNull;
      if (preset != null) {
        _multiPersonas =
            personas.where((p) => preset.personaIds.contains(p.id)).toList();
        _multiBehavior = preset.behavior ?? '';
      }
    }
  }

  /// Computed max tokens from settings, multiplied for multi.
  int _maxTokens(SettingsState settings) {
    final base = settings.aiResponseLimit ~/ 4; // rough char→token
    if (widget.isMulti && _multiPersonas.isNotEmpty) {
      return base * _multiPersonas.length;
    }
    return base;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  void _initIfNeeded() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(chatProvider(widget.branchId).notifier);

      if (!widget.isMulti && _singlePersona != null) {
        notifier.init(
          greeting: _singlePersona!.greeting,
          personaId: _singlePersona!.id,
          personaName: _singlePersona!.name,
          isMulti: false,
        );
      } else if (widget.isMulti) {
        notifier.init(
          greeting: widget.greeting,
          isMulti: true,
        );
      } else {
        notifier.init();
      }
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.branchId));
    final settings = ref.watch(settingsProvider);
    if (_singlePersona != null) ref.watch(galleryProvider(_singlePersona!.id));

    _resolveEntities(ref);
    _initIfNeeded();

    // ── Error toast ───────────────────────────────────────────────────
    if (chatState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Fluttertoast.showToast(
          msg: 'Ошибка API',
          backgroundColor: Colors.red.shade900,
          textColor: Colors.white,
        );
        // Clear error in notifier so toast doesn't loop.
        ref.read(chatProvider(widget.branchId).notifier).clearError();
      });
    }

    // ── Input metrics ─────────────────────────────────────────────────
    final inputLen = _inputCtrl.text.length;
    final inputLimit = settings.userInputLimit;
    final overLimit = inputLen > inputLimit;
    final canSend =
        !overLimit && !chatState.isLoading && _inputCtrl.text.trim().isNotEmpty;

    // Find index of last AI message (for regen button).
    final lastAiIdx =
        chatState.messages.lastIndexWhere((m) => !m.isUser);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // ── Messages list ──────────────────────────────────────
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chatState.messages.length +
                  (chatState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // With reverse: true, index 0 = bottom of screen.
                // Loading indicator at the very bottom (index 0).
                if (chatState.isLoading && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                // Map reversed index to original message index.
                final loadingOffset = chatState.isLoading ? 1 : 0;
                final reversedIdx = index - loadingOffset;
                final msgIdx =
                    chatState.messages.length - 1 - reversedIdx;
                final msg = chatState.messages[msgIdx];

                // Resolve avatar for AI messages.
                String? avatarPath;
                if (!msg.isUser && !widget.isMulti && _singlePersona != null) {
                  avatarPath = _singlePersona!.avatarPath;
                } else if (!msg.isUser && widget.isMulti) {
                  final matched = _multiPersonas
                      .where((p) => p.name == msg.senderName)
                      .firstOrNull;
                  avatarPath = matched?.avatarPath;
                }

                // Show regen only on the last AI message, when not loading.
                final isLastAi = msgIdx == lastAiIdx && !chatState.isLoading;

                return ChatBubble(
                  isUser: msg.isUser,
                  senderName: msg.senderName,
                  content: msg.content,
                  avatarPath: avatarPath,
                  chatFontSize: settings.chatFontSize,
                  showRegenButton: isLastAi,
                  onRegen: isLastAi
                      ? () => _regenLastAI(settings)
                      : null,
                  onLongPress: () => _showMessageActions(
                    context,
                    msg.id,
                    msg.content,
                    msg.isUser,
                    settings,
                  ),
                  onAvatarTap: (!msg.isUser && !widget.isMulti && _singlePersona != null)
                      ? () => _openGalleryFromAvatar(context)
                      : null,
                );
              },
            ),
          ),

          // ── Input area ─────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Char counter.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Text(
                      '$inputLen / $inputLimit',
                      style: TextStyle(
                        color: overLimit ? Colors.red : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          enabled: !chatState.isLoading,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: chatState.isLoading
                                ? 'Ожидание ответа...'
                                : 'Сообщение...',
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: canSend
                            ? () => _send(settings)
                            : null,
                        icon: Icon(
                          Icons.send,
                          color: canSend
                              ? AppTheme.primaryAccent
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIONS ───────────────────────────────────────────────────────────

  /// Send user message (single or multi depending on [isMulti]).
  void _send(SettingsState settings) {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    _inputCtrl.clear();
    setState(() {});

    final tokens = _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);

    if (!widget.isMulti && _singlePersona != null) {
      notifier.sendMessage(
        content: content,
        persona: _singlePersona!,
        maxTokens: tokens,
      );
    } else if (widget.isMulti) {
      notifier.sendMultiMessage(
        content: content,
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
      );
    }
  }

  /// Regenerate the last AI message.
  /// ⚠️ Each regen = full history resent to DeepSeek → increases API token cost.
  void _regenLastAI(SettingsState settings) {
    final tokens = _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);

    if (!widget.isMulti && _singlePersona != null) {
      notifier.regenLastAI(
        persona: _singlePersona,
        maxTokens: tokens,
      );
    } else if (widget.isMulti) {
      notifier.regenLastAI(
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
      );
    }
  }

  /// Show ModalBottomSheet with edit / delete options for a message.
  void _showMessageActions(
    BuildContext context,
    String messageId,
    String currentContent,
    bool isUser,
    SettingsState settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Edit ──
            ListTile(
              leading:
                  const Icon(Icons.edit, color: AppTheme.primaryAccent),
              title: const Text('Редактировать',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(
                    context, messageId, currentContent, settings);
              },
            ),
            // ── Delete ──
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Удалить',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(context, messageId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// AlertDialog: edit message content.
  /// On confirm: notifier.editMessage(id, newContent).
  /// If an AI message follows the edited one, auto-regeneration happens
  /// inside the notifier (full history resent → token cost).
  void _showEditDialog(
    BuildContext context,
    String messageId,
    String currentContent,
    SettingsState settings,
  ) {
    final editCtrl = TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Редактировать сообщение',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: editCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          maxLines: 8,
          minLines: 2,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editCtrl.text.trim();
              if (newContent.isEmpty) return;
              Navigator.pop(ctx);

              final tokens = _maxTokens(settings);
              final notifier =
                  ref.read(chatProvider(widget.branchId).notifier);

              notifier.editMessage(
                messageId: messageId,
                newContent: newContent,
                persona: !widget.isMulti ? _singlePersona : null,
                personas: widget.isMulti ? _multiPersonas : null,
                behavior: widget.isMulti ? _multiBehavior : null,
                maxTokens: tokens,
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  /// Opens gallery fullscreen when AI avatar is tapped.
  void _openGalleryFromAvatar(BuildContext context) {
    if (_singlePersona == null) return;
    final galleryState = ref.read(galleryProvider(_singlePersona!.id));
    if (galleryState.images.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryFullscreenScreen(
            images: galleryState.images,
            initialIndex: 0,
            personaDescription: _singlePersona!.description,
            personaId: _singlePersona!.id,
          ),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: 'Галерея пуста. Откройте карточку персонажа.',
      );
    }
  }

  /// AlertDialog: confirm deletion.
  /// Deletes the message and all messages after it (cascade).
  void _showDeleteConfirm(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить сообщение',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: const Text(
          'Сообщение и все последующие будут удалены. Продолжить?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(chatProvider(widget.branchId).notifier)
                  .deleteMessage(messageId);
            },
            child: const Text('Удалить',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
