import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_persona_screen.dart';
import 'package:nsfw_chat/presentation/screens/gallery_fullscreen_screen.dart';
import 'package:nsfw_chat/presentation/widgets/gallery_thumbnail_widget.dart';
import 'package:nsfw_chat/presentation/widgets/pending_image_widget.dart';

import 'api_keys_screen.dart';

/// Full-page view of a persona: avatar header, description, greeting, gallery.
class PersonaViewScreen extends ConsumerStatefulWidget {
  final PersonaEntity persona;

  const PersonaViewScreen({super.key, required this.persona});

  @override
  ConsumerState<PersonaViewScreen> createState() => _PersonaViewScreenState();
}

class _PersonaViewScreenState extends ConsumerState<PersonaViewScreen> {

  void _showSnack(String msg, {bool isKeyError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isKeyError ? AppTheme.error : AppTheme.warning,
      duration: Duration(seconds: isKeyError ? 8 : 6),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      action: isKeyError ? SnackBarAction(
        label: context.l10n.settings,
        textColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
        ),
      ) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currentPersona = ref.watch(personaProvider)
        .firstWhere((p) => p.id == widget.persona.id, orElse: () => widget.persona);
    final galleryKey = GalleryKey(currentPersona.id, currentPersona.galleryMode);
    final state = ref.watch(galleryProvider(galleryKey));
    final notifier = ref.read(galleryProvider(galleryKey).notifier);

    ref.listen<GalleryState>(galleryProvider(galleryKey), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final isKeyError = next.error is GenerationException &&
            (next.error!.technicalMessage?.contains('api_key') ?? false);

        final msg = switch (next.error) {
          GalleryFullException() => context.l10n.galleryFull,
          GenerationException() when next.error!.technicalMessage == 'api_key_not_set'
          => context.l10n.errorNovitaKeyNotSet,
          GenerationException() when next.error!.technicalMessage == 'api_key_invalid'
          => context.l10n.errorNovitaKeyInvalid,
          GenerationException() => context.l10n.errorImageGeneration,
          SaveException() => context.l10n.errorSave,
          DeleteException() => context.l10n.errorDelete,
          _ => context.l10n.errorUnknown,
        };
        _showSnack(msg, isKeyError: isKeyError);
        ref.read(galleryProvider(galleryKey).notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: context.l10n.editCharacter,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CreateEditPersonaScreen(personaId: widget.persona.id),
              ),
            ).then((changed) {
              if (changed == true && context.mounted) {
                ref.invalidate(personaProvider);
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: context.l10n.chats,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BranchListScreen(
                  entityId: 'single:${widget.persona.id}',
                  entityName: widget.persona.name,
                  isMulti: false,
                  greeting: widget.persona.greeting,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.warning),
            tooltip: context.l10n.delete,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAvatarHeader(currentPersona),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description card
                  _buildInfoCard(
                    context.l10n.description,
                    currentPersona.description,
                    selectable: true,
                  ),
                  const SizedBox(height: 12),

                  // Greeting card
                  if (currentPersona.greeting.isNotEmpty) ...[
                    _buildInfoCard(
                      context.l10n.greeting,
                      currentPersona.greeting,
                      italic: true,
                      textColor: const Color(0xFFCCCCCC),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Gallery section
                  _buildGalleryHeader(state, notifier, context, currentPersona),
                  const SizedBox(height: 12),

                  // Pending image preview
                  if (state.pendingImagePath != null)
                    PendingImageWidget(
                      path: state.pendingImagePath!,
                      onSave: () async {
                        await notifier.confirmPending(
                            currentPersona.id, currentPersona.description);
                        if (!context.mounted) return;
                        if (ref.read(galleryProvider(galleryKey)).error == null) {
                          Fluttertoast.showToast(msg: context.l10n.savedToGallery);
                        }
                      },
                      onRegenerate: () =>
                          notifier.regeneratePending(currentPersona.description),
                      onDiscard: () => notifier.discardPending(),
                      isLoading: state.isGenerating,
                    ),

                  // Generating indicator
                  if (state.isGenerating && state.pendingImagePath == null) ...[
                    Center(
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            color: AppTheme.primaryAccent,
                            backgroundColor: AppTheme.surface,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.generatingWait,
                            style: const TextStyle(
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.l10n.noImagesClickPlus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 2 / 3,
                      ),
                      itemCount: state.images.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GalleryThumbnailWidget(
                            image: state.images[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GalleryFullscreenScreen(
                                  images: state.images,
                                  initialIndex: index,
                                  personaDescription: currentPersona.description,
                                  personaId: currentPersona.id,
                                  galleryMode: currentPersona.galleryMode,
                                ),
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

  Widget _buildAvatarHeader(PersonaEntity p) {
    final hasFile = p.avatarPath != null && File(p.avatarPath!).existsSync();
    final hasAsset = p.avatarAssetPath != null && p.avatarAssetPath!.isNotEmpty;

    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasFile)
            Image.file(File(p.avatarPath!),
                fit: BoxFit.cover, alignment: Alignment.topCenter)
          else if (hasAsset)
            Image.asset(p.avatarAssetPath!,
                fit: BoxFit.cover, alignment: Alignment.topCenter)
          else
            Container(
              color: AppTheme.cardBg,
              child: Center(
                child: Text(
                  _initials(p.name),
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
            bottom: 0, left: 0, right: 0,
            height: 140,
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
            bottom: 16, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (p.behavior != null && p.behavior!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p.behavior!,
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

  // ── Info card — с border как на других экранах ────────────────────────

  Widget _buildInfoCard(
      String title,
      String content, {
        bool selectable = false,
        bool italic = false,
        Color textColor = AppTheme.textPrimary,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          selectable
              ? SelectableText(
            content,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          )
              : Text(
            content,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode carousel — горизонтальный скролл с чипами ────────────────────

  Widget _buildModeSelector(
      GalleryState state, GalleryNotifier notifier, BuildContext context) {
    // Список режимов: value, label, icon
    final modes = [
      (value: 'romantic', label: context.l10n.romantic, icon: Icons.favorite_border),
      (value: 'erotic',   label: context.l10n.erotic,   icon: Icons.local_fire_department),
      (value: 'office',   label: context.l10n.office,   icon: Icons.business_center_outlined),
      (value: 'nude',     label: '18+',                 icon: Icons.whatshot),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Горизонтальная карусель чипов
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: modes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final mode = modes[index];
                final isSelected = state.galleryMode == mode.value;

                return GestureDetector(
                  onTap: () => notifier.setGalleryMode(mode.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentVivid
                          : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentVivid
                            : AppTheme.cardBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                        ] else ...[
                          Icon(mode.icon,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Режим по умолчанию задаётся в редактировании персонажа',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Gallery header row ────────────────────────────────────────────────

  Widget _buildGalleryHeader(GalleryState state, GalleryNotifier notifier,
      BuildContext context, PersonaEntity currentPersona) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModeSelector(state, notifier, context),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gallery',
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
                  GestureDetector(
                    onTap: state.isGenerating
                        ? null
                        : () => notifier
                        .generatePreview(currentPersona.description),
                    child:  const Icon(Icons.add_a_photo_outlined,
                          color: Colors.white, size: 20),
                    ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Delete persona ────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteCharacter,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          context.l10n.characterAndGalleryWillBeDeleted,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(personaProvider.notifier).delete(widget.persona.id);
              GalleryRepository.instance
                  .deleteAllForPersona(widget.persona.id);
              Navigator.pop(context);
            },
            child: Text(context.l10n.delete,
                style: const TextStyle(color: AppTheme.warning)),
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