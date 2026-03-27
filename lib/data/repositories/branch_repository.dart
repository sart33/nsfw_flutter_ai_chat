import 'package:uuid/uuid.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/domain/entities/branch_entity.dart';

import '../../domain/entities/recent_chat_entity.dart';

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
      print('BranchRepository.getBranchesForEntity error: $e');
      rethrow;
    }
  }

  Future<List<RecentChatEntity>> getRecentChats({int limit = 5}) async {
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
        preview: row['preview'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    }).toList();
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
      print('BranchRepository.createBranch error: $e');
      rethrow;
    }
  }

  /// Deletes a branch and all its messages.
  Future<void> deleteBranch(String branchId) async {
    try {
      await _db.deleteBranch(branchId);
    } catch (e) {
      print('BranchRepository.deleteBranch error: $e');
      rethrow;
    }
  }

  /// Deletes all branches (and their messages) for a given entity.
  Future<void> deleteAllForEntity(String entityId) async {
    try {
      await _db.deleteAllForEntity(entityId);
    } catch (e) {
      print('BranchRepository.deleteAllForEntity error: $e');
      rethrow;
    }
  }

  /// Updates the preview text of a branch.
  Future<void> updatePreview(String branchId, String preview) async {
    try {
      await _db.updateBranchPreview(branchId, preview);
    } catch (e) {
      print('BranchRepository.updatePreview error: $e');
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
      print('BranchRepository.getRecentSingleBranches error: $e');
      rethrow;
    }
  }

  /// Touches the updated_at timestamp of a branch to now.
  Future<void> touchTimestamp(String branchId) async {
    try {
      await _db.updateBranchTimestamp(branchId);
    } catch (e) {
      print('BranchRepository.touchTimestamp error: $e');
      rethrow;
    }
  }

  // ── INTERNAL ────────────────────────────────────────────────────────────

  /// Clears the stored summary for a branch.
  Future<void> clearSummary(String branchId) async {
    try {
      await _db.saveBranchSummary(branchId, '');
      print('[Summary] Cleared for branch $branchId');
    } catch (e) {
      print('BranchRepository.clearSummary error: $e');
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
