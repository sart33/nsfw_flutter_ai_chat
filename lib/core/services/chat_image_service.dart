import 'dart:convert';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/services/novita_image_service.dart';
import 'package:nsfw_chat/core/services/scene_extractor_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/seed_utils.dart';

class ChatImageService {
  ChatImageService._();
  static final ChatImageService instance = ChatImageService._();


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
    final prefs = await SharedPreferences.getInstance();
    final size = AppConfig.novitaImageSize(
        prefs.getString('settings_image_size_chat') ?? 'standard');
    final localPath = await NovitaImageService.instance
        .generateImageTo(prompt, saveDir, saveId, seed: seed, size: size);

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
