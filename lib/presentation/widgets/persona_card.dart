import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

/// A list-tile style card showing avatar thumbnail + name + short description.
class PersonaCard extends StatelessWidget {
  final PersonaEntity persona;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PersonaCard({
    super.key,
    required this.persona,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final shortDesc = persona.description.length > 80
        ? '${persona.description.substring(0, 80)}…'
        : persona.description;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarWidget(
                imagePath: persona.avatarPath,
                assetPath: persona.avatarAssetPath,
                name: persona.name,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortDesc,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
