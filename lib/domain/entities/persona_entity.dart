/// Domain entity representing an AI persona / character.
/// All personas are adults. Content is explicit by default — no content filtering.
class PersonaEntity {
  final String id;
  final String name;
  final String description;
  final String greeting;
  final String? avatarPath;
  final String? avatarAssetPath;
  final String? behavior;
  final String galleryMode;
  final bool ageVerified;
  final bool? userAppearanceEnabled; // null = брать из settings
  final String? userGender;
  final String? userAge;
  final String? userHairColor;
  final String? userEthnicity;


  const PersonaEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.greeting,
    this.avatarPath,
    this.avatarAssetPath,
    this.behavior,
    required this.galleryMode,
    this.ageVerified = false,
    this.userAppearanceEnabled,
    this.userGender,
    this.userAge,
    this.userHairColor,
    this.userEthnicity,// NEW
  });

  PersonaEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? greeting,
    String? avatarPath,
    String? avatarAssetPath,
    String? behavior,
    String? galleryMode,
    bool? ageVerified,
    bool? userAppearanceEnabled,
    String? userGender,
    String? userAge,
    String? userHairColor,
    String? userEthnicity,
  }) =>
      PersonaEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        greeting: greeting ?? this.greeting,
        avatarPath: avatarPath ?? this.avatarPath,
        avatarAssetPath: avatarAssetPath ?? this.avatarAssetPath,
        behavior: behavior ?? this.behavior,
        galleryMode: galleryMode ?? this.galleryMode,
        ageVerified: ageVerified ?? this.ageVerified,
        userAppearanceEnabled:
        userAppearanceEnabled ?? this.userAppearanceEnabled,
        userGender: userGender ?? this.userGender,
        userAge: userAge ?? this.userAge,
        userHairColor: userHairColor ?? this.userHairColor,
        userEthnicity: userEthnicity ?? this.userEthnicity,
      );
}
