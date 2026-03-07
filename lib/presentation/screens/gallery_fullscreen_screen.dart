import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';

class GalleryFullscreenScreen extends ConsumerStatefulWidget {
  final List<GalleryImageEntity> images;
  final int initialIndex;
  final String personaDescription;
  final String personaId;

  const GalleryFullscreenScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.personaDescription,
    required this.personaId,
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
    final state = ref.watch(galleryProvider(widget.personaId));
    final notifier = ref.read(galleryProvider(widget.personaId).notifier);
    final imgs = state.images;

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
              return PhotoView(
                imageProvider: FileImage(File(img.localPath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
              );
            },
          ),
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
                    _TemplateNameLabel(
                        templateId: imgs[safeIdx].templateId),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          tooltip: 'Удалить',
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
                            tooltip: 'Перегенерировать',
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить изображение?',
            style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteImage(img.id, img.localPath);
              if (imgs.length <= 1) {
                Navigator.pop(context);
              } else if (idx >= imgs.length - 1) {
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            },
            child: const Text('Удалить',
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
      future: _loadName(),
      builder: (_, snap) {
        final name = snap.data ?? '...';
        return Text(name,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12));
      },
    );
  }

  Future<String> _loadName() async {
    final json =
        await rootBundle.loadString('assets/json/image_templates.json');
    final list = jsonDecode(json) as List;
    final t = list.firstWhere(
      (e) => (e as Map<String, dynamic>)['id'] == templateId,
      orElse: () => {'name': 'Шаблон #$templateId'},
    ) as Map<String, dynamic>;
    return t['name'] as String;
  }
}
