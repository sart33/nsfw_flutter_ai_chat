import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/exceptions/app_exceptions.dart';

/// Thrown when a Novita AI generation task fails or times out.


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
      // 0. Get API key from secure storage
      final apiKey = await AppConfig.getNovitaApiKey();
      if (apiKey.isEmpty) {
        debugPrint('Novita API key is not set. Please add it in settings.');
        throw NovitaApiException('api_key_not_set');
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
      final submitJson =
      jsonDecode(submitResponse.body) as Map<String, dynamic>;
      debugPrint('Novita API key error: ${submitResponse.statusCode} ${submitJson['reason']}');

      if (submitResponse.statusCode == 401) {
        throw NovitaApiException('api_key_invalid');
      }
      if (submitResponse.statusCode == 403) {
        // Парсим reason из тела
        final reason = submitJson['reason'] as String? ?? '';
        if (reason == 'NOT_ENOUGH_BALANCE') {
          throw NovitaApiException('insufficient_balance');
        }
        throw NovitaApiException('api_key_invalid'); // INVALID_API_KEY или неизвестная 403
      }
      if (submitResponse.statusCode != 200) {
        throw NovitaApiException('http_${submitResponse.statusCode}');
      }

      // 3. Parse task_id

      final taskId = submitJson['task_id'] as String?;
      if (taskId == null || taskId.isEmpty) {

        throw NovitaApiException('task_id_missing');
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
          throw NovitaApiException('generation_failed');
        }
      }

      if (resultJson == null) throw NovitaApiException('timeout');

      // debugPrint('Novita generation succeeded: $resultJson');
      // 5. Extract image URL
      final images = resultJson['images'] as List<dynamic>?;
      if (images == null || images.isEmpty) throw NovitaApiException('no_images');

      final imageUrl =
          (images[0] as Map<String, dynamic>)['image_url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) throw NovitaApiException('no_image_url');


      // 6. Download bytes
      final downloadResponse = await http.get(Uri.parse(imageUrl));
      if (downloadResponse.statusCode < 200 ||
          downloadResponse.statusCode >= 300) {
        throw NovitaApiException('download_failed_${downloadResponse.statusCode}');

      }
      final bytes = downloadResponse.bodyBytes;
      if (bytes.isEmpty) throw NovitaApiException('empty_image');

      return bytes;

    }
  }

