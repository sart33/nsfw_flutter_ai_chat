import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/domain/entities/recent_chat_entity.dart';

import '../../domain/entities/recent_multichat_entity.dart';





sealed class RecentItem {
  DateTime get updatedAt;
}

class RecentSingleItem extends RecentItem {
  final RecentChatEntity chat;
  RecentSingleItem(this.chat);
  @override
  DateTime get updatedAt => chat.updatedAt;
}

class RecentMultiItem extends RecentItem {
  final RecentMultiEntity chat;
  RecentMultiItem(this.chat);
  @override
  DateTime get updatedAt => chat.updatedAt;
}

final recentItemsProvider = FutureProvider<List<RecentItem>>((ref) async {
  final branchRepo = BranchRepository(); // ← подставь свой провайдер репозитория (тот же источник, что и в recentChatsProvider)
  final results = await Future.wait([
    branchRepo.getRecentChats(limit: 8),
    branchRepo.getRecentMultiChats(limit: 8),
  ]);
  final singles = results[0] as List<RecentChatEntity>;
  final multis = results[1] as List<RecentMultiEntity>;

  final items = <RecentItem>[
    ...singles.map(RecentSingleItem.new),
    ...multis.map(RecentMultiItem.new),
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return items.take(8).toList();
});
