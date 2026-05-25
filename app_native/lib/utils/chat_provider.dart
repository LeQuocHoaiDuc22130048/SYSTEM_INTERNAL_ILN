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

  ChatProvider({
    required this.api,
    required this.notificationProvider,
  }) {
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageStreamSubscription?.cancel();
    _messageStreamSubscription = notificationProvider.messageStream.listen((data) {
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
        final index = conversations.indexWhere((c) => c.id == message.conversationId);
        if (index != -1) {
          final conv = conversations[index];
          final updatedConv = ChatConversation(
            id: conv.id,
            type: conv.type,
            name: conv.name,
            avatarUrl: conv.avatarUrl,
            members: conv.members,
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
            createdAt: conv.createdAt,
          );
          conversations.removeAt(index);
          conversations.insert(0, updatedConv);
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

  void updateAuthAndNotification(AuthProvider auth, NotificationProvider notifications) {
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
      final data = await api.get('/api/v1/conversations/$conversationId/messages');
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

  Future<void> sendMessage(String conversationId, String content, {String? mediaUrl, String messageType = 'TEXT'}) async {
    try {
      final data = await api.post(
        '/api/v1/conversations/$conversationId/messages',
        body: {
          'content': content,
          'mediaUrl': mediaUrl,
          'messageType': messageType,
        },
      );
      if (data is Map<String, dynamic>) {
        final sentMessage = ChatMessage.fromJson(data);
        if (activeConversationId == conversationId) {
          if (!activeMessages.any((m) => m.id == sentMessage.id)) {
            activeMessages = [sentMessage, ...activeMessages];
            notifyListeners();
          }
        }

        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final conv = conversations[index];
          final updatedConv = ChatConversation(
            id: conv.id,
            type: conv.type,
            name: conv.name,
            avatarUrl: conv.avatarUrl,
            members: conv.members,
            lastMessage: ConversationMessageInfo(
              id: sentMessage.id,
              senderName: sentMessage.sender.fullName,
              content: sentMessage.content,
              messageType: sentMessage.messageType,
              sentAt: sentMessage.sentAt,
            ),
            unreadCount: 0,
            createdAt: conv.createdAt,
          );
          conversations.removeAt(index);
          conversations.insert(0, updatedConv);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[CHAT] Failed to send message: $e');
      rethrow;
    }
  }

  Future<void> createConversation(String type, String name, List<String> memberIds) async {
    try {
      final data = await api.post(
        '/api/v1/conversations',
        body: {
          'type': type,
          'name': name,
          'memberIds': memberIds,
        },
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

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    super.dispose();
  }
}
