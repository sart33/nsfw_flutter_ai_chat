import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/providers/branch_provider.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/screens/chat_screen.dart';


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

    return Scaffold(
      appBar: AppBar(title: Text(entityName)),
      body: branches.isEmpty
          ? Center(
              child: Text(
                context.l10n.noBranches,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                return Card(
                  color: AppTheme.surface,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    onTap: () => _openChat(context, ref, branch.id),
                    borderRadius: BorderRadius.circular(12),
                      child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Left: date
                          Text(
                            _formatDateTime(branch.updatedAt),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Middle: preview
                          Expanded(
                            child: Text(
                              branch.preview ?? context.l10n.emptyBranch,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: branch.preview != null
                                    ? AppTheme.textSecondary
                                    : AppTheme.textSecondary.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Right: summarization icon (if summarized)
                          if (branch.contextSummary != null && branch.contextSummary!.isNotEmpty)
                            Tooltip(
                              message: context.l10n.branchSummarized,
                              child: Icon(
                                Icons.compress,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Right: delete button
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.textSecondary, size: 22),
                            onPressed: () =>
                                _confirmDelete(context, ref, branch.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createAndOpen(context, ref),
        child: const Icon(Icons.add),
      ),
    );
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
    // Extract the raw id from entityId (strip "single:" or "multi:" prefix).
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
      // Refresh branch list when returning from chat (preview may have changed).
      ref.read(branchProvider(entityId).notifier).refresh();
    });
  }

  /// Shows a confirmation dialog before deleting a branch.
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String branchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteBranch,
            style: TextStyle(color: AppTheme.textPrimary)),
        content:  Text(
          context.l10n.allMessagesWillBeDeleted,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:  Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(branchProvider(entityId).notifier).deleteBranch(branchId);
      // Invalidate the chat provider for the deleted branch.
      ref.invalidate(chatProvider(branchId));
    }
  }

  // ── DATE FORMATTING (no intl dependency) ─────────────────────────────

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }
}
