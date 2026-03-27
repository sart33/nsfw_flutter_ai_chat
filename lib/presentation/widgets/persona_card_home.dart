import 'package:flutter/material.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

import '../../core/config/app_theme.dart';
import '../../domain/entities/persona_entity.dart';

class PersonaCardHome extends StatelessWidget {
  final PersonaEntity persona;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PersonaCardHome({
    super.key,
    required this.persona,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final shortDesc = persona.description.length > 40
        ? '${persona.description.substring(0, 40)}…'
        : persona.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6, right: 74),
            child: Row(
              children: [
                // Avatar — скруглённые углы чтобы вписывался в карточку
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AvatarWidget(
                    imagePath: persona.avatarPath,
                    assetPath: persona.avatarAssetPath,
                    name: persona.name,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // const SizedBox(height: 2),
                      Text(
                        shortDesc,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}