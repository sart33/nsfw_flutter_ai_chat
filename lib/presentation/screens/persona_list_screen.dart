import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_persona_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_view_screen.dart';
import 'package:nsfw_chat/presentation/widgets/persona_card.dart';

import '../widgets/custom_app_bar_widget.dart';

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;


class PersonaListScreen extends ConsumerWidget {
  const PersonaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personasAsync = ref.watch(personaProvider);
    final screenWidth   = MediaQuery.of(context).size.width;
    final useDesktop    =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.characters),
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
          if (personas.isEmpty) {
            return Center(
              child: Text(
                context.l10n.noCharacters,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return useDesktop
              ? _buildDesktopGrid(context, ref, personas)
              : _buildMobileList(context, ref, personas);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CreateEditPersonaScreen()),
        ),
        backgroundColor: AppTheme.accentVivid,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: Text(
          context.l10n.newCharacter,
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
  // MOBILE LAYOUT — список без изменений
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileList(
      BuildContext context, WidgetRef ref, List<PersonaEntity> personas) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: personas.length,
      itemBuilder: (context, index) {
        final persona = personas[index];
        return Dismissible(
          key: Key(persona.id),
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
          onDismissed: (_) {
            ref.read(personaProvider.notifier).delete(persona.id);
            GalleryRepository.instance.deleteAllForPersona(persona.id);
          },
          child: PersonaCard(
            persona: persona,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BranchListScreen(
                  entityId: 'single:${persona.id}',
                  entityName: persona.name,
                  isMulti: false,
                  greeting: persona.greeting,
                ),
              ),
            ),
            onLongPress: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonaViewScreen(persona: persona),
              ),
            ),
            onMoreTap: () => _showOptions(context, ref, persona),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT — грид вертикальных карточек
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopGrid(
      BuildContext context, WidgetRef ref, List<PersonaEntity> personas) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62, // ~3:4 с местом под кнопки
          ),
          itemCount: personas.length,
          itemBuilder: (context, index) {
            final persona = personas[index];
            return _DesktopPersonaCard(
              persona: persona,
              onView: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonaViewScreen(persona: persona),
                ),
              ),
              onChat: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BranchListScreen(
                    entityId: 'single:${persona.id}',
                    entityName: persona.name,
                    isMulti: false,
                    greeting: persona.greeting,
                  ),
                ),
              ),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateEditPersonaScreen(personaId: persona.id),
                ),
              ).then((changed) {
                if (changed == true && context.mounted) {
                  ref.invalidate(personaProvider);
                }
              }),
              onDelete: () async {
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref.read(personaProvider.notifier).delete(persona.id);
                  GalleryRepository.instance
                      .deleteAllForPersona(persona.id);
                }
              },
            );
          },
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteCharacter,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.cannotBeUndone,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel,
                style: const TextStyle(
                    color: AppTheme.textSecondary)),
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
      BuildContext context, WidgetRef ref, PersonaEntity persona) {
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
              leading: const Icon(Icons.visibility,
                  color: AppTheme.textPrimary),
              title: Text(context.l10n.view,
                  style:
                  const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PersonaViewScreen(persona: persona)));
              },
            ),
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
                    builder: (_) => CreateEditPersonaScreen(
                        personaId: persona.id),
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
                          entityId: 'single:${persona.id}',
                          entityName: persona.name,
                          isMulti: false,
                          greeting: persona.greeting,
                        )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.redAccent),
              title: Text(context.l10n.delete,
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref.read(personaProvider.notifier).delete(persona.id);
                  GalleryRepository.instance
                      .deleteAllForPersona(persona.id);
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
// Desktop card widget
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopPersonaCard extends StatelessWidget {
  final PersonaEntity persona;
  final VoidCallback onView;
  final VoidCallback onChat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesktopPersonaCard({
    required this.persona,
    required this.onView,
    required this.onChat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shortDesc = persona.description.length > 80
        ? '${persona.description.substring(0, 80)}…'
        : persona.description;

    final hasFile = persona.avatarPath != null &&
        File(persona.avatarPath!).existsSync();
    final hasAsset = persona.avatarAssetPath != null &&
        persona.avatarAssetPath!.isNotEmpty;

    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Аватар — верхняя часть карточки ─────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Изображение
                  hasFile
                      ? Image.file(
                    File(persona.avatarPath!),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  )
                      : hasAsset
                      ? Image.asset(
                    persona.avatarAssetPath!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  )
                      : Container(
                    color: AppTheme.cardBg,
                    child: Center(
                      child: Text(
                        _initials(persona.name),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Градиент снизу
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0xDD000000),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Имя + описание поверх градиента
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          persona.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shortDesc,
                          style: const TextStyle(
                            color: Color(0xBBFFFFFF),
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  icon: Icons.visibility_outlined,
                  color: AppTheme.textSecondary,
                  tooltip: 'Профиль',
                  onTap: onView,
                ),
                _VDivider(),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  color: AppTheme.primaryAccent,
                  tooltip: context.l10n.chats,
                  onTap: onChat,
                ),
                _VDivider(),
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  color: AppTheme.textSecondary,
                  tooltip: context.l10n.edit,
                  onTap: onEdit,
                ),
                _VDivider(),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  color: AppTheme.warning,
                  tooltip: context.l10n.cancel,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
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