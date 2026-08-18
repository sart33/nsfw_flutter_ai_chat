import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/exceptions/app_exceptions.dart';

/// Minimal Novita AI avatar generation service.
/// Generates an NSFW portrait image from a persona description,
/// polls for completion, downloads the result, and saves it locally.
class NovitaAvatarService {
  // ignore: unused_field
  static const _negativePrompt =
      'blurry, lowres, deformed, ugly, bad anatomy, watermark, text, censored';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 150),
    validateStatus: (status) => true, // do not throw DioException on any status

  ));

  /// Generates an avatar image from [description] and saves it to [saveDir].
  /// Returns the absolute path to the saved file.
  /// This method builds a hardcoded erotic prompt internally.
  /// For custom prompts, use [generateAvatarFromPrompt] instead.
  static Future<String> generateAvatarFromPrompt(
      String prompt,
      String saveDir, {
        int seed = AppConfig.bigImageDefaultSeed,
      }) async {
    assert(() {
      debugPrint('seed: $seed');
      return true;
    }());

    final apiKey = await AppConfig.getWaveSpeedApiKey();
    if (apiKey.isEmpty) {
      throw WaveSpeedApiException('api_key_not_set');
    }

    final prefs = await SharedPreferences.getInstance();

    final size = AppConfig.waveSpeedImageSize(
      prefs.getString('settings_image_size_avatar') ?? 'standard',
    );

    return _submit(
      prompt,
      saveDir,
      seed: seed,
      apiKey: apiKey,
      size: size,
    );
  }

  /// Internal method that performs the actual generation with the given prompt and API key.
  static Future<String> _submit(
      String prompt,
      String saveDir, {
        required int seed,
        required String apiKey,
        String size = '768*1024',
      }) async {
    final response = await _dio.post(
      AppConfig.waveSpeedZImageUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'prompt': prompt,
        'seed': seed,
        'size': size,
        'strength': 0.6,
        'output_format': 'webp',
        'enable_sync_mode': true,
        'enable_base64_output': false,
      },
    );

    _throwHttpError(
      response.statusCode ?? 0,
      jsonEncode(response.data),
    );

    final root = Map<String, dynamic>.from(response.data as Map);



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

    final downloadResponse = await _dio.get<List<int>>(
      imageUrl,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    final downloadStatus = downloadResponse.statusCode;
    if (downloadStatus == null ||
        downloadStatus < 200 ||
        downloadStatus >= 300) {
      throw WaveSpeedApiException('download_failed_$downloadStatus');
    }

    final bytes = downloadResponse.data;
    if (bytes == null || bytes.isEmpty) {
      throw WaveSpeedApiException('empty_image');
    }

    final dir = Directory(saveDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fileName =
        'avatar_preview_${DateTime.now().millisecondsSinceEpoch}.webp';

    final filePath = '$saveDir/$fileName';

    await File(filePath).writeAsBytes(bytes, flush: true);

    return filePath;
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