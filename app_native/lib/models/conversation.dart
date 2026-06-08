class ConversationMemberInfo {
  final String userId;
  final String fullName;
  final String? employeeCode;
  final String? avatarUrl;
  final bool isAdmin;
  final String role;
  final bool canChat;

  ConversationMemberInfo({
    required this.userId,
    required this.fullName,
    this.employeeCode,
    this.avatarUrl,
    required this.isAdmin,
    this.role = 'MEMBER',
    this.canChat = true,
  });

  factory ConversationMemberInfo.fromJson(Map<String, dynamic> json) {
    return ConversationMemberInfo(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isAdmin: json['isAdmin'] == true,
      role: json['role']?.toString() ?? (json['isAdmin'] == true ? 'ADMIN' : 'MEMBER'),
      canChat: json['canChat'] != false,
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
  final ConversationMessageInfo? pinnedMessage;
  final bool isPinned;
  final DateTime? pinnedAt;
  final bool notificationsMuted;
  final int unreadCount;
  final DateTime createdAt;

  ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    required this.members,
    this.lastMessage,
    this.pinnedMessage,
    this.isPinned = false,
    this.pinnedAt,
    this.notificationsMuted = false,
    required this.unreadCount,
    required this.createdAt,
  });

  ChatConversation copyWith({
    String? id,
    String? type,
    String? name,
    String? avatarUrl,
    List<ConversationMemberInfo>? members,
    ConversationMessageInfo? lastMessage,
    ConversationMessageInfo? pinnedMessage,
    bool? isPinned,
    DateTime? pinnedAt,
    bool? notificationsMuted,
    int? unreadCount,
    DateTime? createdAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      pinnedMessage: pinnedMessage ?? this.pinnedMessage,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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
      pinnedMessage: json['pinnedMessage'] != null
          ? ConversationMessageInfo.fromJson(json['pinnedMessage'])
          : null,
      isPinned: json['pinned'] == true,
      pinnedAt: json['pinnedAt'] != null
          ? DateTime.tryParse(json['pinnedAt'].toString())
          : null,
      notificationsMuted: json['notificationsMuted'] == true,
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}
