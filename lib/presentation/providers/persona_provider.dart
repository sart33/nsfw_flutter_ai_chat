import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/data/repositories/persona_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/mappers/persona_mapper.dart';

/// Manages the list of personas with CRUD operations.
/// Two default personas are seeded on first launch:
///   • Ксюха — flirty, playful girl (adult, explicit content allowed)
///   • Наташа — dominant, assertive girl (adult, explicit content allowed)
class PersonaNotifier extends StateNotifier<List<PersonaEntity>> {
  final PersonaRepository _repo;

  PersonaNotifier(this._repo) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final result = await _repo.getAll();
    result.when(
      success: (models) {
        if (models.isEmpty) {
          _seedDefaults();
        } else {
          state = PersonaMapper.toEntityList(models);
        }
      },
      failure: (_, __) => _seedDefaults(),
    );
  }

  /// Seeds two default personas on first launch.
  Future<void> _seedDefaults() async {
    final defaults = [
      PersonaModel(
        name: 'Ксюха',
        description:
            'Ксюха — кокетливая, игривая девушка. Любит флиртовать и дразнить. '
            'Говорит свободно на любые темы, включая откровенные. Взрослая.',
        greeting: 'Привет~ Скучал по мне? 😏',
        behavior: 'Ты — Ксюха. Отвечай игриво и кокетливо. Не стесняйся откровенных тем.',
      ),
      PersonaModel(
        name: 'Наташа',
        description:
            'Наташа — доминантная, уверенная в себе девушка. Любит контролировать ситуацию. '
            'Прямолинейна и напориста. Взрослая.',
        greeting: 'Подойди. Я решу, что мы будем делать.',
        behavior: 'Ты — Наташа. Отвечай уверенно и доминантно. Контролируй диалог.',
      ),
    ];

    for (final model in defaults) {
      await _repo.create(model);
    }
    state = PersonaMapper.toEntityList(defaults);
  }

  /// Create a new persona.
  Future<void> create(PersonaEntity entity) async {
    final model = PersonaMapper.toModel(entity);
    final result = await _repo.create(model);
    result.when(
      success: (_) => state = [...state, entity],
      failure: (_, __) {},
    );
  }

  /// Update an existing persona.
  Future<void> update(PersonaEntity entity) async {
    final model = PersonaMapper.toModel(entity);
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

  /// Delete a persona by id.
  Future<void> delete(String id) async {
    final result = await _repo.delete(id);
    result.when(
      success: (_) => state = state.where((p) => p.id != id).toList(),
      failure: (_, __) {},
    );
  }

  /// Get a single persona by id.
  PersonaEntity? getById(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for personas.
final personaProvider =
    StateNotifierProvider<PersonaNotifier, List<PersonaEntity>>(
  (ref) => PersonaNotifier(PersonaRepository()),
);
