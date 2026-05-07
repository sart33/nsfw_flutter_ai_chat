import 'dart:convert';
import 'package:flutter/services.dart';

class SceneSwitchPatterns {
  static Map<String, RegExp> _patterns = {};

  static Future<void> load() async {
    final json = await rootBundle.loadString(
      'assets/json/scene_switch_patterns.json',
    );
    final Map<String, dynamic> raw = jsonDecode(json);
    _patterns = raw.map(
          (lang, pattern) => MapEntry(
        lang,
        RegExp(pattern as String, caseSensitive: false, unicode: true),
      ),
    );

    }

  static RegExp? forLang(String lang) {
    return _patterns[lang] ?? _patterns['en']; // fallback to EN
  }
}