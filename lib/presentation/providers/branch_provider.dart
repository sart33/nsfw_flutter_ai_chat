import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/domain/entities/branch_entity.dart';

/// Manages branches for a specific entity (single or multi).
/// Parameter: entityId — `single:<id>` or `multi:<id>`.
class BranchNotifier extends StateNotifier<List<BranchEntity>> {
  final BranchRepository _repo;
  final String _entityId;

  BranchNotifier({
    required String entityId,
    BranchRepository? repo,
  })  : _entityId = entityId,
        _repo = repo ?? BranchRepository(),
        super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final branches = await _repo.getBranchesForEntity(_entityId);
      state = branches;
    } catch (e) {
      // Keep empty on error.
      state = [];
    }
  }

  /// Reloads branches from the database.
  Future<void> refresh() async {
    await _load();
  }

  /// Creates a new branch, adds to state, returns the entity.
  Future<BranchEntity> createBranch() async {
    final branch = await _repo.createBranch(_entityId);
    state = [branch, ...state];
    return branch;
  }

  /// Deletes a branch and removes from state.
  Future<void> deleteBranch(String branchId) async {
    await _repo.deleteBranch(branchId);
    state = state.where((b) => b.id != branchId).toList();
  }
}

/// Family provider: one [BranchNotifier] per entityId.
final branchProvider =
    StateNotifierProvider.family<BranchNotifier, List<BranchEntity>, String>(
  (ref, entityId) => BranchNotifier(entityId: entityId),
);
