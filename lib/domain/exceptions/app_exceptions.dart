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
class GalleryFullException extends AppException {
  const GalleryFullException() : super('All 20 templates already generated');
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
