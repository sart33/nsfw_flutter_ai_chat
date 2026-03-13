import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/data/repositories/gallery_repository.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_persona_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_view_screen.dart';
import 'package:nsfw_chat/presentation/widgets/persona_card.dart';

class PersonaListScreen extends ConsumerWidget {
  const PersonaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personaProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.characters)),
      body: personas.isEmpty
          ? Center(
              child: Text(context.l10n.noCharacters,
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: personas.length,
              itemBuilder: (context, index) {
                final persona = personas[index];
                return Dismissible(
                  key: Key(persona.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red.shade900,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) {
                    ref.read(personaProvider.notifier).delete(persona.id);
                    GalleryRepository.instance.deleteAllForPersona(persona.id);
                  },
                  child: PersonaCard(
                    persona: persona,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BranchListScreen(
                          entityId: 'single:${persona.id}',
                          entityName: persona.name,
                          isMulti: false,
                          greeting: persona.greeting,
                        ),
                      ),
                    ),
                    // onLongPress: () => _showOptions(context, ref, persona.id),
                    // onTap: () => _showOptions(context, ref, persona),
                    onLongPress: () => _showOptions(context, ref, persona),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CreateEditPersonaScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(context.l10n.deleteCharacter,
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(context.l10n.cannotBeUndone,
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.delete, style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, dynamic persona) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: AppTheme.textPrimary),
              title: Text(context.l10n.view,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PersonaViewScreen(persona: persona)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: Text(context.l10n.editCharacter,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CreateEditPersonaScreen(personaId: persona.id)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.textPrimary),
              title: Text(context.l10n.chats,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BranchListScreen(
                      entityId: 'single:${persona.id}',
                      entityName: persona.name,
                      isMulti: false,
                      greeting: persona.greeting,
                    )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(context.l10n.delete,
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  ref.read(personaProvider.notifier).delete(persona.id);
                  GalleryRepository.instance.deleteAllForPersona(persona.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
