/// Domain entity representing an AI persona / character.
/// All personas are adults. Content is explicit by default — no content filtering.
class PersonaEntity {
  final String id;
  final String name;
  final String description;
  final String greeting;
  final String? avatarPath;
  final String? behavior;

  const PersonaEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.greeting,
    this.avatarPath,
    this.behavior,
  });

  PersonaEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? greeting,
    String? avatarPath,
    String? behavior,
  }) =>
      PersonaEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        greeting: greeting ?? this.greeting,
        avatarPath: avatarPath ?? this.avatarPath,
        behavior: behavior ?? this.behavior,
      );
}
