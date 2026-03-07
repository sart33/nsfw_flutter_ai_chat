/// Domain entity for a multi-persona preset (group chat template).
class MultiPresetEntity {
  final String id;
  final String name;
  final List<String> personaIds;
  final String greeting;
  final String? behavior;

  const MultiPresetEntity({
    required this.id,
    required this.name,
    required this.personaIds,
    required this.greeting,
    this.behavior,
  });

  MultiPresetEntity copyWith({
    String? id,
    String? name,
    List<String>? personaIds,
    String? greeting,
    String? behavior,
  }) =>
      MultiPresetEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        personaIds: personaIds ?? this.personaIds,
        greeting: greeting ?? this.greeting,
        behavior: behavior ?? this.behavior,
      );
}
