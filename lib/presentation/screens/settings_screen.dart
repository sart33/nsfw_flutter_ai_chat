import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';

/// Settings screen with two sliders for adjusting limits.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User input limit ─────────────────────────────────
            const Text(
              'Лимит ввода пользователя',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${settings.userInputLimit} символов',
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.userInputLimit.toDouble(),
              min: 1000,
              max: 4000,
              divisions: 30,
              label: '${settings.userInputLimit}',
              onChanged: (v) => notifier.setUserInputLimit(v.round()),
            ),

            const SizedBox(height: 24),

            // ── AI response limit ────────────────────────────────
            const Text(
              'Лимит ответа AI',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${settings.aiResponseLimit} символов',
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

            const SizedBox(height: 16),

            // ── Multi-chat note ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Для мульти-чата умножается на количество персонажей',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── AI response limit ────────────────────────────────
            const Text(
              'Частота повтора промпта.',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '1 / ${settings.reminderInterval} сообщений',
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: 14,
              ),
            ),
            Slider(
              value: settings.reminderInterval.toDouble(),
              min: 1,
              max: 20,
              divisions: 60,
              label: '${settings.reminderInterval}',
              onChanged: (v) => notifier.setReminderInterval(v.round()),
            ),

            const SizedBox(height: 24),

            // ── Chat font size ─────────────────────────────────────
            const Text(
              'Размер текста в чате',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${settings.chatFontSize.round()}px',
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
          ],
        ),
      ),
    );
  }
}
