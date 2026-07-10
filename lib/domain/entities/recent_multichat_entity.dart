class RecentMultiEntity {
  final String branchId;
  final String presetId;        // extracted: 'multi:UUID' → UUID
  final String presetName;
  final List<String> personaIds;
  final String greeting;
  final String? preview;
  final DateTime updatedAt;

  const RecentMultiEntity({
    required this.branchId,
    required this.presetId,
    required this.presetName,
    required this.personaIds,
    required this.greeting,
    required this.preview,
    required this.updatedAt,
  });
}