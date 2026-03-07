import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_persona_screen.dart';
import 'package:nsfw_chat/presentation/screens/gallery_fullscreen_screen.dart';
import 'package:nsfw_chat/presentation/widgets/gallery_thumbnail_widget.dart';
import 'package:nsfw_chat/presentation/widgets/pending_image_widget.dart';

/// Full-page view of a persona: avatar header, description, greeting, gallery.
class PersonaViewScreen extends ConsumerWidget {
  final PersonaEntity persona;

  const PersonaViewScreen({super.key, required this.persona});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryProvider(persona.id));
    final notifier = ref.read(galleryProvider(persona.id).notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Редактировать',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CreateEditPersonaScreen(personaId: persona.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'Чаты',
            onPressed: () => Navigator.push(
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
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Удалить',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Avatar header ──────────────────────────────────────
          _buildAvatarHeader(),

          // ── Content ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description card
                  _buildInfoCard('Описание', persona.description,
                      selectable: true),
                  const SizedBox(height: 12),

                  // Greeting card
                  if (persona.greeting.isNotEmpty) ...[
                    _buildInfoCard('Приветствие', persona.greeting,
                        italic: true,
                        textColor: const Color(0xFFCCCCCC)),
                    const SizedBox(height: 12),
                  ],

                  // ── Gallery section ────────────────────────────
                  _buildGalleryHeader(state, notifier),
                  const SizedBox(height: 12),

                  // Pending image preview
                  if (state.pendingImagePath != null)
                    PendingImageWidget(
                      path: state.pendingImagePath!,
                      onSave: () => notifier.confirmPending(
                          persona.id, persona.description),
                      onRegenerate: () =>
                          notifier.regeneratePending(persona.description),
                      onDiscard: () => notifier.discardPending(),
                      isLoading: state.isGenerating,
                    ),

                  // Generating indicator (when no pending yet)
                  if (state.isGenerating &&
                      state.pendingImagePath == null) ...[
                    Center(
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            color: const Color(0xFF7C4DFF),
                            backgroundColor: AppTheme.surface,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Генерация... (~15-40 сек)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Empty gallery message
                  if (state.images.isEmpty && !state.isGenerating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Нет изображений.\nНажмите + для генерации.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  // Gallery grid
                  if (state.images.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 2 / 3,
                      ),
                      itemCount: state.images.length,
                      itemBuilder: (context, index) {
                        return GalleryThumbnailWidget(
                          image: state.images[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GalleryFullscreenScreen(
                                images: state.images,
                                initialIndex: index,
                                personaDescription: persona.description,
                                personaId: persona.id,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar header ─────────────────────────────────────────────────────

  Widget _buildAvatarHeader() {
    final hasAvatar =
        persona.avatarPath != null && File(persona.avatarPath!).existsSync();
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasAvatar)
            Image.file(
              File(persona.avatarPath!),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            Container(
              color: const Color(0xFF1A1A1A),
              child: Center(
                child: Text(
                  _initials(persona.name),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF000000)],
                ),
              ),
            ),
          ),
          // Name + behavior
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  persona.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (persona.behavior != null &&
                    persona.behavior!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      persona.behavior!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────

  Widget _buildInfoCard(
    String title,
    String content, {
    bool selectable = false,
    bool italic = false,
    Color textColor = AppTheme.textPrimary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          selectable
              ? SelectableText(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                )
              : Text(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
        ],
      ),
    );
  }

  // ── Gallery header row ────────────────────────────────────────────────

  Widget _buildGalleryHeader(GalleryState state, GalleryNotifier notifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Галерея',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Text(
              '${state.images.length}/20',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(width: 8),
            if (state.images.length < 20)
              IconButton(
                icon: const Icon(Icons.add_photo_alternate,
                    color: Colors.white),
                tooltip: 'Сгенерировать',
                onPressed: state.isGenerating
                    ? null
                    : () => notifier.generatePreview(persona.description),
              ),
          ],
        ),
      ],
    );
  }

  // ── Delete persona + gallery ──────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить персонажа?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Персонаж и вся галерея будут удалены. Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(personaProvider.notifier).delete(persona.id);
              GalleryRepository.instance
                  .deleteAllForPersona(persona.id);
              Navigator.pop(context);
            },
            child: const Text('Удалить',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
