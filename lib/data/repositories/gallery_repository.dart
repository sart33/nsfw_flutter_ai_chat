import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';
import 'package:nsfw_chat/domain/entities/gallery_image_entity.dart';

/// Thrown when all 20 templates have already been generated for a persona.
class GalleryFullException implements Exception {
  const GalleryFullException();
  @override
  String toString() =>
      'GalleryFullException: all 20 templates have been used for this persona';
}

/// Manages gallery image generation, persistence, and deletion for personas.
class GalleryRepository {
  GalleryRepository._();
  static final GalleryRepository instance = GalleryRepository._();

  final _db = DatabaseHelper.instance;
  final _novita = NovitaImageService.instance;
  static const _uuid = Uuid();

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

  Future<GalleryImageEntity> generateNext(
      String personaId, String description) async {
    try {
      final usedIds = await _db.getUsedTemplateIds(personaId);
      final allIds = List.generate(20, (i) => i + 1);
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

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', description);
      final saveId = _uuid.v4();
      final localPath =
          await _novita.generateImage(prompt, personaId, saveId);

      final now = DateTime.now();
      await _db.insertGalleryImage(
        saveId, personaId, selectedId, localPath,
        now.millisecondsSinceEpoch,
      );

      return GalleryImageEntity(
        id: saveId,
        personaId: personaId,
        templateId: selectedId,
        localPath: localPath,
        generatedAt: now,
      );
    } on GalleryFullException {
      rethrow;
    } on NovitaException {
      rethrow;
    } catch (e) {
      rethrow;
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

      final prompt = (template['prompt_template'] as String)
          .replaceAll('{description}', description);
      final saveId = _uuid.v4();
      final localPath =
          await _novita.generateImage(prompt, personaId, saveId);

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
    } on NovitaException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Saves a pre-generated temp image into the proper gallery location + DB.
  Future<GalleryImageEntity> savePreGeneratedImage(
      String tempPath, String personaId, int templateId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final saveId = _uuid.v4();
    final dirPath = '${docsDir.path}/characters/$personaId/gallery';
    await Directory(dirPath).create(recursive: true);
    final savePath = '$dirPath/$saveId.jpg';
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
}
