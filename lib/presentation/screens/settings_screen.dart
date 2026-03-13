import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/api_keys_screen.dart';

/// Settings screen with sliders and toggles for adjusting limits and features.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showTokenInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          context.l10n.tokensAndText,
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.tokenExplanation,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
              Table(
                border: TableBorder.all(
                  color: AppTheme.textSecondary,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.5),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.tokens,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.approximateVolume,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          '1 000',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.words750,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          '2 000',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.words1500,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          '4 000',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.words3000,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          '8 192',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          context.l10n.maxDeepSeek,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.usuallyEnough,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.understood,
              style: TextStyle(color: AppTheme.primaryAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    const whiteStyle = TextStyle(color: AppTheme.textPrimary);
    const graySmall = TextStyle(color: AppTheme.textSecondary, fontSize: 12);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User input limit ─────────────────────────────────
            Text(
              context.l10n.userInputLimit,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.charactersLabel(settings.userInputLimit),
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.userInputLimit.toDouble(),
              min: 1000,
              max: 8000,
              divisions: 60,
              label: '${settings.userInputLimit}',
              onChanged: (v) => notifier.setUserInputLimit(v.round()),
            ),

            const SizedBox(height: 24),

            // ── AI response limit ────────────────────────────────
            Text(
              context.l10n.aiResponseLimit,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.tokensLabel(settings.aiResponseLimit),
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.aiResponseLimit.toDouble(),
              min: 2000,
              max: 8000,
              divisions: 60,
              label: '${settings.aiResponseLimit}',
              onChanged: (v) => notifier.setAiResponseLimit(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showTokenInfoDialog(context),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.whatAreTokens,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),


            // ── Reminder interval ────────────────────────────────
            Text(
              context.l10n.reminderFrequency,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.everyNMessages(settings.reminderInterval),
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.reminderInterval.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '${settings.reminderInterval}',
              onChanged: (v) => notifier.setReminderInterval(v.round()),
            ),

            const SizedBox(height: 24),

            // ── Chat font size ─────────────────────────────────────
            Text(
              context.l10n.chatFontSize,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.pixelsLabel(settings.chatFontSize.round()),
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.chatFontSize,
              min: 12,
              max: 24,
              divisions: 12,
              activeColor: AppTheme.primaryAccent,
              onChanged: (v) => notifier.setChatFontSize(v),
            ),

            const SizedBox(height: 24),

            // ── Reminder toggle ──────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.personalityReminder,
                  style: whiteStyle),
              subtitle: Text(
                context.l10n.reminderNote,
                style: graySmall,
              ),
              value: settings.reminderEnabled,
              onChanged: (v) => notifier.setReminderEnabled(v),
              activeColor: AppTheme.primaryAccent,
            ),

            const SizedBox(height: 8),

            // ── YAML persona toggle ──────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.yamlProfile, style: whiteStyle),
              subtitle: Text(
                context.l10n.yamlProfileNote,
                style: graySmall,
              ),
              value: settings.yamlPersonaEnabled,
              onChanged: (v) => notifier.setYamlPersonaEnabled(v),
              activeColor: AppTheme.primaryAccent,
            ),

            const SizedBox(height: 24),

            // ── Generation temperature ──────────────────────────────
            Text(
              context.l10n.creativity,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              settings.generationTemperature.toStringAsFixed(2),
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.generationTemperature,
              min: 0.1,
              max: 1.5,
              divisions: 28,
              activeColor: AppTheme.primaryAccent,
              onChanged: (v) => notifier.setGenerationTemperature(v),
            ),
            const SizedBox(height: 8),

            // ── Summarization toggle ─────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.summarizationEnabled,
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: Text(context.l10n.summarizationEnabledDesc,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: settings.summarizationEnabled,
              onChanged: (v) => notifier.setSummarizationEnabled(v),
              activeColor: AppTheme.primaryAccent,
            ),

            if (settings.summarizationEnabled) ...[
              const SizedBox(height: 4),
               Text(context.l10n.summarizationEnabled,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${settings.summarizationThreshold} ${context.l10n.messages}',
                style: const TextStyle(
                  color: AppTheme.primaryAccent,
                  fontSize: 14,
                ),
              ),
              Slider(
                value: settings.summarizationThreshold.toDouble(),
                min: 30,
                max: 200,
                divisions: 17,
                activeColor: AppTheme.primaryAccent,
                label: '${settings.summarizationThreshold}',
                onChanged: (v) =>
                    notifier.setSummarizationThreshold(v.round()),
              ),
            ],

            const SizedBox(height: 24),

            // ── Clear all summaries ──────────────────────────────
            Card(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.delete_sweep, color: AppTheme.primaryAccent),
                title: Text(context.l10n.confirmClearAllSummarizations,
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: Text(context.l10n.clearAllSummarizationsWarning,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary, size: 16),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: Text(context.l10n.confirmClearAllSummarizations,
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      content: Text(context.l10n.clearAllSummarizationsWarning,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.cancel,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              await notifier.clearAllSummaries();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.allSummarizationsCleared),
                                    backgroundColor: AppTheme.primaryAccent,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${context.l10n.errorClearingSummaries}: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(context.l10n.clear,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── API Keys management ──────────────────────────────
            Card(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.key, color: AppTheme.primaryAccent),
                title: Text(
                  context.l10n.apiKeys,
                  style: whiteStyle,
                ),
                subtitle: Text(
                  context.l10n.manageApiKeys,
                  style: graySmall,
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiKeysScreen(),
                    ),
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
