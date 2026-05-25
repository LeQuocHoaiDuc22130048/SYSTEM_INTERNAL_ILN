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

class ChatMessage {
  final String id;
  final String conversationId;
  final SenderInfo sender;
  final String content;
  final String? mediaUrl;
  final String messageType;
  final DateTime sentAt;
  final List<String> readByUserIds;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    this.mediaUrl,
    required this.messageType,
    required this.sentAt,
    required this.readByUserIds,
  });

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
      readByUserIds: (json['readByUserIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
    );
  }
}
