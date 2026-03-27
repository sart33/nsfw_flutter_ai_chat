import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/domain/entities/recent_chat_entity.dart';

final recentChatsProvider = FutureProvider<List<RecentChatEntity>>((ref) async {
  final branchRepo = BranchRepository();
  return branchRepo.getRecentChats(limit: 5);
});
