import 'dart:io';

import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/domain/result/result.dart';

/// Persists [PersonaModel] objects in SQLite database.
class PersonaRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── CREATE ──────────────────────────────────────────────────────────────

  Future<Result<PersonaModel>> create(PersonaModel persona) async {
    try {
      await _dbHelper.insertPersona(persona);
      return Result.success(persona);
    } on Exception catch (e) {
      return Result.failure('Failed to create persona', e);
    }
  }

  // ── READ ────────────────────────────────────────────────────────────────

  Future<Result<List<PersonaModel>>> getAll() async {
    try {
      final rows = await _dbHelper.getAllPersonas();
      final personas = rows.map((row) => PersonaModel.fromMap(row)).toList();
      return Result.success(personas);
    } on Exception catch (e) {
      return Result.failure('Failed to load personas', e);
    }
  }

  Future<Result<PersonaModel>> getById(String id) async {
    try {
      final row = await _dbHelper.getPersonaById(id);
      if (row == null) {
        return Result.failure('Persona not found: $id');
      }
      final persona = PersonaModel.fromMap(row);
      return Result.success(persona);
    } on Exception catch (e) {
      return Result.failure('Failed to find persona', e);
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────

  Future<Result<PersonaModel>> update(PersonaModel updated) async {
    try {
      // Check if persona exists
      final existing = await _dbHelper.getPersonaById(updated.id);
      if (existing == null) {
        return Result.failure('Persona not found: ${updated.id}');
      }
      
      await _dbHelper.updatePersona(updated);
      return Result.success(updated);
    } on Exception catch (e) {
      return Result.failure('Failed to update persona', e);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────

  Future<Result<bool>> delete(String id) async {
    try {
      // Get persona to check for avatar file
      final row = await _dbHelper.getPersonaById(id);
      if (row != null) {
        final persona = PersonaModel.fromMap(row);
        // Delete avatar file if exists
        if (persona.avatarPath != null) {
          try {
            final f = File(persona.avatarPath!);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
      }

      // Delete from database
      await _dbHelper.deletePersona(id);
      // Clean up all SQLite branches & messages for this persona.
      await _dbHelper.deleteAllForEntity('single:$id');
      return Result.success(true);
    } on Exception catch (e) {
      return Result.failure('Failed to delete persona', e);
    }
  }
}
