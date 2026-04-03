import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_multi_preset_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

import '../widgets/custom_app_bar_widget.dart';

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class MultiPresetListScreen extends ConsumerWidget {
  const MultiPresetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets       = ref.watch(multiPresetProvider);
    final personasAsync = ref.watch(personaProvider);
    final screenWidth   = MediaQuery.of(context).size.width;
    final useDesktop    =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.multiChat),
      body: personasAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentVivid),
        ),
        error: (error, _) => Center(
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

          return useDesktop
              ? _buildDesktopGrid(context, ref, presets, personas)
              : _buildMobileList(context, ref, presets, personas);
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
        label: Text(
          context.l10n.newMultiChat,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — без изменений
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileList(
      BuildContext context,
      WidgetRef ref,
      List<MultiPresetEntity> presets,
      List<PersonaEntity> personas,
      ) {
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
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: const Icon(Icons.delete_outline,
                color: AppTheme.warning, size: 24),
          ),
          confirmDismiss: (_) => _confirmDelete(context),
          onDismissed: (_) =>
              ref.read(multiPresetProvider.notifier).delete(preset.id),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BranchListScreen(
                      entityId:   'multi:${preset.id}',
                      entityName: preset.name,
                      isMulti:    true,
                      greeting:   preset.greeting,
                    ),
                  ),
                ),
                onLongPress: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateEditMultiPresetScreen(presetId: preset.id),
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
                        onTap: () =>
                            _showOptions(context, ref, preset),
                        child: const Icon(Icons.more_vert,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT — грид карточек
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopGrid(
      BuildContext context,
      WidgetRef ref,
      List<MultiPresetEntity> presets,
      List<PersonaEntity> personas,
      ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final preset = presets[index];
            final matched = preset.personaIds
                .map((id) =>
            personas.where((p) => p.id == id).firstOrNull)
                .where((p) => p != null)
                .cast<PersonaEntity>()
                .toList();

            return _DesktopPresetCard(
              preset:   preset,
              personas: matched,
              onChat: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BranchListScreen(
                    entityId:   'multi:${preset.id}',
                    entityName: preset.name,
                    isMulti:    true,
                    greeting:   preset.greeting,
                  ),
                ),
              ),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEditMultiPresetScreen(
                      presetId: preset.id),
                ),
              ),
              onDelete: () async {
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref
                      .read(multiPresetProvider.notifier)
                      .delete(preset.id);
                }
              },
            );
          },
        ),
      ),
    );
  }

  // ── Мобильный аватар-группа (горизонтальный веер) ─────────────────────────

  Widget _buildAvatarGroup(
      MultiPresetEntity preset, List<PersonaEntity> personas) {
    const double avatarSize = 52.0;
    const double overlap    = 44.0;

    final matched = <PersonaEntity>[];
    for (final id in preset.personaIds) {
      final p = personas.where((p) => p.id == id).firstOrNull;
      if (p != null) matched.add(p);
    }

    final display = matched.take(3).toList();
    final count   = display.length;

    if (count == 0) {
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: AppTheme.iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.group,
            color: AppTheme.accentLight, size: 26),
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
                  imagePath: display[i].avatarPath,
                  assetPath: display[i].avatarAssetPath,
                  name:      display[i].name,
                  size:      avatarSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────────

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
                style:
                const TextStyle(color: AppTheme.textSecondary)),
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

  void _showOptions(
      BuildContext context, WidgetRef ref, MultiPresetEntity preset) {
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
              leading: const Icon(Icons.edit_outlined,
                  color: AppTheme.textPrimary),
              title: Text(context.l10n.editCharacter,
                  style:
                  const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditMultiPresetScreen(
                        presetId: preset.id),
                  ),
                ).then((changed) {
                  if (changed == true) {
                    ref.invalidate(personaProvider);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.textPrimary),
              title: Text(context.l10n.chats,
                  style:
                  const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BranchListScreen(
                      entityId:   'multi:${preset.id}',
                      entityName: preset.name,
                      isMulti:    true,
                      greeting:   preset.greeting,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              title: Text(context.l10n.delete,
                  style:
                  const TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref
                      .read(multiPresetProvider.notifier)
                      .delete(preset.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop card
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopPresetCard extends StatelessWidget {
  final MultiPresetEntity  preset;
  final List<PersonaEntity> personas;
  final VoidCallback onChat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesktopPresetCard({
    required this.preset,
    required this.personas,
    required this.onChat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Аватарки — верхняя часть ────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onChat,
              child: _buildAvatarComposition(),
            ),
          ),

          // ── Имя + кол-во персонажей ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${preset.personaIds.length} ${context.l10n.characters}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Строка действий ──────────────────────────────────────
          Container(
            height: 44,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.cardBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                _ActionBtn(
                  icon:    Icons.chat_bubble_outline,
                  color:   AppTheme.primaryAccent,
                  tooltip: 'Чат',
                  onTap:   onChat,
                ),
                _VDivider(),
                _ActionBtn(
                  icon:    Icons.edit_outlined,
                  color:   AppTheme.textSecondary,
                  tooltip: 'Редактировать',
                  onTap:   onEdit,
                ),
                _VDivider(),
                _ActionBtn(
                  icon:    Icons.delete_outline,
                  color:   AppTheme.warning,
                  tooltip: 'Удалить',
                  onTap:   onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Композиция аватарок в зависимости от количества персонажей.
  Widget _buildAvatarComposition() {
    final count = personas.length.clamp(0, 4);

    if (count == 0) {
      return Container(
        color: AppTheme.cardBg,
        child: const Center(
          child: Icon(Icons.group, color: AppTheme.textSecondary, size: 48),
        ),
      );
    }

    // 5+ — просто иконка с числом
    if (personas.length > 4) {
      return Container(
        color: AppTheme.cardBg,
        child: Center(
          child: Text(
            '${personas.length}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        switch (count) {
        // ── 1 персонаж ─────────────────────────────────────────
          case 1:
            return _avatarTile(personas[0], w, h);

        // ── 2 персонажа — один под другим ─────────────────────
          case 2:
            return Column(
              children: [
                Expanded(child: _avatarTile(personas[0], w, h / 2)),
                Expanded(child: _avatarTile(personas[1], w, h / 2)),
              ],
            );

        // ── 3 персонажа — 2 сверху + 1 снизу по центру ────────
          case 3:
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _avatarTile(personas[0], w / 2, h / 2)),
                      Expanded(
                          child: _avatarTile(personas[1], w / 2, h / 2)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _avatarTile(personas[2], w, h / 2)),
                    ],
                  ),
                ),
              ],
            );

        // ── 4 персонажа — сетка 2×2 ────────────────────────────
          case 4:
          default:
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _avatarTile(personas[0], w / 2, h / 2)),
                      Expanded(
                          child: _avatarTile(personas[1], w / 2, h / 2)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _avatarTile(personas[2], w / 2, h / 2)),
                      Expanded(
                          child: _avatarTile(personas[3], w / 2, h / 2)),
                    ],
                  ),
                ),
              ],
            );
        }
      },
    );
  }

  Widget _avatarTile(PersonaEntity p, double w, double h) {
    final hasFile = p.avatarPath != null && File(p.avatarPath!).existsSync();
    final hasAsset =
        p.avatarAssetPath != null && p.avatarAssetPath!.isNotEmpty;

    if (hasFile) {
      return Image.file(File(p.avatarPath!),
          fit: BoxFit.cover,
          width: w,
          height: h,
          alignment: Alignment.topCenter);
    }
    if (hasAsset) {
      return Image.asset(p.avatarAssetPath!,
          fit: BoxFit.cover,
          width: w,
          height: h,
          alignment: Alignment.topCenter);
    }
    return Container(
      width: w,
      height: h,
      color: AppTheme.cardBg,
      child: Center(
        child: Text(
          _initials(p.name),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Shared action button widgets ──────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    color: AppTheme.cardBorder,
  );
}