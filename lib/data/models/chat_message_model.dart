import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data-layer model for a single chat message (user or AI).
class ChatMessageModel {
  final String id;
  final String? personaId;
  final String senderName;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? branchId;
  final bool isQuickAction;

  ChatMessageModel({
    String? id,
    this.personaId,
    required this.senderName,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.branchId,
    this.isQuickAction = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  // ── SQLite-compatible serialisation ────────────────────────────────────

  /// Returns a map matching the 'messages' table columns.
  /// [is_user] is stored as int (0 or 1).
  /// [timestamp] is stored as millisecondsSinceEpoch.
  Map<String, dynamic> toMap() => {
        'id': id,
        'persona_id': personaId,
        'sender_name': senderName,
        'content': content,
        'is_user': isUser ? 1 : 0,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'is_quick_action': isQuickAction ? 1 : 0,
      };

  /// Creates a model from a SQLite row map.
  /// Handles [is_user] as int (0/1) or bool for backward compat.
  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    // Handle is_user as int (SQLite) or bool (legacy JSON).
    final rawIsUser = map['is_user'] ?? map['isUser'];
    final bool isUser;
    if (rawIsUser is int) {
      isUser = rawIsUser == 1;
    } else if (rawIsUser is bool) {
      isUser = rawIsUser;
    } else {
      isUser = false;
    }

    // Handle timestamp as int (SQLite epoch ms) or String (ISO 8601).
    final rawTs = map['timestamp'];
    final DateTime timestamp;
    if (rawTs is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return ChatMessageModel(
      id: map['id'] as String,
      personaId: (map['persona_id'] ?? map['personaId']) as String?,
      senderName: (map['sender_name'] ?? map['senderName']) as String,
      content: map['content'] as String,
      isUser: isUser,
      timestamp: timestamp,
      branchId: map['branch_id'] as String?,
      isQuickAction: (map['is_quick_action'] as int? ?? 0) == 1,
    );
  }

  // ── JSON helpers (kept for backward compat) ────────────────────────────

  String toJson() => jsonEncode(toMap());

  factory ChatMessageModel.fromJson(String source) =>
      ChatMessageModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  ChatMessageModel copyWith({
    String? id,
    String? personaId,
    String? senderName,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? branchId,
    bool? isQuickAction,
  }) =>
      ChatMessageModel(
        id: id ?? this.id,
        personaId: personaId ?? this.personaId,
        senderName: senderName ?? this.senderName,
        content: content ?? this.content,
        isUser: isUser ?? this.isUser,
        timestamp: timestamp ?? this.timestamp,
        branchId: branchId ?? this.branchId,
        isQuickAction: isQuickAction ?? this.isQuickAction,
      );
}
