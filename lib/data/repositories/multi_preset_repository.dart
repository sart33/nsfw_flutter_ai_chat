import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/data/models/multi_preset_model.dart';
import 'package:nsfw_chat/domain/result/result.dart';

/// Persists [MultiPresetModel] objects as a JSON list inside SharedPreferences.
class MultiPresetRepository {
  static const String _storageKey = 'multi_presets';

  // ── CREATE ──────────────────────────────────────────────────────────────

  Future<Result<MultiPresetModel>> create(MultiPresetModel preset) async {
    try {
      final presets = await _readAll();
      presets.add(preset);
      await _writeAll(presets);
      return Result.success(preset);
    } on Exception catch (e) {
      return Result.failure('Failed to create multi-preset', e);
    }
  }

  // ── READ ────────────────────────────────────────────────────────────────

  Future<Result<List<MultiPresetModel>>> getAll() async {
    try {
      final presets = await _readAll();
      return Result.success(presets);
    } on Exception catch (e) {
      return Result.failure('Failed to load multi-presets', e);
    }
  }

  Future<Result<MultiPresetModel>> getById(String id) async {
    try {
      final presets = await _readAll();
      final preset = presets.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Multi-preset not found: $id'),
      );
      return Result.success(preset);
    } on Exception catch (e) {
      return Result.failure('Failed to find multi-preset', e);
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────

  Future<Result<MultiPresetModel>> update(MultiPresetModel updated) async {
    try {
      final presets = await _readAll();
      final index = presets.indexWhere((p) => p.id == updated.id);
      if (index == -1) {
        return Result.failure('Multi-preset not found: ${updated.id}');
      }
      presets[index] = updated;
      await _writeAll(presets);
      return Result.success(updated);
    } on Exception catch (e) {
      return Result.failure('Failed to update multi-preset', e);
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────

  Future<Result<bool>> delete(String id) async {
    try {
      final presets = await _readAll();
      presets.removeWhere((p) => p.id == id);
      await _writeAll(presets);
      // Clean up all SQLite branches & messages for this multi-preset.
      await DatabaseHelper.instance.deleteAllForEntity('multi:$id');
      return Result.success(true);
    } on Exception catch (e) {
      return Result.failure('Failed to delete multi-preset', e);
    }
  }

  // ── INTERNAL HELPERS ────────────────────────────────────────────────────

  Future<List<MultiPresetModel>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    log('PREFS_READ key=$_storageKey, value length=${raw?.length ?? 0}', name: 'PREFS_READ');
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MultiPresetModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<MultiPresetModel> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((p) => p.toMap()).toList());
    final preview = encoded.length > 100 ? encoded.substring(0, 100) : encoded;
    log('PREFS_WRITE key=$_storageKey, value preview: $preview', name: 'PREFS_WRITE');
    await prefs.setString(_storageKey, encoded);
  }
}
