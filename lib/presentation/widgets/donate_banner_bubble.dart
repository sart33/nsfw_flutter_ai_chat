import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';

class DonateBannerBubble extends StatelessWidget {
  final bool isSecond; // true = banner_2 текст
  final VoidCallback onSupport;
  final VoidCallback onDismiss;

  const DonateBannerBubble({
    super.key,
    required this.isSecond,
    required this.onSupport,
    required this.onDismiss,
  });


  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    try {
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return MediaQuery.of(context).size.width >= AppTheme.kDesktopBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватарка — иконка приложения
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              color: AppTheme.background,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10,top: 10),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.cardBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              isSecond
                                  ? context.l10n.supportChatMessageSecond
                                  : context.l10n.supportChatMessageFirst,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onDismiss,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: SizedBox(height: 1,)),
                          GestureDetector(
                            onTap: onSupport,
                            child: SizedBox(
                              width: 260,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.favorite_outline,
                                    color: AppTheme.primaryAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.l10n.supportChatMessageSupport,
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 15,
                                      color: AppTheme.textChatSupport
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Column(
                                    children: [
                                      SizedBox(height: _isDesktop(context) ? 5 : 2),
                                      Icon(Icons.chevron_right,
                                        color: AppTheme.textPrimary,
                                        size: 21,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Expanded(child: SizedBox(height: 1,)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}