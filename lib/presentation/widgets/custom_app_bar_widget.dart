
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/screens/about_app_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';

import '../../core/config/app_theme.dart';


class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  const CustomAppBar({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    const whiteStyle = TextStyle(color: AppTheme.textPrimary,fontSize: 20,
      fontWeight: FontWeight.w400);
    return AppBar(
      iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      title: Text(title ?? context.l10n.appTitle,
          textAlign: TextAlign.center,
          style: whiteStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      centerTitle: true,
      foregroundColor: AppTheme.textPrimary,
      actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 26, color: AppTheme.accentVivid),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AboutAppScreen()),
              );
            }),

    Padding(
      padding: const EdgeInsets.only(right: 8, left: 0),
      child: IconButton(
      icon: const Icon(Icons.settings, size: 26, color: AppTheme.textPrimary),
      tooltip: context.l10n.chats,
      onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
      builder: (_) => SettingsScreen()
      ),
      )
      ),
    ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}