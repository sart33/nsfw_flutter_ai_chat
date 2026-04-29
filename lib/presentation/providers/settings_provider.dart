import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings state holding user-adjustable limits.
class SettingsState {
  final int userInputLimit;
  final int aiResponseLimit;
  final double chatFontSize;
  final int reminderInterval;
  final bool reminderEnabled;
  final bool yamlPersonaEnabled;
  final double generationTemperature;
  final bool summarizationEnabled;
  final int summarizationThreshold;
  final int summaryMaxBlocks;
  final bool autoDeleteChatImagesEnabled;
  final int autoDeleteChatImagesDays;
  final String? selectedLocale; // null = системная
  static const _sentinel = Object();



  const SettingsState({
    this.userInputLimit = 2000,
    this.aiResponseLimit = 400,
    this.chatFontSize = 18.0,
    this.reminderInterval = 10,        // default 10
    this.reminderEnabled = true,       // default true
    this.yamlPersonaEnabled = false,   // default false
    this.generationTemperature = 0.75,
    this.summarizationEnabled = true,  // default true
    this.summarizationThreshold = 30, // default 50
    this.summaryMaxBlocks = 4,
    this.autoDeleteChatImagesEnabled = false, // default false
    this.autoDeleteChatImagesDays = AppConfig.autoDeleteDefaultDays,
    this.selectedLocale // default from AppConfig

  });

  SettingsState copyWith({
    int? userInputLimit,
    int? aiResponseLimit,
    double? chatFontSize,
    int? reminderInterval,
    bool? reminderEnabled,
    bool? yamlPersonaEnabled,
    double? generationTemperature,
    bool? summarizationEnabled,
    int? summarizationThreshold,
    int? summaryMaxBlocks,
    bool? autoDeleteChatImagesEnabled,
    int? autoDeleteChatImagesDays,
    Object? selectedLocale = _sentinel,
  }) =>
      SettingsState(
        userInputLimit: userInputLimit ?? this.userInputLimit,
        aiResponseLimit: aiResponseLimit ?? this.aiResponseLimit,
        chatFontSize: chatFontSize ?? this.chatFontSize,
        reminderInterval: reminderInterval ?? this.reminderInterval,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        yamlPersonaEnabled: yamlPersonaEnabled ?? this.yamlPersonaEnabled,
        generationTemperature: generationTemperature ?? this.generationTemperature,
        summarizationEnabled: summarizationEnabled ?? this.summarizationEnabled,
        summarizationThreshold: summarizationThreshold ?? this.summarizationThreshold,
        summaryMaxBlocks: summaryMaxBlocks ?? this.summaryMaxBlocks,
        autoDeleteChatImagesEnabled: autoDeleteChatImagesEnabled ?? this.autoDeleteChatImagesEnabled,
        autoDeleteChatImagesDays: autoDeleteChatImagesDays ?? this.autoDeleteChatImagesDays,
        selectedLocale: selectedLocale == _sentinel
            ? this.selectedLocale
            : selectedLocale as String?,
      );
}

