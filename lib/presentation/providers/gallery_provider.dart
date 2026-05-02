import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/prompt_cleaner_service.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';

enum GeneratingPhase { verifying, preparingPrompts, generating }

// ── State ──────────────────────────────────────────────────────────────────

class GalleryState {
  final List<GalleryImageEntity> images;
  final bool isGenerating;
  final String? pendingImagePath;
  final int? pendingTemplateId;
  final AppException? error;
  final bool isLoaded;
  final String galleryMode;
  final GeneratingPhase? generatingPhase; // null = не генерируем

  const GalleryState({
    this.images = const [],
    this.isGenerating = false,
    this.pendingImagePath,
    this.pendingTemplateId,
    this.error,
    this.isLoaded = false,
    this.galleryMode = 'nude',
    this.generatingPhase,
  });

  static const _absent = Object();

  GalleryState copyWith({
    List<GalleryImageEntity>? images,
    bool? isGenerating,
    Object? pendingImagePath = _absent,
    Object? pendingTemplateId = _absent,
    Object? error = _absent,
    bool? isLoaded,
    Object? galleryMode = _absent,
    Object? generatingPhase = _absent,
  }) {
    return GalleryState(
      images: images ?? this.images,
      isGenerating: isGenerating ?? this.isGenerating,
      pendingImagePath:
          identical(pendingImagePath, _absent)
              ? this.pendingImagePath
              : pendingImagePath as String?,
      pendingTemplateId:
          identical(pendingTemplateId, _absent)
              ? this.pendingTemplateId
              : pendingTemplateId as int?,
      error: identical(error, _absent) ? this.error : error as AppException?,
      isLoaded: isLoaded ?? this.isLoaded,
      galleryMode:
          identical(galleryMode, _absent)
              ? this.galleryMode
              : galleryMode as String,
      generatingPhase:
          identical(generatingPhase, _absent)
              ? this.generatingPhase
              : generatingPhase as GeneratingPhase?,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class GalleryNotifier extends StateNotifier<GalleryState> {
  final String personaId;
  final GalleryRepository _repo;

  GalleryNotifier(this.personaId, this._repo, String galleryMode)
    : super(GalleryState(galleryMode: galleryMode)) {
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final allImages = await _repo.getGalleryForPersona(personaId);
      final filtered = _filterByMode(allImages, state.galleryMode);
      state = state.copyWith(images: filtered, isLoaded: true);
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  List<GalleryImageEntity> _filterByMode(
    List<GalleryImageEntity> all,
    String mode,
  ) {
    final List<int> range;
    if (mode == 'romantic') {
      range = List.generate(20, (i) => i + 21);
    } else if (mode == 'erotic') {
      range = List.generate(20, (i) => i + 41);
    } else if (mode == 'office') {
      range = List.generate(20, (i) => i + 61); // 61-80, placeholder
    } else {
      range = List.generate(20, (i) => i + 1);
    }
    return all.where((img) => range.contains(img.templateId)).toList();
  }

  Future<void> setGalleryMode(String mode) async {
    state = state.copyWith(galleryMode: mode);
    await _loadGallery();
  }

  // ── clearError ──────────────────────────────────────────────────────────

  /// Clear error state (called by UI after showing toast).
  void clearError() => state = state.copyWith(error: null);

  // ── generatePreview ─────────────────────────────────────────────────────

  Future<void> generatePreview(String description) async {
    state = state.copyWith(isGenerating: true, pendingImagePath: null);
    try {
      final data = await _repo.generatePreview(
        personaId,
        description,
        state.galleryMode,
      );

      state = state.copyWith(
        isGenerating: false,
        pendingImagePath: data.tempPath,
        pendingTemplateId: data.templateId,
      );
    } on NetworkException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } on GalleryFullException {
      state = state.copyWith(
        isGenerating: false,
        error: const GalleryFullException(),
      );
    } on NovitaApiException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } on DeepSeekApiException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: SaveException(e.toString()),
      );
    }
  }

  // ── generatePreviewWithVerification ─────────────────────────────────────

