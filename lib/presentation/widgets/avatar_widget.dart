import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';

/// Displays a persona avatar from a file path.
/// - Square crop for thumbnail/icon usage.
/// - Top-crop for portrait display (shows face, not legs).
/// - Falls back to initials on a coloured circle if no image.
class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final String name;
  final double size;
  final bool portraitMode;

  const AvatarWidget({
    super.key,
    this.imagePath,
    required this.name,
    this.size = 48,
    this.portraitMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();

    if (portraitMode) {
      return _portraitView(hasImage);
    }
    return _squareView(hasImage);
  }

  /// Square thumbnail (for lists / icons).
  Widget _squareView(bool hasImage) {
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.file(
            File(imagePath!),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // top-crop
          ),
        ),
      );
    }
    return _initialsCircle();
  }

  /// Portrait view (300×500-ish, top portion visible) for chat messages.
  Widget _portraitView(bool hasImage) {
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size * 1.67, // ~300x500 ratio
          child: Image.file(
            File(imagePath!),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // top-crop for portrait
          ),
        ),
      );
    }
    return _initialsCircle();
  }

  /// Fallback: coloured circle with initials.
  Widget _initialsCircle() {
    final initials = name.isNotEmpty
        ? name.characters.first.toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.userBubble,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
