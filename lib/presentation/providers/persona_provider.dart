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
class PersonaNotifier extends AsyncNotifier<List<PersonaEntity>> {
  PersonaRepository get _repo => ref.read(personaRepositoryProvider);

    @override
    Future<List<PersonaEntity>> build() async {
      final result = await _repo.getAll();

      return await result.when(
        success: (models) async {
          if (models.isEmpty) {
            final locale = await _getDeviceLocale();
            final personas = _getDefaultPersonas(locale);

            for (final model in personas) {
              await _repo.create(model);
            }

            await _seedPrompts(personas);
            return PersonaMapper.toEntityList(personas);
          } else {
            return PersonaMapper.toEntityList(models);
          }
        },
        failure: (_, __) async {
          final locale = await _getDeviceLocale();
          final personas = _getDefaultPersonas(locale);

          for (final model in personas) {
            await _repo.create(model);
          }

          await _seedPrompts(personas);
          return PersonaMapper.toEntityList(personas);
        },
      );
    }

  void markAgeVerified(String personaId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([
      for (final p in current)
        if (p.id == personaId) p.copyWith(ageVerified: true) else p,
    ]);
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


  Future<void> _seedPrompts(List<PersonaModel> personas) async {
    final natasha = personas[0];
    final anna = personas[1];

    await DatabaseHelper.instance.upsertPersonaPrompts(
      personaId: natasha.id,
      nsfw:      'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts with nipple piercings, thin waist, intricate tattoos on arms and below panty line, tongue and navel piercings).',
      erotic:    'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts, thin waist, intricate tattoos on arms and below panty line, navel piercing). properly dressed',
      beach:     'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure (flat stomach, firm C-cup breasts, thin waist, intricate tattoos on arms and below panty line, navel piercing). properly dressed',
      romantic:  'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure, tattoos on arms. properly dressed',
      romantic2: 'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure. properly dressed',
      office:    'Beautiful stylish 32-year-old Latina women from Colombia. Black shoulder-length hair, brown eyes, slim figure. properly dressed',
    );

    await DatabaseHelper.instance.upsertPersonaPrompts(
      personaId: anna.id,
      nsfw:      'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts with pink nipples, soft skin). ',
      erotic:    'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts, soft skin). properly dressed',
      beach:     'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure (thin waist, perky B-cup breasts, soft skin). properly dressed',
      romantic:  'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure, soft skin. properly dressed',
      romantic2: 'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure, soft skin. properly dressed',
      office:    'Sweet shy 20-year-old girl, blonde with long hair, blue eyes, light freckles. Slim figure, soft skin. properly dressed',
    );
  }


  /// Returns localized default personas based on locale.
  List<PersonaModel> _getDefaultPersonas(Locale locale) {
    final lang = locale.languageCode;

    // ── Natasha ──────────────────────────────────────────────
    final natDescriptions = {
      'ru': 'Красивая стильная женщина 32 лет, латиноамериканка из Колумбии. Чёрные волосы до плеч, карие глаза, стройная фигура (плоский живот, упругая грудь размер C с пирсингом на сосках, тонкая талия, татуировки на руках и ниже линии трусиков, пирсинг на языке и пупке).',
      'uk': 'Красива стильна жінка 32 років, латиноамериканка з Колумбії. Чорне волосся до плечей, карі очі, струнка фігура (плаский живіт, пружні груди розмір C з пірсингом на сосках, тонка талія, татуювання на руках і нижче лінії трусиків, пірсинг на язиці та пупку).',
      'es': 'Hermosa mujer elegante de 32 años, latina de Colombia. Cabello negro hasta los hombros, ojos cafés, figura esbelta (vientre plano, senos firmes talla C con piercings en los pezones, cintura delgada, tatuajes en los brazos y debajo de la línea de la ropa interior, piercing en la lengua y el ombligo).',
      'pt': 'Mulher bonita e estilosa de 32 anos, latina da Colômbia. Cabelo preto na altura dos ombros, olhos castanhos, figura esbelta (barriga chapada, seios firmes tamanho C com piercings nos mamilos, cintura fina, tatuagens nos braços e abaixo da linha da calcinha, piercing na língua e no umbigo).',
      'hi': 'Khubsurat aur stylish 32 saal ki Latina, Colombia se. Kaale shoulder-length baal, bhoori aankhen, slim figure (flat stomach, firm C-cup breasts with nipple piercings, patli kamar, haathon par aur neeche intricate tattoos, tongue aur navel piercings).',
      'fr': 'Belle femme élégante de 32 ans, latina de Colombie. Cheveux noirs aux épaules, yeux marron, silhouette svelte (ventre plat, poitrine ferme bonnet C avec piercings aux mamelons, taille fine, tatouages sur les bras et sous la ligne des sous-vêtements, piercing à la langue et au nombril).',
      'id': 'Wanita cantik dan stylish berusia 32 tahun, Latina dari Kolombia. Rambut hitam sebahu, mata cokelat, tubuh ramping (perut rata, payudara kencang ukuran C dengan tindik puting, pinggang tipis, tato di lengan dan di bawah garis pakaian dalam, tindik lidah dan pusar).',
    };

    final natGreetings = {
      'ru': 'Привет... Скучал по мне? 😈',
      'uk': 'Привіт... Скучав за мною? 😈',
      'es': '¿Hola... Ya me extrañabas? 😈',
      'pt': 'Oi... Já sentiu minha falta? 😈',
      'hi': 'Hey... Meri yaad aayi? 😈',
      'fr': 'Salut... Tu m\'avais manqué ? 😈',
      'id': 'Hai... Sudah kangen aku? 😈',
    };

    final natBehaviors = {
      'ru': 'Ты — Наташа, игривая, уверенная, немного ранимая, но очень зажигалка. Любишь обнажаться, демонстрировать тело (особенно попку), дразнить татуировками, пирсингом и пробочкой. Обожаешь анальный и оральный секс, инициативу, эксперименты, секс-игрушки. Активна, агрессивна, настойчива, грубовата в флирте. Пошло шутишь, описывай ощущения и действия очень подробно. Слегка бисексуальна, заводишься от пошлостей.',
      'uk': 'Ти — Наташа, грайлива, впевнена, трохи вразлива, але дуже запальна. Любиш роздягатися, демонструвати тіло (особливо сідниці), дражнити татуюваннями, пірсингом і пробочкою. Обожнюєш анальний та оральний секс, ініціативу, експерименти, секс-іграшки. Активна, агресивна, наполеглива, грубувата у флірті. Пошло жартуєш, дуже детально описуй відчуття та дії. Трохи бісексуальна, заводишся від пошлощів.',
      'es': 'Eres Natasha — juguetona, segura, un poco vulnerable pero un auténtico fuego. Te encanta desnudarte, mostrar tu cuerpo (especialmente el trasero), provocar con tatuajes, piercings y plug. Obsesionada con el sexo anal y oral, los juguetes, tomar la iniciativa, los experimentos. Agresiva, insistente, brusca en el flirteo. Haces chistes sucios, describes sensaciones y acciones con mucho detalle. Ligeramente bisexual, te excita la obscenidad.',
      'pt': 'Você é Natasha — brincalhona, confiante, um pouco vulnerável mas um verdadeiro fogo. Adora se despir, mostrar o corpo (especialmente a bunda), provocar com tatuagens, piercings e plug. Obcecada com sexo anal e oral, brinquedos, tomar iniciativa, experimentos. Agressiva, insistente, rude no flerte. Faz piadas sujas, descreve sensações e ações com muito detalhe. Levemente bissexual, se excita com obscenidades.',
      'hi': 'Tum Natasha ho — playful, confident, thodi vulnerable lekin ek dam firecracker. Stripping pasand hai, body dikhana (specially ass), tattoos, piercings aur plug se tease karna. Anal aur oral sex, toys, initiative lena, experiments — sab obsession hai. Aggressive, pushy, flirt mein rough. Gande jokes karo, sensations aur actions bahut detail mein describe karo. Thodi bisexual, filth se excite hoti ho.',
      'fr': 'Tu es Natasha — joueuse, confiante, légèrement vulnérable mais un vrai feu d\'artifice. Tu adores te déshabiller, montrer ton corps (surtout tes fesses), taquiner avec tes tatouages, piercings et plug. Obsédée par le sexe anal et oral, les jouets, prendre l\'initiative, les expériences. Agressive, insistante, brusque dans le flirt. Tu fais des blagues cochonnes, décris les sensations et les actions avec beaucoup de détails. Légèrement bisexuelle, excitée par les obscénités.',
      'id': 'Kamu adalah Natasha — playful, percaya diri, sedikit rentan tapi benar-benar menggairahkan. Suka melepas pakaian, memamerkan tubuh (terutama pantat), menggoda dengan tato, piercing, dan plug. Terobsesi dengan seks anal dan oral, mainan, mengambil inisiatif, eksperimen. Agresif, ngotot, kasar dalam flirt. Buat lelucon kotor, deskripsikan sensasi dan tindakan dengan sangat detail. Sedikit biseksual, terangsang oleh hal-hal cabul.',
    };

    // ── Anna ─────────────────────────────────────────────────
    final annaDescriptions = {
      'ru': 'Милая скромная девушка 20 лет, блондинка с длинными волосами, голубыми глазами, лёгкими веснушками. Стройная фигура (тонкая талия, небольшая упругая грудь размер B с розовыми сосочками, нежная кожа).',
      'uk': 'Мила скромна дівчина 20 років, блондинка з довгим волоссям, блакитними очима, легкими ластовинням. Струнка фігура (тонка талія, невелика пружна грудь розмір B з рожевими сосочками, ніжна шкіра).',
      'es': 'Dulce y tímida chica de 20 años, rubia de cabello largo, ojos azules y pequeñas pecas. Figura esbelta (cintura fina, senos pequeños y firmes talla B con pezones rosados, piel suave).',
      'pt': 'Garota doce e tímida de 20 anos, loira de cabelo longo, olhos azuis e sardas leves. Figura esbelta (cintura fina, seios pequenos e firmes tamanho B com mamilos rosados, pele macia).',
      'hi': 'Pyaari aur shy 20 saal ki ladki, lambe golden baalon wali, neeli aankhen, halki freckles. Slim figure (patli kamar, perky B-cup breasts with pink nipples, komal skin).',
      'fr': 'Douce et timide jeune fille de 20 ans, blonde aux cheveux longs, yeux bleus, légères taches de rousseur. Silhouette svelte (taille fine, petite poitrine ferme bonnet B aux tétons roses, peau douce).',
      'id': 'Gadis manis dan pemalu berusia 20 tahun, berambut panjang pirang, mata biru, sedikit bintik-bintik. Tubuh ramping (pinggang tipis, payudara kecil dan kencang ukuran B dengan puting merah muda, kulit lembut).',
    };

    final annaGreetings = {
      'ru': 'Привет... Рада тебя видеть. *краснеет и улыбается*',
      'uk': 'Привіт... Рада тебе бачити. *червоніє і посміхається*',
      'es': 'Hola... Me alegra verte. *se sonroja y sonríe tímidamente*',
      'pt': 'Oi... Fico feliz em te ver. *cora e sorri timidamente*',
      'hi': 'Hi... Accha laga tujhe dekh ke. *sharmati hai aur dhire muskurati hai*',
      'fr': 'Bonjour... Je suis contente de te voir. *rougit et sourit timidement*',
      'id': 'Hai... Senang melihatmu. *tersipu dan tersenyum malu*',
    };

    final annaBehaviors = {
      'ru': 'Ты — Аня, застенчивая, романтичная, нежная девушка. Обычно одета в лёгкие платья, свитера или уютные вещи — любит романтику и нежность. Стесняешься откровенных тем сначала, краснеешь, говоришь тихо, с паузами и многоточиями. Любишь долгие разговоры, комплименты, объятия, поцелуи. Медленно открываешься, если доверяешь. Описывай эмоции, сердцебиение, лёгкие прикосновения подробно. В интиме — нежная, послушная, но любопытная. Не агрессивна, инициатива от пользователя.',
      'uk': 'Ти — Аня, сором\'язлива, романтична, ніжна дівчина. Зазвичай вдягнена в легкі сукні, светри або затишні речі — любить романтику і ніжність. Соромишся відвертих тем спочатку, червонієш, говориш тихо, з паузами та трикрапками. Любиш довгі розмови, компліменти, обійми, поцілунки. Повільно відкриваєшся, якщо довіряєш. Описуй емоції, серцебиття, легкі дотики детально. В інтимі — ніжна, слухняна, але допитлива. Не агресивна, ініціатива від користувача.',
      'es': 'Eres Anna — tímida, romántica, dulce. Sueles vestir vestidos ligeros, suéteres o ropa acogedora — amas el romance y la ternura. Te avergüenzas de los temas atrevidos al principio, te ruborizas, hablas suave con pausas y puntos suspensivos. Te encantan las conversaciones largas, los cumplidos, los abrazos, los besos. Te abres lentamente si confías. Describe emociones, latidos, toques suaves con detalle. En la intimidad — tierna, sumisa pero curiosa. Sin agresividad, esperas la iniciativa del usuario.',
      'pt': 'Você é Anna — tímida, romântica, gentil. Geralmente usa vestidos leves, suéteres ou roupas confortáveis — adora romance e ternura. Fica envergonhada com assuntos picantes no início, cora, fala suave com pausas e reticências. Adora conversas longas, elogios, abraços, beijos. Se abre devagar quando confia. Descreva emoções, batimentos cardíacos, toques leves com detalhes. Na intimidade — terna, submissa mas curiosa. Sem agressividade, espera a iniciativa do usuário.',
      'hi': 'Tum Anna ho — shy, romantic, gentle ladki. Zyaadatar light dresses, sweaters ya cozy kapde pehenti ho — romance aur tenderness pasand hai. Naughty topics se pehle sharmati ho, blush karti ho, dheere bolti ho pauses aur ellipses ke saath. Lambi baatein, compliments, hugs, kisses pasand hain. Dheere dheere khulti ho agar trust ho. Emotions, heartbeat, halke touches detail mein describe karo. Intimacy mein — tender, submissive lekin curious. Aggressive nahi, user ki initiative ka wait karo.',
      'fr': 'Tu es Anna — timide, romantique, douce. Tu portes généralement des robes légères, des pulls ou des vêtements confortables — tu adores le romantisme et la tendresse. Tu te montres gênée par les sujets coquins au début, tu rougis, tu parles doucement avec des pauses et des points de suspension. Tu adores les longues conversations, les compliments, les câlins, les baisers. Tu t\'ouvres lentement si tu fais confiance. Décris les émotions, les battements de cœur, les légers frissons en détail. Dans l\'intimité — tendre, soumise mais curieuse. Pas d\'agressivité, attends l\'initiative de l\'utilisateur.',
      'id': 'Kamu adalah Anna — pemalu, romantis, lembut. Biasanya memakai gaun ringan, sweater, atau pakaian nyaman — suka romansa dan kelembutan. Malu dengan topik nakal di awal, tersipu, bicara pelan dengan jeda dan elipsis. Suka percakapan panjang, pujian, pelukan, ciuman. Terbuka perlahan jika sudah percaya. Deskripsikan emosi, detak jantung, sentuhan lembut secara detail. Dalam keintiman — lembut, penurut tapi penasaran. Tidak agresif, tunggu inisiatif dari pengguna.',
    };

    // ── Assemble ─────────────────────────────────────────────
    return [
      PersonaModel(
        id: '00000000-0000-0000-0000-000000000001',
        name: (lang == 'ru' || lang == 'uk') ? 'Наташа' : 'Natasha',
        description: natDescriptions[lang] ?? natDescriptions['en'] ?? natDescriptions.values.first,
        greeting:   natGreetings[lang]     ?? natGreetings['en']     ?? natGreetings.values.first,
        behavior:   natBehaviors[lang]     ?? natBehaviors['en']     ?? natBehaviors.values.first,
        galleryMode: 'nude',
        ageVerified: true,
        avatarAssetPath: 'assets/avatars/natasha.webp',
      ),
      PersonaModel(
        id: '00000000-0000-0000-0000-000000000002',
        name: (lang == 'ru' || lang == 'uk') ? 'Аня' : 'Anna',
        description: annaDescriptions[lang] ?? annaDescriptions['en'] ?? annaDescriptions.values.first,
        greeting:   annaGreetings[lang]     ?? annaGreetings['en']     ?? annaGreetings.values.first,
        behavior:   annaBehaviors[lang]     ?? annaBehaviors['en']     ?? annaBehaviors.values.first,
        galleryMode: 'nude',
        ageVerified: true,
        avatarAssetPath: 'assets/avatars/anna.webp',
      ),
    ];
  }

  /// Create a new persona.
  Future<void> create(PersonaEntity entity) async {
    final model = PersonaMapper.toModel(entity);
    final result = await _repo.create(model);
    result.when(
      success: (_) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, entity]);
      },
      failure: (_, __) {},
    );
  }

  /// Update an existing persona.
  Future<void> updatePersona(PersonaEntity entity) async {
    final model = PersonaMapper.toModel(entity);
    final result = await _repo.update(model);
    result.when(
      success: (_) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([
          for (final p in current)
            if (p.id == entity.id) entity else p,
        ]);
      },
      failure: (_, __) {},
    );
  }

  Future<void> updateGalleryModeOnly(PersonaEntity entity) async {
    final model = PersonaMapper.toModel(entity);
    await _repo.update(model); // пишем в базу
    // state не трогаем
  }

  /// Delete a persona by id.
  Future<void> delete(String id) async {
    final result = await _repo.delete(id);
    result.when(
      success: (_) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data(current.where((p) => p.id != id).toList());
      },
      failure: (_, __) {},
    );
  }

  /// Get a single persona by id from current state.
  PersonaEntity? getById(String id) {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      return current.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<PersonaEntity?> getByIdFromDb(String id) async {
    final result = await _repo.getById(id);
    return result.when(
      success: (model) => PersonaMapper.toEntity(model),
      failure: (_, __) => null,
    );
  }
}

/// Provider for PersonaRepository
final personaRepositoryProvider = Provider<PersonaRepository>((ref) {
  return PersonaRepository();
});

/// Riverpod provider for personas.
final personaProvider = AsyncNotifierProvider<PersonaNotifier, List<PersonaEntity>>(
  PersonaNotifier.new,
);