import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings state holding user-adjustable limits.
class SettingsState {
  final int userInputLimit;
  final int aiResponseLimit;
  final double chatFontSize;
  final int reminderInterval;

  const SettingsState({
    this.userInputLimit = 2000,
    this.aiResponseLimit = 4000,
    this.chatFontSize = 16.0,
    this.reminderInterval = 10,  // default 10
  });

  SettingsState copyWith({
    int? userInputLimit,
    int? aiResponseLimit,
    double? chatFontSize,
    int? reminderInterval,
  }) =>
      SettingsState(
        userInputLimit: userInputLimit ?? this.userInputLimit,
        aiResponseLimit: aiResponseLimit ?? this.aiResponseLimit,
        chatFontSize: chatFontSize ?? this.chatFontSize,
        reminderInterval: reminderInterval ?? this.reminderInterval,
      );
}

/// Manages user-adjustable limits, persisted in SharedPreferences.
class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _keyUserInput = 'settings_user_input_limit';
  static const _keyAiResponse = 'settings_ai_response_limit';
  static const _keyChatFontSize = 'chat_font_size';
  static const _keyReminderInterval = 'settings_reminder_interval';

  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userLimit = prefs.getInt(_keyUserInput) ?? 2000;
    final aiLimit = prefs.getInt(_keyAiResponse) ?? 4000;
    final fontSize = prefs.getDouble(_keyChatFontSize) ?? 16.0;
    final reminderInterval = prefs.getInt(_keyReminderInterval) ?? 10;
    state = SettingsState(
      userInputLimit: userLimit,
      aiResponseLimit: aiLimit,
      chatFontSize: fontSize,
      reminderInterval: reminderInterval,
    );
  }

  /// Set user input limit (1000–4000).
  Future<void> setUserInputLimit(int value) async {
    final clamped = value.clamp(1000, 4000);
    state = state.copyWith(userInputLimit: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserInput, clamped);
  }

  /// Set AI response limit (2000–8000).
  Future<void> setAiResponseLimit(int value) async {
    final clamped = value.clamp(2000, 8000);
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

  /// Set reminder interval in seconds (1–20).
  Future<void> setReminderInterval(int value) async {
    final clamped = value.clamp(1, 20);
    state = state.copyWith(reminderInterval: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderInterval, clamped);
  }
}

/// Riverpod provider for settings.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
