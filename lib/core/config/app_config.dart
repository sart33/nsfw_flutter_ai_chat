/// Application-wide configuration constants.
class AppConfig {
  AppConfig._();

  // ── App metadata ───────────────────────────────────────────────────────
  static const String novitaApiKey = 'YOUR_NOVITA_API_KEY_HERE';
  // ── DeepSeek API ──────────────────────────────────────────────────────
  /// TODO: Replace with your actual DeepSeek API key before release.
  static const String deepSeekApiKey = 'YOUR_DEEPSEEK_API_KEY_HERE';

  /// Base URL for the DeepSeek chat completions endpoint.
  static const String deepSeekBaseUrl = 'https://api.deepseek.com';

  /// Model identifier sent in every request.
  static const String deepSeekModel = 'deepseek-chat';

  // ── Input / output limits ─────────────────────────────────────────────
  /// Maximum number of characters a user may type in a single message.
  static const int userInputMaxChars = 2000;

  /// Maximum number of characters (approx. tokens × 4) the AI may return.
  static const int aiResponseMaxChars = 4000;

  /// Corresponding max_tokens value sent to the API (rough char/4 estimate).
  static const int aiResponseMaxTokens = 1000;
}
