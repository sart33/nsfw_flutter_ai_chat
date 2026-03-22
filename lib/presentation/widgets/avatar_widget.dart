import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';

/// Displays a persona avatar with fallback priority:
/// 1. [imagePath] — File on disk (user uploaded / generated). Check existsSync().
/// 2. [assetPath] — Flutter asset (e.g. "assets/avatars/natasha.png").
/// 3. Initials fallback — colored circle with first letter.
///
/// - Square crop for thumbnail/icon usage.
/// - Top-crop for portrait display (shows face, not legs).
class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final String? assetPath;
  final String name;
  final double size;
  final bool portraitMode;

  const AvatarWidget({
    super.key,
    this.imagePath,
    this.assetPath,
    required this.name,
    this.size = 48,
    this.portraitMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasFileImage =
        imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();
    final hasAssetImage = assetPath != null && assetPath!.isNotEmpty;

    if (portraitMode) {
      return _portraitView(hasFileImage, hasAssetImage);
    }
    return _squareView(hasFileImage, hasAssetImage);
  }

  /// Square thumbnail (for lists / icons).
  Widget _squareView(bool hasFileImage, bool hasAssetImage) {
    if (hasFileImage) {
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
    if (hasAssetImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            assetPath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // top-crop
            errorBuilder: (_, __, ___) => _initialsCircle(),
          ),
        ),
      );
    }
    return _initialsCircle();
  }

  /// Portrait view (300×500-ish, top portion visible) for chat messages.
  Widget _portraitView(bool hasFileImage, bool hasAssetImage) {
    if (hasFileImage) {
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
    if (hasAssetImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size * 1.67, // ~300x500 ratio
          child: Image.asset(
            assetPath!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // top-crop for portrait
            errorBuilder: (_, __, ___) => _initialsCircle(),
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
