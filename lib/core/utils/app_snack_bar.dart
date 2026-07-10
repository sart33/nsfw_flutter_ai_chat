import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/main.dart';

import '../../domain/entities/persona_entity.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/screens/api_keys_screen.dart';
import '../../presentation/screens/create_edit_persona_screen.dart';
import '../config/app_theme.dart'; // for scaffoldMessengerKey


class AppSnackBar {

  static void show(
      String message, {
        bool isError = false,
        bool withSettings = false,
        int isDuration = 0,
      }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final context = navigatorKey.currentContext;
    final isDesktop = context != null && MediaQuery.of(context).size.width >= 600;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: isError ? AppTheme.error : AppTheme.warning,
      duration: Duration(seconds:
      isDuration == 0
          ? isError
          ? 8 : 6
          : isDuration),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (withSettings) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.textPrimary, width: 1.5),
                padding: isDesktop
                    ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 32 : 16),
                ),
              ),
              onPressed: () {
                messenger.removeCurrentSnackBar();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
                );
              },
              child: Text(
                navigatorKey.currentContext!.l10n.settings,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }

  static void showExtended(
      String messageOne,
      String? messageTwo,{
        bool isError = false,
        bool withSettings = false,
      }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final context = navigatorKey.currentContext;
    final isDesktop = context != null && MediaQuery.of(context).size.width >= 600;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: isError ? AppTheme.error : AppTheme.warning,
      duration: Duration(seconds: withSettings ? 16 : 12),
      content: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  messageOne,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (withSettings) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.textPrimary, width: 1.5),
                    padding: isDesktop
                        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isDesktop ? 32 : 16),
                    ),
                  ),
                  onPressed: () {
                    messenger.removeCurrentSnackBar();
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
                    );
                  },
                  child: Text(
                    navigatorKey.currentContext!.l10n.settings,
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              ],
            ],
          ),
          if (messageTwo != null) ...[

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  messageTwo,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 14,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
    ],
      ),
    ));
  }


  static void showSuccess(String message, {bool isIcon = false}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final context = navigatorKey.currentContext;
    final isDesktop = context != null && MediaQuery.of(context).size.width >= 600;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppTheme.success,
      duration: const Duration(seconds: 3),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isIcon) ...[
            Icon(Icons.verified_outlined, color: AppTheme.textPrimary, size: isDesktop ? 20 : 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  static void showDeepSeekError(DeepSeekApiException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.code) {
      'key_not_set'          => (l10n.errorDeepSeekNotSet,              true,  true),
      'key_invalid'          => (l10n.errorDeepSeekKeyInvalid,          true,  true),
      'insufficient_balance' => (l10n.errorDeepSeekInsufficientBalance, true,  false),
      'service_unavailable'  => (l10n.errorDeepseekServiceUnavailable,  false, false),
      'http_error'           => ('DeepSeek error ${e.statusCode}',      false, false),
      'network_error'        => (l10n.networkError,                     false, false),
      'response_truncated'   => (l10n.errorDeepSeekResponseTruncated,   false, false),
      _                      => ('l10n.errorGeneric',                   false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }

    static void showPersonaValidationError(DeepSeekApiException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.code) {
      'key_not_set'          => (l10n.personaNotValidatedKeyNotSet,     true, true),
      'key_invalid'          => (l10n.personaNotValidatedKeyInvalid,    true, true),
      'insufficient_balance' => (l10n.personaNotValidatedNoBalance,     false, false),
      'network_error'        => (l10n.personaNotValidatedNetworkError,  false, false),
      'service_unavailable'  => (l10n.personaNotValidatedDeepseekUnavailable,  false, false),
      'http_error'           => ('DeepSeek error ${e.statusCode}',      false, false),
      _                      => (l10n.personaNotValidatedGeneric,       false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }

    static void showCreatePersonaValidationError(DeepSeekApiException e, AppLocalizations l10n) {
    final (msg1, msg2,isError, withSettings) = switch (e.code) {
      'key_not_set'          => (l10n.characterSavedNotVerifiedKeyNotSet, l10n.characterSavedNotVerifiedContinueHint, false, true),
      'key_invalid'          => (l10n.characterSavedNotVerifiedKeyInvalid, l10n.characterSavedNotVerifiedContinueHint,   false, true),
      'insufficient_balance' => (l10n.characterSavedNotVerifiedNoBalance, l10n.characterSavedNotVerifiedContinueHint,    false, false),
      'network_error'        => (l10n.characterSavedNotVerifiedNetworkError, null, false, false),
      'service_unavailable'  => (l10n.characterSavedNotVerifiedDeepSeekUnavailable, null, false, false),
      _                      => (l10n.characterSavedNotVerifiedGeneric, null,      false, false),
    };
    showExtended(msg1, msg2, isError: isError, withSettings: withSettings);
  }

  static void showNovitaError(NovitaApiException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e.technicalMessage) {
      'api_key_not_set'      => (l10n.errorNovitaKeyNotSet,            true,  true),
      'api_key_invalid'      => (l10n.errorNovitaKeyInvalid,           true,  true),
      'insufficient_balance' => (l10n.errorNovitaInsufficientBalance,  true,  false),
      _                      => (l10n.errorImageGeneration,            false, false),
    };
    show(msg, isError: isError, withSettings: withSettings);
  }

  static void showFormatError(FormatException e, AppLocalizations l10n) {
    final (msg, isError, withSettings) = switch (e) {

      _                      => (e,      true, false)
    };
    show(msg as String, isError: isError, withSettings: withSettings);
  }


  static void showAgeConflictSingle(
      AppLocalizations l10n,
      String personaId,
      AgeCheckFailReason reason,  // ← добавили
      ) {
    final messenger = scaffoldMessengerKey.currentState;
    final context = navigatorKey.currentContext;
    final isDesktop = context != null && MediaQuery.of(context).size.width >= 600;
    if (messenger == null) return;
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: reason == AgeCheckFailReason.conflictHigh
          ? AppTheme.error
          : AppTheme.warning,
      duration: const Duration(seconds: 15),
      // action убираем совсем
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
                switch (reason) {
                  AgeCheckFailReason.conflictHigh   => l10n.personaDescriptionConflictHigh,
                  AgeCheckFailReason.conflictMedium => l10n.personaDescriptionConflictMedium,
                  AgeCheckFailReason.missing        => l10n.personaAgeMissing,
                },
              style: TextStyle(fontSize: isDesktop ? 14 : 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.textPrimary, width: 1.5),
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 32 : 16),
              ),
            ),
            onPressed: () {
              messenger.removeCurrentSnackBar();
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => CreateEditPersonaScreen(personaId: personaId),
                ),
              );
            },
            child: Text(l10n.edit,
                style: TextStyle(fontSize: isDesktop ? 14 : 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ));
  }

  static void showAgeConflictMulti(AppLocalizations l10n, List<PersonaEntity> failedPersonas, AgeCheckFailReason reason) {
    final messenger = scaffoldMessengerKey.currentState;
    final context = navigatorKey.currentContext;
    final isDesktop = context != null && MediaQuery.of(context).size.width >= 600;
    if (messenger == null) return;
    final uniquePersonas = failedPersonas.fold<List<PersonaEntity>>([], (list, p) {
      if (!list.any((x) => x.id == p.id)) list.add(p);
      return list;
    });
    final names = uniquePersonas.take(3).map((p) => p.name).join(', ');
    final suffix = uniquePersonas.length > 3
        ? ' ${l10n.andMore(uniquePersonas.length - 3)}'
        : '';
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: reason == AgeCheckFailReason.conflictHigh
          ? AppTheme.error
          : AppTheme.warning,
      duration: const Duration(seconds: 12),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (reason) {
                    AgeCheckFailReason.conflictHigh   => l10n.personaDescriptionConflictHigh,
                    AgeCheckFailReason.conflictMedium => l10n.personaDescriptionConflictMedium,
                    AgeCheckFailReason.missing        => l10n.personaAgeMissing,
                  },
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 14 : 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text('$names$suffix', style: AppTheme.bodyStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.textPrimary, width: 1.5),
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 32 : 16),
              ),
            ),
            onPressed: () {
              messenger.removeCurrentSnackBar();
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => CreateEditPersonaScreen(personaId: uniquePersonas.first.id),
                ),
              );
            },
            child: Text(
              l10n.edit,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
