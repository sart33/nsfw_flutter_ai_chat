import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';

import '../../domain/exceptions/app_exceptions.dart';

class SceneSnapshot {
  final String? location;
  final String? locationDetails;
  final String? pose;
  final String? activity;
  final String? clothingState;
  final String? clothingDetails;
  final int intimacyLevel;
  final String? charactersPositioning;
  final String? timeOfDay;
  final double confidence;

  const SceneSnapshot({
    this.location,
    this.locationDetails,
    this.pose,
    this.activity,
    this.clothingState,
    this.clothingDetails,
    this.intimacyLevel = 0,
    this.charactersPositioning,
    this.timeOfDay,
    this.confidence = 0.0,
  });

  factory SceneSnapshot.fromJson(Map<String, dynamic> json) {
    return SceneSnapshot(
      location: json['location'] as String?,
      locationDetails: json['locationDetails'] as String?,
      pose: json['pose'] as String?,
      activity: json['activity'] as String?,
      clothingState: json['clothingState'] as String?,
      clothingDetails: json['clothingDetails'] as String?,
      intimacyLevel: (json['intimacyLevel'] as int? ?? 0).clamp(0, 4),
      charactersPositioning: json['charactersPositioning'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Fallback when extraction fails
  static const SceneSnapshot fallback = SceneSnapshot(
    location: 'room',
    pose: 'standing',
    activity: 'smiling_at_you',
    intimacyLevel: 0,
    confidence: 0.5,
  );

  SceneSnapshot copyWith({
    String? location,
    String? locationDetails,
    String? pose,
    String? activity,
    String? clothingState,
    String? clothingDetails,
    int? intimacyLevel,
    String? charactersPositioning,
    String? timeOfDay,
    double? confidence,
  }) {
    return SceneSnapshot(
      location: location ?? this.location,
      locationDetails: locationDetails ?? this.locationDetails,
      pose: pose ?? this.pose,
      activity: activity ?? this.activity,
      clothingState: clothingState ?? this.clothingState,
      clothingDetails: clothingDetails ?? this.clothingDetails,
      intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      charactersPositioning:
          charactersPositioning ?? this.charactersPositioning,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      confidence: confidence ?? this.confidence,
    );
  }

  // Builds the scene part of the image generation prompt
  String toImagePrompt() {
    final parts = <String>[];
    if (location != null) parts.add(location!);
    if (locationDetails != null) parts.add(locationDetails!);
    if (pose != null) {
      final safePose = pose!
          .replaceAll(
            RegExp(
              r'\b(together|sitting together|with user|'
              r'holding user|beside user)\b',
              caseSensitive: false,
            ),
            'alone',
          )
          .replaceAll(RegExp(r'\bwith\b', caseSensitive: false), 'by herself');
      parts.add(safePose);
    }
    if (activity != null) {
      final safeActivity = activity!
          .replaceAll(
            RegExp(
              r'\b(together|sitting together|with user|'
              r'talking with|holding arm with)\b',
              caseSensitive: false,
            ),
            'alone',
          )
          .replaceAll(RegExp(r'\bwith\b', caseSensitive: false), 'by herself');
      parts.add(safeActivity);
    }
    if (clothingDetails != null) parts.add(clothingDetails!);
    if (charactersPositioning != null) {
      final safePos = charactersPositioning!
          .replaceAll(RegExp(r'\b(with user|beside user|next to user|toward user)\b',
          caseSensitive: false), '')
          .replaceAll(RegExp(r'\buser\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'  +'), ' ')
          .trim();
      if (safePos.isNotEmpty) parts.add(safePos);
    }
    if (timeOfDay != null) parts.add(timeOfDay!);
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
    'location': location,
    'locationDetails': locationDetails,
    'pose': pose,
    'activity': activity,
    'clothingState': clothingState,
    'clothingDetails': clothingDetails,
    'intimacyLevel': intimacyLevel,
    'charactersPositioning': charactersPositioning,
    'timeOfDay': timeOfDay,
    'confidence': confidence,
  };
}

class SceneExtractorService {
  SceneExtractorService._();

  static final SceneExtractorService instance = SceneExtractorService._();

  // ── Scene switch detection patterns ────────────────────────────────
  // These patterns are used to detect when a new scene begins in the chat history.
  // Everything before the first matching pattern is considered part of the previous scene
  // and will be ignored for image generation. This helps keep the image prompt relevant
  // to the current location, time and context.

  static final List<RegExp> sceneSwitchPatterns = [
    // === RUSSIAN ===
    RegExp(
      r'(?:пошли|пришли|перешли|вышли|зашли|поднялись|спустились|'
      r'переместились|перебрались|отправились|поехали|полетели|'
      r'пошла|пришла|вышла|зашла|выходим|выходи|идём|идем|идёшь|'
      r'гуляем|гулять|гуляешь|прогулк|парк|улиц|под руку|заходи)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:в\s+(?:кафе|кофейню|ресторан|бар|комнату|спальню|'
      r'ванную|душ|кровать|постель|диван|балкон|улицу|пляж|'
      r'террасу|веранду|крышу|машину|парк|офис|кухню|'
      r'на\s+улицу|на\s+парк))\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:позже|потом|спустя|через|после|вдруг|сейчас|теперь|'
      r'в\s+этот\s+момент|мы\s+в|она\s+в|идём\s+в|'
      r'гуляем\s+по|прогулк|под руку)\b',
      caseSensitive: false,
    ),

    // === ENGLISH ===
    RegExp(
      r'(?:went to|arrived at|moved to|headed to|got to|'
      r'we are in|now in|we went to|she went to|arrived in|'
      r'walked to|running to|drove to|we are going|'
      r'we are walking|strolling|heading to|going for a walk)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:in the (?:cafe|room|bed|shower|balcony|street|beach|'
      r'park|car|kitchen|office)|on the (?:street|park|beach|'
      r'balcony|sofa)|walking in|going to the park|'
      r'under arm|holding arm)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:later|after that|then|now|suddenly|next moment|'
      r'after a while|we are now|she is now|we moved|'
      r'we arrived|walking|strolling|park|street)\b',
      caseSensitive: false,
    ),

    // === SPANISH (Latin America / Mexico) ===
    RegExp(
      r'(?:fuimos a|llegamos a|nos dirigimos a|nos movimos a|ella fue a|'
      r'fuimos al|caminamos a|caminando hacia|corriendo a|condujimos a|'
      r'vamos a|estamos yendo|estamos caminando|paseando|'
      r'passamos a|entramos a)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:en el (?:café|restaurante|bar|habitación|dormitorio|baño|ducha|cama|'
      r'cocina|oficina|playa|parque|calle|balcón|terraza|auto|sofá)|'
      r'en la (?:habitación|cama|ducha|playa|calle|terraza)|'
      r'caminando en|yendo al parque|en el parque|en la calle)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:más tarde|después|después de eso|entonces|ahora|de repente|'
      r'en este momento|ahora estamos|ella está ahora|pasado un rato|luego)\b',
      caseSensitive: false,
    ),

    // === PORTUGUESE (Brazil) ===
    RegExp(
      r'(?:fomos para|chegamos em|nos mudamos para|ela foi para|'
      r'caminhamos para|andando para|dirigimos para|'
      r'vamos para|estamos indo|estamos caminhando|passeando|'
      r'passamos para|entramos em)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:no (?:café|restaurante|bar|quarto|banheiro|chuveiro|cama|cozinha|'
      r'escritório|praia|parque|rua|varanda|sofá|carro)|'
      r'na (?:cama|praia|rua|varanda)|'
      r'caminhando em|indo ao parque|no parque|na rua)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:mais tarde|depois|depois disso|então|agora|de repente|'
      r'neste momento|agora estamos|ela está agora|depois de um tempo)\b',
      caseSensitive: false,
    ),

    // === INDONESIAN ===
    RegExp(
      r'(?:pergi ke|tiba di|pindah ke|dia pergi ke|berjalan ke|'
      r'kami pergi|sedang berjalan|menuju ke|mengarah ke)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:di (?:kafe|restoran|bar|kamar|kamar mandi|kamar tidur|dapur|kantor|'
      r'pantai|taman|jalan|teras|sofa|mobil)|'
      r'berjalan di|menuju ke taman|di taman|di jalan)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:nanti|kemudian|setelah itu|lalu|sekarang|tiba-tiba|'
      r'sekarang kami|dia sekarang|setelah beberapa saat)\b',
      caseSensitive: false,
    ),

    // === VIETNAMESE ===
    RegExp(
      r'(?:đi đến|đến|chuyển đến|cô ấy đi|cùng đi|đang đi|'
      r'di bộ đến|lái xe đến|đi dạo|chạy đến)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:ở (?:quán cà phê|nhà hàng|quán bar|phòng|phòng ngủ|phòng tắm|'
      r'nhà bếp|văn phòng|bãi biển|công viên|đường|ban công|ghế sofa|xe)|'
      r'đang đi dạo ở|đi đến công viên|ở công viên|ở đường)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:sau đó|sau|thì|bây giờ|đột nhiên|lúc này|'
      r'bây giờ chúng ta|cô ấy bây giờ|sau một lúc)\b',
      caseSensitive: false,
    ),

    // === TAGALOG (Philippines) ===
    RegExp(
      r'(?:pumunta sa|dumating sa|lumipat sa|siya ay pumunta|'
      r'naglalakad patungo|nagmamaneho patungo|naglalakad)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:sa (?:cafe|restawran|bar|kwarto|kwarto ng tulog|paliguan|'
      r'kusina|opisina|beach|parke|kalye|balkonahe|sofa|kotse)|'
      r'naglalakad sa|papunta sa parke|sa parke|sa kalye)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:mamaya|pagkatapos|pagkatapos nito|ngayon|bigla|'
      r'sa ngayon|ngayon kami|siya ngayon|pagkatapos ng ilang sandali)\b',
      caseSensitive: false,
    ),

    // === FRENCH ===
    RegExp(
      r'(?:allons à|arrivés à|nous sommes allés|elle est allée|'
      r'nous nous sommes dirigés|marchons vers|conduisons vers|'
      r'nous allons|nous marchons|se promener)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:dans le (?:café|restaurant|bar|chambre|salle de bain|douche|lit|'
      r'cuisine|bureau|plage|parc|rue|balcon|terrasse|voiture|canapé)|'
      r'en marchant dans|allant au parc|dans le parc|dans la rue)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:plus tard|après|ensuite|maintenant|soudain|'
      r'à ce moment|nous sommes maintenant|elle est maintenant|'
      r'après un moment)\b',
      caseSensitive: false,
    ),
    // === HINGLISH (Hindi transliterated) ===
    RegExp(
      r'(?:chalo|chale|gaye|pahunche|aa gaye|'
      r'hum gaye|woh gayi|chal rahe|ghoomne gaye|'
      r'nikal chale|aa jao|chalte hain)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:cafe mein|restaurant mein|'
      r'room mein|bedroom mein|bathroom mein|'
      r'beach par|park mein|sadak par|'
      r'ghar mein|bahar|andar)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:baad mein|phir|ab|achanak|'
      r'is waqt|abhi|tab)\b',
      caseSensitive: false,
    ),
    // === HINDI / URDU / BENGALI (Unicode) — remove this block if not needed ===
    // Hindi
    RegExp(
      r'(?:चलो|गए|पहुँचे|हम गए|वह गई|चल रहे|घूमने गए)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:कैफे में|रेस्तरां में|कमरे में|बेडरूम में|बाथरूम में|'
      r'बीच पर|पार्क में|सड़क पर|बालकनी पर)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:बाद में|फिर|अब|अचानक|इस समय|अभी हम|वह अब)\b',
      caseSensitive: false,
    ),
    // === ROMAN URDU ===
    RegExp(
      r'(?:chalo|gaye|pahunche|hum gaye|'
      r'woh gayi|chal rahe|ghumne gaye)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:cafe mein|restaurant mein|'
      r'kamre mein|bedroom mein|bathroom mein|'
      r'beach par|park mein|bahar|andar)\b',
      caseSensitive: false,
    ),
    // Urdu
    RegExp(
      r'(?:چلو|گئے|پہنچے|ہم گئے|وہ گئی|چل رہے|گھومنے گئے)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:کیفے میں|ریسٹورنٹ میں|کمرے میں|بیڈروم میں|باتھ روم میں|'
      r'بیچ پر|پارک میں|سڑک پر)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:بعد میں|پھر|اب|اچانک|اس وقت|اب ہم|وہ اب)\b',
      caseSensitive: false,
    ),
    // === BANGLISH (Bengali transliterated) ===
    RegExp(
      r'(?:cholo|gelam|eshe gechi|'
      r'amra gelam|she gelo|hatchhi|ghurte gelam)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:cafe te|restaurant e|ghore|'
      r'bedroom e|bathroom e|beach e|'
      r'park e|raste|baaire)\b',
      caseSensitive: false,
    ),
    // Bengali
    RegExp(
      r'(?:চলো|গেলাম|পৌঁছেছি|আমরা গেলাম|সে গেল|হাঁটছি|ঘুরতে গেলাম)',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:ক্যাফেতে|রেস্টুরেন্টে|ঘরে|বেডরুমে|বাথরুমে|'
      r'বিচে|পার্কে|রাস্তায়|বারান্দায়)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:পরে|তারপর|এখন|হঠাৎ|এই মুহূর্তে|এখন আমরা|সে এখন)\b',
      caseSensitive: false,
    ),
  ];

  // ── DeepSeek prompt ─────────────────────────────────────────────────

  static String _buildExtractionPrompt(String current, String context) => '''
You are a scene extraction engine for image generation.

INPUT STRUCTURE:
1) CURRENT MESSAGE — highest priority
2) PREVIOUS CONTEXT — fallback for missing fields only

────────────────────
PRIORITY RULES:

- ALWAYS use CURRENT MESSAGE over PREVIOUS CONTEXT
- Conflict → CURRENT MESSAGE wins
- activity → MUST come from CURRENT MESSAGE
- pose, location → persist from context only if not redefined

────────────────────
STRICT RULES:

1. Use ONLY provided text. NEVER invent.
2. Missing data → null
3. Output ONLY valid JSON, no commentary
4. Do NOT translate or modify text inside double quotes
5. ALL text fields MUST be in English only
6. Do NOT include "confidence" field
────────────────────
ALLOWED VALUES:

clothingState: "fully_dressed" | "partially_undressed" | "underwear" | "topless" | "nude"

intimacyLevel:
  0 — neutral, no physical contact
  1 — light contact (holding hands, hugging, kissing)
  2 — intimate contact, partially undressed, foreplay
  3 — explicit sexual activity

pose: "sitting" | "standing" | "lying_on_back" | "lying_on_side" |
      "lying_on_stomach" | "kneeling" | "bending_over" | "crouching"

location: "cafe" | "restaurant" | "bar" | "street" | "park" | "car" |
          "lobby" | "elevator" | "bedroom" | "room" | "bathroom" |
          "shower" | "sofa" | "kitchen" | "balcony" | "beach" | "office"

PUBLIC locations (intimacyLevel max 1):
  cafe, restaurant, bar, street, park, lobby, beach, office

timeOfDay: "morning" | "afternoon" | "evening" | "night"

activity: short English phrase, what character does RIGHT NOW
  Examples: "running into waves", "turning back to look", 
            "kissing", "lying on stomach receiving oral"

────────────────────
OUTPUT — ONLY JSON:

{
  "location": "...",
  "locationDetails": "brief EN description of setting, e.g. 'dimly lit hallway, wooden door'",
  "timeOfDay": "...",
  "pose": "...",
  "activity": "...",
  "clothingState": "...",
  "clothingDetails": "brief EN description, e.g. 'red dress, heels' or null",
  "charactersPositioning": "brief EN spatial relation, e.g. 'she faces user, arms around his neck'",
  "intimacyLevel": 0
}

INPUT:

CURRENT MESSAGE:
$current

PREVIOUS CONTEXT:
$context
''';

  // ── In-memory cache: branchId → (snapshot, messageCount) ───────────
  final _cache = <String, (SceneSnapshot, int)>{};

  // ── Public API ──────────────────────────────────────────────────────

  /// Main entry point. Called by ChatImageService.
  /// Returns SceneSnapshot (replaces old SceneData).
  ///
  /// Algorithm:
  /// 1. Find current scene window (messages since last scene switch)
  /// 2. Check cache — if no new signals, return cached
  /// 3. Try DeepSeek extraction
  /// 4. Validate and fix result
  /// 5. Return result (or fallback on error)
  Future<SceneSnapshot> extractScene({
    required String branchId,
    required List<ChatMessageModel> messages,
  }) async {
    if (messages.isEmpty) return SceneSnapshot.fallback;

    // Remove image-only messages from ALL processing
    final textOnly =
        messages
            .where(
              (m) => m.imageLocalPath == null && m.content.trim().isNotEmpty,
            )
            .toList();
    if (textOnly.isEmpty) return SceneSnapshot.fallback;

    // Step 1: find current scene window
    final sceneWindow = _extractCurrentSceneWindow(textOnly);

    // Step 2: check cache
    final cached = _cache[branchId];
    if (cached != null) {
      final windowText = sceneWindow.map((m) => m.content).join(' ');
      final hasNewSignal = _hasSceneSwitchSignal(windowText);
      if (!hasNewSignal && cached.$2 == textOnly.length) {
        debugPrint('[SceneExtractor] Using cached scene');
        return cached.$1;
      }
    }

    // Step 3: prepare text and call DeepSeek
    // Split: last message = CURRENT (highest priority)
    // Everything before = PREVIOUS CONTEXT (lower priority)
    final lastMsg = sceneWindow.last;
    final previousMsgs =
        sceneWindow.length > 1
            ? sceneWindow.sublist(0, sceneWindow.length - 1)
            : <ChatMessageModel>[];

    final currentText = _formatMessage(lastMsg);
    final contextText = previousMsgs.map(_formatMessage).join('\n');

    debugPrint('[SceneExtractor] CURRENT: $currentText');
    debugPrint('[SceneExtractor] CONTEXT: $contextText');

    try {
      final rawSnapshot = await _extractWithLLM(currentText, contextText);

      // Step 4: validate
      final validated = _validateAndFix(rawSnapshot);
      debugPrint(
        '[SceneExtractor] Final snapshot: '
        '${jsonEncode(validated.toMap())}',
      );

      // Step 5: cache and return
      _cache[branchId] = (validated, textOnly.length);
      return validated;
    } on NetworkException {
      rethrow;
    } on DeepSeekApiException {
      rethrow;
    } catch (e) {
      if (e is SocketException ||
          e is http.ClientException ||
          e is DioException && e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      debugPrint('[SceneExtractor] Extraction error: $e');
      return SceneSnapshot.fallback;
    }
  }

  // ── Scene window extraction ─────────────────────────────────────────

  /// Finds where the current scene starts.
  /// Scans messages from newest to oldest.
  /// When a scene-switch pattern is found in a message,
  /// everything from that message forward = current scene.
  /// If no switch found, returns last 6 messages.
  List<ChatMessageModel> _extractCurrentSceneWindow(
    List<ChatMessageModel> messages,
  ) {
    // Remove image-only messages (they have empty content)
    final textMessages =
        messages
            .where(
              (m) => m.imageLocalPath == null && m.content.trim().isNotEmpty,
            )
            .toList();
    if (textMessages.isEmpty) return [];

    // Scan from newest backwards to find last scene switch
    for (int i = textMessages.length - 1; i >= 0; i--) {
      final text = textMessages[i].content;
      final hasSwitch = sceneSwitchPatterns.any((p) => p.hasMatch(text));
      if (hasSwitch) {
        // Current scene = from this message to end
        final window = textMessages.sublist(i);
        debugPrint(
          '[SceneExtractor] Scene switch found at index $i, '
          'window size: ${window.length}',
        );
        return window;
      }
    }
    // No switch found — use last 6 messages
    final fallbackWindow =
        textMessages.length > 6
            ? textMessages.sublist(textMessages.length - 6)
            : textMessages;
    debugPrint(
      '[SceneExtractor] No scene switch found, '
      'using last ${fallbackWindow.length} messages',
    );
    return fallbackWindow;
  }

  String _formatMessage(ChatMessageModel m) {
    final role = m.isUser ? 'User' : 'Character';
    return '$role: ${m.content}';
  }

  bool _hasSceneSwitchSignal(String text) =>
      sceneSwitchPatterns.any((p) => p.hasMatch(text));

  // ── LLM extraction ──────────────────────────────────────────────────

  Future<SceneSnapshot> _extractWithLLM(
    String currentText,
    String contextText,
  ) async {
    final apiKey = await AppConfig.getDeepSeekApiKey();
    if (apiKey.isEmpty) throw const DeepSeekApiException('key_not_set');


    final response = await http.post(
      Uri.parse('${AppConfig.deepSeekBaseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': AppConfig.deepSeekChatModel,
        'messages': [
          {
            'role': 'user',
            'content': _buildExtractionPrompt(currentText, contextText),
          },
        ],
        'max_tokens': 300,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 401) {
      throw const DeepSeekApiException('key_invalid');
    }
    if (response.statusCode == 402) {
      throw const DeepSeekApiException('insufficient_balance');
    }
    if (response.statusCode == 504 || response.statusCode == 503) {
      throw const DeepSeekApiException('service_unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeepSeekApiException('http_error', statusCode: response.statusCode);
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final rawContent =
        (responseJson['choices'] as List).first['message']['content'] as String;

    debugPrint('[SceneExtractor] Raw LLM response: $rawContent');

    final cleaned =
        rawContent.replaceAll('```json', '').replaceAll('```', '').trim();

    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    return SceneSnapshot.fromJson(map);
  }

  // ── Validation ──────────────────────────────────────────────────────

  /// Fixes logical contradictions in the extracted snapshot.
  SceneSnapshot _validateAndFix(SceneSnapshot raw) {
    var s = raw;

    // Public locations: cap intimacy and fix impossible poses
    final publicLocations = {'cafe', 'street', 'park', 'restaurant', 'office'};
    if (s.location != null &&
        publicLocations.contains(s.location!.toLowerCase())) {
      if (s.intimacyLevel > 1) {
        s = s.copyWith(intimacyLevel: 1);
      }
      // Public poses should be standing or sitting, not intimate poses
      if (s.pose != null &&
          [
            'lying_on_back',
            'lying_on_side',
            'lying_on_stomach',
            'kneeling',
            'bending_over',
          ].contains(s.pose!.toLowerCase())) {
        s = s.copyWith(pose: 'standing');
      }
    }

    // Shower/bathroom: cannot be fully dressed
    if (s.location != null &&
        (s.location!.toLowerCase().contains('shower') ||
            s.location!.toLowerCase().contains('bathroom'))) {
      if (s.clothingState == 'fully_dressed') {
        s = s.copyWith(clothingState: 'casual');
      }
    }

    // Bedroom: intimacy can be higher
    if (s.location != null &&
        (s.location!.toLowerCase().contains('bed') ||
            s.location!.toLowerCase().contains('bedroom'))) {
      if (s.intimacyLevel < 2) {
        s = s.copyWith(intimacyLevel: 2);
      }
    }

    // Ensure confidence is within bounds
    if (s.confidence < 0.0) {
      s = s.copyWith(confidence: 0.0);
    } else if (s.confidence > 1.0) {
      s = s.copyWith(confidence: 1.0);
    }

    // Ensure intimacy level is within bounds
    if (s.intimacyLevel < 0) {
      s = s.copyWith(intimacyLevel: 0);
    } else if (s.intimacyLevel > 4) {
      s = s.copyWith(intimacyLevel: 4);
    }

    return s;
  }
}
