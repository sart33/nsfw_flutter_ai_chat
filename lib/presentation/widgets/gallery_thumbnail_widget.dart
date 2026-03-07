import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';

class GalleryThumbnailWidget extends StatelessWidget {
  final GalleryImageEntity image;
  final VoidCallback onTap;

  const GalleryThumbnailWidget({
    super.key,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(image.localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.surface,
            child: const Center(
              child: Icon(Icons.broken_image,
                  color: AppTheme.textSecondary, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
