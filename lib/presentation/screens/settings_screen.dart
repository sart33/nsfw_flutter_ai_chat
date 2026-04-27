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

final _supportedLocales = [
  (code: 'en', name: 'English'),
  (code: 'ru', name: 'Русский'),
  (code: 'uk', name: 'Українська'),
  (code: 'es', name: 'Español'),
  (code: 'pt', name: 'Português'),
  (code: 'hi', name: 'हिन्दी'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
        onTap: () => BackupService.importBackup(context),
      ),
    ]);

    final currentLocale = settings.selectedLocale;

    final languageCard = _SettingsCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.language, // добавь в ARB
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // «Системный» чип
                _LocaleChip(
                  label: context.l10n.systemLanguage, // добавь в ARB
                  selected: currentLocale == null,
                  onTap: () => notifier.setLocale(null),
                ),
                ..._supportedLocales.map((loc) => _LocaleChip(
                  label: loc.name,
                  selected: currentLocale == loc.code,
                  onTap: () => notifier.setLocale(loc.code),
                )),
              ],
            ),
          ],
        ),
      ),
    ]);

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.settings),
      body: useDesktop
          ? _buildDesktopBody(
        aboutCard: aboutCard,
        supportCard: supportCard,
        apiKeysCard: apiKeysCard,
        chatFontCard: chatFontCard,
        personalityCard: personalityCard,
        creativityCard: creativityCard,
        summarizationCard: summarizationCard,
        autoDeleteCard: autoDeleteCard,
        userInputCard: userInputCard,
        aiResponseCard: aiResponseCard,
        clearCard: clearCard,
        backupCard: backupCard,
        languageCard: languageCard,
      )
          : _buildMobileBody(
        aboutCard: aboutCard,
        supportCard: supportCard,
        apiKeysCard: apiKeysCard,
        chatFontCard: chatFontCard,
        personalityCard: personalityCard,
        creativityCard: creativityCard,
        summarizationCard: summarizationCard,
        autoDeleteCard: autoDeleteCard,
        userInputCard: userInputCard,
        aiResponseCard: aiResponseCard,
        clearCard: clearCard,
        backupCard: backupCard,
        languageCard: languageCard,
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
        supportCard,     gap,
        apiKeysCard,     gap,
        chatFontCard,    gap,
        personalityCard, gap,
        creativityCard,  gap,
        summarizationCard, gap,
        clearCard,       gap,
        autoDeleteCard,  gap,
        userInputCard,   gap,
        aiResponseCard,  gap,
        backupCard,      gap,
        languageCard,
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
      summarizationCard, gap,
      clearCard,         gap,
      userInputCard,
    ];

    final rightColumn = <Widget>[
      apiKeysCard,      gap,
      personalityCard,  gap,
      autoDeleteCard,   gap,
      aiResponseCard,   gap,
      backupCard,       gap,
      languageCard,
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

class _LocaleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LocaleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryAccent : AppTheme.iconBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryAccent : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}