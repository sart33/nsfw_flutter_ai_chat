class RecentChatEntity {
  final String branchId;
  final String entityId;
  final String personaId; // extracted from entityId: 'single:UUID' → UUID
  final String personaName;
  final String? avatarPath;
  final String? avatarAssetPath;
  final String? preview;
  final DateTime updatedAt;

  const RecentChatEntity({
    required this.branchId,
    required this.entityId,
    required this.personaId,
    required this.personaName,
    required this.avatarPath,
    required this.avatarAssetPath,
    required this.preview,
    required this.updatedAt,
  });
}