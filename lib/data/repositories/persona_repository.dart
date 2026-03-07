import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/domain/result/result.dart';

/// Persists [PersonaModel] objects as a JSON list inside SharedPreferences.
class PersonaRepository {
  static const String _storageKey = 'personas';

  // ── CREATE ──────────────────────────────────────────────────────────────

  Future<Result<PersonaModel>> create(PersonaModel persona) async {
    try {
      final personas = await _readAll();
      personas.add(persona);
      await _writeAll(personas);
      return Result.success(persona);
    } on Exception catch (e) {
      return Result.failure('Failed to create persona', e);
    }
  }

  // ── READ ────────────────────────────────────────────────────────────────

  Future<Result<List<PersonaModel>>> getAll() async {
    try {
      final personas = await _readAll();
      return Result.success(personas);
    } on Exception catch (e) {
      return Result.failure('Failed to load personas', e);
    }
  }

  Future<Result<PersonaModel>> getById(String id) async {
    try {
      final personas = await _readAll();
      final persona = personas.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Persona not found: $id'),
      );
      return Result.success(persona);
    } on Exception catch (e) {
      return Result.failure('Failed to find persona', e);
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────

  Future<Result<PersonaModel>> update(PersonaModel updated) async {
    try {
      final personas = await _readAll();
      final index = personas.indexWhere((p) => p.id == updated.id);
      if (index == -1) {
        return Result.failure('Persona not found: ${updated.id}');
      }
      personas[index] = updated;
      await _writeAll(personas);
      return Result.success(updated);
    } on Exception catch (e) {
      return Result.failure('Failed to update persona', e);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────

  Future<Result<bool>> delete(String id) async {
    try {
      final personas = await _readAll();
      personas.removeWhere((p) => p.id == id);
      await _writeAll(personas);
      // Clean up all SQLite branches & messages for this persona.
      await DatabaseHelper.instance.deleteAllForEntity('single:$id');
      return Result.success(true);
    } on Exception catch (e) {
      return Result.failure('Failed to delete persona', e);
    }
  }

  // ── INTERNAL HELPERS ────────────────────────────────────────────────────

  Future<List<PersonaModel>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    log('PREFS_READ key=$_storageKey, value length=${raw?.length ?? 0}', name: 'PREFS_READ');
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => PersonaModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<PersonaModel> personas) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(personas.map((p) => p.toMap()).toList());
    final preview = encoded.length > 100 ? encoded.substring(0, 100) : encoded;
    log('PREFS_WRITE key=$_storageKey, value preview: $preview', name: 'PREFS_WRITE');
    await prefs.setString(_storageKey, encoded);
  }
}