  Future<void> generatePreviewWithVerification(
    PersonaEntity persona,
    VoidCallback onVerified,
  ) async {
    if (persona.ageVerified) {
      state = state.copyWith(
        isGenerating: true,
        pendingImagePath: null,
        generatingPhase: GeneratingPhase.generating,
      );
      await generatePreview(persona.description);
      return;
    }

    // Фаза 1: верификация
    state = state.copyWith(
      isGenerating: true,
      pendingImagePath: null,
      generatingPhase: GeneratingPhase.verifying,
    );
    try {
      final combinedText = [
        persona.description,
        persona.behavior,
        persona.greeting,
      ].join('\n\n');
      final check = await PromptCleanerService.instance.checkForMinorSignals(
        combinedText,
      );

      if (check.hasConflict == true &&
          (check.severity == 'high' || check.severity == 'medium')) {
        final reason = check.severity == 'high'
            ? AgeCheckFailReason.conflictHigh
            : AgeCheckFailReason.conflictMedium;
        state = state.copyWith(
          isGenerating: false,
          error: AgeVerificationException(reason),
        );
        return;
      }
      if (!check.hasAge) {
        state = state.copyWith(
          isGenerating: false,
          error: const AgeVerificationException(AgeCheckFailReason.missing),
        );
        return;
      }
      await DatabaseHelper.instance.setPersonaAgeVerified(persona.id, true);
      onVerified();

      state = state.copyWith(generatingPhase: GeneratingPhase.preparingPrompts);

      await PromptCleanerService.instance.cleanAndSave(
        persona.id,
        persona.description,
      );

      state = state.copyWith(generatingPhase: GeneratingPhase.generating);

      await generatePreview(persona.description);

    } on NetworkException catch (e) {
      state = state.copyWith(isGenerating: false, generatingPhase: null, error: e);
    } on DeepSeekApiException catch (e) {
      // network_error, key_invalid, 402 и т.д. — всё сюда
      state = state.copyWith(
        isGenerating: false,
        generatingPhase: null,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        generatingPhase: null,
        error: e,
      );
    }
  }

  // ── confirmPending ──────────────────────────────────────────────────────

  Future<void> confirmPending(String personaId, String description) async {
    final pendingPath = state.pendingImagePath;
    final templateId = state.pendingTemplateId;
    if (pendingPath == null || templateId == null) return;

    try {
      final entity = await _repo.savePreGeneratedImage(
        pendingPath,
        personaId,
        templateId,
      );
      state = state.copyWith(
        images: [entity, ...state.images],
        pendingImagePath: null,
        pendingTemplateId: null,
      );
      // Success toast is shown by the UI layer.
    } catch (e) {
      debugPrint('[GalleryNotifier] confirmPending error: $e');
      state = state.copyWith(
        isGenerating: false,
        error: e is AppException ? e : SaveException(e.toString()),
      );
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
    final data = await _repo.regeneratePreview(
      personaId,
      description,
      templateId,
      state.galleryMode,
    );

              state = state.copyWith(
                isGenerating: false,
                pendingImagePath: data.tempPath,
                pendingTemplateId: data.templateId,
              );
    } on GalleryFullException {
      state = state.copyWith(
        isGenerating: false,
        error: const GalleryFullException(),
      );
    } on NetworkException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } on NovitaApiException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } on DeepSeekApiException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: SaveException(e.toString()),
      );
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
    state = state.copyWith(pendingImagePath: null, pendingTemplateId: null);
  }

  // ── regenerateExisting ──────────────────────────────────────────────────

  Future<void> regenerateExisting(
    String imageId,
    String description,
    int templateId,
  ) async {
    state = state.copyWith(isGenerating: true);
    try {
    final entity = await _repo.regenerateSameTemplate(
      imageId,
      personaId,
      description,
      templateId,
    );
      final outdated =
            state.images.map((img) {
              return img.id == imageId ? entity : img;
            }).toList();
        state = state.copyWith(images: outdated, isGenerating: false);
    } on NovitaApiException catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: SaveException(e.toString()));
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
      debugPrint('[GalleryNotifier] deleteImage error: $e');
      state = state.copyWith(
        error: e is AppException ? e : DeleteException(e.toString()),
      );
    }
  }
}

// ── GalleryKey ─────────────────────────────────────────────────────────────

class GalleryKey {
  final String personaId;
  final String galleryMode;

  const GalleryKey(this.personaId, this.galleryMode);

  @override
  bool operator ==(Object other) =>
      other is GalleryKey &&
      other.personaId == personaId &&
      other.galleryMode == galleryMode;

  @override
  int get hashCode => Object.hash(personaId, galleryMode);
}

// ── Provider ───────────────────────────────────────────────────────────────

final galleryProvider =
    StateNotifierProvider.family<GalleryNotifier, GalleryState, GalleryKey>(
      (ref, key) => GalleryNotifier(
        key.personaId,
        GalleryRepository.instance,
        key.galleryMode,
      ),
    );
