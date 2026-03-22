import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/utils/app_snack_bar.dart';
import 'package:path_provider/path_provider.dart';

/// Thrown when a Novita AI generation task fails or times out.
class NovitaException implements Exception {
  final String message;
  const NovitaException(this.message);
  @override
  String toString() => 'NovitaException: $message';
}

/// Singleton service for generating NSFW images via the Novita AI async API.
/// Uses the z-image-turbo model with task-result polling.
class NovitaImageService {
  NovitaImageService._();
  static final NovitaImageService instance = NovitaImageService._();

  static const _baseUrl = AppConfig.novitaBaseUrl;
  // ignore: unused_field
  static const _negativePrompt =
      'blurry, lowres, deformed, ugly, bad anatomy, bad hands, extra limbs, watermark, text, censored';
  // static const _enhancers =
  //     'masterpiece, best quality, ultra detailed, sharp focus';

  /// Generates an image, saves to standard persona gallery path.
  Future<String> generateImage(
      String promptTemplate, String personaId, String saveId,
      {int seed = AppConfig.defaultSeed}) async {
    final bytes = await _generateBytes(promptTemplate, seed: seed);
    final docsDir = await getApplicationDocumentsDirectory();
    final dirPath = '${docsDir.path}/characters/$personaId/gallery';
    await Directory(dirPath).create(recursive: true);
    final savePath = '$dirPath/$saveId.webp';
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  /// Generates an image, saves to a custom directory.
  Future<String> generateImageTo(
      String promptTemplate, String saveDir, String saveId,
      {int seed = AppConfig.defaultSeed}) async {
    final bytes = await _generateBytes(promptTemplate, seed: seed);
    await Directory(saveDir).create(recursive: true);
    final savePath = '$saveDir/$saveId.webp';
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  /// Core generation logic: submit → poll → download bytes.
  Future<List<int>> _generateBytes(String promptTemplate,
      {int seed = AppConfig.defaultSeed}) async {
    try {
      // 0. Get API key from secure storage
      final apiKey = await AppConfig.getNovitaApiKey();
      if (apiKey.isEmpty) {
        AppSnackBar.showCriticalWithLang(
          'Novita API key not set. Please add key in API Keys screen.',
          'Ключ Novita не установлен. Добавьте ключ в настройках API.',
        );
        throw Exception('Novita API key not set. Please add key in API Keys screen.');
      }

      // 1. Build final prompt
      // final finalPrompt = '$promptTemplate, $_enhancers';

      // 2. Submit generation task
      final submitResponse = await http.post(
        Uri.parse('$_baseUrl/z-image-turbo'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'seed': seed,
          'size': '768*1024',
          'prompt': promptTemplate,
          // 'negative_prompt': _negativePrompt,
        }),
      );

      if (submitResponse.statusCode == 401) {
        AppSnackBar.showCriticalWithLang(
          'Novita API key is invalid. Please update it in settings.',
          'Ключ Novita недействителен. Обновите его в настройках.',
        );
        throw NovitaException('Submit failed: HTTP ${submitResponse.statusCode}');
      } else if (submitResponse.statusCode < 200 || submitResponse.statusCode >= 300) {
        AppSnackBar.showErrorWithLang(
          'Image generation failed. Please try again.',
          'Ошибка генерации изображения. Попробуйте снова.',
        );
        throw NovitaException('Submit failed: HTTP ${submitResponse.statusCode}');
      }

      // 3. Parse task_id
      final submitJson =
          jsonDecode(submitResponse.body) as Map<String, dynamic>;
      final taskId = submitJson['task_id'] as String?;
      if (taskId == null || taskId.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Image generation failed. Invalid response from server.',
          'Ошибка генерации изображения. Неверный ответ сервера.',
        );
        throw NovitaException('task_id missing in submit response');
      }

      // 4. Poll for result — every 3 s, max 40 attempts (~2 min total)
      Map<String, dynamic>? resultJson;
      final pollUri = Uri.parse('$_baseUrl/task-result')
          .replace(queryParameters: {'task_id': taskId});

      for (int attempt = 0; attempt < 40; attempt++) {
        await Future.delayed(const Duration(seconds: 3));

        final pollResponse = await http.get(
          pollUri,
          headers: {'Authorization': 'Bearer $apiKey'},
        );

        final pollJson =
            jsonDecode(pollResponse.body) as Map<String, dynamic>;
        final status =
            (pollJson['task'] as Map<String, dynamic>?)?['status'] as String? ??
                '';

        if (status == 'TASK_STATUS_SUCCEED') {
          resultJson = pollJson;
          break;
        } else if (status == 'TASK_STATUS_FAILED') {
          AppSnackBar.showErrorWithLang(
            'Image generation failed. Please try again.',
            'Ошибка генерации изображения. Попробуйте снова.',
          );
          throw NovitaException('Generation failed');
        }
      }

      if (resultJson == null) {
        AppSnackBar.showErrorWithLang(
          'Image generation timed out. Please try again.',
          'Таймаут генерации изображения. Попробуйте снова.',
        );
        throw NovitaException('Timed out waiting for generation result');
      }
      // debugPrint('Novita generation succeeded: $resultJson');
      // 5. Extract image URL
      final images = resultJson['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Image generation failed. No images in result.',
          'Ошибка генерации изображения. Нет изображений в результате.',
        );
        throw NovitaException('No images in result');
      }
      final imageUrl =
          (images[0] as Map<String, dynamic>)['image_url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Image generation failed. Invalid image URL.',
          'Ошибка генерации изображения. Неверный URL изображения.',
        );
        throw NovitaException('image_url is missing in result');
      }

      // 6. Download bytes
      final downloadResponse = await http.get(Uri.parse(imageUrl));
      if (downloadResponse.statusCode < 200 ||
          downloadResponse.statusCode >= 300) {
        AppSnackBar.showErrorWithLang(
          'Failed to download generated image.',
          'Ошибка загрузки сгенерированного изображения.',
        );
        throw NovitaException(
            'Image download failed: HTTP ${downloadResponse.statusCode}');
      }
      final bytes = downloadResponse.bodyBytes;
      if (bytes.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Generated image is empty.',
          'Сгенерированное изображение пустое.',
        );
        throw NovitaException('Downloaded image bytes are empty');
      }

      return bytes;
    } catch (e) {
      if (e is! NovitaException) {
        // Only show generic error if it's not a NovitaException (which already showed snackbar)
        AppSnackBar.showErrorWithLang(
          'Image generation failed. Please try again.',
          'Ошибка генерации изображения. Попробуйте снова.',
        );
      }
      rethrow;
    }
  }
}
