import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_multi_preset_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';

/// Lists saved multi-presets. Tap → open multi chat. FAB → create new.
class MultiPresetListScreen extends ConsumerWidget {
  const MultiPresetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(multiPresetProvider);
    final personas = ref.watch(personaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.multiChat)),
      body: presets.isEmpty
          ? Center(
              child: Text(
                context.l10n.noMultiPresets,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                return Dismissible(
                  key: Key(preset.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red.shade900,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) {
                    ref
                        .read(multiPresetProvider.notifier)
                        .delete(preset.id);
                  },
                  child: Card(
                    color: AppTheme.surface,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BranchListScreen(
                            entityId: 'multi:${preset.id}',
                            entityName: preset.name,
                            isMulti: true,
                            greeting: preset.greeting,
                          ),
                        ),
                      ),
                      onLongPress: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateEditMultiPresetScreen(
                              presetId: preset.id),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _buildAvatarGroup(preset, personas),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${preset.personaIds.length} персонажей',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateEditMultiPresetScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAvatarGroup(MultiPresetEntity preset, List<PersonaEntity> personas) {
    const double avatarSize = 52.0;
    const double overlap = 44.0;

    // Filter personas to only those whose id is in preset.personaIds, preserving order
    final matchedPersonas = <PersonaEntity>[];
    for (final personaId in preset.personaIds) {
      final persona = personas.where((p) => p.id == personaId).firstOrNull;
      if (persona != null) {
        matchedPersonas.add(persona);
      }
    }

    // Take at most 4 matched personas
    final displayPersonas = matchedPersonas.take(3).toList();
    final count = displayPersonas.length;

    // If 0 matches — return fallback icon
    if (count == 0) {
      return const Icon(Icons.group, color: AppTheme.primaryAccent);
    }

    // Calculate width: avatarSize + (count - 1) * overlap
    final width = avatarSize + (count - 1) * overlap;

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: [
          // Add avatars in reverse order so index 0 appears on top
          for (int i = count - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              child: AvatarWidget(
                imagePath: displayPersonas[i].avatarPath,
                name: displayPersonas[i].name,
                size: avatarSize,
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deletePreset,
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.cannotBeUndone,
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(context.l10n.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
