import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

/// A list-tile style card showing avatar thumbnail + name + short description.
class PersonaCard extends StatelessWidget {
  final PersonaEntity persona;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMoreTap;


  const PersonaCard({
    super.key,
    required this.persona,
    this.onTap,
    this.onLongPress,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortDesc = persona.description.length > 80
        ? '${persona.description.substring(0, 80)}…'
        : persona.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        // color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: AppTheme.cardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar — скруглённые углы чтобы вписывался в карточку
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AvatarWidget(
                    imagePath: persona.avatarPath,
                    assetPath: persona.avatarAssetPath,
                    name: persona.name,
                    size: 54,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              persona.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!persona.ageVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.unVerified,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shortDesc,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onMoreTap,
                  child: const Icon(Icons.more_vert,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}