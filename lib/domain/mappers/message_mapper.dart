import 'package:nsfw_chat/data/models/chat_message_model.dart';
import 'package:nsfw_chat/domain/entities/message_entity.dart';

/// Maps between [ChatMessageModel] and [MessageEntity].
class MessageMapper {
  MessageMapper._();

  static MessageEntity toEntity(ChatMessageModel model) => MessageEntity(
        id: model.id,
        personaId: model.personaId,
        senderName: model.senderName,
        content: model.content,
        isUser: model.isUser,
        timestamp: model.timestamp,
      );

  static ChatMessageModel toModel(MessageEntity entity) => ChatMessageModel(
        id: entity.id,
        personaId: entity.personaId,
        senderName: entity.senderName,
        content: entity.content,
        isUser: entity.isUser,
        timestamp: entity.timestamp,
      );

  static List<MessageEntity> toEntityList(List<ChatMessageModel> models) =>
      models.map(toEntity).toList();

  static List<ChatMessageModel> toModelList(List<MessageEntity> entities) =>
      entities.map(toModel).toList();
}
