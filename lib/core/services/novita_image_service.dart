import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:nsfw_chat/core/config/app_config.dart';

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

  static const _baseUrl = 'https://api.novita.ai/v3/async';
  // ignore: unused_field
  static const _negativePrompt =
      'blurry, lowres, deformed, ugly, bad anatomy, bad hands, extra limbs, watermark, text, censored';
  // static const _enhancers =
  //     'masterpiece, best quality, ultra detailed, sharp focus';

  /// Generates an image, saves to standard persona gallery path.
  Future<String> generateImage(
      String promptTemplate, String personaId, String saveId) async {
    final bytes = await _generateBytes(promptTemplate);
    final docsDir = await getApplicationDocumentsDirectory();
    final dirPath = '${docsDir.path}/characters/$personaId/gallery';
    await Directory(dirPath).create(recursive: true);
    final savePath = '$dirPath/$saveId.jpg';
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  /// Generates an image, saves to a custom directory.
  Future<String> generateImageTo(
      String promptTemplate, String saveDir, String saveId) async {
    final bytes = await _generateBytes(promptTemplate);
    await Directory(saveDir).create(recursive: true);
    final savePath = '$saveDir/$saveId.jpg';
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  /// Core generation logic: submit → poll → download bytes.
  Future<List<int>> _generateBytes(String promptTemplate) async {
    // 0. Get API key from secure storage
    final apiKey = await AppConfig.getNovitaApiKey();
    if (apiKey.isEmpty) {
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
        'seed': 101,
        'size': '1024*1024',
        'prompt': promptTemplate,
        // 'negative_prompt': _negativePrompt,
      }),
    );

    if (submitResponse.statusCode < 200 || submitResponse.statusCode >= 300) {
      throw NovitaException(
          'Submit failed: HTTP ${submitResponse.statusCode}');
    }

    // 3. Parse task_id
    final submitJson =
        jsonDecode(submitResponse.body) as Map<String, dynamic>;
    final taskId = submitJson['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) {
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
        throw NovitaException('Generation failed');
      }
    }

    if (resultJson == null) {
      throw NovitaException('Timed out waiting for generation result');
    }

    // 5. Extract image URL
    final images = resultJson['images'] as List<dynamic>?;
    if (images == null || images.isEmpty) {
      throw NovitaException('No images in result');
    }
    final imageUrl =
        (images[0] as Map<String, dynamic>)['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw NovitaException('image_url is missing in result');
    }

    // 6. Download bytes
    final downloadResponse = await http.get(Uri.parse(imageUrl));
    if (downloadResponse.statusCode < 200 ||
        downloadResponse.statusCode >= 300) {
      throw NovitaException(
          'Image download failed: HTTP ${downloadResponse.statusCode}');
    }
    final bytes = downloadResponse.bodyBytes;
    if (bytes.isEmpty) {
      throw NovitaException('Downloaded image bytes are empty');
    }

    return bytes;
  }
}
