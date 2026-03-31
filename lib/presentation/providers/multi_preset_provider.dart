import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/models/multi_preset_model.dart';
import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/data/repositories/multi_preset_repository.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/mappers/multi_preset_mapper.dart';
import 'package:nsfw_chat/domain/mappers/persona_mapper.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the list of multi-persona presets with CRUD operations.
class MultiPresetNotifier extends StateNotifier<List<MultiPresetEntity>> {
  final MultiPresetRepository _repo;
  final Ref _ref;

  MultiPresetNotifier(this._repo, this._ref) : super([]) {
    _init();
  }

  /// Gets the current device locale for seeding.
  Future<Locale> _getDeviceLocale() async {
    // Try to read from SharedPreferences first (if user set locale manually)
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString('flutter.locale');
      if (savedLocale != null && savedLocale.isNotEmpty) {
        return Locale(savedLocale);
      }
    } catch (_) {}
    
    // Fall back to platform dispatcher locale
    return WidgetsBinding.instance.platformDispatcher.locale;
  }

  Future<void> _init() async {
    final result = await _repo.getAll();
    result.when(
      success: (models) async {
        if (models.isEmpty) {
          // Check if personas are seeded and seed default preset
          await _seedDefaultPresetIfNeeded();
        } else {
          state = MultiPresetMapper.toEntityList(models);
        }
      },
      failure: (_, __) {},
    );
  }

  /// Seeds default multi-preset if personas are already seeded.
  Future<void> _seedDefaultPresetIfNeeded() async {
    final personas = await _ref.read(personaProvider.future);
        debugPrint('=== personas count: ${personas.length}'); // <-- добавь
        debugPrint('=== personas names: ${personas.map((p) => p.name).toList()}');
        if (personas.isNotEmpty) {
          final locale = await _getDeviceLocale();
          await _seedDefaultPreset(PersonaMapper.toModelList(personas),
              locale
          );
        }
      }


  /// Seeds one default multi-preset linking the two default personas.
  Future<void> _seedDefaultPreset(List<PersonaModel> personas, Locale locale) async {
    final isRu = locale.languageCode == 'ru';
    final name1 = isRu ? 'Наташа' : 'Natasha';
    final name2 = isRu ? 'Аня' : 'Anna';
    final p1 = personas.firstWhereOrNull((p) => p.name == name1);
    final p2 = personas.firstWhereOrNull((p) => p.name == name2);
    if (p1 == null || p2 == null) return; // personas not seeded yet, skip

    final preset = MultiPresetModel(
      name: isRu ? 'Наташа + Аня' : 'Natasha + Anna',
      personaIds: [p1.id, p2.id],
      greeting: isRu
          ? 'Наташа: Привет... Скучал по нам? 😈\nАня: Привет... *краснеет* Рада видеть тебя.'
          : 'Natasha: Hey... Missed us? 😈\nAnna: Hi... *blushes* Nice to see you.',
      behavior: isRu
          ? 'Ты играешь за двух девушек: активную Наташу и стеснительную Аню. '
            'Чередуй реплики — они общаются между собой и с пользователем, '
            'иногда флиртуют друг с другом. Наташа ведёт и дразнит, '
            'Аня краснеет и следует. Описывай подробно на русском.'
          : 'You play two girls: bold Natasha and shy Anna. Alternate their lines — '
            'they talk to each other and to the user, occasionally flirting. '
            'Natasha leads and teases, Anna blushes and follows. '
            'Describe everything in detail in English.',
    );

    await _repo.create(preset);
    state = MultiPresetMapper.toEntityList([preset]);
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
  (ref) => MultiPresetNotifier(MultiPresetRepository(), ref),
);
