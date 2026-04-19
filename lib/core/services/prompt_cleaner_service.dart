import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
You are a prompt cleaner for AI image generation.
Given a character description (may be in any language),
return 3 cleaned versions as a single JSON object.
No explanation, no markdown, only raw JSON.

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
- remove any mentions of clothing or worn items (e.g. lingerie, underwear, bra, panties, swimsuit, dress, skirt, straps, harness, corset, latex, uniform)
- append "properly dressed" at the end

romantic:
- remove all breast mentions including size and adjectives
- remove all nipple mentions with adjectives
- remove all piercings everywhere
- remove all genital mentions
- remove tongue piercing and tongue ball mentions
- keep tattoo mention but change location to arms only
- remove any clothing, outfit, lingerie, underwear, or wearable items completely
- remove any mentions of clothing or worn items (e.g. lingerie, underwear, bra, panties, swimsuit, dress, skirt, straps, harness, corset, latex, uniform)
- append "properly dressed" at the end

office:
- same as romantic
- remove all tattoo mentions entirely
- remove any mentions of fetish clothing, BDSM elements, or sexualized accessories (e.g. straps, harnesses, chokers, latex, corsets used in sexual context)
- remove any clothing descriptions that imply sexualized style or exposure
- remove phrases implying seduction, sexual intent, or body used for attraction
- remove any clothing, outfit, lingerie, underwear, or wearable items completely
- remove any mentions of clothing or worn items (e.g. lingerie, underwear, bra, panties, swimsuit, dress, skirt, straps, harness, corset, latex, uniform)
- remove any phrases implying seduction, sexual intent, or provocative use of the body
- append "properly dressed" at the end

Input:
"$description"

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
        debugPrint('[PromptCleanerService] DeepSeek API key is not set, skipping.');
        throw const PromptCleanerException('key_not_set');

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
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'user',
              'content': _buildPrompt(description),
            }
          ],
          'max_tokens': 1500,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 401) {
        throw const PromptCleanerException('key_invalid');
      }
      if (response.statusCode == 402) {
        throw const PromptCleanerException('insufficient_balance');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PromptCleanerException('http_error', statusCode: response.statusCode);
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
      debugPrint('[PromptCleanerService] cleanAndSave personaId=$personaId');

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
      debugPrint('[PromptCleanerService] Error: $e');
      throw const PromptCleanerException('parse_error');
      // AppSnackBar.showErrorWithLang(
      //   'Gallery prompts and chat scene update failed. Please try again.',
      //   'Ошибка обновления описаний для галереи и сцен чата. Попробуйте снова.',
      // );
    }
  }
    /// Checks the character description for signs of underage.
    /// Returns hasConflict, severity ('low'/'medium'/'high'), reason.
    /// Call only if the API key is present.
  Future<({bool hasConflict, String? severity, String reason})>
  checkForMinorSignals(String description) async {

    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) {
        throw const PromptCleanerException('key_not_set');
      }


      const prompt = '''
Analyze the following character description.
The character is defined as an adult (18+).
Return ONLY valid JSON in this format:
{"has_conflict": true/false, "severity": "low" | "medium" | "high", "reason": "short explanation"}

Task:
Detect whether the description contains ANY signals that contradict the character being an adult (18+).
These include:
- explicit age under 18
- references to school (schoolgirl, schoolboy, student in a minor context)
- words like child, kid, minor, underage
- descriptions that strongly imply a minor

Important:
- Ignore vague words like "cute", "petite", "young-looking", "youthful"
- Be conservative: if unclear, return has_conflict = false
- Answer in English regardless of description language
''';


      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': description},
          ],
          'max_tokens': 150,
          'temperature': 0.0,
        }),
      );

      debugPrint('[PromptCleanerService] checkForMinorSignals response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 401) {
        throw const PromptCleanerException('key_invalid');
      }

      if (response.statusCode == 402) {
        throw const PromptCleanerException('insufficient_balance');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PromptCleanerException('http_error', statusCode: response.statusCode);
      }


      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final finishReason = (responseJson['choices'] as List)
          .first['finish_reason'] as String?;

      if (finishReason == 'length') {
        debugPrint('[PromptCleanerService] checkForMinorSignals response truncated (finish_reason=length), likely due to max_tokens limit. Consider increasing max_tokens or check if the prompt is too long.');
        throw const PromptCleanerException('invalid_response');
      }

      final content = ((responseJson['choices'] as List)
          .first['message']['content'] as String)
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final result = jsonDecode(content) as Map<String, dynamic>;

      final hasConflict = (result['has_conflict'] as bool?)
          ?? (throw const PromptCleanerException('invalid_response'));

      final severity = result['severity'] as String?;

      final reason = (result['reason'] as String?) ?? '';

      return (
      hasConflict: hasConflict,
      severity: severity,
      reason: reason,
      );

    } on PromptCleanerException {
      rethrow; // ВАЖНО: не глотаем свои ошибки
    } catch (e) {
      debugPrint('[PromptCleanerService] Unexpected error: $e');

      debugPrint('[PromptCleanerService] Unexpected error: $e');
      if (e is SocketException || e is http.ClientException) {
        throw const PromptCleanerException('network_error');
      }
      throw const PromptCleanerException('invalid_response');
    }
    }
  }
