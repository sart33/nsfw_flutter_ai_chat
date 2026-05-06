import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';
import 'package:nsfw_chat/core/services/scene_extractor_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../utils/seed_utils.dart';

class ChatImageService {
  ChatImageService._();
  static final ChatImageService instance = ChatImageService._();

  SceneSnapshot _validateAndFix(SceneSnapshot raw) {
    var s = raw;

    // Public locations: intimacyLevel 3 → cap to 1
    final publicLocations = {
      'cafe', 'street', 'park', 'restaurant', 'office', 'supermarket',
    };
    if (s.location != null &&
        publicLocations.contains(s.location!.toLowerCase())) {
      if (s.intimacyLevel >= 3) {
        s = s.copyWith(intimacyLevel: 1);
      }
    }

    // Bed/bedroom + intimacyLevel 0 → force selectLevel 2
    if (s.location != null &&
        (s.location!.toLowerCase() == 'bed')) {
      if (s.intimacyLevel == 0) {
        s = s.copyWith(intimacyLevel: 2);
      }
    }

    // Баг 2: Минет в спальне/ванной → добавить floor в locationDetails
// Заменить условие добавления floor:
    if (s.pose?.toLowerCase() == 'kneeling' &&
        (s.activity?.toLowerCase().contains('blowjob') == true ||
            s.activity?.toLowerCase().contains('oral') == true) &&
        s.activity?.toLowerCase().contains('mutual') != true) {
      if (s.location != null &&
          (s.location!.toLowerCase().contains('bedroom') ||
              s.location!.toLowerCase().contains('bathroom') ||
              s.location!.toLowerCase().contains('room'))) {
        s = s.copyWith(
          locationDetails: s.locationDetails != null
              ? '${s.locationDetails}, floor'
              : 'floor',
        );
      }
    }

    return s;
  }

  Future<void> debugRunSceneBatch({
    required String personaId,
    required String personaName,
    required List<Map<String, dynamic>> rawSnapshots,
    void Function(String localPath, int index)? onImageGenerated,
  }) async {
    final prompts = await DatabaseHelper.instance.getPersonaPrompts(personaId);
    if (prompts == null) {
      debugPrint('[BatchTest] ERROR: no persona prompts found for $personaId');
      return;
    }

    debugPrint('[BatchTest] ══════════════════════════════════════');
    debugPrint('[BatchTest] persona: $personaName ($personaId)');
    debugPrint('[BatchTest] total cases: ${rawSnapshots.length}');
    debugPrint('[BatchTest] ══════════════════════════════════════');

    final docsDir = await getApplicationDocumentsDirectory();
    final saveDir = '${docsDir.path}/characters/$personaId/chat_images';

    for (int i = 0; i < rawSnapshots.length; i++) {
      final raw = SceneSnapshot.fromJson(rawSnapshots[i]);
      final validated = _validateAndFix(raw);
      final level = validated.selectLevel;

      final String baseDescription = switch (level) {
        0 => (prompts['romantic'] as String?) ?? '',
        1 => (prompts['romantic'] as String?) ?? '',
        2 => (prompts['erotic']   as String?) ?? '',
        _ => (prompts['nsfw']     as String?) ?? '',
      };

      final sceneStr = validated.toImagePrompt();
      final finalPrompt = baseDescription.isNotEmpty
          ? '$baseDescription, $sceneStr'
          : sceneStr;

      debugPrint('[BatchTest] ── case ${i + 1} ──────────────────────');
      debugPrint('[BatchTest] RAW    clothingState: ${raw.clothingState}  '
          'clothingDetails: ${raw.clothingDetails}  '
          'intimacyLevel: ${raw.intimacyLevel}');
      debugPrint('[BatchTest] VALID  clothingState: ${validated.clothingState}  '
          'pose: ${validated.pose}  '
          'intimacyLevel: ${validated.intimacyLevel}');
      debugPrint('[BatchTest] selectLevel: $level  '
          '(prompt key: ${level <= 1 ? "romantic" : level == 2 ? "erotic" : "nsfw"})');
      // Вывод RAW snapshot в читаемом формате для копирования
      final rawMap = rawSnapshots[i];
      final rawFormatted = rawMap.entries
          .map((e) => '  "${e.key}": ${e.value == null ? 'null' : '"${e.value}"'}')
          .join(',\n');
      debugPrint('[BatchTest] sceneStr:  $sceneStr');
      debugPrint('[BatchTest] RAW_JSON:\n{\n$rawFormatted\n}');
      debugPrint('[BatchTest] FINAL:     $finalPrompt');

      try {
        final saveId = const Uuid().v4();
        final localPath = await NovitaImageService.instance
            .generateImageTo(finalPrompt, saveDir, saveId, seed: regenSeed());
        debugPrint('[BatchTest] image saved: $localPath');
        onImageGenerated?.call(localPath, i);
      } catch (e) {
        debugPrint('[BatchTest] generation failed for case ${i + 1}: $e');
      }
    }

    debugPrint('[BatchTest] ══════════════════════════════════════');
    debugPrint('[BatchTest] done.');
  }
  /// Builds prompt and generates image.
  /// Returns local file path of saved image.
  Future<String> generateFromScene({
    required String personaId,
    required String personaName,
    required String branchId,
    required SceneSnapshot scene,
    bool regen = false,
  }) async {
    // 1. Get cleaned description for current gallery mode
    final prompts =
        await DatabaseHelper.instance.getPersonaPrompts(personaId);

    final String baseDescription;
    if (prompts != null) {
      baseDescription = switch (scene.selectLevel) {
        0 => (prompts['romantic'] as String?) ?? '',
        1 => (prompts['romantic'] as String?) ?? '',
        2 => (prompts['erotic']   as String?) ?? '',
        _ => (prompts['nsfw']     as String?) ?? '',
      };
    } else {
      baseDescription = '';
    }

    // 2. Build scene part using SceneSnapshot.toImagePrompt()
    final sceneStr = scene.toImagePrompt();


    final prompt = baseDescription.isNotEmpty
        ? '$baseDescription, $sceneStr'
        : sceneStr;

    // Log for debugging — save to DB
    debugPrint('[ChatImageService] Final prompt: $prompt');

    // 3. Seed logic
    const int seedBase = AppConfig.defaultSeed;
    final seed = regen
        ? seedBase
        : regenSeed(); // new random seed for first gen, or if regenerating use same seed

    // 4. Save to chat_images folder
    final docsDir = await getApplicationDocumentsDirectory();
    final saveDir =
        '${docsDir.path}/characters/$personaId/chat_images';
    final saveId = const Uuid().v4();

    // 5. Generate via NovitaImageService (no HTTP code here)
    final localPath = await NovitaImageService.instance
        .generateImageTo(prompt, saveDir, saveId, seed: seed);

    // 6. Log generation to database
    await DatabaseHelper.instance.insertSceneGenerationLog(
      id: saveId,
      branchId: branchId,
      personaName: personaName,
      sceneWindow: '', // filled by caller via extractScene
      rawLlmJson: jsonEncode(scene.toMap()),
      finalPrompt: prompt,
      imagePath: localPath,
    );

    return localPath;
  }
}
