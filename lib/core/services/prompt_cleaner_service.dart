import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';

import '../../domain/exceptions/app_exceptions.dart';


class PromptCleanerService {
  PromptCleanerService._();
  static final PromptCleanerService instance = PromptCleanerService._();

  static const _endpoint = '${AppConfig.deepSeekBaseUrl}/chat/completions';

  // Builds the cleaning prompt sent to DeepSeek.
  // nude is NOT requested — caller copies raw description.
  // beach is NOT requested — caller copies erotic result.
  // romantic2 is NOT requested — caller copies office result.
  static String _buildPrompt(String description) => '''

Rules:

erotic:
- remove nipples and all adjectives directly before them
- remove all genital mentions
- remove all genital piercings
- remove tongue piercing and tongue ball mentions
- keep breast size mentions
- keep tattoos with body location
- remove any fetish gear or sexual accessories (e.g. anal plugs, BDSM items)
- remove any clothing, outfit, lingerie, underwear, or wearable items completely
- append "properly dressed" at the end

romantic:
- remove all breast mentions including size and adjectives
- remove all nipple mentions with adjectives
- remove all piercings everywhere
- remove all genital mentions
- remove tongue piercing and tongue ball mentions
- remove flat stomach / toned stomach mentions
- remove buttocks / ass / butt / glutes mentions and all adjectives before them
- remove waist mentions (slim waist, thin waist, narrow waist, etc.)
- remove any belly / abdomen mentions
- do NOT add any replacement for removed body part descriptions- keep tattoo mention but change location to arms only
- remove any clothing, outfit, lingerie, underwear, or wearable items completely
- append "properly dressed" at the end

office:
- apply all romantic rules above
- remove all tattoo mentions entirely
- remove any fetish clothing, BDSM elements, or sexualized accessories
- remove any phrases implying seduction, sexual intent, or provocative use of the body
- append "properly dressed" at the end

Input: "$description"

Return only this JSON, nothing else:
{"erotic":"...","romantic":"...","office":"..."}
''';

