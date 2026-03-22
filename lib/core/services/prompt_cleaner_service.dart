import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/utils/app_snack_bar.dart';

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
    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) return; // already handled by UI before calling this

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
          'max_tokens': 500,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 401) {
        AppSnackBar.showCriticalWithLang(
          'DeepSeek API key is invalid. Please update it in API Keys screen.',
          'Ключ DeepSeek недействителен. Обновите его в настройках API.',
        );
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppSnackBar.showErrorWithLang(
          'DeepSeek error ${response.statusCode}. Description cleaning failed.',
          'Ошибка DeepSeek ${response.statusCode}. Очистка описания не выполнена.',
        );
        return;
      }

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
      debugPrint('[PromptCleanerService] : description="$description"' );

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
      AppSnackBar.showErrorWithLang(
        'Description cleaning failed: $e',
        'Ошибка обработки описания: $e',
      );
    }
  }
}