import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/api_keys_screen.dart';
import 'package:nsfw_chat/presentation/screens/support_the_project.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';

import 'about_app_screen.dart';

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
                style: const TextStyle(color: AppTheme.primaryAccent)),
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
            padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(col1, style: style)),
        Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(col2, style: style)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.settings),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [

          // ── About — отдельная карточка ─────────────────────────
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.info_outline,
              title: context.l10n.aboutAppTitle,
              subtitle: 'Стоимость, приватность, поддержка проекта',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AboutAppScreen())),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Support the project — отдельная карточка ─────────────────────────
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.money,
              title: context.l10n.supportProjectTitle,
              subtitle: 'Стоимость, приватность, поддержка проекта',
              onTap: () =>
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const SupportProjectScreen())),
            ),
          ]),

          const SizedBox(height: 12),

          // ── API Keys — отдельная карточка ──────────────────────
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.vpn_key_outlined,
              title: context.l10n.apiKeys,
              subtitle: context.l10n.manageApiKeys,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ApiKeysScreen())),
            ),
          ]),

          const SizedBox(height: 12),


          // ── Chat text size ─────────────────────────────────────
          _SettingsCard(children: [
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
          ]),

          const SizedBox(height: 12),

          // ── Personality reminder + frequency (одна карточка) ───
          _SettingsCard(children: [
            _SwitchTile(
              title: context.l10n.personalityReminder,
              subtitle: context.l10n.reminderNote,
              value: settings.reminderEnabled,
              onChanged: (v) => notifier.setReminderEnabled(v),
            ),
            _Divider(),
            _SliderTile(
              title: context.l10n.reminderFrequency,
              valueLabel:
              context.l10n.everyNMessages(settings.reminderInterval),
              value: settings.reminderInterval.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => notifier.setReminderInterval(v.round()),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Response creativity ────────────────────────────────
          _SettingsCard(children: [
            _SliderTile(
              title: context.l10n.creativity,
              valueLabel:
              settings.generationTemperature.toStringAsFixed(2),
              value: settings.generationTemperature,
              min: 0.1,
              max: 1.5,
              divisions: 28,
              onChanged: (v) => notifier.setGenerationTemperature(v),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Summarization ──────────────────────────────────────
          _SettingsCard(children: [
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
                min: 30,
                max: 200,
                divisions: 17,
                onChanged: (v) =>
                    notifier.setSummarizationThreshold(v.round()),
              ),
            ],
          ]),

          const SizedBox(height: 12),

          // ── Auto-delete chat images ────────────────────────────
          _SettingsCard(children: [
            _SwitchTile(
              title: 'Auto-delete old chat images',
              subtitle:
              'Automatically delete chat images older than specified days',
              value: settings.autoDeleteChatImagesEnabled,
              onChanged: (v) => notifier.setAutoDeleteEnabled(v),
            ),
            if (settings.autoDeleteChatImagesEnabled) ...[
              _Divider(),
              _SliderTile(
                title: 'Auto-delete after',
                valueLabel: '${settings.autoDeleteChatImagesDays} days',
                value: settings.autoDeleteChatImagesDays.toDouble(),
                min: 7,
                max: 60,
                divisions: 53,
                onChanged: (v) =>
                    notifier.setAutoDeleteDays(v.round()),
              ),
            ],
          ]),

          const SizedBox(height: 12),

          // ── User input limit ───────────────────────────────────
          _SettingsCard(children: [
            _SliderTile(
              title: context.l10n.userInputLimit,
              valueLabel:
              context.l10n.charactersLabel(settings.userInputLimit),
              value: settings.userInputLimit.toDouble(),
              min: 1000,
              max: 8000,
              divisions: 60,
              onChanged: (v) => notifier.setUserInputLimit(v.round()),
            ),
          ]),

          const SizedBox(height: 12),

          // ── AI response limit ──────────────────────────────────
          _SettingsCard(children: [
            _SliderTile(
              title: context.l10n.aiResponseLimit,
              valueLabel:
              context.l10n.tokensLabel(settings.aiResponseLimit),
              value: settings.aiResponseLimit.toDouble(),
              min: 2000,
              max: 8000,
              divisions: 60,
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
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Clear all summaries ────────────────────────────────
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.delete_sweep_outlined,
              title: context.l10n.confirmClearAllSummarizations,
              subtitle: context.l10n.clearAllSummarizationsWarning,
              destructive: true,
              onTap: () => _confirmClear(context, notifier),
            ),
          ]),

          const SizedBox(height: 32),
        ],
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
                style:
                const TextStyle(color: AppTheme.textSecondary)),
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
            // оранжевый вместо красного для destructive-действия
            child: Text(context.l10n.clear,
                style: const TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable sub-widgets
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

/// Switch уменьшен через Transform.scale(0.8) —
/// визуально компактнее, touch target остаётся нормальным.
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
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
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