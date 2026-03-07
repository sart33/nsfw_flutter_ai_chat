import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/repositories/multi_preset_repository.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/mappers/multi_preset_mapper.dart';

/// Manages the list of multi-persona presets with CRUD operations.
class MultiPresetNotifier extends StateNotifier<List<MultiPresetEntity>> {
  final MultiPresetRepository _repo;

  MultiPresetNotifier(this._repo) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final result = await _repo.getAll();
    result.when(
      success: (models) {
        state = MultiPresetMapper.toEntityList(models);
      },
      failure: (_, __) {},
    );
  }

  /// Create a new multi-preset.
  Future<void> create(MultiPresetEntity entity) async {
    final model = MultiPresetMapper.toModel(entity);
    final result = await _repo.create(model);
    result.when(
      success: (_) => state = [...state, entity],
      failure: (_, __) {},
    );
  }

  /// Update an existing multi-preset.
  Future<void> update(MultiPresetEntity entity) async {
    final model = MultiPresetMapper.toModel(entity);
    final result = await _repo.update(model);
    result.when(
      success: (_) {
        state = [
          for (final p in state)
            if (p.id == entity.id) entity else p,
        ];
      },
      failure: (_, __) {},
    );
  }

  /// Delete a multi-preset by id.
  Future<void> delete(String id) async {
    final result = await _repo.delete(id);
    result.when(
      success: (_) => state = state.where((p) => p.id != id).toList(),
      failure: (_, __) {},
    );
  }

  /// Get a single multi-preset by id.
  MultiPresetEntity? getById(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for multi-presets.
final multiPresetProvider =
    StateNotifierProvider<MultiPresetNotifier, List<MultiPresetEntity>>(
  (ref) => MultiPresetNotifier(MultiPresetRepository()),
);
