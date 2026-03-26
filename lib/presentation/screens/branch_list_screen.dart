import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/presentation/providers/branch_provider.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/screens/chat_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

import '../widgets/custom_app_bar_widget.dart';

/// Displays a list of conversation branches for an entity.
///
/// Args:
///   [entityId]   — `single:{id}` or `multi:{id}`
///   [entityName] — display name for the AppBar
///   [isMulti]    — true for multi-preset, false for single persona
///   [greeting]   — greeting text to seed new branches
class BranchListScreen extends ConsumerWidget {
  final String entityId;
  final String entityName;
  final bool isMulti;
  final String greeting;

  const BranchListScreen({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.isMulti,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchProvider(entityId));
    final personas = ref.watch(personaProvider);
    final presets = ref.watch(multiPresetProvider);

    return Scaffold(
      appBar: CustomAppBar(title: entityName),
      body: branches.isEmpty
          ? Center(
        child: Text(
          context.l10n.noBranches,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          return Dismissible(
            key: Key(branch.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red.shade900,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) {
              ref.read(branchProvider(entityId).notifier).deleteBranch(branch.id);
              ref.invalidate(chatProvider(branch.id));
            },
            // ── Branch card — matches PersonaCard style ──────────────
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openChat(context, ref, branch.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: AppTheme.cardDecoration(),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // ── Avatar area ────────────────────────────
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildAvatarArea(personas, presets),
                        ),
                        const SizedBox(width: 14),
                        // ── Text area ──────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDateTime(branch.updatedAt),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                branch.preview ?? context.l10n.emptyBranch,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: branch.preview != null
                                      ? AppTheme.textSecondary
                                      : AppTheme.textSecondary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAndOpen(context, ref),
          backgroundColor: AppTheme.accentVivid,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32)),
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          label: Text(context.l10n.newChat,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2))
      ),
    );
  }

  /// Builds the avatar area based on single or multi chat mode.
  Widget _buildAvatarArea(
      List<PersonaEntity> personas, List<MultiPresetEntity> presets) {
    const double avatarSize = 54.0;
    const double overlap = 44.0;
    const int maxAvatars = 3;

    if (!isMulti) {
      // Single chat: parse personaId from entityId
      final personaId = entityId.startsWith('single:')
          ? entityId.substring(7)
          : entityId;
      final persona = personas.where((p) => p.id == personaId).firstOrNull;
      return AvatarWidget(
        imagePath: persona?.avatarPath,
        assetPath: persona?.avatarAssetPath,
        name: persona?.name ?? '?',
        size: avatarSize,
      );
    } else {
      // Multi chat: parse presetId from entityId
      final presetId = entityId.startsWith('multi:')
          ? entityId.substring(6)
          : entityId;
      final preset = presets.where((p) => p.id == presetId).firstOrNull;
      if (preset == null) {
        return Icon(Icons.group, color: AppTheme.primaryAccent, size: avatarSize);
      }

      final matchedPersonas = preset.personaIds
          .map((id) => personas.where((p) => p.id == id).firstOrNull)
          .where((p) => p != null)
          .cast<PersonaEntity>()
          .take(maxAvatars)
          .toList();

      if (matchedPersonas.isEmpty) {
        return Icon(Icons.group, color: AppTheme.primaryAccent, size: avatarSize);
      }

      final count = matchedPersonas.length;
      final totalWidth = avatarSize + (count - 1) * overlap;

      return SizedBox(
        width: totalWidth,
        height: avatarSize,
        child: Stack(
          children: List.generate(count, (index) {
            final reverseIndex = count - 1 - index;
            final persona = matchedPersonas[reverseIndex];
            return Positioned(
              left: reverseIndex * overlap,
              child: AvatarWidget(
                imagePath: persona.avatarPath,
                assetPath: persona.avatarAssetPath,
                name: persona.name,
                size: avatarSize,
              ),
            );
          }),
        ),
      );
    }
  }

  /// Creates a new branch and navigates to chat.
  Future<void> _createAndOpen(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(branchProvider(entityId).notifier);
    final branch = await notifier.createBranch();
    if (!context.mounted) return;
    _openChat(context, ref, branch.id);
  }

  /// Navigates to the chat screen for a branch.
  void _openChat(BuildContext context, WidgetRef ref, String branchId) {
    final rawId = entityId.contains(':')
        ? entityId.substring(entityId.indexOf(':') + 1)
        : entityId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          branchId: branchId,
          entityId: rawId,
          isMulti: isMulti,
          greeting: greeting,
          title: entityName,
        ),
      ),
    ).then((_) {
      ref.read(branchProvider(entityId).notifier).refresh();
    });
  }

  /// Shows a confirmation dialog before deleting a branch.
  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          context.l10n.deleteBranch,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          context.l10n.allMessagesWillBeDeleted,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ── DATE FORMATTING (no intl dependency) ─────────────────────────────

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }
}