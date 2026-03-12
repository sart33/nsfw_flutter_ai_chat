import 'package:flutter/material.dart';
import 'package:nsfw_chat/l10n/app_localizations.dart';


/// Extension to easily access AppLocalizations from BuildContext
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
