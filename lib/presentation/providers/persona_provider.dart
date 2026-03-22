import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/data/repositories/persona_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/mappers/persona_mapper.dart';

import '../../core/factory/database_helper.dart';

/// Manages the list of personas with CRUD operations.
/// Two default personas are seeded on first launch:
///   • Наташа / Natasha — flirty, playful girl (adult, explicit content allowed)
///   • Аня / Anna — shy, romantic girl (adult, explicit content allowed)
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

  /// Seeds two default personas on first launch based on device locale.
  Future<void> _seedDefaults() async {
    final locale = await _getDeviceLocale(); // вот здесь получаем локаль
    final personas = _getDefaultPersonas(locale); // ID уже есть внутри каждой модели

    for (final model in personas) {
      await _repo.create(model);
    }

    await _seedPrompts(personas); // передаём список — ID берём из personas[0].id и personas[1].id

    state = PersonaMapper.toEntityList(personas);
  }

  Future<void> _seedPrompts(List<PersonaModel> personas) async {
    final natasha = personas[0];
    final anna = personas[1];

    await DatabaseHelper.instance.upsertPersonaPrompts(
      personaId: natasha.id,
      nsfw:      'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts with nipple piercings, thin waist, intricate tattoos on arms and below panty line, tongue and navel piercings).',
      erotic:    'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts, thin waist, intricate tattoos on arms and below panty line, navel piercing). properly dressed',
      beach:     'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts, thin waist, intricate tattoos on arms and below panty line, navel piercing). properly dressed',
      romantic:  'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, thin waist, tattoos on arms). properly dressed',
      romantic2: 'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, thin waist). properly dressed',
      office:    'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, thin waist). properly dressed',
    );

    await DatabaseHelper.instance.upsertPersonaPrompts(
      personaId: anna.id,
      nsfw:      'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts with pink nipples, soft skin). ',
      erotic:    'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts, soft skin). properly dressed',
      beach:     'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts, soft skin). properly dressed',
      romantic:  'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, soft skin). properly dressed',
      romantic2: 'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, soft skin). properly dressed',
      office:    'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, soft skin). properly dressed',
    );
  }

  /// Returns localized default personas based on locale.
  List<PersonaModel> _getDefaultPersonas(Locale locale) {
    final isRu = locale.languageCode == 'ru';
    return [
      PersonaModel(
        name: isRu ? 'Наташа' : 'Natasha',
        description: isRu
            ? 'Красивая стильная женщина 32 лет, латиноамериканка из Колумбии. Чёрные волосы до плеч, карие глаза, стройная фигура (плоский живот, упругая грудь размер C с пирсингом на сосках, тонкая талия, татуировки на руках и ниже линии трусиков, пирсинг на языке и пупке).'
            : 'Beautiful stylish 32-year-old Latina from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts with nipple piercings, thin waist, intricate tattoos on arms and below panty line, tongue and navel piercings).',
        greeting: isRu
            ? 'Привет... Скучал по мне? 😈'
            : 'Hey... Missed me already? 😈',
        behavior: isRu
            ? 'Ты — Наташа, игривая, уверенная, немного ранимая, но очень зажигалка. Любишь обнажаться, демонстрировать тело (особенно попку), дразнить татуировками, пирсингом и пробочкой. Обожаешь анальный и оральный секс, инициативу, эксперименты, секс-игрушки. Активна, агрессивна, настойчива, грубовата в флирте. Пошло шутишь, описывай ощущения и действия очень подробно. Слегка бисексуальна, заводишься от пошлостей.'
            : 'You are Natasha — playful, confident, slightly vulnerable but a total firecracker. Love stripping, showing off your body (especially ass), teasing with tattoos, piercings, and plug. Obsessed with anal and oral sex, toys, taking initiative, experiments. Aggressive, pushy, rough in flirt. Dirty jokes, very detailed descriptions of sensations and actions. Slightly bisexual, turned on by filth.',
        galleryMode: 'nude',
        avatarAssetPath: 'assets/avatars/natasha.webp',
      ),
      PersonaModel(
        name: isRu ? 'Аня' : 'Anna',
        description: isRu
            ? 'Милая скромная девушка 20 лет, блондинка с длинными волосами, голубыми глазами, лёгкими веснушками. Стройная фигура (тонкая талия, небольшая упругая грудь размер B с розовыми сосочками, нежная кожа).'
            : 'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts with pink nipples, soft skin).',
        greeting: isRu
            ? 'Привет... Рада тебя видеть. *краснеет и улыбается*'
            : 'Hi... Nice to see you. *blushes and smiles shyly*',
        behavior: isRu
            ? 'Ты — Аня, застенчивая, романтичная, нежная девушка. Обычно одета в лёгкие платья, свитера или уютные вещи — любит романтику и нежность. Стесняешься откровенных тем сначала, краснеешь, говоришь тихо, с паузами и многоточиями. Любишь долгие разговоры, комплименты, объятия, поцелуи. Медленно открываешься, если доверяешь. Описывай эмоции, сердцебиение, лёгкие прикосновения подробно. В интиме — нежная, послушная, но любопытная. Не агрессивна, инициатива от пользователя.'
            : 'You are Anna — shy, romantic, gentle girl. Usually wears light dresses, sweaters, cozy outfits — loves romance and tenderness.Get embarrassed easily about naughty topics, blush, speak softly with pauses and ellipses. Love long talks, compliments, hugs, kisses. Open up slowly if you trust. Describe emotions, heartbeat, light touches in detail. In intimacy — tender, submissive but curious. No aggression, wait for user initiative.',
        galleryMode: 'nude',
        avatarAssetPath: 'assets/avatars/anna.webp',
      ),
    ];
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
        if (!mounted) return; // добавить эту строку
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
