import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/config/chat_constants.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

/// Maps a raw [senderName] constant to its localised display string.
///
/// - [ChatConstants.userSender] → l10n.senderYou
/// - [ChatConstants.systemSender] → l10n.senderSystem
/// - anything else (persona name) → returned as-is
String _resolveSenderName(BuildContext context, String senderName) {
  return switch (senderName) {
    ChatConstants.userSender => context.l10n.senderYou,
    ChatConstants.systemSender => context.l10n.senderSystem,
    _ => senderName,
  };
}

/// A single chat bubble with optional long-press and regen actions.
/// - User messages: right-aligned, #333333 background.
/// - AI messages: left-aligned, #111111 background, sender name above in gray.
/// NSFW: explicit content expected — no filtering in UI layer.
class ChatBubble extends StatelessWidget {
  final bool isUser;
  final String senderName;
  final String content;
  final String? avatarPath;
  final String? imageLocalPath;
  final VoidCallback? onImageTap;
  final VoidCallback? onImageRegen;

  /// Called on long-press (edit / delete actions).
  final VoidCallback? onLongPress;

  /// Whether to show the regenerate button at bottom-left of the bubble.
  final bool showRegenButton;

  /// Called when the regen button is tapped.
  final VoidCallback? onRegen;

  /// Called when the AI avatar is tapped (e.g. open gallery).
  final VoidCallback? onAvatarTap;

  /// Font size for the message body text. Defaults to 15.
  final double chatFontSize;

  const ChatBubble({
    super.key,
    required this.isUser,
    required this.senderName,
    required this.content,
    this.avatarPath,
    this.imageLocalPath,
    this.onImageTap,
    this.onImageRegen,
    this.onLongPress,
    this.showRegenButton = false,
    this.onRegen,
    this.onAvatarTap,
    this.chatFontSize = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              GestureDetector(
                onTap: onAvatarTap,
                child: AvatarWidget(
                  imagePath: avatarPath,
                  name: senderName,
                  size: 36,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name above AI bubble.
                  if (!isUser)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _resolveSenderName(context, senderName),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Bubble body.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.userBubble : AppTheme.aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: chatFontSize,
                      ),
                    ),
                  ),
                  // Image if present
                  if (imageLocalPath != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imageLocalPath!),
                          width: 220,
                          height: 280,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    (showRegenButton && !isUser) ?
                    InkWell(
                      onTap: onImageRegen,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh,
                                size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.regenerate,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
    : const SizedBox(height: 8),
                  ],
                  // Regen button — only for the last AI message.
                  if (showRegenButton && !isUser && imageLocalPath == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: onRegen,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh,
                                  size: 16, color: AppTheme.textSecondary),
                              SizedBox(width: 4),
                              Text(
                                context.l10n.regenerate,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}
