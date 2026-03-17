import 'dart:math';
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
    required String personaGalleryMode,
    required SceneData scene,
    bool regen = false,
  }) async {
    // 1. Get cleaned description for current gallery mode
    final prompts =
        await DatabaseHelper.instance.getPersonaPrompts(personaId);

    final String baseDescription;
    if (prompts != null) {
      baseDescription = switch (personaGalleryMode) {
        'erotic'   => (prompts['erotic']   as String?) ?? '',
        'romantic' => (prompts['romantic'] as String?) ?? '',
        'office'   => (prompts['office']   as String?) ?? '',
        _          => (prompts['nsfw']     as String?) ?? '',
      };
    } else {
      baseDescription = '';
    }

    // 2. Build scene part
    final sceneParts = <String>[];
    if (scene.location != null) sceneParts.add('in ${scene.location}');
    if (scene.clothing != null) sceneParts.add('wearing ${scene.clothing}');
    if (scene.pose != null) sceneParts.add(scene.pose!);
    if (scene.intimacyLevel <= 1) sceneParts.add('properly dressed');

    final sceneStr = sceneParts.join(', ');
    final prompt = baseDescription.isNotEmpty
        ? '$baseDescription, $sceneStr'
        : sceneStr;

    // 3. Seed: 101 for first gen, random 1-600 for regen
    final seed = regen
        ? (Random().nextInt(600) + 1)
        : 101;

    // 4. Save to chat_images folder
    final docsDir = await getApplicationDocumentsDirectory();
    final saveDir =
        '${docsDir.path}/characters/$personaId/chat_images';
    final saveId = const Uuid().v4();

    // 5. Generate via NovitaImageService (no HTTP code here)
    final localPath = await NovitaImageService.instance
        .generateImageTo(prompt, saveDir, saveId, seed: seed);

    return localPath;
  }
}
