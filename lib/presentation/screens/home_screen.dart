import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/entities/recent_chat_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/recent_chats_provider.dart';
import 'package:nsfw_chat/presentation/screens/about_app_screen.dart';
import 'package:nsfw_chat/presentation/screens/branch_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/multi_preset_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';

// ─────────────────────────────────────────────
//  HomeScreen
// ─────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 28),
          const _Headline(),
          const SizedBox(height: 32),
          _NavCard(
            icon: Icons.people_alt_outlined,
            title: context.l10n.characters,
            subtitle: 'Browse the gallery or create a new custom persona from scratch.',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PersonaListScreen())).then((_) => ref.invalidate(recentChatsProvider)),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.chat_bubble_outline,
            title: context.l10n.multiChat,
            subtitle: 'Start dynamic group scenarios with multiple AI characters at once.',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MultiPresetListScreen())).then((_) => ref.invalidate(recentChatsProvider)),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.tune_outlined,
            title: context.l10n.settings,
            subtitle: 'Configure your app preferences, safety filters, and API models.',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(height: 36),
          _SectionHeader(
            title: 'Continue Roleplay',
            actionLabel: 'View all',
            onAction: () {/* TODO */},
          ),
          const SizedBox(height: 12),
          const _RecentChatsList(),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: _NewChatFab(
        onPressed: () => _showPersonaPicker(context, ref),
        label: context.l10n.newChat,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.accentVivid,
              backgroundBlendMode: BlendMode.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/logos/logo_1.jpg',
              width: 60,
                height: 60,
          ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Aura RP',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () {Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AboutAppScreen()),
            ).then((_) => ref.invalidate(recentChatsProvider));},
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.cardBg,
              child: Icon(Icons.info_outline, size: 26, color: AppTheme.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

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
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: personas.length,
        itemBuilder: (_, i) {
          final p = personas[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.accentVivid,
              child: Text(
                p.name.isNotEmpty ? p.name[0] : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(p.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600)),
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
    ).then((_) {
      if (mounted) ref.invalidate(recentChatsProvider);
    });
  }
}

// ─────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where imagination\ntakes over.',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Step into new worlds, create unforgettable personas, and explore '
              'limitless scenarios with advanced AI roleplay.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.accentLight, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        GestureDetector(
          onTap: onAction,
          child: const Text('View all',
              style: TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _RecentChatsList extends ConsumerWidget {
  const _RecentChatsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChats = ref.watch(recentChatsProvider);
    return asyncChats.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (chats) {
        if (chats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No recent chats yet. Start a new one!',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          );
        }
        return Column(
          children: chats.map((c) => _RecentChatCard(chat: c)).toList(),
        );
      },
    );
  }
}

class _RecentChatCard extends ConsumerWidget {
  final RecentChatEntity chat;
  const _RecentChatCard({required this.chat});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BranchListScreen(
                  entityId: chat.entityId,
                  entityName: chat.personaName,
                  isMulti: false,
                  greeting: '',
                ),
            ),
          ).then((_) => ref.invalidate(recentChatsProvider)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: AppTheme.cardDecoration(radius: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AvatarWidget(
                    imagePath: chat.avatarPath,
                    assetPath: chat.avatarAssetPath,
                    name: chat.personaName,
                    size: 52,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(chat.personaName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatTime(chat.updatedAt),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.preview ?? '...',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewChatFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _NewChatFab({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppTheme.accentVivid,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32)),
      icon: const Icon(Icons.chat_bubble_outline, size: 20),
      label: Text(label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2)),
    );
  }
}
