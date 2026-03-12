import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/multi_preset_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';
import 'package:nsfw_chat/l10n/app_localizations.dart';

/// Home screen — menu with navigation + FAB to start a new single chat.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('NSFW Chat')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            _menuButton(
              context,
              icon: Icons.people,
              label: context.l10n.characters,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonaListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _menuButton(
              context,
              icon: Icons.group,
              label: context.l10n.multiChat,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MultiPresetListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _menuButton(
              context,
              icon: Icons.settings,
              label: context.l10n.settings,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPersonaPicker(context, ref),
        icon: const Icon(Icons.chat),
        label: Text(context.l10n.newChat),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Shows a bottom sheet to pick a persona for a new single chat.
  void _showPersonaPicker(BuildContext context, WidgetRef ref) {
    final personas = ref.read(personaProvider);
    if (personas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noCharactersCreate)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: personas.length,
        itemBuilder: (_, i) {
          final p = personas[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.userBubble,
              child: Text(
                p.name.isNotEmpty ? p.name[0] : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(p.name,
                style: const TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              _openChat(context, p);
            },
          );
        },
      ),
    );
  }

  void _openChat(BuildContext context, PersonaEntity persona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchListScreen(
          entityId: 'single:${persona.id}',
          entityName: persona.name,
          isMulti: false,
          greeting: persona.greeting,
        ),
      ),
    );
  }
}
