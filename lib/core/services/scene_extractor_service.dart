import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../config/scene_switch_patterns.dart';

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

  int get selectLevel {
    if (clothingState?.toLowerCase() == 'nude') {
      return 3;
    }
    //if (intimacyLevel >= 3) return 2;
    final cl = (clothingState ?? '').toLowerCase();
    if (cl.contains('lingerie') ||
        cl.contains('bikini') ||
        cl.contains('swimsuit')) {
      return 2;
    }
    return intimacyLevel.clamp(0, 1);
  }

  // Builds the scene part of the image generation prompt
  String toImagePrompt() {
    final parts = <String>[];
    if (location != null) parts.add(location!);
    if (locationDetails != null) parts.add(locationDetails!);

    if (pose != null) {
      var s = pose!;
      s = s.replaceAll(
        RegExp(r'\b(passionate\s+)?kissing\b', caseSensitive: false),
        'blowing a kiss',
      );
      s = s.replaceAll(
          RegExp(r'\b(together|sitting together|with user|holding user|beside user)\b',
              caseSensitive: false), 'alone');
      s = s.replaceAll(RegExp(r'\bwith\b', caseSensitive: false), 'by herself');
      parts.add(s);
    }

    if (activity != null) {
      var s = activity!;
      s = s.replaceAll(
        RegExp(r'\b(passionate\s+)?kissing\b', caseSensitive: false),
        'blowing a kiss',
      );
      s = s.replaceAll(
          RegExp(r'\b(together|sitting together|with user|talking with|holding arm with)\b',
              caseSensitive: false), 'alone');
      s = s.replaceAll(RegExp(r'\bwith\b', caseSensitive: false), 'by herself');
      parts.add(s);
    }

    if (clothingDetails != null) parts.add(clothingDetails!);

    if (clothingState?.toLowerCase() == 'nude') {
      parts.add('nude, naked');
    }

    if (charactersPositioning != null) {
      var pos = charactersPositioning!;
      if (pose?.toLowerCase() == 'standing') {
        pos = _cleanStandingContext(pos);
      }
      final cleaned = _cleanPositioning(pos);
      if (cleaned.isNotEmpty) parts.add(cleaned);
    }

    if (timeOfDay != null) parts.add(timeOfDay!);
    return parts.join(', ');
  }

  static String _cleanStandingContext(String raw) {
    var s = raw;

    // Близость к user — вырезать клаузу
    s = s.replaceAll(
      RegExp(
        r'\b(very\s+close\s+to|close\s+to|next\s+to|near)\s+(the\s+)?users?\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // Направляет/корректирует — вырезать клаузу
    s = s.replaceAll(
      RegExp(
        r'\b(guiding|correcting|adjusting|directing|coaching)\s+(his|her)\s+\w+\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    return s;
  }

  static String _cleanPositioning(String raw) {
    var s = raw;
    // Баг 1 — только для sitting
    if (raw.toLowerCase().contains('sitting')) {
      s = s.replaceAll(
        RegExp(
          r'\b(across\s+from|next\s+to|beside|opposite|in\s+front\s+of|'
          r'close\s+to|near|behind)\s+(the\s+)?users?\b',
          caseSensitive: false,
        ),
        '',
      );
    }
      // 1. Физконтакт с user/him — вся клауза
      s = s.replaceAll(
        RegExp(
          r'\b(holds?|grabs?|pulls?|pushes?|leads?|drags?|guides?|takes?|wraps?|climbs?|presses?|pins?)\s[^,]*\b(users?|him)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );

    // 2. holding his hand ... and → оставить что после
    s = s.replaceAll(
      RegExp(r'\bholding\s+his\s+hand\b[^,]*?\band\s+', caseSensitive: false),
      '',
    );

// 3. holding user hand ... and → оставить что после
    s = s.replaceAll(
      RegExp(r'\bholding\s+users?\s+hand\b[^,]*?\band\s+', caseSensitive: false),
      '',
    );

      // 4. hand in hand / holding hands
      s = s.replaceAll(
        RegExp(r'\b(holding hands?|hand in hand)\b', caseSensitive: false),
        '',
      );

    // 4b. side by side / arms brushing — физконтакт без явного user
    s = s.replaceAll(
      RegExp(r'\bside\s+by\s+side\b[^,]*', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r',?\s*\barms?\s+brushing\b[^,]*', caseSensitive: false),
      '',
    );

      // 5. Объятия с user/him — вся клауза
      s = s.replaceAll(
        RegExp(r'\b(hugs?|embraces?)\s[^,]*\b(users?|him)\b[^,]*',
            caseSensitive: false),
        '',
      );

    // 5b. while [кто-то] stands/sits/walks beside/next to her — придаточная клауза
    s = s.replaceAll(
      RegExp(
        r'\bwhile\s+(the\s+)?\w+\s+(stands?|sits?|walks?|kneels?)\s+(beside|next\s+to|behind|in\s+front\s+of)\s+her\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

      // 6. Поцелуй user/him — вся клауза
      s = s.replaceAll(
        RegExp(r'\bkisses?\s+(users?|him|his\s+\w+)\b[^,]*',
            caseSensitive: false),
        '',
      );

      // 7. jumps into user's/the user's arms — вся клауза
      s = s.replaceAll(
        RegExp(r'\bjumps?\s+into\s+(the\s+)?users?\s+\w+\b[^,]*',
            caseSensitive: false),
        '',
      );

      // 8. sits on user's/the user's lap — вся клауза
      s = s.replaceAll(
        RegExp(r'\bsits?\s+on\s+(the\s+)?users?\s+\w+\b[^,]*',
            caseSensitive: false),
        '',
      );
      s = s.replaceAll(RegExp(r"user's", caseSensitive: false), 'user');

      s = s.replaceAll(
        RegExp(r'\bwrapping\s+her\s+arms\s+around\s+his\s+\w+\b[^,]*',
            caseSensitive: false),
        '',
      );

    s = s.replaceAll(
        RegExp(r'\bwhispering\b[^,]*', caseSensitive: false),
      '',
    );

      // 9. Убираем user/him везде где остались
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'\bhim\b', caseSensitive: false), '');

      // 10. Танцевальный контекст — восстанавливаем партнёра
      // "dancing closely with the ," → "dancing closely with a partner,"
      s = s.replaceAll(
        RegExp(r'\b(dancing[\w\s]+with)\s+(the\s+)?,', caseSensitive: false),
        'dancing closely with a partner,',
      );
      s = s.replaceAll(
        RegExp(r'\b(dancing[\w\s]+with)\s*$', caseSensitive: false),
        'dancing closely with a partner',
      );

      // 11. Висячие предлоги/союзы перед запятой или концом
      s = s.replaceAll(
        RegExp(
          r'\b(and|but|while|in front of|on top of|of|at|to|for|with|by|the|into|onto|behind|against)\s*(?=,|$)',
          caseSensitive: false,
        ),
        '',
      );

      // 12. Зачистка мусора
      s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
      s = s.replaceAll(RegExp(r',\s*,'), ',');
      s = s.trim().replaceAll(RegExp(r'^,+|,+$'), '');

      return s;
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
    // Step 1: detect language
    final lastCharMsg = _getLastCharacterMessage(textOnly);
    final detectedLang = lastCharMsg != null
        ? langdetect.detect(lastCharMsg.content)
        : 'en';
    // Step 2: find current scene window
    final sceneWindow = _extractCurrentSceneWindow(textOnly, detectedLang);

    // Step 3: check cache
    final cached = _cache[branchId];
    if (cached != null) {
      final windowText = sceneWindow.map((m) => m.content).join(' ');
      final hasNewSignal = _hasSceneSwitchSignal(windowText, detectedLang);
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
  ChatMessageModel? _getLastCharacterMessage(List<ChatMessageModel> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isUser &&
          !m.isHidden &&
          m.imageLocalPath == null &&
          m.content.trim().isNotEmpty) {
        return m;
      }
    }
    return null;
  }
  /// Finds where the current scene starts.
  /// Scans messages from newest to oldest.
  /// When a scene-switch pattern is found in a message,
  /// everything from that message forward = current scene.
  /// If no switch found, returns last 6 messages.
  List<ChatMessageModel> _extractCurrentSceneWindow(
      List<ChatMessageModel> messages,
      String lang,
      ) {
    final textMessages = messages
        .where((m) => m.imageLocalPath == null && m.content.trim().isNotEmpty)
        .toList();
    if (textMessages.isEmpty) return [];


    final pattern = SceneSwitchPatterns.forLang(lang);
    if (pattern == null) {
      debugPrint('[SceneExtractor] No pattern for lang: $lang');
      return textMessages.length > 6
          ? textMessages.sublist(textMessages.length - 6)
          : textMessages;
    }

    for (int i = textMessages.length - 1; i >= 0; i--) {
      if (pattern.hasMatch(textMessages[i].content)) {
        final window = textMessages.sublist(i);
        final limited = window.length > AppConfig.maxSceneWindowSize
            ? window.sublist(window.length - AppConfig.maxSceneWindowSize)
            : window;
        debugPrint(
          '[SceneExtractor] Scene switch at index $i ($lang), '
              'window: ${limited.length}',
        );
        return limited;
      }
    }

    final fallback = textMessages.length > 6
        ? textMessages.sublist(textMessages.length - 6)
        : textMessages;
    debugPrint('[SceneExtractor] Fallback: ${fallback.length} messages');
    return fallback;
  }

  String _formatMessage(ChatMessageModel m) {
    final role = m.isUser ? 'User' : 'Character';
    return '$role: ${m.content}';
  }

  bool _hasSceneSwitchSignal(String text, String lang) {
    final pattern = SceneSwitchPatterns.forLang(lang);
    return pattern?.hasMatch(text) ?? false;
  }

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
        'model': 'deepseek-chat',
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

    // Public locations: intimacyLevel 3 → cap to 1
    final publicLocations = {
      'cafe', 'street', 'park', 'restaurant', 'office', 'supermarket',
    };
    if (s.location != null &&
        publicLocations.contains(s.location!.toLowerCase())) {
      if (s.intimacyLevel >= 3) {
        s = s.copyWith(intimacyLevel: 1);
      }
    }

    // Bed/bedroom + intimacyLevel 0 → force selectLevel 2
    if (s.location != null &&
        (s.location!.toLowerCase() == 'bed')) {
      if (s.intimacyLevel == 0) {
        s = s.copyWith(intimacyLevel: 2);
      }
    }

    // Баг 2: Минет в спальне/ванной → добавить floor в locationDetails
    if (s.pose?.toLowerCase() == 'kneeling' &&
        s.activity?.toLowerCase().contains('blowjob') == true ||
        s.activity?.toLowerCase().contains('oral') == true) {
      if (s.location != null &&
          (s.location!.toLowerCase().contains('bedroom') ||
              s.location!.toLowerCase().contains('bathroom') ||
              s.location!.toLowerCase().contains('room'))) {
        s = s.copyWith(
          locationDetails: s.locationDetails != null
              ? '${s.locationDetails}, floor'
              : 'floor',
        );
      }
    }

    return s;
  }
}
