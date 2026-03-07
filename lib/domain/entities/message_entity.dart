/// Domain entity for a single chat message.
class MessageEntity {
  final String id;
  final String? personaId;
  final String senderName;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const MessageEntity({
    required this.id,
    this.personaId,
    required this.senderName,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  MessageEntity copyWith({
    String? id,
    String? personaId,
    String? senderName,
    String? content,
    bool? isUser,
    DateTime? timestamp,
  }) =>
      MessageEntity(
        id: id ?? this.id,
        personaId: personaId ?? this.personaId,
        senderName: senderName ?? this.senderName,
        content: content ?? this.content,
        isUser: isUser ?? this.isUser,
        timestamp: timestamp ?? this.timestamp,
      );
}
