class SenderInfo {
  final String userId;
  final String fullName;
  final String? avatarUrl;

  SenderInfo({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
  });

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    return SenderInfo(
      userId: (json['id'] ?? json['userId'])?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

class MessageReactionInfo {
  final String emoji;
  final int count;
  final List<String> userIds;

  MessageReactionInfo({
    required this.emoji,
    required this.count,
    required this.userIds,
  });

  factory MessageReactionInfo.fromJson(Map<String, dynamic> json) {
    return MessageReactionInfo(
      emoji: json['emoji']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
      userIds: (json['userIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final SenderInfo sender;
  final String content;
  final String? mediaUrl;
  final String messageType;
  final DateTime sentAt;
  final DateTime? editedAt;
  final DateTime? deletedForEveryoneAt;
  final List<String> readByUserIds;
  final List<String> mentionUserIds;
  final List<MessageReactionInfo> reactions;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    this.mediaUrl,
    required this.messageType,
    required this.sentAt,
    this.editedAt,
    this.deletedForEveryoneAt,
    required this.readByUserIds,
    this.mentionUserIds = const [],
    this.reactions = const [],
  });

  bool get isEdited => editedAt != null;
  bool get isRecalled => deletedForEveryoneAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      sender: SenderInfo.fromJson(json['sender'] ?? {}),
      content: json['content']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      messageType: json['messageType']?.toString() ?? 'TEXT',
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'].toString())
          : DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'].toString())
          : null,
      deletedForEveryoneAt: json['deletedForEveryoneAt'] != null
          ? DateTime.tryParse(json['deletedForEveryoneAt'].toString())
          : null,
      readByUserIds: (json['readByUserIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
      mentionUserIds: (json['mentionUserIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
      reactions: (json['reactions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MessageReactionInfo.fromJson)
          .toList(),
    );
  }
}
