import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';

class ChatImageCleanupService {
  ChatImageCleanupService._();
  static final instance = ChatImageCleanupService._();

  Future<void> runIfEnabled(SettingsState settings) async {
    if (!settings.autoDeleteChatImagesEnabled) return;
    final cutoffMs = DateTime.now()
        .subtract(Duration(days: settings.autoDeleteChatImagesDays))
        .millisecondsSinceEpoch;
    final rows = await DatabaseHelper.instance.getOldChatImageMessages(cutoffMs);
    if (rows.isEmpty) return;
    for (final row in rows) {
      final path = row['imageLocalPath'] as String?;
      if (path != null) {
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
    final ids = rows.map((r) => r['id'] as String).toList();
    await DatabaseHelper.instance.deleteMessagesByIds(ids);
    debugPrint('[ChatImageCleanup] Deleted ${ids.length} old chat images');
  }
}