/// Manages user-adjustable limits, persisted in SharedPreferences.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  static const _keyUserInput = 'settings_user_input_limit';
  static const _keyAiResponse = 'settings_ai_response_limit';
  static const _keyChatFontSize = 'chat_font_size';
  static const _keyReminderInterval = 'settings_reminder_interval';
  static const _keyReminderEnabled = 'settings_reminder_enabled';
  static const _keyYamlPersonaEnabled = 'settings_yaml_persona_enabled';
  static const _keyGenerationTemperature = 'generation_temperature';
  static const _keySummarizationEnabled = 'settings_summarization_enabled';
  static const _keySummarizationThreshold = 'settings_summarization_threshold';
  static const _keySummaryMaxBlocks = 'settings_summary_max_blocks';
  static const _keyAutoDeleteEnabled = 'settings_auto_delete_enabled';
  static const _keyAutoDeleteDays = 'settings_auto_delete_days';
  static const _keyLocale = 'settings_locale';


  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userLimit = prefs.getInt(_keyUserInput) ?? 4000;
    final aiLimit = prefs.getInt(_keyAiResponse) ?? 400;
    final fontSize = prefs.getDouble(_keyChatFontSize) ?? 18.0;
    final reminderInterval = prefs.getInt(_keyReminderInterval) ?? 10;
    final reminderEnabled = prefs.getBool(_keyReminderEnabled) ?? true;
    final yamlPersonaEnabled = prefs.getBool(_keyYamlPersonaEnabled) ?? false;
    final temperature = prefs.getDouble(_keyGenerationTemperature) ?? 0.75;
    final summarizationEnabled = prefs.getBool(_keySummarizationEnabled) ??
        true;
    final summarizationThreshold = prefs.getInt(_keySummarizationThreshold) ??
        30;
    final summaryMaxBlocks = prefs.getInt(_keySummaryMaxBlocks) ?? 4;
    final autoDeleteEnabled = prefs.getBool(_keyAutoDeleteEnabled) ?? false;
    final autoDeleteDays = prefs.getInt(_keyAutoDeleteDays) ??
        AppConfig.autoDeleteDefaultDays;
    final locale = prefs.getString(_keyLocale); // null если не установлен
    state = SettingsState(
      userInputLimit: userLimit,
      aiResponseLimit: aiLimit,
      chatFontSize: fontSize,
      reminderInterval: reminderInterval,
      reminderEnabled: reminderEnabled,
      yamlPersonaEnabled: yamlPersonaEnabled,
      generationTemperature: temperature,
      summarizationEnabled: summarizationEnabled,
      summarizationThreshold: summarizationThreshold,
      summaryMaxBlocks: summaryMaxBlocks,
      autoDeleteChatImagesEnabled: autoDeleteEnabled,
      autoDeleteChatImagesDays: autoDeleteDays,
      selectedLocale: locale,
    );
  _ready.complete();
  }

  /// Set user input limit (1000–4000).
  Future<void> setUserInputLimit(int value) async {
    final clamped = value.clamp(1000, 8000);
    state = state.copyWith(userInputLimit: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserInput, clamped);
  }

  /// Set AI response limit (100–4000).
  Future<void> setAiResponseLimit(int value) async {
    final clamped = value.clamp(100, 4000);
    state = state.copyWith(aiResponseLimit: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAiResponse, clamped);
  }

  /// Set chat font size (12–24).
  Future<void> setChatFontSize(double size) async {
    final clamped = size.clamp(12.0, 24.0);
    state = state.copyWith(chatFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyChatFontSize, clamped);
  }

  /// Set reminder interval in messages (1–20).
  Future<void> setReminderInterval(int value) async {
    final clamped = value.clamp(1, 20);
    state = state.copyWith(reminderInterval: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderInterval, clamped);
  }

  /// Enable or disable persona reminder injection.
  Future<void> setReminderEnabled(bool value) async {
    state = state.copyWith(reminderEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, value);
  }

  /// Enable or disable YAML system prompt override.
  Future<void> setYamlPersonaEnabled(bool value) async {
    state = state.copyWith(yamlPersonaEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyYamlPersonaEnabled, value);
  }

  /// Set generation temperature (0.1–1.5).
  Future<void> setGenerationTemperature(double value) async {
    final clamped = value.clamp(0.1, 1.5);
    state = state.copyWith(generationTemperature: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGenerationTemperature, clamped);
  }

  /// Enable or disable automatic conversation summarization.
  Future<void> setSummarizationEnabled(bool value) async {
    state = state.copyWith(summarizationEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySummarizationEnabled, value);
  }

  /// Set the message-count threshold that triggers summarization (20–100).
  Future<void> setSummarizationThreshold(int value) async {
    final clamped = value.clamp(20, 100);
    state = state.copyWith(summarizationThreshold: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySummarizationThreshold, clamped);
  }
  /// Set the maximum number of summary blocks to keep (0–10).
  Future<void> setSummaryMaxBlocks(int value) async {
    final clamped = value.clamp(1, 10);
    state = state.copyWith(summaryMaxBlocks: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySummaryMaxBlocks, clamped);
  }

  /// Clears all summary blocks from the database.
  Future<void> clearAllSummaries() async {
    try {
      await DatabaseHelper.instance.clearAllSummaries();
    } catch (e) {
      debugPrint('Error clearing summaries: $e');
      rethrow;
    }
  }

  /// Enable or disable auto-delete for chat images.
  Future<void> setAutoDeleteEnabled(bool value) async {
    state = state.copyWith(autoDeleteChatImagesEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDeleteEnabled, value);
  }

  /// Set auto-delete days (7–60).
  Future<void> setAutoDeleteDays(int value) async {
    final clamped = value.clamp(7, 60);
    state = state.copyWith(autoDeleteChatImagesDays: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoDeleteDays, clamped);
  }

  /// Set selected locale (null = system default).
  Future<void> setLocale(String? languageCode) async {
    state = state.copyWith(selectedLocale: languageCode);
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_keyLocale);
    } else {
      await prefs.setString(_keyLocale, languageCode);
    }
  }
}

/// Riverpod provider for settings.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
