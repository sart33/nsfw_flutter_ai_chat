import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';
import 'package:nsfw_chat/domain/result/preview_result.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/seed_utils.dart';

/// Manages gallery image generation, persistence, and deletion for personas.
class GalleryRepository {
  GalleryRepository._();
  static final GalleryRepository instance = GalleryRepository._();

  final _db = DatabaseHelper.instance;
  final _novita = NovitaImageService.instance;
  static const _uuid = Uuid();

  // Template IDs where clothing covers arms/tattoos fully.
  // Uses romantic2 (office-cleaned) description instead of romantic.
  static const _romantic2TemplateIds = <int>[
    23, 27, 28, 29, 33, 34, 39, 40,
  ];

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<List<GalleryImageEntity>> getGalleryForPersona(
      String personaId) async {
    try {
      final rows = await _db.getGalleryForPersona(personaId);
      final entities = rows.map(_rowToEntity).toList();
      entities.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return entities;
    } catch (e) {
      rethrow;
    }
  }

  // ── Generate ──────────────────────────────────────────────────────────────


  Future<PreviewResult> generatePreview(
      String personaId, String description, String galleryMode) async {
    try {
      final usedIds = await _db.getUsedTemplateIds(personaId);
      final List<int> allIds;
      if (galleryMode == 'romantic') {
        allIds = List.generate(20, (i) => i + 21); // 21-40
      } else if (galleryMode == 'erotic') {
        allIds = List.generate(20, (i) => i + 41); // 41-60
      } else if (galleryMode == 'office') {
        allIds = List.generate(20, (i) => i + 61); // 61-80, placeholder
      } else {
        allIds = List.generate(20, (i) => i + 1); // 1-20, nude (default)
      }
      final available =
      allIds.where((id) => !usedIds.contains(id)).toList();
      if (available.isEmpty) throw const GalleryFullException();

      final selectedId = available[Random().nextInt(available.length)];
      final jsonStr =
      await rootBundle.loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template = templates.firstWhere(
            (t) => (t as Map<String, dynamic>)['id'] == selectedId,
      ) as Map<String, dynamic>;

      final String effectiveDescription;
      final prompts =
      await DatabaseHelper.instance.getPersonaPrompts(personaId);

      if (prompts != null) {
        effectiveDescription = switch (galleryMode) {
          'erotic' => (prompts['erotic'] as String?) ?? description,
          'romantic' =>
          _romantic2TemplateIds.contains(selectedId)
              ? (prompts['romantic2'] as String?) ?? description
              : (prompts['romantic'] as String?) ?? description,
          'office' => (prompts['office'] as String?) ?? description,
          _ => ('${prompts['nsfw']}, nude, naked' as String?) ?? description,
        };
      } else {
        effectiveDescription = description;
      }

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', effectiveDescription);
      debugPrint('Generating with prompt: $prompt');
      final docsDir = await getApplicationDocumentsDirectory();
      final tempDir = '${docsDir.path}/gallery_temp';
      final saveId = _uuid.v4();
      final tempPath =
      await _novita.generateImageTo(prompt, tempDir, saveId);


      return PreviewResult(
        tempPath: tempPath,
        templateId: selectedId,
      );
    } on NetworkException catch (e) {
      debugPrint('Network error during image generation: ${e.toString()}');
      rethrow;
    } on GalleryFullException {
      rethrow; // провайдер поймает и покажет galleryFull
    } on NovitaApiException {
      rethrow; // провайдер поймает и покажет novita error
    } on DeepSeekApiException {
      rethrow; // если cleanAndSave кинул
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        throw const NetworkException();
      }
      throw SaveException(e.toString());
    }
  }

  Future<PreviewResult> regeneratePreview(
      String personaId,
      String description,
      int templateId,
      String galleryMode,
      ) async {

    try {
      final jsonStr =
      await rootBundle.loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template = templates.firstWhere(
            (t) => (t as Map<String, dynamic>)['id'] == templateId,
      ) as Map<String, dynamic>;

      final String effectiveDescription;
      final prompts =
      await DatabaseHelper.instance.getPersonaPrompts(personaId);

      if (prompts != null) {
        effectiveDescription = switch (galleryMode) {
          'erotic'   => (prompts['erotic']   as String?) ?? description,
          'romantic' => _romantic2TemplateIds.contains(templateId)
              ? (prompts['romantic2'] as String?) ?? description
              : (prompts['romantic']  as String?) ?? description,
          'office'   => (prompts['office']   as String?) ?? description,
          _ => ('${prompts['nsfw']}, nude, naked' as String?) ?? description,
        };
      } else {
        effectiveDescription = description;
      }

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', effectiveDescription);
      debugPrint('Generating with prompt: $prompt');
      final docsDir = await getApplicationDocumentsDirectory();
      final tempDir = '${docsDir.path}/gallery_temp';
      final saveId = _uuid.v4();
      final tempPath =
      await _novita.generateImageTo(prompt, tempDir, saveId, seed: regenSeed());

      return PreviewResult(
        tempPath: tempPath,
        templateId: templateId,
      );
    } on GalleryFullException {
      rethrow; // провайдер поймает и покажет galleryFull
    } on NovitaApiException {
      rethrow; // провайдер поймает и покажет novita error
    } on DeepSeekApiException {
      rethrow; // если cleanAndSave кинул
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        throw const NetworkException();
      }
      throw SaveException(e.toString());

    }
  }




  Future<GalleryImageEntity> regenerateSameTemplate(
    String oldImageId,
    String personaId,
    String description,
    int templateId,
  ) async {
    try {
      final oldRow = await _db.getGalleryImageById(oldImageId);
      if (oldRow != null) {
        final oldPath = oldRow['local_path'] as String;
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
      }
      await _db.deleteGalleryImage(oldImageId);

      final jsonStr =
          await rootBundle.loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template = templates.firstWhere(
        (t) => (t as Map<String, dynamic>)['id'] == templateId,
      ) as Map<String, dynamic>;

      // Determine gallery mode from templateId
      final String galleryMode = _determineGalleryMode(templateId);

      final String effectiveDescription;
      final prompts =
          await DatabaseHelper.instance.getPersonaPrompts(personaId);

      if (prompts != null) {
        effectiveDescription = switch (galleryMode) {
          'erotic'   => (prompts['erotic']   as String?) ?? description,
          'romantic' => _romantic2TemplateIds.contains(templateId)
              ? (prompts['romantic2'] as String?) ?? description
              : (prompts['romantic']  as String?) ?? description,
          'office'   => (prompts['office']   as String?) ?? description,
          _ => ('${prompts['nsfw']}, nude, naked' as String?) ?? description,

        };
      } else {
        effectiveDescription = description;
      }

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', effectiveDescription);
      final saveId = _uuid.v4();
      final localPath =
          await _novita.generateImage(prompt, personaId, saveId, seed: regenSeed());

      final now = DateTime.now();
      await _db.insertGalleryImage(
        saveId, personaId, templateId, localPath,
        now.millisecondsSinceEpoch,
      );

      return GalleryImageEntity(
        id: saveId,
        personaId: personaId,
        templateId: templateId,
        localPath: localPath,
        generatedAt: now,
      );

    } on GalleryFullException {
      rethrow; // провайдер поймает и покажет galleryFull
    } on NovitaApiException {
      rethrow; // провайдер поймает и покажет novita error
    } catch (e) {
      throw SaveException(e.toString());

    }
  }

  /// Saves a pre-generated temp image into the proper gallery location + DB.
  Future<GalleryImageEntity> savePreGeneratedImage(
      String tempPath, String personaId, int templateId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final saveId = _uuid.v4();
    final dirPath = '${docsDir.path}/characters/$personaId/gallery';
    await Directory(dirPath).create(recursive: true);
    final savePath = '$dirPath/$saveId.webp';
    await File(tempPath).copy(savePath);

    // Remove temp file
    try {
      final f = File(tempPath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}

    final now = DateTime.now();
    await _db.insertGalleryImage(
      saveId, personaId, templateId, savePath,
      now.millisecondsSinceEpoch,
    );

    return GalleryImageEntity(
      id: saveId,
      personaId: personaId,
      templateId: templateId,
      localPath: savePath,
      generatedAt: now,
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteImage(String imageId, String localPath) async {
    try {
      final file = File(localPath);
      if (file.existsSync()) file.deleteSync();
      await _db.deleteGalleryImage(imageId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAllForPersona(String personaId) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dirPath = '${docsDir.path}/characters/$personaId/gallery';
      final dir = Directory(dirPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await _db.deleteAllGalleryForPersona(personaId);
      await DatabaseHelper.instance.deletePersonaPrompts(personaId);
    } catch (e) {
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static GalleryImageEntity _rowToEntity(Map<String, dynamic> row) {
    return GalleryImageEntity(
      id: row['id'] as String,
      personaId: row['persona_id'] as String,
      templateId: row['template_id'] as int,
      localPath: row['local_path'] as String,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['generated_at'] as int),
    );
  }

  /// Determines gallery mode from template ID ranges.
  /// 1-20: nude, 21-40: romantic, 41-60: erotic, 61-80: office.
  String _determineGalleryMode(int templateId) {
    if (templateId >= 1 && templateId <= 20) return 'nude';
    if (templateId >= 21 && templateId <= 40) return 'romantic';
    if (templateId >= 41 && templateId <= 60) return 'erotic';
    if (templateId >= 61 && templateId <= 81) return 'office';
    return 'nude'; // fallback
  }
}
