import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';

class SceneData {
  final String? location;   // e.g. "bedroom", "beach", "office"
  final String? clothing;   // e.g. "lingerie", "office suit", "nude"
  final String? pose;       // e.g. "lying", "sitting", "standing"
  final int intimacyLevel;  // 0-4
  final bool fromCache;

  const SceneData({
    this.location,
    this.clothing,
    this.pose,
    this.intimacyLevel = 0,
    this.fromCache = false,
  });
}

class SceneExtractorService {
  SceneExtractorService._();
  static final SceneExtractorService instance = SceneExtractorService._();

  // ── Regex keyword banks (Russian + English) ──────────────────────────

  // Location keywords → location name
  static final _locationPatterns = <RegExp, String>{
    RegExp(r'\b(кроват|постел|bed|bedroom)\w*\b', caseSensitive: false):
        'bedroom',
    RegExp(r'\b(диван|sofa|couch)\w*\b', caseSensitive: false): 'sofa',
    RegExp(r'\b(пляж|beach|берег моря)\w*\b', caseSensitive: false): 'beach',
    RegExp(r'\b(офис|office|рабоч)\w*\b', caseSensitive: false): 'office',
    RegExp(r'\b(кухн|kitchen)\w*\b', caseSensitive: false): 'kitchen',
    RegExp(r'\b(душ|ванн|shower|bathroom)\w*\b', caseSensitive: false):
        'bathroom',
    RegExp(r'\b(пол|floor)\w*\b', caseSensitive: false): 'floor',
    RegExp(r'\b(стол|desk|table)\w*\b', caseSensitive: false): 'desk',
    RegExp(r'\b(кресл|chair|стул)\w*\b', caseSensitive: false): 'chair',
  };

  // Intimacy bump words → how much to add to intimacyLevel
  static final _intimacyPatterns = <RegExp, int>{
    // +1 — light
    RegExp(r'\b(целу|kiss|обнима|hug|ласка)\w*\b',
        caseSensitive: false): 1,
    // +2 — moderate
    RegExp(r'\b(раздева|undress|снима|трогa|touch|гладит|stroke)\w*\b',
        caseSensitive: false): 2,
    // +3 — explicit
    RegExp(
        r'\b(трах|fuck|секс|sex|сосёт|suck|кончи|cum|член|cock|пизд|pussy)\w*\b',
        caseSensitive: false): 3,
  };

  // Pose keywords
  static final _posePatterns = <RegExp, String>{
    RegExp(r'\b(лежит|лежа|lying|on her back|на спин)\w*\b',
        caseSensitive: false): 'lying on back',
    RegExp(r'\b(сидит|сидя|sitting)\w*\b', caseSensitive: false): 'sitting',
    RegExp(r'\b(стоит|стоя|standing)\w*\b', caseSensitive: false): 'standing',
    RegExp(r'\b(на коленях|kneel|kneeling)\w*\b', caseSensitive: false):
        'kneeling',
    RegExp(r'\b(нагнул|bent over|наклон)\w*\b', caseSensitive: false):
        'bent over',
    RegExp(r'\b(обнима|embracing|прижима)\w*\b', caseSensitive: false):
        'embracing',
  };

  // Clothing keywords
  static final _clothingPatterns = <RegExp, String>{
    RegExp(r'\b(голая|голый|nude|naked|без одежды)\w*\b',
        caseSensitive: false): 'nude',
    RegExp(r'\b(бельё|белье|lingerie|underwear|трусик|бюстгальтер|lace)\w*\b',
        caseSensitive: false): 'lingerie',
    RegExp(r'\b(бикини|bikini|купальник|swimsuit)\w*\b',
        caseSensitive: false): 'bikini',
    RegExp(r'\b(платье|dress)\w*\b', caseSensitive: false): 'dress',
    RegExp(r'\b(блузк|blouse|рубашк|shirt)\w*\b', caseSensitive: false):
        'blouse',
    RegExp(r'\b(халат|robe|пеньюар)\w*\b', caseSensitive: false): 'robe',
  };

  // ── Cache (in-memory per branchId) ────────────────────────────────────
  // Key: branchId, Value: (SceneData, lastMessageCount)
  final _cache = <String, (SceneData, int)>{};

  // ── Public API ────────────────────────────────────────────────────────

