import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:photo_view/photo_view.dart';

import '../../core/utils/app_snack_bar.dart';
import '../../domain/exceptions/app_exceptions.dart';

class GalleryFullscreenScreen extends ConsumerStatefulWidget {
  final List<GalleryImageEntity> images;
  final int initialIndex;
  final String personaDescription;
  final String personaId;
  final String galleryMode;
  final String? avatarPath;


  const GalleryFullscreenScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.personaDescription,
    required this.personaId,
    required this.galleryMode,
    this.avatarPath,
  });

  @override
  ConsumerState<GalleryFullscreenScreen> createState() =>
      _GalleryFullscreenScreenState();
}

class _GalleryFullscreenScreenState
    extends ConsumerState<GalleryFullscreenScreen> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final galleryKey = GalleryKey(widget.personaId, widget.galleryMode);
    final state = ref.watch(galleryProvider(galleryKey));
    final notifier = ref.read(galleryProvider(galleryKey).notifier);

    ref.listen<GalleryState>(galleryProvider(galleryKey), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final l10n = context.l10n;

        switch (next.error) {
          case AgeVerificationException(:final reason):
            AppSnackBar.showAgeConflictSingle(l10n, widget.personaId, reason);
          case NetworkException():
            AppSnackBar.show(l10n.networkError, isError: true);
          case DeepSeekApiException():
            AppSnackBar.showDeepSeekError(next.error! as DeepSeekApiException, l10n);

          case NovitaApiException():
            AppSnackBar.showNovitaError(next.error! as NovitaApiException, l10n);

          case GalleryFullException():
            AppSnackBar.show(l10n.galleryFull);

          case SaveException():
            AppSnackBar.show(l10n.errorSave);

          case DeleteException():
            AppSnackBar.show(l10n.errorDelete);

          default:
            AppSnackBar.show(l10n.errorUnknown);
        }
        ref.read(galleryProvider(galleryKey).notifier).clearError();
      }
    });
    final imgs = [
      if (widget.avatarPath != null)
        GalleryImageEntity(
          id: 'avatar_${widget.personaId}',
          personaId: widget.personaId,
          templateId: -1,
          localPath: widget.avatarPath!,
          generatedAt: DateTime(0),
        ),
      ...state.images,
    ];

    if (imgs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final safeIdx = _currentIndex.clamp(0, imgs.length - 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView with PhotoView
          PageView.builder(
            controller: _pageCtrl,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              final img = imgs[index];
              final isAsset = img.templateId == -1 &&
                  img.localPath.startsWith('assets/');
              return PhotoView(
                imageProvider: isAsset
                    ? AssetImage(img.localPath) as ImageProvider
                    : FileImage(File(img.localPath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                backgroundDecoration:
                const BoxDecoration(color: Colors.black),
              );
            },
          ),
          // Desktop-only navigation arrows
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            // LEFT
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 80,
              child: GestureDetector(
                onTap: () {
                  if (_currentIndex > 0) {
                    _pageCtrl.animateToPage(
                      _currentIndex - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  child: _currentIndex > 0
                      ? const Center(
                      child: Icon(Icons.chevron_left,
                          color: Colors.white70, size: 48))
                      : null,
                ),
              ),
            ),
            // RIGHT
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 80,
              child: GestureDetector(
                onTap: () {
                  if (_currentIndex < imgs.length - 1) {
                    _pageCtrl.animateToPage(
                      _currentIndex + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  child: _currentIndex < imgs.length - 1
                      ? const Center(
                      child: Icon(Icons.chevron_right,
                          color: Colors.white70, size: 48))
                      : null,
                ),
              ),
            ),
          ],
          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      '${safeIdx + 1} / ${imgs.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
    if (imgs[safeIdx].templateId != -1) ...[
                    _TemplateNameLabel(
                        templateId: imgs[safeIdx].templateId),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          tooltip: context.l10n.delete,
                          onPressed: () =>
                              _confirmDelete(context, notifier, imgs, safeIdx),
                        ),
                        if (state.isGenerating)
                          const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.white),
                            tooltip: context.l10n.regenerate,
                            onPressed: () {
                              final img = imgs[safeIdx];
                              notifier.regenerateExisting(
                                img.id,
                                widget.personaDescription,
                                img.templateId,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _confirmDelete(BuildContext context, GalleryNotifier notifier,
      List<GalleryImageEntity> imgs, int idx) {
    final img = imgs[idx];
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(context.l10n.deleteImage,
                style: TextStyle(color: AppTheme.textPrimary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  notifier.deleteImage(img.id, img.localPath);
                  if (imgs.length <= 1) {
                    Navigator.pop(context);
                  } else if (idx >= imgs.length - 1) {
                    _pageCtrl.previousPage(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(context.l10n.delete,
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}

class _TemplateNameLabel extends StatelessWidget {
  final int templateId;
  const _TemplateNameLabel({required this.templateId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadName(context),
      builder: (_, snap) {
        final name = snap.data ?? '...';
        return Text(name,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12));
      },
    );
  }

  Future<String> _loadName(BuildContext context) async {
    final json =
        await rootBundle.loadString('assets/json/image_templates.json');
    final list = jsonDecode(json) as List;
    final t = list.firstWhere(
      (e) => (e as Map<String, dynamic>)['id'] == templateId,
      orElse: () => {'name': '${context.l10n.templateNumber} #$templateId'},
    ) as Map<String, dynamic>;
    return t['name'] as String;
  }
}
