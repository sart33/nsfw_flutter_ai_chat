import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/entities/recent_chat_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/recent_chats_provider.dart';
import 'package:nsfw_chat/presentation/screens/about_app_screen.dart';
import 'package:nsfw_chat/presentation/screens/chat_screen.dart';
import 'package:nsfw_chat/presentation/screens/multi_preset_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_list_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';
import 'package:nsfw_chat/presentation/widgets/persona_card_home.dart';

import '../../data/repositories/branch_repository.dart';

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
          const SizedBox(height: 18),
          const _Headline(),
          const SizedBox(height: 16),
          _NavCard(
            icon: Icons.people_alt_outlined,
            title: context.l10n.characters,
            subtitle: context.l10n.browseGalleryOrCreatePersona,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PersonaListScreen())).then((_) => ref.invalidate(recentChatsProvider)),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.chat_bubble_outline,
            title: context.l10n.multiChat,
            subtitle: context.l10n.startGroupScenarios,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MultiPresetListScreen())).then((_) => ref.invalidate(recentChatsProvider)),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.tune_outlined,
            title: context.l10n.settings,
            subtitle: context.l10n.configureAppPreferences,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(height: 36),
          _SectionHeader(
            title: context.l10n.continueRoleplay,
            actionLabel: context.l10n.viewAll,
            onAction: () {/* TODO */},
          ),
          const SizedBox(height: 12),
          const _RecentChatsList(),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: _NewChatFab(
        onPressed: () async => _showPersonaPicker(context, ref),
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
            'Uncensored Souls',
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

  Future<void> _showPersonaPicker(BuildContext context, WidgetRef ref) async {
    final personasAsync = ref.read(personaProvider);

    final personas = switch (personasAsync) {
      AsyncData(:final value) => value,
      AsyncLoading() => await ref.read(personaProvider.future),
      AsyncError() => <PersonaEntity>[],
      _ => <PersonaEntity>[],
    };

    if (!context.mounted) return;

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
      builder: (ctx) =>
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: personas.length,
            itemBuilder: (_, i) {
              final p = personas[i];
              return PersonaCardHome(
                persona: p,
                onTap: () async {
                  Navigator.pop(ctx); // закрыть боттомшит

                  final branchRepo = BranchRepository();
                  final branch = await branchRepo.createBranch('single:${p.id}');

                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        branchId: branch.id,
                        entityId: p.id,
                        isMulti: false,
                        greeting: p.greeting,
                        title: p.name,
                      ),
                    ),
                  ).then((_) => ref.invalidate(recentChatsProvider));
                },
              );

            },
          ),
    );
  }
}

// ─────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.mainTitle,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 10),
        Text(context.l10n.mainSubtitle,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width * 0.5 - 20), // отступ для выравнивания с правой частью
            Text(context.l10n.mainText,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400
              ),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                            height: 1.4,)),
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
    const whiteStyle = TextStyle(color: AppTheme.textPrimary,fontSize: 18,
        fontWeight: FontWeight.w400);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: whiteStyle),
        // GestureDetector(
        //   onTap: onAction,
        //   child: Text(context.l10n.viewAll,
        //       style: TextStyle(
        //           color: AppTheme.accentLight,
        //           fontSize: 14,
        //           fontWeight: FontWeight.w500)),
        // ),
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
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(context.l10n.noRecentChats,
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

  String _formatTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}${context.l10n.minutesAgo}';
    if (diff.inHours < 24) return '${diff.inHours}${context.l10n.hoursAgo}';
    if (diff.inDays == 1) return context.l10n.yesterday;
    return '${diff.inDays}${context.l10n.daysAgo}';
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
              builder: (_) => ChatScreen(
                branchId: chat.branchId,
                entityId: chat.personaId,
                isMulti: false,
                greeting: '',
                title: chat.personaName,
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
                          Text(_formatTime(context, chat.updatedAt),
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
