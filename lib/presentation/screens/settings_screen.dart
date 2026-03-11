import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/api_keys_screen.dart';

/// Settings screen with sliders and toggles for adjusting limits and features.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    const whiteStyle = TextStyle(color: AppTheme.textPrimary);
    const graySmall = TextStyle(color: AppTheme.textSecondary, fontSize: 12);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SingleChildScrollView(
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
              max: 8000,
              divisions: 60,
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
              '${settings.aiResponseLimit} токенов',
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
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: AppTheme.surface,
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: const Row(
            //     children: [
            //       Icon(
            //         Icons.info_outline,
            //         color: AppTheme.textSecondary,
            //         size: 20,
            //       ),
            //       SizedBox(width: 8),
            //       Expanded(
            //         child: Text(
            //           'Для мульти-чата умножается на количество персонажей',
            //           style: TextStyle(
            //             color: AppTheme.textSecondary,
            //             fontSize: 13,
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 24),

            // ── Reminder interval ────────────────────────────────
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
              divisions: 19,
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

            const SizedBox(height: 24),

            // ── Reminder toggle ──────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Напоминание о личности персонажа',
                  style: whiteStyle),
              subtitle: const Text(
                'Каждые N сообщений добавляет напоминание в промпт '
                '(не сохраняется в историю)',
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
              title: const Text('YAML-профиль персонажа', style: whiteStyle),
              subtitle: const Text(
                'Если включено и файл assets/characters/character_{id}.yaml '
                'существует — использовать как системный промпт',
                style: graySmall,
              ),
              value: settings.yamlPersonaEnabled,
              onChanged: (v) => notifier.setYamlPersonaEnabled(v),
              activeColor: AppTheme.primaryAccent,
            ),

            const SizedBox(height: 24),

            // ── Generation temperature ──────────────────────────────
            const Text(
              'Креативность ответа',
              style: TextStyle(
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
              onChanged: (v) =>  notifier.setGenerationTemperature(
                  double.parse(v.toStringAsFixed(2)),
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
                  'API Ключи',
                  style: whiteStyle,
                ),
                subtitle: Text(
                  'Управление ключами DeepSeek и Novita AI',
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
