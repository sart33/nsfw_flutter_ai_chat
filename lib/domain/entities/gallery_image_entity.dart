/// Represents a generated gallery image associated with a persona.
/// [templateId] == 0 means generated from chat context (future use).
class GalleryImageEntity {
  final String id;
  final String personaId;
  final int templateId;
  final String localPath;
  final DateTime generatedAt;

  const GalleryImageEntity({
    required this.id,
    required this.personaId,
    required this.templateId,
    required this.localPath,
    required this.generatedAt,
  });
}
