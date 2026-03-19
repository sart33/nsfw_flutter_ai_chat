import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';

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
      charactersPositioning:
          json['charactersPositioning'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      confidence:
          (json['confidence'] as num?)?.toDouble() ?? 0.0,
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
          .replaceAll(
            RegExp(r'\bwith\b', caseSensitive: false),
            'by herself',
          );
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
          .replaceAll(
            RegExp(r'\bwith\b', caseSensitive: false),
            'by herself',
          );
      parts.add(safeActivity);
    }
    if (clothingDetails != null) parts.add(clothingDetails!);
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
  static final SceneExtractorService instance =
      SceneExtractorService._();

  // ── Scene switch detection patterns ────────────────────────────────
  // Used to find where the current scene starts in message history.
  // When one of these patterns is found, everything before that
  // message is considered a different scene and ignored.

  static final List<RegExp> sceneSwitchPatterns = [
    // RUSSIAN
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
    // ENGLISH
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
  ];

  // ── DeepSeek prompt ─────────────────────────────────────────────────

  static String _buildExtractionPrompt(
      String current, String context) =>
'''
You are a scene extraction engine for image generation.

You receive TWO parts:
1) CURRENT MESSAGE (highest priority)
2) PREVIOUS CONTEXT (lower priority)

Your task is to extract the CURRENT visual state.

────────────────────
PRIORITY RULES (CRITICAL):

- ALWAYS prioritize CURRENT MESSAGE over PREVIOUS CONTEXT
- If there is ANY conflict → use CURRENT MESSAGE
- PREVIOUS CONTEXT is only for missing data

- Activity MUST be taken from CURRENT MESSAGE if present
- Pose can persist from context IF not redefined
- Location usually persists unless changed explicitly

────────────────────
STRICT RULES:

1. Use ONLY the provided text
2. NEVER invent details
3. If missing → return null
4. Output ONLY valid JSON

────────────────────
SEMANTIC RULES:

- Activity = what is happening RIGHT NOW (latest action)
- Do NOT use outdated actions from earlier messages

Examples:
WRONG:
- kneeling + looking_up (if later action is different)

CORRECT:
- kneeling + performing_oral (latest action)

────────────────────
Allowed values:

- clothingState: "fully_dressed", "casual", "underwear", "nude"
- intimacyLevel: 0,1,2,3

- pose:
"sitting", "standing", "lying_on_back",
"lying_on_side", "lying_on_stomach",
"kneeling", "bending_over"

- location:
"cafe", "bed", "bedroom", "balcony",
"shower", "bathroom", "beach",
"street", "sofa", "kitchen",
"park", "room", "restaurant",
"car", "office"

────────────────────
HARD CONSTRAINTS:

- Public locations → intimacyLevel ≤ 1
- Shower → not fully_dressed
- Activity must describe current action toward user
- Do NOT change, transliterate or translate ANY text inside double quotes ("...").

INPUT:

CURRENT MESSAGE:
$current

PREVIOUS CONTEXT:
$context

OUTPUT — ONLY JSON:
{
  "location": "...",
  "locationDetails": "...",
  "pose": "...",
  "activity": "...",
  "clothingState": "...",
  "clothingDetails": "...",
  "intimacyLevel": 0,
  "charactersPositioning": "...",
  "timeOfDay": "...",
  "confidence": 0.95
}
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
    final textOnly = messages
        .where((m) =>
            m.imageLocalPath == null && m.content.trim().isNotEmpty)
        .toList();
    if (textOnly.isEmpty) return SceneSnapshot.fallback;

    // Step 1: find current scene window
    final sceneWindow = _extractCurrentSceneWindow(textOnly);

    // Step 2: check cache
    final cached = _cache[branchId];
    if (cached != null) {
      final windowText = sceneWindow
          .map((m) => m.content)
          .join(' ');
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
    final previousMsgs = sceneWindow.length > 1
        ? sceneWindow.sublist(0, sceneWindow.length - 1)
        : <ChatMessageModel>[];

    final currentText = _formatMessage(lastMsg);
    final contextText = previousMsgs
        .map(_formatMessage)
        .join('\n');

    debugPrint('[SceneExtractor] CURRENT: $currentText');
    debugPrint('[SceneExtractor] CONTEXT: $contextText');

    final rawSnapshot = await _extractWithLLM(currentText, contextText);

    // Step 4: validate
    final validated = _validateAndFix(rawSnapshot);
    debugPrint('[SceneExtractor] Final snapshot: '
        '${jsonEncode(validated.toMap())}');

    // Step 5: cache and return
    _cache[branchId] = (validated, textOnly.length);
    return validated;
  }

  // ── Scene window extraction ─────────────────────────────────────────

  /// Finds where the current scene starts.
  /// Scans messages from newest to oldest.
  /// When a scene-switch pattern is found in a message,
  /// everything from that message forward = current scene.
  /// If no switch found, returns last 6 messages.
  List<ChatMessageModel> _extractCurrentSceneWindow(
      List<ChatMessageModel> messages) {
    // Remove image-only messages (they have empty content)
    final textMessages = messages
        .where((m) => m.imageLocalPath == null && m.content.trim().isNotEmpty)
        .toList();
    if (textMessages.isEmpty) return [];
    
    // Scan from newest backwards to find last scene switch
    for (int i = textMessages.length - 1; i >= 0; i--) {
      final text = textMessages[i].content;
      final hasSwitch =
          sceneSwitchPatterns.any((p) => p.hasMatch(text));
      if (hasSwitch) {
        // Current scene = from this message to end
        final window = textMessages.sublist(i);
        debugPrint(
            '[SceneExtractor] Scene switch found at index $i, '
            'window size: ${window.length}');
        return window;
      }
    }
    // No switch found — use last 6 messages
    final fallbackWindow = textMessages.length > 6
        ? textMessages.sublist(textMessages.length - 6)
        : textMessages;
    debugPrint('[SceneExtractor] No scene switch found, '
        'using last ${fallbackWindow.length} messages');
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
      String currentText, String contextText) async {
    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) {
        debugPrint('[SceneExtractor] No API key, using fallback');
        return SceneSnapshot.fallback;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.deepSeekBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.deepSeekModel,
          'messages': [
            {
              'role': 'user',
              'content': _buildExtractionPrompt(currentText, contextText),
            }
          ],
          'max_tokens': 300,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[SceneExtractor] HTTP error: ${response.statusCode}');
        return SceneSnapshot.fallback;
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      final rawContent = (responseJson['choices'] as List)
          .first['message']['content'] as String;

      debugPrint('[SceneExtractor] Raw LLM response: $rawContent');

      final cleaned = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return SceneSnapshot.fromJson(map);
    } catch (e) {
      debugPrint('[SceneExtractor] LLM error: $e');
      return SceneSnapshot.fallback;
    }
  }

  // ── Validation ──────────────────────────────────────────────────────

  /// Fixes logical contradictions in the extracted snapshot.
  SceneSnapshot _validateAndFix(SceneSnapshot raw) {
    var s = raw;

    // Public locations: cap intimacy and fix impossible poses
    final publicLocations = {
      'cafe', 'street', 'park', 'restaurant', 'office'
    };
    if (s.location != null &&
        publicLocations.contains(s.location!.toLowerCase())) {
      if (s.intimacyLevel > 1) {
        s = s.copyWith(intimacyLevel: 1);
      }
      final impossiblePoses = {
        'lying_on_back', 'lying_on_side',
        'lying_on_stomach', 'kneeling', 'bending_over',
      };
      if (s.pose != null &&
          impossiblePoses.contains(s.pose!.toLowerCase())) {
        s = s.copyWith(pose: 'sitting');
      }
    }

    // Shower: cannot be fully dressed
    if (s.location == 'shower' &&
        s.clothingState == 'fully_dressed') {
      s = s.copyWith(clothingState: 'nude');
    }

    // Activity-driven pose correction:
    // If activity implies specific pose → enforce it
    if (s.activity != null) {
      final a = s.activity!.toLowerCase();

      // Oral sex activity → must be kneeling
      if (a.contains('oral') ||
          a.contains('mouth') ||
          a.contains('blowjob') ||
          a.contains('fellatio') ||
          a.contains('минет') ||
          a.contains('сосёт') ||
          a.contains('рот')) {
        s = s.copyWith(pose: 'kneeling');
      }

      // Riding activity → must be on top
      if (a.contains('riding') ||
          a.contains('on top') ||
          a.contains('верхом') ||
          a.contains('скачет')) {
        s = s.copyWith(pose: 'lying_on_back');
      }

      // Doggy style → bending over
      if (a.contains('doggy') ||
          a.contains('раком') ||
          a.contains('четвереньк')) {
        s = s.copyWith(pose: 'bending_over');
      }
    }

    return s;
  }
}