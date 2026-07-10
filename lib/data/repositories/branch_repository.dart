import 'dart:convert';

import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/domain/entities/branch_entity.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/recent_chat_entity.dart';
import '../../domain/entities/recent_multichat_entity.dart';

/// Repository that manages conversation branches via SQLite.
class BranchRepository {
  final DatabaseHelper _db;

  BranchRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  /// Returns all branches for [entityId], newest-updated first.
  Future<List<BranchEntity>> getBranchesForEntity(String entityId) async {
    try {
      final rows = await _db.getBranchesForEntity(entityId);
      return rows.map(_mapRowToEntity).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RecentChatEntity>> getRecentChats({int limit = 8}) async {
    final rows = await _db.getRecentSingleBranches(limit: limit);

    return rows.map((row) {
      final updatedAtMs = (row['real_updated_at'] ?? row['updated_at']) as int;

      return RecentChatEntity(
        branchId: row['id'] as String,
        entityId: row['entity_id'] as String,
        personaId: (row['entity_id'] as String).replaceFirst('single:', ''),
        personaName: row['persona_name'] as String,
        avatarPath: row['avatar_path'] as String?,
        avatarAssetPath: row['avatar_asset_path'] as String?,
        ageVerified: row['persona_age_verified'],
        preview: row['preview'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    }).toList();
  }



// Толерантный парсер: понимает и JSON-массив ["a","b"], и "a,b" через запятую.
  List<String> _parsePersonaIds(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
  final decoded = jsonDecode(raw);
  if (decoded is List) return decoded.map((e) => e.toString()).toList();
  } catch (_) {}
  return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Creates a new branch for [entityId], inserts it, and returns the entity.
  Future<BranchEntity> createBranch(String entityId) async {
    try {
      final id = const Uuid().v4();
      await _db.insertBranch(id, entityId, null);
      final now = DateTime.now();
      return BranchEntity(
        id: id,
        entityId: entityId,
        createdAt: now,
        updatedAt: now,
        preview: null,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RecentMultiEntity>> getRecentMultiChats({int limit = 8}) async {
    final rows = await _db.getRecentMultiBranches(limit: limit);
    return rows.map((row) {
      final updatedAtMs = (row['real_updated_at'] ?? row['updated_at']) as int;
      return RecentMultiEntity(
        branchId: row['id'] as String,
        presetId: (row['entity_id'] as String).replaceFirst('multi:', ''),
        presetName: row['preset_name'] as String,
        personaIds: _parsePersonaIds(row['persona_ids']),
        greeting: (row['greeting'] as String?) ?? '',
        preview: row['preview'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    }).toList();
  }

  /// Deletes a branch and all its messages.
  Future<void> deleteBranch(String branchId) async {
    try {
      await _db.deleteBranch(branchId);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all branches (and their messages) for a given entity.
  Future<void> deleteAllForEntity(String entityId) async {
    try {
      await _db.deleteAllForEntity(entityId);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the preview text of a branch.
  Future<void> updatePreview(String branchId, String preview) async {
    try {
      await _db.updateBranchPreview(branchId, preview);
    } catch (e) {
      rethrow;
    }
  }

  /// Returns up to [limit] most recently updated branches
  /// whose entity_id starts with 'single:'.
  Future<List<BranchEntity>> getRecentSingleBranches({int limit = 5}) async {
    try {
      final rows = await _db.getRecentSingleBranches(limit: limit);
      return rows.map(_mapRowToEntity).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Touches the updated_at timestamp of a branch to now.
  Future<void> touchTimestamp(String branchId) async {
    try {
      await _db.updateBranchTimestamp(branchId);
    } catch (e) {
      rethrow;
    }
  }

  // ── INTERNAL ────────────────────────────────────────────────────────────

  /// Clears the stored summary for a branch.
  Future<void> clearSummary(String branchId) async {
    try {
      await _db.saveBranchSummary(branchId, '');
    } catch (e) {
      rethrow;
    }
  }

  // ── INTERNAL ────────────────────────────────────────────────────────────

  BranchEntity _mapRowToEntity(Map<String, dynamic> row) {
    final updatedAtMs = (row['real_updated_at'] ?? row['updated_at']) as int;
    return BranchEntity(
      id: row['id'] as String,
      entityId: row['entity_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      preview: row['preview'] as String?,
      contextSummary: row['context_summary'] as String?,
    );
  }
}
