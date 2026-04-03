import 'dart:convert';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/data/models/multi_preset_model.dart';
import 'package:nsfw_chat/domain/result/result.dart';

/// Persists [MultiPresetModel] objects in SQLite database.
class MultiPresetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── CREATE ──────────────────────────────────────────────────────────────

  Future<Result<MultiPresetModel>> create(MultiPresetModel preset) async {
    try {
      final presetMap = preset.toMap();
      // Convert personaIds list to JSON string
      presetMap['persona_ids'] = jsonEncode(preset.personaIds);
      // Ensure behavior is not null for NOT NULL column
      presetMap['behavior'] = preset.behavior ?? '';
      await _dbHelper.insertMultiPreset(presetMap);
      return Result.success(preset);
    } on Exception catch (e) {
      return Result.failure('Failed to create multi-preset', e);
    }
  }

  // ── READ ────────────────────────────────────────────────────────────────

  Future<Result<List<MultiPresetModel>>> getAll() async {
    try {
      final rows = await _dbHelper.getAllMultiPresets();
      final presets = rows.map((row) => _rowToModel(row)).toList();
      return Result.success(presets);
    } on Exception catch (e) {
      return Result.failure('Failed to load multi-presets', e);
    }
  }

  Future<Result<MultiPresetModel>> getById(String id) async {
    try {
      final row = await _dbHelper.getMultiPresetById(id);
      if (row == null) {
        return Result.failure('Multi-preset not found: $id');
      }
      final preset = _rowToModel(row);
      return Result.success(preset);
    } on Exception catch (e) {
      return Result.failure('Failed to find multi-preset', e);
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────

  Future<Result<MultiPresetModel>> update(MultiPresetModel updated) async {
    try {
      // Check if preset exists
      final existing = await _dbHelper.getMultiPresetById(updated.id);
      if (existing == null) {
        return Result.failure('Multi-preset not found: ${updated.id}');
      }
      
      final presetMap = updated.toMap();
      // Convert personaIds list to JSON string
      presetMap['persona_ids'] = jsonEncode(updated.personaIds);
      // Ensure behavior is not null for NOT NULL column
      presetMap['behavior'] = updated.behavior ?? '';
      await _dbHelper.updateMultiPreset(presetMap);
      return Result.success(updated);
    } on Exception catch (e) {
      return Result.failure('Failed to update multi-preset', e);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────

  Future<Result<bool>> delete(String id) async {
    try {
      await _dbHelper.deleteMultiPreset(id);
      // Clean up all SQLite branches & messages for this multi-preset.
      await _dbHelper.deleteAllForEntity('multi:$id');
      return Result.success(true);
    } on Exception catch (e) {
      return Result.failure('Failed to delete multi-preset', e);
    }
  }

  // ── INTERNAL HELPERS ────────────────────────────────────────────────────

  MultiPresetModel _rowToModel(Map<String, dynamic> row) {
    // Parse JSON string back to List<String>
    final personaIdsJson = row['persona_ids'] as String;
    final personaIds = List<String>.from(jsonDecode(personaIdsJson) as List);
    
    return MultiPresetModel(
      id: row['id'] as String,
      name: row['name'] as String,
      personaIds: personaIds,
      greeting: row['greeting'] as String,
      behavior: row['behavior'] as String?,
    );
  }
}
