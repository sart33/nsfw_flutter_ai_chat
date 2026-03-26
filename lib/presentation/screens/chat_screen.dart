
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';
import 'package:nsfw_chat/main.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/gallery_fullscreen_screen.dart';
import 'package:nsfw_chat/presentation/widgets/chat_bubble.dart';
import 'package:photo_view/photo_view.dart';

import 'api_keys_screen.dart';

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
    this.title = '',
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
        final String trimmedBehavior = preset.behavior!.trim().replaceFirst(RegExp(r'[,.]+$'), '').trim();
        _multiBehavior = trimmedBehavior.isNotEmpty
            ? '$trimmedBehavior. ${AppConfig.addToMultiChatBehavior}'
            : AppConfig.addToMultiChatBehavior;
        // debugPrint('Resolved multi-preset behavior: $_multiBehavior', wrapWidth: 2000);
      }
    }
  }

  /// Computed max tokens from settings, multiplied for multi.
  int _maxTokens(SettingsState settings) {
    return settings.aiResponseLimit.clamp(1, 8192);
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


  void showSnack(String message, {bool isKeyError = false, bool withSettings = false}) {
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      backgroundColor: isKeyError ?  AppTheme.error : AppTheme.warning,
      duration: const Duration(seconds: 8),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      action: withSettings ? SnackBarAction(
        label: context.l10n.settings,
        textColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
        ),
      ) : null,
    ));
  }
  // ── BUILD ─────────────────────────────────────────────────────────────


  @override
  Widget build(BuildContext context) {
    // ── Error listener ───────────────────────────────────────────────────
    ref.listen<ChatState>(chatProvider(widget.branchId), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final error = next.error!;

        if (error is ApiException) {
          final is401 = error.toString().contains('401');
          final is403 = error.toString().contains('403');
          final isDeepSeek = error.toString().contains('deepseek');
          final isNovita = error.toString().contains('novita');
          showSnack(
            is401 || is403
                ? (isDeepSeek ? context.l10n.errorDeepSeekKeyInvalid
                : isNovita ? context.l10n.errorNovitaKeyInvalid
                : context.l10n.errorApiKeyInvalid)
                : context.l10n.errorConnectionFailed,
            isKeyError: is401 || is403,
            withSettings: is401 || is403,
          );
        } else if (error is GenerationException) {
          final isKeyNotSet = error.toString().contains('api_key_not_set');
          final isKeyInvalid = error.toString().contains('api_key_invalid');
          showSnack(
            isKeyNotSet ? context.l10n.errorNovitaKeyNotSet
                : isKeyInvalid ? context.l10n.errorNovitaKeyInvalid
                : context.l10n.errorImageGeneration,
            isKeyError: isKeyNotSet || isKeyInvalid,
            withSettings: isKeyNotSet || isKeyInvalid,
          );
        } else {
          final msg = switch (error) {
            HistoryException() => context.l10n.errorHistory,
            _ => context.l10n.errorUnknown,
          };
          showSnack(msg);
        }

        ref.read(chatProvider(widget.branchId).notifier).clearError();
      }
    });

    final chatState = ref.watch(chatProvider(widget.branchId));
    final settings = ref.watch(settingsProvider);
    if (_singlePersona != null) ref.watch(galleryProvider(GalleryKey(_singlePersona!.id, _singlePersona!.galleryMode)));
    // Pre-watch all multi-persona galleries to have them ready on avatar tap.
    for (final p in _multiPersonas) {
      ref.watch(galleryProvider(GalleryKey(p.id, p.galleryMode)));
    }
    _resolveEntities(ref);
    _initIfNeeded();

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
                if (msg.isQuickAction) return const SizedBox.shrink();

                // Resolve avatar for AI messages.
                String? avatarPath;
                String? avatarAssetPath;
                if (!msg.isUser && !widget.isMulti && _singlePersona != null) {
                  avatarPath = _singlePersona!.avatarPath;
                  avatarAssetPath = _singlePersona!.avatarAssetPath;
                } else if (!msg.isUser && widget.isMulti) {
                  final matched = _multiPersonas
                      .where((p) => p.name == msg.senderName)
                      .firstOrNull;
                  avatarPath = matched?.avatarPath;
                  avatarAssetPath = matched?.avatarAssetPath;
                }

                // Show regen only on the last AI message, when not loading.
                final isLastAi = msgIdx == lastAiIdx && !chatState.isLoading;

                return ChatBubble(
                  isUser: msg.isUser,
                  senderName: msg.senderName,
                  content: msg.content,
                  avatarPath: avatarPath,
                  avatarAssetPath: avatarAssetPath,
                  imageLocalPath: msg.imageLocalPath,
                  onImageTap: msg.imageLocalPath != null
                      ? () => _openImageFullscreen(context, msg.imageLocalPath!)
                      : null,
                  onImageRegen: msg.imageLocalPath != null && !chatState.isLoading && isLastAi
                      ? () => _regenSceneImage()
                      : null,
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
                      : (!msg.isUser && widget.isMulti)
                      ? () => _openGalleryFromMultiAvatar(context, msg.senderName)
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
                  // Quick action buttons — visible only when not loading
                  if (!chatState.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          _QuickActionButton(
                            label: context.l10n.continueAction,
                            icon: Icons.play_arrow,
                            onTap: () => _sendQuick(context.l10n.continueAction, settings),
                          ),
                          const SizedBox(width: 8),
                          _QuickActionButton(
                            label: context.l10n.moreDetails,
                            icon: Icons.auto_stories,
                            onTap: () => _sendQuick(
                              'Продолжи и опиши сцену подробнее — '
                              'действия, эмоции и ощущения персонажей. '
                              'Напиши в два раза больше. !!!Это всё относится к этому сообщению. Потом вернись к обычному стилю и размеру ответов.!!!',
                              settings,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!widget.isMulti)
                            _QuickActionButton(
                            label: context.l10n.photo,
                            icon: Icons.camera_alt_outlined,
                            onTap: () => _generateSceneImage(),
                          ),
                        ],
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
                                ? context.l10n.waitingForResponse
                                : context.l10n.message,
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
  void _send(SettingsState settings) async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    if (!await _ensureApiKey()) return;
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

  /// Sends a predefined quick-action message without touching _inputCtrl.
  void _sendQuick(String content, SettingsState settings) async {
    if (!await _ensureApiKey()) return;
    final tokens = _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);

    if (!widget.isMulti && _singlePersona != null) {
      notifier.sendMessage(
        content: content,
        persona: _singlePersona!,
        maxTokens: tokens,
        isQuickAction: true,
      );
    } else if (widget.isMulti) {
      notifier.sendMultiMessage(
        content: content,
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
        isQuickAction: true,
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

  /// Returns true if API key is present, false + shows SnackBar if not.
  Future<bool> _ensureApiKey() async {
    final apiKey = await AppConfig.getDeepSeekApiKey();
    if (apiKey.isNotEmpty) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(
        context.l10n.errorDeepSeekNotSet,
        style: const TextStyle(color: Colors.white),
      ),
      action: SnackBarAction(
        label: context.l10n.settings,
        textColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
        ),
      ),
      duration: const Duration(seconds: 8),
    ));
    return false;
  }

  void _generateSceneImage() async {
    if (_singlePersona == null) return;
    if (!await _ensureApiKey()) return;
// Block if the last error is an invalid DeepSeek key
    final error = ref.read(chatProvider(widget.branchId)).error;
    if (error is ApiException && error.toString().contains('401')) {
      return;
    }
    ref
        .read(chatProvider(widget.branchId).notifier)
        .generateSceneImage(persona: _singlePersona!);
  }

  void _regenSceneImage() async {
    if (_singlePersona == null) return;
    if (!await _ensureApiKey()) return;
    final error = ref.read(chatProvider(widget.branchId)).error;
    if (error is ApiException && error.toString().contains('401')) {
      return;
      }
    ref
        .read(chatProvider(widget.branchId).notifier)
        .generateSceneImage(persona: _singlePersona!, regen: true);
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
            // ── Copy ──
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primaryAccent),
              title: Text(context.l10n.copy,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: currentContent));
                Fluttertoast.showToast(msg: context.l10n.copiedToClipboard);
              },
            ),
            // ── Edit ──
            ListTile(
              leading:
                  const Icon(Icons.edit, color: AppTheme.primaryAccent),
              title: Text(context.l10n.editCharacter,
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
              title:  Text(context.l10n.delete,
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
        title: Text(context.l10n.editMessage,
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
            child: Text(context.l10n.cancel),
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
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  /// Opens gallery fullscreen when AI avatar is tapped.
  void _openGalleryFromAvatar(BuildContext context) {
    if (_singlePersona == null) return;
    final galleryState = ref.read(galleryProvider(GalleryKey(_singlePersona!.id, _singlePersona!.galleryMode)));
    if (galleryState.images.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryFullscreenScreen(
            images: galleryState.images,
            initialIndex: 0,
            personaDescription: _singlePersona!.description,
            personaId: _singlePersona!.id,
            galleryMode: _singlePersona!.galleryMode,
          ),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: context.l10n.galleryEmpty,
      );
    }
  }

  void _openGalleryFromMultiAvatar(BuildContext context, String senderName) {
    final persona = _multiPersonas
        .where((p) => p.name == senderName)
        .firstOrNull;
    if (persona == null) return;

    final galleryState = ref.read(galleryProvider(GalleryKey(persona.id, persona.galleryMode)));
    if (galleryState.images.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryFullscreenScreen(
            images: galleryState.images,
            initialIndex: 0,
            personaDescription: persona.description,
            personaId: persona.id,
            galleryMode: persona.galleryMode,
          ),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: context.l10n.galleryNameEmpty(persona.name),
      );
    }
  }

  void _openImageFullscreen(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
          ),
          body: PhotoView(
            imageProvider: FileImage(File(imagePath)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            backgroundDecoration:
                const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  /// AlertDialog: confirm deletion.
  /// Deletes the message and all messages after it (cascade).
  void _showDeleteConfirm(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteMessage,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          context.l10n.messageAndFollowingWillBeDeleted,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(chatProvider(widget.branchId).notifier)
                  .deleteMessage(messageId);
            },
            child: Text(context.l10n.delete,
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

  }
}

/// Quick-action button used above the input field.
class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
