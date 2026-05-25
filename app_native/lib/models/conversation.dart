class ConversationMemberInfo {
  final String userId;
  final String fullName;
  final String? employeeCode;
  final String? avatarUrl;
  final bool isAdmin;

  ConversationMemberInfo({
    required this.userId,
    required this.fullName,
    this.employeeCode,
    this.avatarUrl,
    required this.isAdmin,
  });

  factory ConversationMemberInfo.fromJson(Map<String, dynamic> json) {
    return ConversationMemberInfo(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isAdmin: json['isAdmin'] == true,
    );
  }
}

class ConversationMessageInfo {
  final String id;
  final String senderName;
  final String content;
  final String messageType;
  final DateTime sentAt;

  ConversationMessageInfo({
    required this.id,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.sentAt,
  });

  factory ConversationMessageInfo.fromJson(Map<String, dynamic> json) {
    return ConversationMessageInfo(
      id: json['id']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'].toString())
          : DateTime.now(),
    );
  }
}

class ChatConversation {
  final String id;
  final String type;
  final String name;
  final String? avatarUrl;
  final List<ConversationMemberInfo> members;
  final ConversationMessageInfo? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    required this.members,
    this.lastMessage,
    required this.unreadCount,
    required this.createdAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DIRECT',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      members: (json['members'] as List? ?? [])
          .map((m) => ConversationMemberInfo.fromJson(m))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? ConversationMessageInfo.fromJson(json['lastMessage'])
          : null,
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}
