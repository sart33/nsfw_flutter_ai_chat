import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data-layer model representing an AI persona / character.
class PersonaModel {
  final String id;
  final String name;
  final String description;
  final String greeting;
  final String? avatarPath;
  final String? avatarAssetPath;
  final String? behavior;
  final String galleryMode;
  final bool ageVerified; // NEW

  PersonaModel({
    String? id,
    required this.name,
    required this.description,
    required this.greeting,
    this.avatarPath,
    this.avatarAssetPath,
    this.behavior,
    this.ageVerified = false, // NEW
    this.galleryMode = 'nude',
  }) : id = id ?? const Uuid().v4();

  // ── JSON serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'greeting': greeting,
    'avatar_path': avatarPath,
    'avatar_asset_path': avatarAssetPath,
    'behavior': behavior,
    'gallery_mode': galleryMode,
    'age_verified': ageVerified ? 1 : 0, // NEW
  };

  factory PersonaModel.fromMap(Map<String, dynamic> map) => PersonaModel(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String,
    greeting: map['greeting'] as String,
    avatarPath: map['avatar_path'] as String?,
    avatarAssetPath: map['avatar_asset_path'] as String?,
    behavior: map['behavior'] as String?,
    galleryMode: (map['gallery_mode'] as String?) ?? 'nude',
    ageVerified: ((map['age_verified'] as int?) ?? 0) == 1,   // NEW
  );

  String toJson() => jsonEncode(toMap());

  factory PersonaModel.fromJson(String source) =>
      PersonaModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  PersonaModel copyWith({
    String? id,
    String? name,
    String? description,
    String? greeting,
    String? avatarPath,
    String? avatarAssetPath,
    String? behavior,
    String? galleryMode,
    bool? ageVerified,
  }) => PersonaModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    greeting: greeting ?? this.greeting,
    avatarPath: avatarPath ?? this.avatarPath,
    avatarAssetPath: avatarAssetPath ?? this.avatarAssetPath,
    behavior: behavior ?? this.behavior,
    galleryMode: galleryMode ?? this.galleryMode,
    ageVerified: ageVerified ?? this.ageVerified,
  );
}
