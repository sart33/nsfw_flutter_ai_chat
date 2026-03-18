import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/scene_extractor_service.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';

class ChatImageService {
  ChatImageService._();
  static final ChatImageService instance = ChatImageService._();

  /// Builds prompt and generates image.
  /// Returns local file path of saved image.
  Future<String> generateFromScene({
    required String personaId,
    required String personaName,
    required String branchId,
    required String personaGalleryMode,
    required SceneSnapshot scene,
    bool regen = false,
  }) async {
    // 1. Get cleaned description for current gallery mode
    final prompts =
        await DatabaseHelper.instance.getPersonaPrompts(personaId);

    final String baseDescription;
    if (prompts != null) {
      baseDescription = switch (scene.intimacyLevel) {
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

    // Add clothing anchor for low intimacy
    final clothingAnchor =
        scene.intimacyLevel <= 1 ? ', properly dressed' : '';

    final prompt = baseDescription.isNotEmpty
        ? '$baseDescription, $sceneStr$clothingAnchor'
        : '$sceneStr$clothingAnchor';

    // Log for debugging — save to DB
    debugPrint('[ChatImageService] Final prompt: $prompt');

    // 3. Seed logic
    const int seedBase = 101;
    const int seedRange = 200;
    final int seedMin = (seedBase - seedRange).clamp(1, seedBase);
    final int seedMax = seedBase + seedRange;
    final seed = regen
        ? (seedMin + Random().nextInt(seedMax - seedMin + 1))
        : seedBase;

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
