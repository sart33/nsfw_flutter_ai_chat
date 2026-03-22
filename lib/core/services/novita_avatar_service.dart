import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/utils/app_snack_bar.dart';

/// Minimal Novita AI avatar generation service.
/// Generates an NSFW portrait image from a persona description,
/// polls for completion, downloads the result, and saves it locally.
class NovitaAvatarService {
  static const _baseUrl = AppConfig.novitaBaseUrl;
  // ignore: unused_field
  static const _negativePrompt =
      'blurry, lowres, deformed, ugly, bad anatomy, watermark, text, censored';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Generates an avatar image from [description] and saves it to [saveDir].
  /// Returns the absolute path to the saved file.
  static Future<String> generateAvatar(
      String description, String saveDir, {int seed = 101}) async {
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

      // 1. Build prompt
      final prompt =
          'Эротическое фото $description, explicit nsfw details, aroused expression, '
          'detailed skin texture, erotic pose with focus on body and face. '
          'Masterpiece, best quality, ultra detailed';
      debugPrint('[NovitaAvatarService] prompt: $prompt');
      // 2. Submit generation task
      final submitResp = await _dio.post(
        '$_baseUrl/z-image-turbo',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'seed': seed,
          'size': '512*768',
          'prompt': prompt,
          // 'negative_prompt': _negativePrompt,
        },
      );

      // Check for 401 error
      if (submitResp.statusCode == 401) {
        AppSnackBar.showCriticalWithLang(
          'Novita API key is invalid. Please update it in settings.',
          'Ключ Novita недействителен. Обновите его в настройках.',
        );
        throw Exception('Novita: Invalid API key');
      } else if (submitResp.statusCode != 200) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. Please try again.',
          'Ошибка генерации аватара. Попробуйте снова.',
        );
        throw Exception('Novita: Submit failed with status ${submitResp.statusCode}');
      }

      // 3. Get task_id
      final taskId = submitResp.data['task_id'] as String?;
      if (taskId == null || taskId.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. Invalid response from server.',
          'Ошибка генерации аватара. Неверный ответ сервера.',
        );
        throw Exception('Novita: task_id missing in response');
      }

      // 4. Poll for result — every 3 s, max 40 attempts (2 min total)
      Map<String, dynamic>? resultData;
      for (int attempt = 0; attempt < 40; attempt++) {
        await Future.delayed(const Duration(seconds: 3));

        final pollResp = await _dio.get(
          '$_baseUrl/task-result',
          queryParameters: {'task_id': taskId},
          options: Options(headers: {
            'Authorization': 'Bearer $apiKey',
          }),
        );

        final status =
            pollResp.data['task']?['status'] as String? ?? '';

        if (status == 'TASK_STATUS_SUCCEED') {
          resultData = pollResp.data as Map<String, dynamic>;
          break;
        } else if (status == 'TASK_STATUS_FAILED') {
          AppSnackBar.showErrorWithLang(
            'Avatar generation failed. Please try again.',
            'Ошибка генерации аватара. Попробуйте снова.',
          );
          throw Exception('Generation failed');
        }
        // Otherwise keep polling (TASK_STATUS_QUEUED / TASK_STATUS_PROCESSING)
      }

      if (resultData == null) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation timed out. Please try again.',
          'Таймаут генерации аватара. Попробуйте снова.',
        );
        throw Exception('Novita: timed out waiting for generation result');
      }

      // 5. Extract image URL
      final images = resultData['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. No images in result.',
          'Ошибка генерации аватара. Нет изображений в результате.',
        );
        throw Exception('Novita: no images in result');
      }
      final imageUrl = images[0]['image_url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. Invalid image URL.',
          'Ошибка генерации аватара. Неверный URL изображения.',
        );
        throw Exception('Novita: image_url is missing');
      }

      // 6. Download image bytes
      final downloadResp = await _dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = downloadResp.data;
      if (bytes == null || bytes.isEmpty) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. Downloaded image is empty.',
          'Ошибка генерации аватара. Загруженное изображение пустое.',
        );
        throw Exception('Novita: downloaded image is empty');
      }

      // 7. Save to disk
      final dir = Directory(saveDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final fileName =
          'avatar_preview_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$saveDir/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      // 8. Return saved path
      return filePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppSnackBar.showErrorWithLang(
          'Connection timeout. Check your internet connection.',
          'Таймаут соединения. Проверьте подключение к интернету.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        AppSnackBar.showErrorWithLang(
          'No internet connection.',
          'Нет подключения к интернету.',
        );
      } else if (e.response?.statusCode == 401) {
        // Already handled above, but just in case
        AppSnackBar.showCriticalWithLang(
          'Novita API key is invalid. Please update it in settings.',
          'Ключ Novita недействителен. Обновите его в настройках.',
        );
      }
      rethrow;
    } catch (e) {
      // Generic error - only show if not already shown by specific handlers
      if (e is! Exception || !e.toString().contains('Novita')) {
        AppSnackBar.showErrorWithLang(
          'Avatar generation failed. Please try again.',
          'Ошибка генерации аватара. Попробуйте снова.',
        );
      }
      rethrow;
    }
  }
}
