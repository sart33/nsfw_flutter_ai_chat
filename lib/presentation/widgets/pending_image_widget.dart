import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/l10n/app_localizations.dart';

class PendingImageWidget extends StatelessWidget {
  final String path;
  final VoidCallback onSave;
  final VoidCallback onRegenerate;
  final VoidCallback onDiscard;
  final bool isLoading;

  const PendingImageWidget({
    super.key,
    required this.path,
    required this.onSave,
    required this.onRegenerate,
    required this.onDiscard,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Image + overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: Image.file(
                  File(path),
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: isLoading ? null : onDiscard,
                ),
              ),
            ],
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: isLoading ? null : onRegenerate,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(context.l10n.regenerate),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onSave,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(context.l10n.save),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
