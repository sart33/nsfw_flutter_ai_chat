import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data-layer model representing an AI persona / character.
class PersonaModel {
  final String id;
  final String name;
  final String description;
  final String greeting;
  final String? avatarPath;
  final String? behavior;
  final String galleryMode;

  PersonaModel({
    String? id,
    required this.name,
    required this.description,
    required this.greeting,
    this.avatarPath,
    this.behavior,
    this.galleryMode = 'nude',
  }) : id = id ?? const Uuid().v4();

  // ── JSON serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'greeting': greeting,
        'avatarPath': avatarPath,
        'behavior': behavior,
        'galleryMode': galleryMode,
      };

  factory PersonaModel.fromMap(Map<String, dynamic> map) => PersonaModel(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        greeting: map['greeting'] as String,
        avatarPath: map['avatarPath'] as String?,
        behavior: map['behavior'] as String?,
        galleryMode: (map['galleryMode'] as String?) ?? 'nude',
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
    String? behavior,
    String? galleryMode,
  }) =>
      PersonaModel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        greeting: greeting ?? this.greeting,
        avatarPath: avatarPath ?? this.avatarPath,
        behavior: behavior ?? this.behavior,
        galleryMode: galleryMode ?? this.galleryMode,
      );
}
