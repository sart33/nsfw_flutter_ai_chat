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

import '../widgets/custom_app_bar_widget.dart';

class MultiPresetListScreen extends ConsumerWidget {
  const MultiPresetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(multiPresetProvider);
    final personasAsync = ref.watch(personaProvider);

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.multiChat),
      body: personasAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentVivid),
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            '${context.l10n.errorLoadingCharacters}$error',
            style: const TextStyle(color: AppTheme.warning),
          ),
        ),
        data: (personas) {
          if (presets.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noMultiPresets,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return Dismissible(
                key: Key(preset.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 28),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  child: const Icon(Icons.delete_outline,
                      color: AppTheme.warning, size: 24),
                ),
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) =>
                    ref.read(multiPresetProvider.notifier).delete(preset.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  child: Material(
                    color: Colors.transparent,
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
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: AppTheme.cardDecoration(),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _buildAvatarGroup(preset, personas),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                    '${preset.personaIds.length} ${context.l10n.characters}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showOptions(context, ref, preset),
                      child: const Icon(Icons.more_vert,
                              color: AppTheme.textSecondary, size: 20),
                        )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CreateEditMultiPresetScreen()),
        ),
        backgroundColor: AppTheme.accentVivid,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        icon: const Icon(Icons.group_add_outlined, size: 20),
        label: Text(context.l10n.newMultiChat,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarGroup(
      MultiPresetEntity preset, List<PersonaEntity> personas) {
    const double avatarSize = 52.0;
    const double overlap = 44.0;

    final matchedPersonas = <PersonaEntity>[];
    for (final personaId in preset.personaIds) {
      final persona =
          personas.where((p) => p.id == personaId).firstOrNull;
      if (persona != null) matchedPersonas.add(persona);
    }

    final displayPersonas = matchedPersonas.take(3).toList();
    final count = displayPersonas.length;

    if (count == 0) {
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: AppTheme.iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.group, color: AppTheme.accentLight, size: 26),
      );
    }

    final width = avatarSize + (count - 1) * overlap;

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: [
          for (int i = count - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AvatarWidget(
                  imagePath: displayPersonas[i].avatarPath,
                  assetPath: displayPersonas[i].avatarAssetPath,
                  name: displayPersonas[i].name,
                  size: avatarSize,
                ),
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
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.cannotBeUndone,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete,
                style: const TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }

  /// Shows options for a persona like view, edit, chats, delete
  void _showOptions(BuildContext context, WidgetRef ref, dynamic preset) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
              title: Text(context.l10n.editCharacter,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CreateEditMultiPresetScreen(presetId: preset.id)
                ),
                ).then((changed) {
                  if (changed == true) {
                    // Refresh persona list after editing
                    ref.invalidate(personaProvider);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.textPrimary),
              title: Text(context.l10n.chats,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BranchListScreen(
                      entityId: 'multi:${preset.id}',
                      entityName: preset.name,
                      isMulti: true,
                      greeting: preset.greeting,
                    ),
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(context.l10n.delete,
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref.read(multiPresetProvider.notifier).delete(preset.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}