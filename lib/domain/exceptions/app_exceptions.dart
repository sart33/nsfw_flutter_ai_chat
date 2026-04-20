// Hierarchy of typed domain exceptions used across providers and repositories.
// All exceptions carry an optional [technicalMessage] for debug logging only.
// User-facing strings are resolved in the UI layer via ARB localisation.

class AppException implements Exception {
  final String? technicalMessage;
  const AppException([this.technicalMessage]);

  @override
  String toString() =>
      '$runtimeType: ${technicalMessage ?? '(no details)'}';
}

/// Thrown when a network / AI API call fails.
class ApiException extends AppException {
  const ApiException([super.technicalMessage]);
}

/// Thrown when loading chat history from the database fails.
class HistoryException extends AppException {
  const HistoryException([super.technicalMessage]);
}

/// Thrown when an image generation request fails.
class GenerationException extends AppException {
  const GenerationException([super.technicalMessage]);
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
/// Thrown when the prompt cleaner service encounters an error, such as missing API key, invalid response, or HTTP failure.
class PromptCleanerException implements Exception {
  final String code; // 'key_not_set' | 'key_invalid' | 'http_error' | 'parse_error'
  final int? statusCode;
  const PromptCleanerException(this.code, {this.statusCode});
}
/// Thrown when a Novita AI generation task fails or times out.
class NovitaException implements Exception {
  final String message;
  const NovitaException(this.message);
  @override
  String toString() => 'NovitaException: $message';
}

/// Interface for gallery-related exceptions
abstract interface class GalleryException implements Exception {
  String get technicalMessage;
}

/// Thrown when age verification fails during gallery preview generation.
class AgeVerificationException extends AppException implements GalleryException {
  const AgeVerificationException() : super('age_verification_failed');
  @override
  String get technicalMessage => 'age_verification_failed';
}

/// Thrown when prompt cleaner service fails during gallery preview generation.
class PromptCleanerGalleryException extends AppException implements GalleryException {
  final PromptCleanerException cause;
  PromptCleanerGalleryException(this.cause) : super(cause.code);
  @override
  String get technicalMessage => cause.code;
}

class PromptCleanerChatException extends AppException {
  final PromptCleanerException cause;
  const PromptCleanerChatException(this.cause);
}
