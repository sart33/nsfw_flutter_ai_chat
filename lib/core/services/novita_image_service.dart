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

  // ignore: unused_field
  static const _negativePrompt =
      'blurry, lowres, deformed, ugly, bad anatomy, bad hands, extra limbs, watermark, text, censored';
  // static const _enhancers =
  //     'masterpiece, best quality, ultra detailed, sharp focus';

  /// Generates an image, saves to standard persona gallery path.
  Future<String> generateImage(
      String promptTemplate, String personaId, String saveId,
      {int seed = AppConfig.defaultSeed, String size = '768*1024'}) async {
    final bytes = await _generateBytes(promptTemplate, seed: seed, size: size);
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
      {int seed = AppConfig.defaultSeed, String size = '768*1024'}) async {
    final bytes = await _generateBytes(promptTemplate, seed: seed, size: size);
    await Directory(saveDir).create(recursive: true);
    final savePath = '$saveDir/$saveId.webp';
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  /// Core generation logic: submit → poll → download bytes.
  Future<List<int>> _generateBytes(
      String promptTemplate, {
        int seed = AppConfig.defaultSeed,
        String size = '768*1024',
      }) async {
    final apiKey = await AppConfig.getWaveSpeedApiKey();

    if (apiKey.isEmpty) {
      throw WaveSpeedApiException('api_key_not_set');
    }

    final response = await http
        .post(
      Uri.parse(AppConfig.waveSpeedZImageUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prompt': promptTemplate,
        'seed': seed,
        'size': size,
        'strength': 0.6,
        'output_format': 'webp',
        'enable_sync_mode': true,
        'enable_base64_output': false,
      }),
    )
        .timeout(
      const Duration(seconds: 150),
      onTimeout: () {
        throw WaveSpeedApiException('timeout');
      },
    );
    assert(() {
      debugPrint('[NovitaImageService] WaveSpeedApiException: ${response.statusCode}');
      return true;
    }());
    assert(() {
      debugPrint('[NovitaImageService] WaveSpeedApiException: ${response.body}');
      return true;
    }());


    final root =
    jsonDecode(response.body) as Map<String, dynamic>;

    _throwHttpError(
      response.statusCode,
      response.body,
    );


    final rawData = root['data'];
    if (rawData is! Map) {
      throw WaveSpeedApiException('invalid_response');
    }

    final data = Map<String, dynamic>.from(rawData);

    final status = data['status'] as String? ?? '';
    final code = (data['code'] as num?)?.toInt() ?? 0;

    if (code != 0) {
      _throwPredictionError(code);
    }

    if (status != 'completed') {
      if (status == 'processing' ||
          status == 'created' ||
          status == 'timeout') {
        throw WaveSpeedApiException('timeout');
      }

      throw WaveSpeedApiException('generation_failed');
    }

    final outputs = data['outputs'] as List<dynamic>?;
    if (outputs == null || outputs.isEmpty) {
      throw WaveSpeedApiException('no_images');
    }

    final imageUrl = outputs.first as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw WaveSpeedApiException('no_image_url');
    }

    final downloadResponse = await http
        .get(Uri.parse(imageUrl))
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw WaveSpeedApiException('download_timeout');
      },
    );

    if (downloadResponse.statusCode < 200 ||
        downloadResponse.statusCode >= 300) {
      throw WaveSpeedApiException(
        'download_failed_${downloadResponse.statusCode}',
      );
    }

    final bytes = downloadResponse.bodyBytes;

    if (bytes.isEmpty) {
      throw WaveSpeedApiException('empty_image');
    }

    return bytes;
  }

  static void _throwHttpError(
      int statusCode,
      String body,
      ) {
    String message = '';

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      message = json['message']?.toString().toLowerCase() ?? '';
    } catch (_) {}

    if (message.contains('insufficient credits')) {
      throw WaveSpeedApiException('insufficient_balance');
    }

    switch (statusCode) {
      case 200:
        return;

      case 400:
        throw WaveSpeedApiException('invalid_request');

      case 401:
        throw WaveSpeedApiException('api_key_invalid');

      case 403:
        throw WaveSpeedApiException('access_forbidden');

      case 429:
        throw WaveSpeedApiException('rate_limited');

      case 500:
        throw WaveSpeedApiException('server_error');

      default:
        throw WaveSpeedApiException('http_$statusCode');
    }
  }

  static void _throwPredictionError(int code) {
    switch (code) {
      case 1200:
        throw WaveSpeedApiException('content_moderation');

      case 1400:
        throw WaveSpeedApiException('missing_parameter');

      case 1401:
        throw WaveSpeedApiException('invalid_parameter');

      case 1402:
        throw WaveSpeedApiException('media_access_failed');

      case 1403:
        throw WaveSpeedApiException('generation_failed');

      case 1405:
        throw WaveSpeedApiException('unknown_error');

      case 1406:
        throw WaveSpeedApiException('retry_exhausted');

      case 1407:
        throw WaveSpeedApiException('insufficient_balance');

      case 5000:
        throw WaveSpeedApiException('server_error');

      case 5003:
        throw WaveSpeedApiException('service_unavailable');

      case 5004:
        throw WaveSpeedApiException('timeout');

      default:
        throw WaveSpeedApiException('api_error_$code');
    }
  }
  }

