/// Domain entity representing a conversation branch.
class BranchEntity {
  final String id;
  final String entityId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? preview;
  final String? contextSummary;

  const BranchEntity({
    required this.id,
    required this.entityId,
    required this.createdAt,
    required this.updatedAt,
    this.preview,
    this.contextSummary,
  });

  BranchEntity copyWith({
    String? id,
    String? entityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? preview,
    String? contextSummary,
  }) =>
      BranchEntity(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        preview: preview ?? this.preview,
        contextSummary: contextSummary ?? this.contextSummary,
      );
}
