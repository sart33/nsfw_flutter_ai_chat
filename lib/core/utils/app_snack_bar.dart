import 'package:flutter/material.dart';
import 'package:nsfw_chat/main.dart'; // for scaffoldMessengerKey

class AppSnackBar {
  AppSnackBar._();

  static const _orange = Color(0xFFE65100);
  static const _red = Color(0xFFB71C1C);

  /// Shows error snackbar without context (uses GlobalKey).
  /// Accepts a single message string (already localized via context.l10n).
  static void showError(String message) {
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: _orange,
        duration: const Duration(seconds: 6),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Shows critical error (red) snackbar.
  /// Accepts a single message string (already localized via context.l10n).
  static void showCritical(String message) {
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: _red,
        duration: const Duration(seconds: 8),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Legacy method for backward compatibility with services that pass English/Russian messages.
  /// [isRu] — pass true for Russian, false for English.
  static void showErrorWithLang(String messageEn, String messageRu, {bool? isRu}) {
    final lang = isRu ?? _isRussian();
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: _orange,
        duration: const Duration(seconds: 6),
        content: Text(
          lang ? messageRu : messageEn,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  /// Legacy method for backward compatibility with services that pass English/Russian messages.
  /// [isRu] — pass true for Russian, false for English.
  static void showCriticalWithLang(String messageEn, String messageRu, {bool? isRu}) {
    final lang = isRu ?? _isRussian();
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: _red,
        duration: const Duration(seconds: 8),
        content: Text(
          lang ? messageRu : messageEn,
          style: const TextStyle(color: Colors.white),
        ),

      ),
    );
  }

  static bool isRussian() {
    try {
      final locale =
          WidgetsBinding.instance.platformDispatcher.locale;
      return locale.languageCode == 'ru';
    } catch (_) {
      return false;
    }
  }

  static bool _isRussian() => isRussian();
}
