import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/data/repositories/branch_repository.dart';
import 'package:nsfw_chat/data/repositories/persona_repository.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/entities/recent_chat_entity.dart';
import 'package:nsfw_chat/domain/mappers/persona_mapper.dart';

final recentChatsProvider = FutureProvider<List<RecentChatEntity>>((ref) async {
  final branchRepo = BranchRepository();
  final personaRepo = PersonaRepository();
  
  final branches = await branchRepo.getRecentSingleBranches(limit: 5);
  final personaModels = await personaRepo.getAll();
  final personas = personaModels.when(
    success: (models) => PersonaMapper.toEntityList(models),
    failure: (_, __) => <PersonaEntity>[],
  );
  
  final result = <RecentChatEntity>[];
  for (final branch in branches) {
    final personaId = branch.entityId.replaceFirst('single:', '');
    PersonaEntity? persona;
    try {
      persona = personas.firstWhere((p) => p.id == personaId);
    } catch (_) {
      // Persona not found (might have been deleted)
      continue;
    }
    
    result.add(RecentChatEntity(
      branchId: branch.id,
      entityId: branch.entityId,
      personaId: personaId,
      personaName: persona.name,
      avatarPath: persona.avatarPath,
      avatarAssetPath: persona.avatarAssetPath,
      preview: branch.preview,
      updatedAt: branch.updatedAt,
    ));
  }
  return result;
});
