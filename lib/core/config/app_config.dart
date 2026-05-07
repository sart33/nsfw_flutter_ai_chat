
import '../services/key_storage_service.dart';

class AppConfig {
  AppConfig._();

  static const String appTitle = 'Uncensored Souls';
  static const String appVersion = '1.0.0';

  // ── DeepSeek API ──────────────────────────────────────────────────────
  /// Base URL for the DeepSeek chat completions endpoint.
  static const String deepSeekBaseUrl = 'https://api.deepseek.com';

  static const String novitaBaseUrl = 'https://api.novita.ai/v3/async';

  /// Model identifier sent in every request.
  static const String deepSeekV4FlashModel = 'deepseek-v4-flash';
  static const String deepSeekV4RroModel = 'deepseek-v4-pro';

  // ── Input / output limits ─────────────────────────────────────────────
  /// Maximum number of characters a user may type in a single message.
  static const int userInputMaxChars = 2000;

  /// Maximum number of characters (approx. tokens × 4) the AI may return.
  static const int aiResponseMaxChars = 4000;

  /// Corresponding max_tokens value sent to the API (rough char/4 estimate).
  static const int aiResponseMaxTokens = 1000;

  // Image generation
  static const int defaultSeed = 101;
  static const int seedRange = 200;

  // Auto-delete for chat images
  static const int autoDeleteDefaultDays = 30;

  //
  static const int maxSceneWindowSize = 60;


  // Prompts / system strings — да, сюда
  static const String addToMultiChatBehavior = 'Always start each character\'s turn with exactly: [Name]: No variations. No spaces before colon. No other prefixes.';
  // ── Secure storage API key access ─────────────────────────────────────


  /// Reads DeepSeek API key from secure storage.
  /// Returns empty string if key is not set.
  static Future<String> getDeepSeekApiKey() async {
    return await KeyStorageService.read('deepseek_api_key');
  }

  /// Reads
  static Future<String> getNovitaApiKey() async {
    return await KeyStorageService.read('novita_api_key');
  }

  // SECURITY NOTE: flutter_secure_storage uses Android Keystore / iOS Keychain.
  // Keys are encrypted at rest. Do not log or print API key values.
}
