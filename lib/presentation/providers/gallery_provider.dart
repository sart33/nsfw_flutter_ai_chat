import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';

// ── State ──────────────────────────────────────────────────────────────────

class GalleryState {
  final List<GalleryImageEntity> images;
  final bool isGenerating;
  final String? pendingImagePath;
  final int? pendingTemplateId;
  final String? error;

  const GalleryState({
    this.images = const [],
    this.isGenerating = false,
    this.pendingImagePath,
    this.pendingTemplateId,
    this.error,
  });

  static const _absent = Object();

  GalleryState copyWith({
    List<GalleryImageEntity>? images,
    bool? isGenerating,
    Object? pendingImagePath = _absent,
    Object? pendingTemplateId = _absent,
    Object? error = _absent,
  }) {
    return GalleryState(
      images: images ?? this.images,
      isGenerating: isGenerating ?? this.isGenerating,
      pendingImagePath: identical(pendingImagePath, _absent)
          ? this.pendingImagePath
          : pendingImagePath as String?,
      pendingTemplateId: identical(pendingTemplateId, _absent)
          ? this.pendingTemplateId
          : pendingTemplateId as int?,
      error: identical(error, _absent) ? this.error : error as String?,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class GalleryNotifier extends StateNotifier<GalleryState> {
  final String personaId;
  final GalleryRepository _repo;
  final _novita = NovitaImageService.instance;
  final _db = DatabaseHelper.instance;
  static const _uuid = Uuid();

  GalleryNotifier(this.personaId, this._repo) : super(const GalleryState()) {
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final images = await _repo.getGalleryForPersona(personaId);
      state = state.copyWith(images: images);
    } catch (_) {}
  }

  // ── generateNext ────────────────────────────────────────────────────────

  Future<void> generateNext(String description) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final entity = await _repo.generateNext(personaId, description);
      state = state.copyWith(
        images: [entity, ...state.images],
        isGenerating: false,
      );
    } on GalleryFullException {
      Fluttertoast.showToast(msg: 'Все 20 шаблонов уже сгенерированы');
      state = state.copyWith(isGenerating: false);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      Fluttertoast.showToast(msg: 'Ошибка генерации');
    }
  }

  // ── generatePreview ─────────────────────────────────────────────────────

  Future<void> generatePreview(String description) async {
    state = state.copyWith(isGenerating: true, pendingImagePath: null);
    try {
      final usedIds = await _db.getUsedTemplateIds(personaId);
      // Also exclude the currently pending template if any
      final pendingTid = state.pendingTemplateId;
      if (pendingTid != null && !usedIds.contains(pendingTid)) {
        usedIds.add(pendingTid);
      }

      final allIds = List.generate(20, (i) => i + 1);
      final available = allIds.where((id) => !usedIds.contains(id)).toList();
      if (available.isEmpty) {
        Fluttertoast.showToast(msg: 'Все 20 шаблонов уже сгенерированы');
        state = state.copyWith(isGenerating: false);
        return;
      }

      final selectedId = available[Random().nextInt(available.length)];

      final jsonStr =
          await rootBundle.loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template = templates.firstWhere(
        (t) => (t as Map<String, dynamic>)['id'] == selectedId,
      ) as Map<String, dynamic>;

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', description);

      final docsDir = await getApplicationDocumentsDirectory();
      final tempDir = '${docsDir.path}/gallery_temp';
      final saveId = _uuid.v4();
      final tempPath =
          await _novita.generateImageTo(prompt, tempDir, saveId);

      state = state.copyWith(
        isGenerating: false,
        pendingImagePath: tempPath,
        pendingTemplateId: selectedId,
      );
    } on GalleryFullException {
      Fluttertoast.showToast(msg: 'Все 20 шаблонов уже сгенерированы');
      state = state.copyWith(isGenerating: false);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      Fluttertoast.showToast(msg: 'Ошибка генерации');
    }
  }

  // ── confirmPending ──────────────────────────────────────────────────────

  Future<void> confirmPending(
      String personaId, String description) async {
    final pendingPath = state.pendingImagePath;
    final templateId = state.pendingTemplateId;
    if (pendingPath == null || templateId == null) return;

    try {
      final entity = await _repo.savePreGeneratedImage(
          pendingPath, personaId, templateId);
      state = state.copyWith(
        images: [entity, ...state.images],
        pendingImagePath: null,
        pendingTemplateId: null,
      );
      Fluttertoast.showToast(msg: 'Сохранено в галерею');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Ошибка сохранения');
    }
  }

  // ── regeneratePending ───────────────────────────────────────────────────

  Future<void> regeneratePending(String description) async {
    final templateId = state.pendingTemplateId;
    if (templateId == null) {
      await generatePreview(description);
      return;
    }

    // Delete old temp file
    final oldPath = state.pendingImagePath;
    if (oldPath != null) {
      try {
        final f = File(oldPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    state = state.copyWith(isGenerating: true, pendingImagePath: null);
    try {
      final jsonStr =
          await rootBundle.loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template = templates.firstWhere(
        (t) => (t as Map<String, dynamic>)['id'] == templateId,
      ) as Map<String, dynamic>;

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', description);

      final docsDir = await getApplicationDocumentsDirectory();
      final tempDir = '${docsDir.path}/gallery_temp';
      final saveId = _uuid.v4();
      final newTempPath =
          await _novita.generateImageTo(prompt, tempDir, saveId);

      state = state.copyWith(
        pendingImagePath: newTempPath,
        isGenerating: false,
      );
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      Fluttertoast.showToast(msg: 'Ошибка генерации');
    }
  }

  // ── discardPending ──────────────────────────────────────────────────────

  void discardPending() {
    final p = state.pendingImagePath;
    if (p != null) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    state = state.copyWith(
      pendingImagePath: null,
      pendingTemplateId: null,
    );
  }

  // ── regenerateExisting ──────────────────────────────────────────────────

  Future<void> regenerateExisting(
      String imageId, String description, int templateId) async {
    state = state.copyWith(isGenerating: true);
    try {
      final entity = await _repo.regenerateSameTemplate(
          imageId, personaId, description, templateId);
      final updated = state.images.map((img) {
        return img.id == imageId ? entity : img;
      }).toList();
      state = state.copyWith(images: updated, isGenerating: false);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      Fluttertoast.showToast(msg: 'Ошибка генерации');
    }
  }

  // ── deleteImage ─────────────────────────────────────────────────────────

  Future<void> deleteImage(String imageId, String localPath) async {
    try {
      await _repo.deleteImage(imageId, localPath);
      state = state.copyWith(
        images: state.images.where((img) => img.id != imageId).toList(),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Ошибка удаления');
    }
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final galleryProvider =
    StateNotifierProvider.family<GalleryNotifier, GalleryState, String>(
  (ref, personaId) =>
      GalleryNotifier(personaId, GalleryRepository.instance),
);
