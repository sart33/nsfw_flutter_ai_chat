import 'package:nsfw_chat/data/models/persona_model.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';

/// Maps between [PersonaModel] (data layer) and [PersonaEntity] (domain layer).
class PersonaMapper {
  PersonaMapper._();

  static PersonaEntity toEntity(PersonaModel model) => PersonaEntity(
    id: model.id,
    name: model.name,
    description: model.description,
    greeting: model.greeting,
    avatarPath: model.avatarPath,
    avatarAssetPath: model.avatarAssetPath,
    behavior: model.behavior,
    galleryMode: model.galleryMode,
    ageVerified: model.ageVerified,
    userAppearanceEnabled: model.userAppearanceEnabled,
    userAge: model.userAge,
    userEthnicity: model.userEthnicity,
    userGender: model.userGender,
    userHairColor: model.userHairColor,
  );

  static PersonaModel toModel(PersonaEntity entity) => PersonaModel(
    id: entity.id,
    name: entity.name,
    description: entity.description,
    greeting: entity.greeting,
    avatarPath: entity.avatarPath,
    avatarAssetPath: entity.avatarAssetPath,
    behavior: entity.behavior,
    galleryMode: entity.galleryMode,
    ageVerified: entity.ageVerified,
    userAppearanceEnabled: entity.userAppearanceEnabled,
    userAge: entity.userAge,
    userEthnicity: entity.userEthnicity,
    userGender: entity.userGender,
    userHairColor: entity.userHairColor,
  );

  static List<PersonaEntity> toEntityList(List<PersonaModel> models) =>
      models.map(toEntity).toList();

  static List<PersonaModel> toModelList(List<PersonaEntity> entities) =>
      entities.map(toModel).toList();
}
