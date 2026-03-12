/// Constant identifiers for message sender roles.
///
/// These are stored in the database as [senderName] on [ChatMessageModel].
/// The UI layer maps them to localised display strings via [_resolveSenderName].
class ChatConstants {
  ChatConstants._();

  /// Identifies a message sent by the human user.
  static const String userSender = 'user';

  /// Identifies a system-injected message (e.g. multi-chat greeting).
  static const String systemSender = 'system';

  /// Fallback sender name when no persona name is available.
  static const String aiSender = 'ai';
}
