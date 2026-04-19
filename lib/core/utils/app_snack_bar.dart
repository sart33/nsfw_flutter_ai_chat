import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/main.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/screens/api_keys_screen.dart';
import '../config/app_theme.dart'; // for scaffoldMessengerKey


class AppSnackBar {
  static void show(
      String message, {
        bool isError = false,      // true = красный + 8 сек, false = оранжевый + 6 сек
        bool withSettings = false, // true = кнопка Settings → ApiKeysScreen
      }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: isError ? AppTheme.error : AppTheme.warning,
      duration: Duration(seconds: isError ? 8 : 6),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      action: withSettings
          ? SnackBarAction(
        label: navigatorKey.currentContext!.l10n.settings,
        textColor: Colors.white,
        onPressed: () => navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
        ),
      )
          : null,
    ));
  }

  // success — отдельный метод, зелёный, 3 сек, без action
  // static void showSuccess(String message) {
  //   final messenger = scaffoldMessengerKey.currentState;
  //   if (messenger == null) return;
  //   messenger.removeCurrentSnackBar();
  //   messenger.showSnackBar(SnackBar(
  //     backgroundColor: AppTheme.success,
  //     duration: const Duration(seconds: 3),
  //     content: Text(message, style: const TextStyle(color: Colors.white)),
  //   ));
  // }


  static void showSuccess(String message, {bool isIcon = false}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        backgroundColor: AppTheme.success, // зелёный
        duration: const Duration(seconds: 3),
        content: isIcon ? Row(
          children: [
             Icon(Icons.verified_outlined, color: AppTheme.textPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              message, style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ) : Text(message, style: const TextStyle(color: AppTheme.textPrimary))
      ));
  }

  static void showPromptCleanerError(PromptCleanerException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.code) {
      'key_not_set'          => (l10n.errorDeepSeekNotSet,              true,  true),
      'key_invalid'          => (l10n.errorDeepSeekKeyInvalid,          true,  true),
      'insufficient_balance' => (l10n.errorDeepSeekInsufficientBalance, true,  false),
      'http_error'           => ('DeepSeek error ${e.statusCode}',      false, false),
      _                      => ('l10n.errorGeneric',                     false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }

  static void showPersonaValidationError(PromptCleanerException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.code) {
      'key_not_set'          => (l10n.personaNotValidatedKeyNotSet,     true, true),
      'key_invalid'          => (l10n.personaNotValidatedKeyInvalid,    true, true),
      'insufficient_balance' => (l10n.personaNotValidatedNoBalance,     false, false),
      'network_error'        => (l10n.personaNotValidatedNetworkError, false, false),
      'http_error'           => ('DeepSeek error ${e.statusCode}',      false, false),
      _                      => (l10n.personaNotValidatedGeneric,       false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }

  static void showNovitaError(NovitaException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.message) {
      'api_key_not_set'      => (l10n.errorNovitaKeyNotSet,            true,  true),
      'api_key_invalid'      => (l10n.errorNovitaKeyInvalid,           true,  true),
      'insufficient_balance' => (l10n.errorNovitaInsufficientBalance,  true,  false),
      _                      => (l10n.errorImageGeneration,            false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }
}