  /// Extracts scene from recent messages.
  /// Uses regex first, falls back to DeepSeek only if confidence is low.
  /// Caches result per branchId. Cache invalidated when new messages
  /// contain location or intimacy keywords in last 3 messages.
  Future<SceneData> extractScene({
    required String branchId,
    required List<dynamic> messages, // List<ChatMessageModel>
    required String personaGalleryMode,
  }) async {
    // Take last 8 messages for analysis
    final recent = messages.length > 8
        ? messages.sublist(messages.length - 8)
        : messages;
    final recentText =
        recent.map((m) => m.content as String).join(' ');

    // Check cache — invalidate if last 3 messages have new location/intimacy
    final cached = _cache[branchId];
    if (cached != null) {
      final last3 = messages.length > 3
          ? messages.sublist(messages.length - 3)
          : messages;
      final last3Text = last3.map((m) => m.content as String).join(' ');
      final hasNewSignal = _hasLocationSignal(last3Text) ||
          _hasIntimacySignal(last3Text);
      if (!hasNewSignal) {
        return cached.$1.copyWith(fromCache: true);
      }
    }

    // Step 1 — regex parse
    final regexResult = _parseWithRegex(recentText);

    // Step 2 — if confidence high enough, use regex result
    if (_isConfident(regexResult)) {
      final result = regexResult.copyWith(fromCache: false);
      _cache[branchId] = (result, messages.length);
      return result;
    }

    // Step 3 — fallback to DeepSeek
    final llmResult = await _extractWithLLM(recentText);
    final merged = _merge(regexResult, llmResult);
    _cache[branchId] = (merged, messages.length);
    return merged;
  }

  // ── Private: regex parser ─────────────────────────────────────────────

  SceneData _parseWithRegex(String text) {
    String? location;
    String? clothing;
    String? pose;
    int intimacy = 0;

    for (final entry in _locationPatterns.entries) {
      if (entry.key.hasMatch(text)) {
        location = entry.value;
        break;
      }
    }
    for (final entry in _clothingPatterns.entries) {
      if (entry.key.hasMatch(text)) {
        clothing = entry.value;
        break;
      }
    }
    for (final entry in _posePatterns.entries) {
      if (entry.key.hasMatch(text)) {
        pose = entry.value;
        break;
      }
    }
    for (final entry in _intimacyPatterns.entries) {
      if (entry.key.hasMatch(text)) {
        intimacy = (intimacy + entry.value).clamp(0, 4);
      }
    }

    return SceneData(
      location: location,
      clothing: clothing,
      pose: pose,
      intimacyLevel: intimacy,
    );
  }

  bool _isConfident(SceneData d) =>
      d.location != null && d.intimacyLevel > 0;

  bool _hasLocationSignal(String text) =>
      _locationPatterns.keys.any((r) => r.hasMatch(text));

  bool _hasIntimacySignal(String text) =>
      _intimacyPatterns.keys.any((r) => r.hasMatch(text));

  // ── Private: LLM fallback ─────────────────────────────────────────────

  Future<SceneData> _extractWithLLM(String recentText) async {
    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) return const SceneData();

      final prompt = '''
Read these chat messages and fill ONLY these fields.
Do not invent. If unsure — write null.
Return only raw JSON, no markdown.

Messages:
"$recentText"

Return:
{
  "location": "bedroom/beach/office/kitchen/bathroom/sofa/floor/null",
  "clothing": "nude/lingerie/bikini/dress/blouse/robe/null",
  "pose": "lying/sitting/standing/kneeling/bent over/embracing/null",
  "intimacy_level": 0
}

intimacy_level rules:
0 = no physical contact
1 = kissing, hugging
2 = undressing, touching
3 = explicit sexual act
4 = very explicit''';

      final response = await http.post(
        Uri.parse('https://api.deepseek.com/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 150,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const SceneData();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (json['choices'] as List)
          .first['message']['content'] as String;
      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final map = jsonDecode(cleaned) as Map<String, dynamic>;

      return SceneData(
        location: map['location'] as String?,
        clothing: map['clothing'] as String?,
        pose: map['pose'] as String?,
        intimacyLevel: (map['intimacy_level'] as int? ?? 0).clamp(0, 4),
      );
    } catch (e) {
      debugPrint('[SceneExtractor] LLM error: $e');
      return const SceneData();
    }
  }

  // ── Private: merge regex + LLM ────────────────────────────────────────

  SceneData _merge(SceneData regex, SceneData llm) {
    return SceneData(
      location: regex.location ?? llm.location,
      clothing: regex.clothing ?? llm.clothing,
      pose: regex.pose ?? llm.pose,
      intimacyLevel: regex.intimacyLevel > 0
          ? regex.intimacyLevel
          : llm.intimacyLevel,
    );
  }
}

// Add copyWith to SceneData:
extension SceneDataX on SceneData {
  SceneData copyWith({
    String? location,
    String? clothing,
    String? pose,
    int? intimacyLevel,
    bool? fromCache,
  }) {
    return SceneData(
      location: location ?? this.location,
      clothing: clothing ?? this.clothing,
      pose: pose ?? this.pose,
      intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}