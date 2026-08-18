// Hierarchy of typed domain exceptions used across providers and repositories.
// All exceptions carry an optional [technicalMessage] for debug logging only.
// User-facing strings are resolved in the UI layer via ARB localisation.

// Hierarchy of typed domain exceptions used across providers and repositories.
// All exceptions carry an optional [technicalMessage] for debug logging only.
// User-facing strings are resolved in the UI layer via ARB localisation.

class AppException implements Exception {
  final String? technicalMessage;
  const AppException([this.technicalMessage]);

  @override
  String toString() => '$runtimeType: ${technicalMessage ?? '(no details)'}';
}

class NetworkException implements AppException {
  const NetworkException();

  @override

  String? get technicalMessage => throw UnimplementedError();
}
/// Thrown when loading chat history from the database fails.
class HistoryException extends AppException {
  const HistoryException([super.technicalMessage]);
}

/// Thrown when all 20 image templates have already been used for a persona.
class GalleryFullException extends AppException implements GalleryException {
  const GalleryFullException() : super('All 20 templates already generated');
  @override
  String get technicalMessage => 'All 20 templates already generated';
}
/// Thrown when saving a generated image to the gallery fails.
class SaveException extends AppException {
  const SaveException([super.technicalMessage]);
}

/// Thrown when deleting an image from the gallery fails.
class DeleteException extends AppException {
  const DeleteException([super.technicalMessage]);
}

/// Thrown when a message summarization request fails.
class SummarizationException extends AppException {
  const SummarizationException([super.technicalMessage]);
}

/// Thrown when a DeepSeek API call fails.
/// [technicalMessage]: 'key_not_set' | 'key_invalid' | 'insufficient_balance' |
///                     'service_unavailable' | 'network_error' | 'http_error' |
///                     'invalid_response' | 'parse_error'
class DeepSeekApiException extends AppException {
  final int? statusCode;
  const DeepSeekApiException(String code, {this.statusCode}) : super(code);

  String get code => technicalMessage ?? 'unknown';
}

/// Thrown when a Novita AI generation task fails or times out.
/// [technicalMessage]: 'api_key_not_set' | 'api_key_invalid' | 'insufficient_balance' |
///                     'generation_failed' | 'timeout' | 'no_images' | etc.
// class NovitaApiException extends AppException {
//   const NovitaApiException(super.technicalMessage);
// }



/// Thrown when a Kie AI generation task fails or times out.
/// [technicalMessage]: 'api_key_not_set' | 'api_key_invalid' | 'insufficient_balance' |
///                     'generation_failed' | 'timeout' | 'no_images' | etc.
class WaveSpeedApiException extends AppException {
  const WaveSpeedApiException(super.technicalMessage);
}

/// Interface for gallery-related exceptions.
abstract interface class GalleryException implements Exception {
  String get technicalMessage;
}

/// Thrown when age verification fails.
///
enum AgeCheckFailReason { conflictHigh, conflictMedium, missing }
class AgeVerificationException extends AppException {
  final AgeCheckFailReason reason;
  const AgeVerificationException(this.reason) : super('age_verification_failed');
  @override
  String get technicalMessage => 'age_verification_failed';
}


