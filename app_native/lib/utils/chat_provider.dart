import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final ApiClient api;
  NotificationProvider notificationProvider;

  List<ChatConversation> conversations = [];
  bool isLoadingConversations = false;
  String? conversationsError;

  // Active chat state
  String? activeConversationId;
  List<ChatMessage> activeMessages = [];
  bool isLoadingMessages = false;
  String? messagesError;

  StreamSubscription? _messageStreamSubscription;

  ChatProvider({required this.api, required this.notificationProvider}) {
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageStreamSubscription?.cancel();
    _messageStreamSubscription = notificationProvider.messageStream.listen((
      data,
    ) {
      try {
        final message = ChatMessage.fromJson(data);

        // 1. If it belongs to our active conversation, append it
        if (message.conversationId == activeConversationId) {
          // Prevent duplicates if REST API and WebSocket events trigger concurrently
          if (!activeMessages.any((m) => m.id == message.id)) {
            activeMessages = [message, ...activeMessages];
            notifyListeners();
          }
          markAsRead(message.conversationId);
        }

        // 2. Update the conversation list's lastMessage and unread count
        final index = conversations.indexWhere(
          (c) => c.id == message.conversationId,
        );
        if (index != -1) {
          final conv = conversations[index];
          final updatedConv = conv.copyWith(
            lastMessage: ConversationMessageInfo(
              id: message.id,
              senderName: message.sender.fullName,
              content: message.content,
              messageType: message.messageType,
              sentAt: message.sentAt,
            ),
            unreadCount: message.conversationId == activeConversationId
                ? 0
                : conv.unreadCount + 1,
          );
          conversations.removeAt(index);
          conversations.insert(0, updatedConv);
          _sortConversations();
          notifyListeners();
        } else {
          // If we received a message for a conversation we don't have yet, reload conversations
          loadConversations();
        }
      } catch (e) {
        debugPrint('[CHAT] Failed to process real-time message: $e');
      }
    });
  }

  String? _lastToken;

  int get totalUnreadCount {
    return conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  void updateAuthAndNotification(
    AuthProvider auth,
    NotificationProvider notifications,
  ) {
    notificationProvider = notifications;
    _subscribeToMessages();
    final token = auth.api.accessToken;
    if (auth.isAuthenticated && token != null) {
      if (token != _lastToken) {
        _lastToken = token;
        loadConversations();
      }
    } else {
      _lastToken = null;
      conversations = [];
      activeConversationId = null;
      activeMessages = [];
    }
  }

  Future<void> loadConversations() async {
    isLoadingConversations = true;
    conversationsError = null;
    notifyListeners();

    try {
      final data = await api.get('/api/v1/conversations');
      if (data is List) {
        conversations = data.map((c) => ChatConversation.fromJson(c)).toList();
        _sortConversations();
      }
    } catch (e) {
      conversationsError = e.toString();
    } finally {
      isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    activeConversationId = conversationId;
    isLoadingMessages = true;
    messagesError = null;
    activeMessages = [];
    notifyListeners();

    try {
      final data = await api.get(
        '/api/v1/conversations/$conversationId/messages',
      );
      if (data is Map<String, dynamic> && data['content'] is List) {
        final content = data['content'] as List;
        activeMessages = content.map((m) => ChatMessage.fromJson(m)).toList();
      }
      await markAsRead(conversationId);
    } catch (e) {
      messagesError = e.toString();
    } finally {
      isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    String conversationId,
    String content, {
    String? mediaUrl,
    String messageType = 'TEXT',
    List<String> mentionUserIds = const [],
  }) async {
    try {
      final data = await api.post(
        '/api/v1/conversations/$conversationId/messages',
        body: {
          'content': content,
          'mediaUrl': mediaUrl,
          'messageType': messageType,
          if (mentionUserIds.isNotEmpty) 'mentionUserIds': mentionUserIds,
        },
      );
      _consumeSentMessage(conversationId, data);
    } catch (e) {
      debugPrint('[CHAT] Failed to send message: $e');
      rethrow;
    }
  }

  Future<void> sendMediaMessage(
    String conversationId, {
    required Uint8List bytes,
    required String filename,
    required String messageType,
    String content = '',
  }) async {
    try {
      final data = await api.postMultipart(
        '/api/v1/conversations/$conversationId/messages/media',
        fields: {
          'messageType': messageType,
          if (content.trim().isNotEmpty) 'content': content.trim(),
        },
        filename: filename,
        bytes: bytes,
      );
      _consumeSentMessage(conversationId, data);
    } catch (e) {
      debugPrint('[CHAT] Failed to upload attachment: $e');
      rethrow;
    }
  }

  String mediaUrl(String mediaPath) => api.resolveUrl(mediaPath);

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String content, {
    List<String> mentionUserIds = const [],
  }) async {
    final data = await api.patch(
      '/api/v1/conversations/$conversationId/messages/$messageId',
      body: {
        'content': content,
        if (mentionUserIds.isNotEmpty) 'mentionUserIds': mentionUserIds,
      },
    );
    _replaceMessage(data);
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    final data = await api.delete(
      '/api/v1/conversations/$conversationId/messages/$messageId',
      body: {'scope': forEveryone ? 'EVERYONE' : 'ME'},
    );
    if (forEveryone) {
      _replaceMessage(data);
    } else {
      activeMessages = activeMessages.where((m) => m.id != messageId).toList();
      notifyListeners();
    }
  }

  Future<void> reactToMessage(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final data = await api.put(
      '/api/v1/conversations/$conversationId/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    _replaceMessage(data);
  }

  Future<void> removeReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final data = await api.delete(
      '/api/v1/conversations/$conversationId/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    _replaceMessage(data);
  }

  Future<void> sendTyping(String conversationId, bool typing) async {
    try {
      await api.post(
        '/api/v1/conversations/$conversationId/typing',
        body: {'typing': typing},
      );
    } catch (e) {
      debugPrint('[CHAT] Failed to send typing state: $e');
    }
  }

  Future<void> pinConversation(String conversationId, bool pinned) async {
    final data = pinned
        ? await api.put('/api/v1/conversations/$conversationId/pin')
        : await api.delete('/api/v1/conversations/$conversationId/pin');
    _replaceConversation(data);
  }

  Future<void> pinMessage(String conversationId, String messageId) async {
    final data = await api.put(
      '/api/v1/conversations/$conversationId/pinned-message/$messageId',
    );
    _replaceConversation(data);
  }

  Future<void> unpinMessage(String conversationId) async {
    final data = await api.delete(
      '/api/v1/conversations/$conversationId/pinned-message',
    );
    _replaceConversation(data);
  }

  Future<void> sendRichMediaUrl(
    String conversationId, {
    required String mediaUrl,
    required String messageType,
    String content = '',
  }) {
    return sendMessage(
      conversationId,
      content,
      mediaUrl: mediaUrl,
      messageType: messageType,
    );
  }

  Future<List<ChatMessage>> searchMessages(
    String conversationId,
    String query,
  ) async {
    final data = await api.get(
      '/api/v1/conversations/$conversationId/messages/search',
      queryParameters: {'query': query, 'size': 30},
    );
    return _messagesFromPage(data);
  }

  Future<List<ChatMessage>> loadGallery(
    String conversationId,
    String type,
  ) async {
    final data = await api.get(
      '/api/v1/conversations/$conversationId/gallery',
      queryParameters: {'type': type, 'size': 60},
    );
    return _messagesFromPage(data);
  }

  Future<void> setNotificationsMuted(
    String conversationId,
    bool muted,
  ) async {
    final data = muted
        ? await api.put('/api/v1/conversations/$conversationId/mute')
        : await api.delete('/api/v1/conversations/$conversationId/mute');
    _replaceConversation(data);
  }

  void _replaceConversation(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    final updated = ChatConversation.fromJson(data);
    final index = conversations.indexWhere((c) => c.id == updated.id);
    if (index == -1) {
      conversations.insert(0, updated);
    } else {
      conversations[index] = updated;
    }
    _sortConversations();
    notifyListeners();
  }

  void _replaceMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    final updated = ChatMessage.fromJson(data);
    final index = activeMessages.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      activeMessages[index] = updated;
      notifyListeners();
    }
  }

  List<ChatMessage> _messagesFromPage(dynamic data) {
    if (data is Map<String, dynamic> && data['content'] is List) {
      return (data['content'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
    }
    return const [];
  }

  void _consumeSentMessage(String conversationId, dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final sentMessage = ChatMessage.fromJson(data);
    if (activeConversationId == conversationId &&
        !activeMessages.any((m) => m.id == sentMessage.id)) {
      activeMessages = [sentMessage, ...activeMessages];
      notifyListeners();
    }

    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    final conv = conversations[index];
    final updatedConv = conv.copyWith(
      lastMessage: ConversationMessageInfo(
        id: sentMessage.id,
        senderName: sentMessage.sender.fullName,
        content: sentMessage.content,
        messageType: sentMessage.messageType,
        sentAt: sentMessage.sentAt,
      ),
      unreadCount: 0,
    );
    conversations.removeAt(index);
    conversations.insert(0, updatedConv);
    _sortConversations();
    notifyListeners();
  }

  Future<void> createConversation(
    String type,
    String name,
    List<String> memberIds,
  ) async {
    try {
      final data = await api.post(
        '/api/v1/conversations',
        body: {'type': type, 'name': name, 'memberIds': memberIds},
      );
      if (data is Map<String, dynamic>) {
        final newConv = ChatConversation.fromJson(data);
        final index = conversations.indexWhere((c) => c.id == newConv.id);
        if (index == -1) {
          conversations.insert(0, newConv);
          notifyListeners();
        }
        await loadMessages(newConv.id);
      }
    } catch (e) {
      debugPrint('[CHAT] Failed to create conversation: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await api.put('/api/v1/conversations/$conversationId/read');
      final index = conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final conv = conversations[index];
        if (conv.unreadCount > 0) {
          conversations[index] = ChatConversation(
            id: conv.id,
            type: conv.type,
            name: conv.name,
            avatarUrl: conv.avatarUrl,
            members: conv.members,
            lastMessage: conv.lastMessage,
            pinnedMessage: conv.pinnedMessage,
            isPinned: conv.isPinned,
            pinnedAt: conv.pinnedAt,
            notificationsMuted: conv.notificationsMuted,
            unreadCount: 0,
            createdAt: conv.createdAt,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[CHAT] Failed to mark as read: $e');
    }
  }

  Future<void> selectConversationById(String conversationId) async {
    // 1. If not loaded, or not found in current list, reload conversations list first
    int index = conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) {
      await loadConversations();
      index = conversations.indexWhere((c) => c.id == conversationId);
    }

    if (index != -1) {
      // 2. Found it, load messages and activate it
      activeConversationId = conversationId;
      notifyListeners();
      await loadMessages(conversationId);
    } else {
      // 3. Fallback placeholder
      final fallback = ChatConversation(
        id: conversationId,
        type: 'DIRECT',
        name: 'Cuộc trò chuyện',
        avatarUrl: null,
        members: [],
        lastMessage: null,
        unreadCount: 0,
        createdAt: DateTime.now(),
      );
      if (!conversations.any((c) => c.id == conversationId)) {
        conversations.insert(0, fallback);
      }
      activeConversationId = conversationId;
      notifyListeners();
      await loadMessages(conversationId);
    }
  }

  void clearActiveChat() {
    activeConversationId = null;
    activeMessages = [];
    notifyListeners();
  }

  void _sortConversations() {
    conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aTime = a.lastMessage?.sentAt ?? a.createdAt;
      final bTime = b.lastMessage?.sentAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    super.dispose();
  }
}
