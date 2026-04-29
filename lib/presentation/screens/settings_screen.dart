import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/core/services/backup_service.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/api_keys_screen.dart';
import 'package:nsfw_chat/presentation/screens/support_the_project_screen.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';

import 'about_app_screen.dart';

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;


const _supportedLocales = [
  (code: 'en',  name: 'English'),
  (code: 'ru',  name: 'Русский'),
  (code: 'uk',  name: 'Українська'),
  (code: 'es',  name: 'Español'),
  (code: 'pt',  name: 'Português'),
  (code: 'hi',  name: 'हिन्दी'),
  (code: 'id',  name: 'Indonesia'),
  (code: 'fr',  name: 'Français'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showLanguageSheet(
      BuildContext context,
      String? currentLocale,
      SettingsNotifier notifier,
      ) {
    final locales = [
      (code: null as String?,  nameKey: context.l10n.systemLanguage, nameNative: ''),
      (code: 'en',  nameKey: context.l10n.en,    nameNative: 'English'),
      (code: 'ru',  nameKey: context.l10n.ru,    nameNative: 'Русский'),
      (code: 'uk',  nameKey: context.l10n.uk,  nameNative: 'Українська'),
      (code: 'es',  nameKey: context.l10n.es,    nameNative: 'Español'),
      (code: 'pt',  nameKey: context.l10n.pt, nameNative: 'Português'),
      (code: 'hi',  nameKey: context.l10n.hi,      nameNative: 'हिन्दी'),
      (code: 'id',  nameKey: context.l10n.id, nameNative: 'Indonesia'),
      (code: 'fr',  nameKey: context.l10n.fr,     nameNative: 'Français'),
    ];

    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => _LanguageDialog(
          locales: locales,
          currentLocale: currentLocale,
          notifier: notifier,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0D0D10),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        isScrollControlled: true,
        builder: (_) => _LanguageSheet(
          locales: locales,
          currentLocale: currentLocale,
          notifier: notifier,
        ),
      );
    }
  }
  void _showTokenInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.tokensAndText,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.tokenExplanation,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13)),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(
                    color: AppTheme.textSecondary, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                },
                children: [
                  _tableRow(context, context.l10n.tokens,
                      context.l10n.approximateVolume,
                      header: true),
                  _tableRow(context, '1 000', context.l10n.words750),
                  _tableRow(context, '2 000', context.l10n.words1500),
                  _tableRow(context, '4 000', context.l10n.words3000),
                  _tableRow(context, '8 192', context.l10n.maxDeepSeek),
                ],
              ),
              const SizedBox(height: 12),
              Text(context.l10n.usuallyEnough,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.understood,
                style:
                const TextStyle(color: AppTheme.primaryAccent)),
          ),
        ],
      ),
    );
  }

  TableRow _tableRow(BuildContext context, String col1, String col2,
      {bool header = false}) {
    final style = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 12,
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
    );
    return TableRow(
      decoration: header
          ? BoxDecoration(
          color: AppTheme.background.withValues(alpha: 0.5))
          : null,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            child: Text(col1, style: style)),
        Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            child: Text(col2, style: style)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings   = ref.watch(settingsProvider);
    final notifier   = ref.read(settingsProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop  =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

    // ── Все блоки-карточки ────────────────────────────────────────────
    // Собираем список «секций». Каждая секция — это один _SettingsCard.
    // На мобайле выводим в один столбец, на десктопе — в два.

    final aboutCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.info_outline,
        title: context.l10n.aboutAppTitle,
        subtitle: context.l10n.appSettingsDescription,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AboutAppScreen())),
      ),
    ]);

    final supportCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.money,
        title: context.l10n.supportProjectTitle,
        subtitle: context.l10n.projectSupport,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const SupportProjectScreen())),
      ),
    ]);

    final apiKeysCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.vpn_key_outlined,
        title: context.l10n.apiKeys,
        subtitle: context.l10n.manageApiKeys,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ApiKeysScreen())),
      ),
    ]);

    final chatFontCard = _SettingsCard(children: [
      _SliderTile(
        title: context.l10n.chatFontSize,
        valueLabel:
        context.l10n.pixelsLabel(settings.chatFontSize.round()),
        value: settings.chatFontSize,
        min: 12,
        max: 24,
        divisions: 12,
        onChanged: (v) => notifier.setChatFontSize(v),
      ),
    ]);

    final personalityCard = _SettingsCard(children: [
      _SwitchTile(
        title: context.l10n.personalityReminder,
        subtitle: context.l10n.reminderNote,
        value: settings.reminderEnabled,
        onChanged: (v) => notifier.setReminderEnabled(v),
      ),
      if (settings.reminderEnabled) ...[
        _Divider(),
        _SliderTile(
          title: context.l10n.reminderFrequency,
          valueLabel: context.l10n.everyNMessages(settings.reminderInterval),
          value: settings.reminderInterval.toDouble(),
          min: 1,
          max: 20,
          divisions: 20,
          onChanged: (v) => notifier.setReminderInterval(v.round()),
        ),
      ],
    ]);

    final creativityCard = _SettingsCard(children: [
      _SliderTile(
        title: context.l10n.creativity,
        valueLabel:
        settings.generationTemperature.toStringAsFixed(2),
        value: settings.generationTemperature,
        min: 0.1,
        max: 1.5,
        divisions: 15,
        onChanged: (v) => notifier.setGenerationTemperature(v),
      ),
    ]);

    final summarizationCard = _SettingsCard(children: [
      _SwitchTile(
        title: context.l10n.summarizationEnabled,
        subtitle: context.l10n.summarizationEnabledDesc,
        value: settings.summarizationEnabled,
        onChanged: (v) => notifier.setSummarizationEnabled(v),
      ),
      if (settings.summarizationEnabled) ...[
        _Divider(),
        _SliderTile(
          title: context.l10n.messages,
          valueLabel:
          '${settings.summarizationThreshold} ${context.l10n.messages}',
          value: settings.summarizationThreshold.toDouble(),
          min: 20,
          max: 100,
          divisions: 20,
          onChanged: (v) =>
              notifier.setSummarizationThreshold(v.round()),
        ),
        _Divider(),
        _SliderTile(
          title: context.l10n.summaryMaxBlocks,
          subtitle: context.l10n.summaryMaxBlocksDesc,// новый ARB ключ
          valueLabel: '${settings.summaryMaxBlocks}',
          value: settings.summaryMaxBlocks.toDouble(),
          min: 1,
          max: 10,
          divisions: 10,
          onChanged: (v) => notifier.setSummaryMaxBlocks(v.round()),
        ),
      ],
    ]);

    final autoDeleteCard = _SettingsCard(children: [
      _SwitchTile(
        title: context.l10n.autoDeleteImages,
        subtitle: context.l10n.autoDeleteImagesDescription,
        value: settings.autoDeleteChatImagesEnabled,
        onChanged: (v) => notifier.setAutoDeleteEnabled(v),
      ),
      if (settings.autoDeleteChatImagesEnabled) ...[
        _Divider(),
        _SliderTile(
          title: context.l10n.autoDeleteAfter,
          valueLabel:
          '${settings.autoDeleteChatImagesDays} ${context.l10n.days}',
          value: settings.autoDeleteChatImagesDays.toDouble(),
          min: 7,
          max: 60,
          divisions: 30,
          onChanged: (v) => notifier.setAutoDeleteDays(v.round()),
        ),
      ],
    ]);

    final userInputCard = _SettingsCard(children: [
      _SliderTile(
        title: context.l10n.userInputLimit,
        valueLabel:
        context.l10n.charactersLabel(settings.userInputLimit),
        value: settings.userInputLimit.toDouble(),
        min: 400,
        max: 8000,
        divisions: 15,
        onChanged: (v) => notifier.setUserInputLimit(v.round()),
      ),
    ]);

    final aiResponseCard = _SettingsCard(children: [
      _SliderTile(
        title: context.l10n.aiResponseLimit,
        valueLabel:
        context.l10n.tokensLabel(settings.aiResponseLimit),
        value: settings.aiResponseLimit.toDouble(),
        min: 100,
        max: 4000,
        divisions: 30,
        onChanged: (v) => notifier.setAiResponseLimit(v.round()),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: GestureDetector(
          onTap: () => _showTokenInfoDialog(context),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 15, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(context.l10n.whatAreTokens,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    ]);

    final clearCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.delete_sweep_outlined,
        title: context.l10n.confirmClearAllSummarizations,
        subtitle: context.l10n.clearAllSummarizationsWarning,
        destructive: true,
        onTap: () => _confirmClear(context, notifier),
      ),
    ]);

    final backupCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.upload_outlined,
        title: context.l10n.backupExport,
        subtitle: context.l10n.backupExportDesc,
        onTap: () => BackupService.exportBackup(context),
      ),
      _Divider(),
      _NavTile(
        icon: Icons.download_outlined,
        title: context.l10n.backupImport,
        subtitle: context.l10n.backupImportDesc,
        onTap: () => BackupService.importBackup(context, ref),
      ),
    ]);

    final currentLocale = settings.selectedLocale;

    final currentLocaleName = currentLocale == null
        ? context.l10n.systemLanguage
        : _supportedLocales
        .firstWhere(
          (l) => l.code == currentLocale,
      orElse: () => (code: currentLocale, name: currentLocale),
    )
        .name;

    final languageCard = _SettingsCard(children: [
      _NavTile(
        icon: Icons.language,
        title: context.l10n.language,
        subtitle: currentLocaleName,
        onTap: () => _showLanguageSheet(context, currentLocale, notifier),
      ),
    ]);
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.settings),
      body: useDesktop
          ? _buildDesktopBody(
        aboutCard: aboutCard,
        apiKeysCard: apiKeysCard,
        supportCard: supportCard,
        languageCard: languageCard,
        chatFontCard: chatFontCard,
        backupCard: backupCard,
        creativityCard: creativityCard,
        personalityCard: personalityCard,
        summarizationCard: summarizationCard,
        autoDeleteCard: autoDeleteCard,
        userInputCard: userInputCard,
        aiResponseCard: aiResponseCard,
        clearCard: clearCard,

      )
          : _buildMobileBody(
        aboutCard: aboutCard,
        apiKeysCard: apiKeysCard,
        supportCard: supportCard,
        languageCard: languageCard,
        chatFontCard: chatFontCard,
        backupCard: backupCard,
        creativityCard: creativityCard,
        personalityCard: personalityCard,
        summarizationCard: summarizationCard,
        autoDeleteCard: autoDeleteCard,
        userInputCard: userInputCard,
        aiResponseCard: aiResponseCard,
        clearCard: clearCard,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — один столбец, без изменений
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileBody({
    required Widget aboutCard,
    required Widget supportCard,
    required Widget apiKeysCard,
    required Widget chatFontCard,
    required Widget personalityCard,
    required Widget creativityCard,
    required Widget summarizationCard,
    required Widget autoDeleteCard,
    required Widget userInputCard,
    required Widget aiResponseCard,
    required Widget clearCard,
    required Widget backupCard,
    required Widget languageCard,
  }) {
    const gap = SizedBox(height: 12);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        aboutCard,       gap,
        apiKeysCard,     gap,
        languageCard,    gap,
        supportCard,     gap,
        backupCard,      gap,
        chatFontCard,    gap,
        creativityCard,  gap,
        personalityCard, gap,
        summarizationCard, gap,
        clearCard,       gap,
        autoDeleteCard,  gap,
        userInputCard,   gap,
        aiResponseCard,
        const SizedBox(height: 32),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT — два независимых столбца
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopBody({
    required Widget aboutCard,
    required Widget supportCard,
    required Widget apiKeysCard,
    required Widget chatFontCard,
    required Widget personalityCard,
    required Widget creativityCard,
    required Widget summarizationCard,
    required Widget autoDeleteCard,
    required Widget userInputCard,
    required Widget aiResponseCard,
    required Widget clearCard,
    required Widget backupCard,
    required Widget languageCard,
  }) {
    const gap = SizedBox(height: 12);

    final leftColumn = <Widget>[
      aboutCard,         gap,
      supportCard,       gap,
      chatFontCard,      gap,
      creativityCard,    gap,
      personalityCard,   gap,
      autoDeleteCard,    gap,
      userInputCard,     gap,
      aiResponseCard,

    ];

    final rightColumn = <Widget>[
      apiKeysCard,      gap,
      languageCard,     gap,
      backupCard,       gap,
      summarizationCard,gap,
      clearCard,

    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leftColumn,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rightColumn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, dynamic notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.confirmClearAllSummarizations,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.clearAllSummarizationsWarning,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel,
                style: const TextStyle(
                    color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await notifier.clearAllSummaries();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                    Text(context.l10n.allSummarizationsCleared),
                    backgroundColor: AppTheme.primaryAccent,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${context.l10n.errorClearingSummaries}: $e'),
                    backgroundColor: AppTheme.warning,
                  ));
                }
              }
            },
            child: Text(context.l10n.clear,
                style:
                const TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable sub-widgets (без изменений)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    color: AppTheme.cardBorder,
    indent: 16,
    endIndent: 16,
  );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
    destructive ? AppTheme.warning : AppTheme.primaryAccent;
    final titleColor =
    destructive ? AppTheme.warning : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String? subtitle;  // новый опциональный параметр
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    this.subtitle,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(valueLabel,
                  style: const TextStyle(
                      color: AppTheme.primaryAccent, fontSize: 14)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
// ── Общий тип для записи локали ──────────────────────────────────────────
typedef _LocaleEntry = ({String? code, String nameKey, String nameNative});

// ── Карточка языка (общая для шита и диалога) ────────────────────────────
class _LangCard extends StatelessWidget {
  final _LocaleEntry loc;
  final bool selected;
  final VoidCallback onTap;

  const _LangCard({
    required this.loc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryAccent.withValues(alpha: 0.12)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryAccent : AppTheme.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.nameKey,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.primaryAccent
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (loc.nameNative.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      loc.nameNative,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppTheme.primaryAccent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Мобильный bottom sheet ────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  final List<_LocaleEntry> locales;
  final String? currentLocale;
  final SettingsNotifier notifier;

  const _LanguageSheet({
    required this.locales,
    required this.currentLocale,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 14, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: locales.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final loc = locales[i];
                return _LangCard(
                  loc: loc,
                  selected: loc.code == currentLocale,
                  onTap: () {
                    notifier.setLocale(loc.code);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Десктопный диалог ─────────────────────────────────────────────────────
class _LanguageDialog extends StatelessWidget {
  final List<_LocaleEntry> locales;
  final String? currentLocale;
  final SettingsNotifier notifier;

  const _LanguageDialog({
    required this.locales,
    required this.currentLocale,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D0D10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.language,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: AppTheme.textSecondary, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: locales.length,
                  itemBuilder: (_, i) {
                    final loc = locales[i];
                    return _LangCard(
                      loc: loc,
                      selected: loc.code == currentLocale,
                      onTap: () {
                        notifier.setLocale(loc.code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
