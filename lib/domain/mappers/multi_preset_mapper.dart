import 'package:nsfw_chat/data/models/multi_preset_model.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';

/// Maps between [MultiPresetModel] and [MultiPresetEntity].
class MultiPresetMapper {
  MultiPresetMapper._();

  static MultiPresetEntity toEntity(MultiPresetModel model) =>
      MultiPresetEntity(
        id: model.id,
        name: model.name,
        personaIds: List<String>.from(model.personaIds),
        greeting: model.greeting,
        behavior: model.behavior,
      );

  static MultiPresetModel toModel(MultiPresetEntity entity) =>
      MultiPresetModel(
        id: entity.id,
        name: entity.name,
        personaIds: List<String>.from(entity.personaIds),
        greeting: entity.greeting,
        behavior: entity.behavior,
      );

  static List<MultiPresetEntity> toEntityList(List<MultiPresetModel> models) =>
      models.map(toEntity).toList();
}
