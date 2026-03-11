import 'package:dio/dio.dart';
import 'package:nsfw_chat/core/config/app_config.dart';

/// Creates and configures a [Dio] client for DeepSeek API requests.
class DioFactory {
  DioFactory._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.deepSeekBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          // Authorization header will be added per request after reading from secure storage
        },
      ),
    );

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));

    return dio;
  }
}
