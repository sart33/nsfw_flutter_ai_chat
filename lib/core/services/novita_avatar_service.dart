import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';

import '../../domain/exceptions/app_exceptions.dart';

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
    validateStatus: (status) => true, // do not throw DioException on any status

  ));

  /// Generates an avatar image from [description] and saves it to [saveDir].
  /// Returns the absolute path to the saved file.
  /// This method builds a hardcoded erotic prompt internally.
  /// For custom prompts, use [generateAvatarFromPrompt] instead.
  static Future<String> generateAvatarFromPrompt(
      String prompt,
      String saveDir, {
        int seed = 101,
      }) async {
    final apiKey = await AppConfig.getNovitaApiKey();
    if (apiKey.isEmpty) throw NovitaApiException('api_key_not_set');
    debugPrint('[NovitaAvatarService] prompt: $prompt');
    return _submit(prompt, saveDir, seed: seed, apiKey: apiKey);
  }

  /// Internal method that performs the actual generation with the given prompt and API key.
  static Future<String> _submit(
      String prompt,
      String saveDir, {
        required int seed,
        required String apiKey,
      }) async {
    final submitResp = await _dio.post(
      '$_baseUrl/z-image-turbo',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {'seed': seed, 'size': '768*1024', 'prompt': prompt},
    );
debugPrint('[NovitaAvatarService] submit response: ${submitResp.statusCode} ${submitResp.data}');
    if (submitResp.statusCode == 401) {
      throw NovitaApiException('api_key_invalid');
    }
    if (submitResp.statusCode == 403) {
      // Парсим reason из тела
      final reason = submitResp.data?['reason'] as String? ?? '';
      if (reason == 'NOT_ENOUGH_BALANCE') {
        throw NovitaApiException('insufficient_balance');
      }
      throw NovitaApiException('api_key_invalid'); // INVALID_API_KEY или неизвестная 403
    }
    if (submitResp.statusCode != 200) {
      throw NovitaApiException('http_${submitResp.statusCode}');
    }

    final taskId = submitResp.data['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) throw NovitaApiException('task_id_missing');

    Map<String, dynamic>? resultData;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      final poll = await _dio.get(
        '$_baseUrl/task-result',
        queryParameters: {'task_id': taskId},
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      final status = poll.data['task']?['status'] as String? ?? '';
      if (status == 'TASK_STATUS_SUCCEED') {
        resultData = poll.data as Map<String, dynamic>;
        break;
      } else if (status == 'TASK_STATUS_FAILED') {
        throw NovitaApiException('generation_failed');
      }
    }

    if (resultData == null) throw NovitaApiException('timeout');

    final images = resultData['images'] as List<dynamic>?;
    if (images == null || images.isEmpty) throw NovitaApiException('no_images');
    final imageUrl = images[0]['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) throw NovitaApiException('no_image_url');

    final downloadResp = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = downloadResp.data;
    if (bytes == null || bytes.isEmpty) throw NovitaApiException('empty_image');

    final dir = Directory(saveDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fileName = 'avatar_preview_${DateTime.now().millisecondsSinceEpoch}.webp';
    final filePath = '$saveDir/$fileName';
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }


}