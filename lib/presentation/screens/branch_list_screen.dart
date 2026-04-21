import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/branch_provider.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/chat_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_view_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';
import 'package:nsfw_chat/presentation/screens/support_the_project_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

import 'about_app_screen.dart';
import 'home_screen.dart';

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;


/// Displays a list of conversation branches for an entity.
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
    final branches      = ref.watch(branchProvider(entityId));
    final personasAsync = ref.watch(personaProvider);
    final presets       = ref.watch(multiPresetProvider);
    final screenWidth   = MediaQuery.of(context).size.width;
    final useDesktop    =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;



    const whiteStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: !isMulti
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) {
                final personaId = entityId.substring(7);
                final personas  = personasAsync.value ?? [];
                final persona =
                personas.firstWhere((p) => p.id == personaId);
                return PersonaViewScreen(persona: persona);
              },
            ),
          )
              : null,
          child: Text(
            entityName,
            style: whiteStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        centerTitle: true,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          if (useDesktop)
            IconButton(
              icon: const Icon(
                Icons.home_outlined,
                size: 26,
                color: AppTheme.textPrimary,
              ),
              tooltip: 'Home',
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              size: useDesktop ? 26 : 24,
              color:  useDesktop ? AppTheme.primaryAccent : AppTheme.textSecondary,

            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupportProjectScreen()),
              );
            },
          ),
          if (useDesktop)
            IconButton(
              icon: const Icon(Icons.info_outline,
                  size: 26, color: AppTheme.textSecondary),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutAppScreen())),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings,
                  size: 26, color: AppTheme.textPrimary),
              tooltip: context.l10n.settings,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
      body: personasAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentVivid),
        ),
        error: (error, _) => Center(
          child: Text(
            '${context.l10n.errorLoadingCharacters} $error',
            style: const TextStyle(color: AppTheme.warning),
          ),
        ),
        data: (personas) {
          if (branches.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noBranches,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                ),
              ),
            );
          }

          return useDesktop
              ? _buildDesktopGrid(context, ref, personas, presets)
              : _buildMobileList(context, ref, personas, presets);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAndOpen(context, ref),
        backgroundColor: AppTheme.accentVivid,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: Text(
          context.l10n.newChat,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — список без изменений
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileList(
      BuildContext context,
      WidgetRef ref,
      List<PersonaEntity> personas,
      List<MultiPresetEntity> presets,
      ) {
    final branches = ref.watch(branchProvider(entityId));
    final branchPersonas = _branchPersonas(personas, presets);

    return ListView.builder(
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
            ref
                .read(branchProvider(entityId).notifier)
                .deleteBranch(branch.id);
            ref.invalidate(chatProvider(branch.id));
          },
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildAvatarArea(personas, presets),
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
                                    _formatDateTime(branch.updatedAt),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (branchPersonas.any((p) => !p.ageVerified)) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.warning_amber_rounded, color: AppTheme.unVerified, size: 20),
                                ],
                              ],
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT — две колонки
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopGrid(
      BuildContext context,
      WidgetRef ref,
      List<PersonaEntity> personas,
      List<MultiPresetEntity> presets,
      ) {
    final branches = ref.watch(branchProvider(entityId));
    final branchPersonas = _branchPersonas(personas, presets);

    // Разбиваем ветки на две колонки: чётные — левая, нечётные — правая
    final leftBranches  = [for (int i = 0; i < branches.length; i += 2) branches[i]];
    final rightBranches = [for (int i = 1; i < branches.length; i += 2) branches[i]];

    Widget branchCard(branch) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(branch.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: AppTheme.warning),
        ),
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) {
          ref
              .read(branchProvider(entityId).notifier)
              .deleteBranch(branch.id);
          ref.invalidate(chatProvider(branch.id));
        },
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildAvatarArea(personas, presets),
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
                                _formatDateTime(branch.updatedAt),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (branchPersonas.any((p) => !p.ageVerified)) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: context.l10n.ageNotVerified,
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.unVerified,
                                  size: 20,
                                ),
                              ),
                            ],
                          ],
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Левая колонка
              Expanded(
                child: Column(
                  children: leftBranches.map(branchCard).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Правая колонка
              Expanded(
                child: Column(
                  children: rightBranches.map(branchCard).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  List<PersonaEntity> _branchPersonas(
      List<PersonaEntity> personas,
      List<MultiPresetEntity> presets,
      ) {
    if (!isMulti) {
      final personaId = entityId.startsWith('single:')
          ? entityId.substring(7)
          : entityId;
      return personas.where((p) => p.id == personaId).toList();
    } else {
      final presetId = entityId.startsWith('multi:')
          ? entityId.substring(6)
          : entityId;
      final preset = presets.where((p) => p.id == presetId).firstOrNull;
      if (preset == null) return [];
      return preset.personaIds
          .map((id) => personas.where((p) => p.id == id).firstOrNull)
          .where((p) => p != null)
          .cast<PersonaEntity>()
          .toList();
    }
  }

  Widget _buildAvatarArea(
      List<PersonaEntity> personas, List<MultiPresetEntity> presets) {
    const double avatarSize = 54.0;
    const double overlap    = 44.0;
    const int    maxAvatars = 3;

    if (!isMulti) {
      final personaId = entityId.startsWith('single:')
          ? entityId.substring(7)
          : entityId;
      final persona =
          personas.where((p) => p.id == personaId).firstOrNull;
      return AvatarWidget(
        imagePath: persona?.avatarPath,
        assetPath: persona?.avatarAssetPath,
        name: persona?.name ?? '?',
        size: avatarSize,
      );
    } else {
      final presetId = entityId.startsWith('multi:')
          ? entityId.substring(6)
          : entityId;
      final preset =
          presets.where((p) => p.id == presetId).firstOrNull;
      if (preset == null) {
        return Icon(Icons.group,
            color: AppTheme.primaryAccent, size: avatarSize);
      }

      final matchedPersonas = preset.personaIds
          .map((id) => personas.where((p) => p.id == id).firstOrNull)
          .where((p) => p != null)
          .cast<PersonaEntity>()
          .take(maxAvatars)
          .toList();

      if (matchedPersonas.isEmpty) {
        return Icon(Icons.group,
            color: AppTheme.primaryAccent, size: avatarSize);
      }

      final count      = matchedPersonas.length;
      final totalWidth = avatarSize + (count - 1) * overlap;

      return SizedBox(
        width: totalWidth,
        height: avatarSize,
        child: Stack(
          children: List.generate(count, (index) {
            final reverseIndex = count - 1 - index;
            final persona      = matchedPersonas[reverseIndex];
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

  Future<void> _createAndOpen(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(branchProvider(entityId).notifier);
    final branch   = await notifier.createBranch();
    if (!context.mounted) return;
    _openChat(context, ref, branch.id);
  }

  void _openChat(BuildContext context, WidgetRef ref, String branchId) {
    final rawId = entityId.contains(':')
        ? entityId.substring(entityId.indexOf(':') + 1)
        : entityId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          branchId:  branchId,
          entityId:  rawId,
          isMulti:   isMulti,
          greeting:  greeting,
          title:     entityName,
        ),
      ),
    ).then((_) {
      ref.read(branchProvider(entityId).notifier).refresh();
    });
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteBranch,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.allMessagesWillBeDeleted,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d.$m.$y';
  }
}