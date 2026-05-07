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
    // One-time cleanup: delete SharedPreferences key if it exists
    await _cleanupSharedPreferences();
    
    final result = await _repo.getAll();
    result.when(
      success: (models) async {
        if (models.isEmpty) {
          // Check if personas are seeded and seed default preset
          await _seedDefaultPresetIfNeeded();
        } else {
          // Validate that all personaIds in each preset actually exist
          final personas = await _ref.read(personaProvider.future);
          final validModels = <MultiPresetModel>[];
          final invalidPresetIds = <String>[];
          
          for (final preset in models) {
            // Filter personaIds to only those that exist in current personas
            final validPersonaIds = preset.personaIds
                .where((id) => personas.any((p) => p.id == id))
                .toList();
            
            if (validPersonaIds.isEmpty) {
              // Preset has zero valid personaIds - mark for deletion
              invalidPresetIds.add(preset.id);
            } else if (validPersonaIds.length != preset.personaIds.length) {
              // Some personaIds are invalid, update the preset with filtered list
              final updatedPreset = preset.copyWith(personaIds: validPersonaIds);
              await _repo.update(updatedPreset);
              validModels.add(updatedPreset);
            } else {
              // All personaIds are valid
              validModels.add(preset);
            }
          }
          
          // Delete invalid presets from database
          for (final id in invalidPresetIds) {
            await _repo.delete(id);
          }
          
          // If after cleanup we have no presets, seed default
          if (validModels.isEmpty) {
            await _seedDefaultPresetIfNeeded();
          } else {
            state = MultiPresetMapper.toEntityList(validModels);
          }
        }
      },
      failure: (_, __) {},
    );
  }

  /// One-time cleanup: delete SharedPreferences key if it exists.
  Future<void> _cleanupSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('multi_presets');
    } catch (_) {
      // Ignore errors
    }
  }

  /// Seeds default multi-preset if personas are already seeded.
  Future<void> _seedDefaultPresetIfNeeded() async {
    final personas = await _ref.read(personaProvider.future);
        if (personas.isNotEmpty) {
          final locale = await _getDeviceLocale();
          await _seedDefaultPreset(PersonaMapper.toModelList(personas),
              locale
          );
        }
      }


  /// Seeds one default multi-preset linking the two default personas.
  Future<void> _seedDefaultPreset(List<PersonaModel> personas, Locale locale) async {
    final lang = locale.languageCode;

    final names = {
      'ru': ('Наташа', 'Аня'),
      'uk': ('Наташа', 'Аня'),
      'es': ('Natasha', 'Anna'),
      'pt': ('Natasha', 'Anna'),
      'hi': ('Natasha', 'Anna'),
      'fr': ('Natasha', 'Anna'),
      'id': ('Natasha', 'Anna'),
    };
    final (name1, name2) = names[lang] ?? ('Natasha', 'Anna');
    final p1 = personas.firstWhereOrNull((p) => p.name == name1);
    final p2 = personas.firstWhereOrNull((p) => p.name == name2);
    if (p1 == null || p2 == null) return;

    final greetings = {
      'ru': 'Наташа: Привет... Скучал по нам? 😈\nАня: Привет... *краснеет* Рада видеть тебя.',
      'uk': 'Наташа: Привіт... Скучав за нами? 😈\nАня: Привіт... *червоніє* Рада тебе бачити.',
      'es': 'Natasha: Hola... ¿Nos extrañaste? 😈\nAnna: Hola... *se sonroja* Me alegra verte.',
      'pt': 'Natasha: Oi... Sentiu nossa falta? 😈\nAnna: Oi... *cora* Fico feliz em te ver.',
      'hi': 'Natasha: Hey... Hamari yaad aayi? 😈\nAnna: Hi... *sharmati hai* Accha laga tujhe dekh ke.',
      'fr': 'Natasha: Salut... Tu nous as manqué ? 😈\nAnna: Salut... *rougit* Je suis contente de te voir.',
      'id': 'Natasha: Hai... Kangen sama kita? 😈\nAnna: Hai... *tersipu* Senang melihatmu.',
    };

    final behaviors = {
      'ru': 'Ты играешь за двух девушек: смелую Наташу и стеснительную Аню. Чередуй их реплики — они общаются между собой и с пользователем, иногда флиртуют друг с другом и с пользователем. Наташа ведёт и дразнит, Аня краснеет и следует за ней. Описывай действия и происходящее подробно. В каждом сообщении отвечай за обеих по очереди, начиная с имени.',
      'uk': 'Ти граєш за двох дівчат: сміливу Наташу і сором\'язливу Аню. Чергуй їхні репліки — вони спілкуються між собою і з користувачем, іноді фліртують одна з одною і з користувачем. Наташа веде і дражнить, Аня червоніє і слідує за нею. Описуй дії та те, що відбувається, детально. У кожному повідомленні відповідай за обох по черзі, починаючи з імені.',
      'es': 'Interpretas a dos chicas: la atrevida Natasha y la tímida Anna. Alterna sus intervenciones — hablan entre ellas y con el usuario, a veces coqueteando entre sí y con el usuario. Natasha lleva la iniciativa y provoca, Anna se sonroja y sigue su juego. Describe las acciones y lo que ocurre con detalle. En cada mensaje, responde por las dos en orden, comenzando con su nombre.',
      'pt': 'Você interpreta duas garotas: a ousada Natasha e a tímida Anna. Alterne as falas delas — elas conversam entre si e com o usuário, às vezes flertando entre si e com o usuário. Natasha toma a iniciativa e provoca, Anna fica envergonhada e a segue. Descreva as ações e o que acontece com detalhes. Em cada mensagem, responda pelas duas na ordem, começando pelo nome.',
      'hi': 'Tum do ladkiyon ko play karti ho: bold Natasha aur shy Anna. Unki baari-baari lines likho — woh ek-dusre se aur user se baat karti hain, kabhi kabhi ek-dusre se aur user se flirt bhi karti hain. Natasha lead karti hai aur tease karti hai, Anna sharmati hai aur uske peeche chalti hai. Actions aur events ko detail mein describe karo. Har message mein dono ke liye baari-baari jawab do, naam se shuru karke.',
      'fr': 'Tu joues deux filles : la téméraire Natasha et la timide Anna. Alterne leurs répliques — elles parlent entre elles et avec l\'utilisateur, en flirtant parfois entre elles et avec l\'utilisateur. Natasha mène le jeu et taquine, Anna rougit et suit. Décris les actions et les événements en détail. Dans chaque message, réponds pour toutes les deux à tour de rôle, en commençant par leur prénom.',
      'id': 'Kamu memainkan dua gadis: Natasha yang berani dan Anna yang pemalu. Bergantian giliran mereka — mereka mengobrol satu sama lain dan dengan pengguna, terkadang saling menggoda satu sama lain dan dengan pengguna. Natasha memimpin dan menggoda, Anna tersipu dan mengikuti. Jelaskan tindakan dan kejadian secara detail. Di setiap pesan, jawab untuk keduanya secara bergantian, dimulai dengan nama mereka.',
    };

    final defaultGreeting = 'Natasha: Hey... Missed us? 😈\nAnna: Hi... *blushes* Nice to see you.';
    final defaultBehavior = 'You play two girls: bold Natasha and shy Anna. Alternate their lines — they talk to each other and to the user, sometimes flirting with each other and with the user. Natasha leads and teases, Anna blushes and follows. Describe actions and events in detail. In every message, respond for both of them in turn, starting with their names.';


    final preset = MultiPresetModel(
      id: '00000000-0000-0000-0000-000000000003',
      name: (lang == 'ru' || lang == 'uk') ? '${name1} + ${name2}' : 'Natasha + Anna',
      personaIds: [p1.id, p2.id],
      greeting: greetings[lang] ?? defaultGreeting,
      behavior: behaviors[lang] ?? defaultBehavior,
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
