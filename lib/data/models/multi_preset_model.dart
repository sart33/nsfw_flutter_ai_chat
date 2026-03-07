import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data-layer model for a multi-persona preset (group chat template).
class MultiPresetModel {
  final String id;
  final String name;
  final List<String> personaIds;
  final String greeting;
  final String? behavior;

  MultiPresetModel({
    String? id,
    required this.name,
    required this.personaIds,
    required this.greeting,
    this.behavior,
  }) : id = id ?? const Uuid().v4();

  // ── JSON serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'personaIds': personaIds,
        'greeting': greeting,
        'behavior': behavior,
      };

  factory MultiPresetModel.fromMap(Map<String, dynamic> map) =>
      MultiPresetModel(
        id: map['id'] as String,
        name: map['name'] as String,
        personaIds: List<String>.from(map['personaIds'] as List),
        greeting: map['greeting'] as String,
        behavior: map['behavior'] as String?,
      );

  String toJson() => jsonEncode(toMap());

  factory MultiPresetModel.fromJson(String source) =>
      MultiPresetModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  MultiPresetModel copyWith({
    String? id,
    String? name,
    List<String>? personaIds,
    String? greeting,
    String? behavior,
  }) =>
      MultiPresetModel(
        id: id ?? this.id,
        name: name ?? this.name,
        personaIds: personaIds ?? this.personaIds,
        greeting: greeting ?? this.greeting,
        behavior: behavior ?? this.behavior,
      );
}
