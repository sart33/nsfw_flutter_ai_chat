import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';

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
    // 0. Get API key from secure storage
    final apiKey = await AppConfig.getNovitaApiKey();
    if (apiKey.isEmpty) {
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

    // 3. Get task_id
    final taskId = submitResp.data['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) {
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
        throw Exception('Generation failed');
      }
      // Otherwise keep polling (TASK_STATUS_QUEUED / TASK_STATUS_PROCESSING)
    }

    if (resultData == null) {
      throw Exception('Novita: timed out waiting for generation result');
    }

    // 5. Extract image URL
    final images = resultData['images'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      throw Exception('Novita: no images in result');
    }
    final imageUrl = images[0]['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Novita: image_url is missing');
    }

    // 6. Download image bytes
    final downloadResp = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = downloadResp.data;
    if (bytes == null || bytes.isEmpty) {
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
  }
}