  /// Calls DeepSeek, parses result, saves to DB.
  /// nsfw = raw description (no cleaning needed)
  /// beach = copy of erotic
  /// romantic2 = copy of office
  Future<void> cleanAndSave(String personaId, String description) async {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) {
        throw const DeepSeekApiException('key_not_set');

        // AppSnackBar.showCriticalWithLang(
        //   'DeepSeek API key not set. Gallery prompts and chat scene descriptions will not be generated.',
        //   'Ключ DeepSeek не установлен. Обновление описаний для галереи и сцен чата пропущено.',
        // );
        //return;
      }

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.deepSeekV4RroModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a prompt cleaner for AI image generation. Given a character description (may be in any language), return 3 cleaned versions as a single JSON object.',
            },
            {
              'role': 'user',
              'content': _buildPrompt(description),
            }
          ],
          'response_format':{
            'type': 'json_object'
          },
         'max_tokens': 500,
          'temperature': 0.1,
          "thinking": {"type": "disabled"},
          "stream": false

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

      try {
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (responseJson['choices'] as List)
          .first['message']['content'] as String;

      // Strip markdown code fences if present
      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> result =
          jsonDecode(cleaned) as Map<String, dynamic>;
      final erotic   = (result['erotic']   as String?) ?? description;
      final romantic = (result['romantic'] as String?) ?? description;
      final office   = (result['office']   as String?) ?? description;

      await DatabaseHelper.instance.upsertPersonaPrompts(
        personaId:  personaId,
        nsfw:       description,   // raw, no cleaning
        erotic:     erotic,
        beach:      erotic,        // copy of erotic
        romantic:   romantic,
        romantic2:  office,        // copy of office
        office:     office,
      );
    } catch (e) {
        if (e is SocketException || e is http.ClientException) {
          throw const NetworkException();
        }
      throw const DeepSeekApiException('parse_error');
      // AppSnackBar.showErrorWithLang(
      //   'Gallery prompts and chat scene update failed. Please try again.',
      //   'Ошибка обновления описаний для галереи и сцен чата. Попробуйте снова.',
      // );
    }
  }
    /// Checks the character description for signs of underage.
    /// Returns hasConflict, severity ('low'/'medium'/'high'), reason.
    /// Call only if the API key is present.
  Future<({bool hasConflict, String? severity, String reason, bool hasAge})>
  checkForMinorSignals(String description) async {

    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) {
        throw const DeepSeekApiException('key_not_set');
      }


      const prompt = '''
Analyze the following character description.
The character is defined as an adult (18+).

Return ONLY valid JSON in this format:
{
  "has_conflict": true/false,
  "severity": "low" | "medium" | "high" | null,
  "reason": "short explanation",
  "has_age": true/false
}

---

## STEP 1 — Detect explicit age

Check whether the description contains an explicit age (a number or a clear statement like "43 years old", "she is 28").
- If found → has_age = true, extract the numeric age for use in steps below.
- If missing or ambiguous → has_age = false. Treat as "unknown age" in all rules below.

---

## STEP 2 — Hard Ban Terms (unconditional conflict)

If ANY of the following terms appear in the description, set has_conflict = true and severity = "high",
REGARDLESS of any stated adult age:

- schoolgirl, schoolboy
- child, kid, minor, underage
- teenager, adolescent, teen
- any word or phrase that explicitly identifies the character as a minor

EXCEPTION: If the term clearly and explicitly refers to a DIFFERENT person
(e.g. "she has a teenage daughter", "his 13-year-old son"),
and the character themselves is described as an adult — do NOT flag.
If ambiguous, assume the term refers to the character → flag it.

---

## STEP 3 — Soft Ban Terms (context-dependent)

Soft ban terms have two weight levels:

Heavy terms: loli, lolita, loli-type, loli type, loli-style, and similar compound forms.
Light terms: young-looking, youthful, looks younger than her age, petite or miniature as body-type (not height).

Apply the following rules:

### 3a. No age stated (has_age = false)
Any heavy or light term present → has_conflict = true, severity = "medium".

### 3b. Age < 18
has_conflict = true, severity = "high".

### 3c. Age 18, 19, or 20
Any heavy or light term present → has_conflict = true, severity = "medium".

### 3d. Age 21, 22, 23, 24 or 25 (boundary zone)
- Heavy term alone → has_conflict = true, severity = "medium". Do not downgrade.
- Light term alone → has_conflict = false.
- Heavy + light combined → has_conflict = true, severity = "medium".
- Two or more light terms combined → has_conflict = true, severity = "low".

### 3e. Age 26, 27, 28, or 29 (near boundary)
- Heavy term alone → has_conflict = true, severity = "low".
- Light term alone → has_conflict = false.
- Heavy + light combined → has_conflict = true, severity = "medium".
- Two or more light terms combined → has_conflict = false.

### 3f. Age 30 and above
Any number of heavy or light terms → has_conflict = false.

---

## STEP 4 — Whitelist exceptions

The following terms are NOT considered soft ban terms on their own
and should NOT contribute to a conflict flag:

- cute, pretty, adorable
- petite (height only, no body-type implication)
- youthful energy / youthful spirit (personality, not appearance)
- firestarter, spitfire, girl-next-door (character archetypes)

---

## STEP 5 — Combination amplification

When evaluating, always check for signal combinations, not isolated words.
Multiple weak signals together may cross the threshold.

Examples:
- "loli-type" + age 25 → has_conflict = true, severity = "medium"
- "young-looking" + age 22 → has_conflict = false
- "loli-type" + "young-looking" + age 25 → has_conflict = true, severity = "medium"
- "loli-type" + age 28 → has_conflict = true, severity = "low"
- "young-looking" + age 22 → has_conflict = false
- "loli" + no age → has_conflict = true, severity = "medium"
- "teenager" + age 27 → has_conflict = true, severity = "high" (hard ban overrides)

---

## STEP 6 — Output rules

- has_conflict: true only if Step 2 or Step 3 produced a flag.
- severity: set according to the matching rule. null if has_conflict = false.
- reason: one concise sentence explaining what triggered the flag (or why it passed).
- has_age: true if an explicit numeric age or clear age statement was found.

Do not flag vague or neutral words in isolation.
Do not flag descriptions based on sexual content or tone. Flag only based on age signals and the terms listed above. A character aged 18–29 in a sexual or flirtatious context is not a conflict by itself.
Words like playful, seductive, flirtatious, or their equivalents in any language are NOT conflict signals under any circumstances.
When uncertain, default to has_conflict = false.
Answer in English regardless of description language.

''';


      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.deepSeekV4FlashModel,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': description},
          ],
          'max_tokens': 1000,
          'thinking': {'type': 'enabled'},
          'reasoning_effort': 'high',
          'temperature': 0.0,
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
      final finishReason = (responseJson['choices'] as List)
          .first['finish_reason'] as String?;

      if (finishReason == 'length') {
        throw const DeepSeekApiException('invalid_response');
      }

      final content = ((responseJson['choices'] as List)
          .first['message']['content'] as String)
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final result = jsonDecode(content) as Map<String, dynamic>;

      final hasConflict = (result['has_conflict'] as bool?)
          ?? (throw const DeepSeekApiException('invalid_response'));

      final severity = result['severity'] as String?;

      final reason = (result['reason'] as String?) ?? '';

      final hasAge = (result['has_age'] as bool?)
          ?? (throw const DeepSeekApiException('invalid_response'));

      return (
      hasConflict: hasConflict,
      severity: severity,
      reason: reason,
      hasAge: hasAge,
      );

    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        throw const NetworkException();
      }
      if (e is DeepSeekApiException) rethrow;
     throw const DeepSeekApiException('invalid_response');
    }
    }
  }
