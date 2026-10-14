import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/chat_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';

Map<String, dynamic> message(String id, String conversation) => {
  'id': id,
  'conversationId': conversation,
  'sender': {'id': 'other', 'fullName': 'Other'},
  'content': id,
  'messageType': 'TEXT',
  'sentAt': '2026-10-13T00:00:00Z',
};

class EventNotifications extends NotificationProvider {
  EventNotifications(ApiClient api) : super(api: api);
  final events = StreamController<Map<String, dynamic>>.broadcast();
  String? watched;
  @override
  Stream<Map<String, dynamic>> get conversationEventStream => events.stream;
  @override
  void watchConversationEvents(String? id) {
    watched = id;
  }

  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

void main() {
  test(
    'failed older page can retry same page without losing messages',
    () async {
      var fail = true;
      final pages = <String>[];
      final api = ApiClient(
        baseUrl: 'https://chat.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/read')) {
            return http.Response('{}', 200);
          }
          final page = request.url.queryParameters['page']!;
          pages.add(page);
          if (page == '1' && fail) {
            return http.Response('{"message":"Offline"}', 503);
          }
          return http.Response(
            jsonEncode({
              'content': [message(page, 'c1')],
              'last': page == '1',
            }),
            200,
          );
        }),
      );
      final notifications = NotificationProvider(api: api);
      final chat = ChatProvider(api: api, notificationProvider: notifications);
      addTearDown(chat.dispose);
      addTearDown(notifications.dispose);
      await chat.loadMessages('c1');
      await chat.loadOlderMessages();
      expect(chat.olderMessagesError, isNotNull);
      expect(chat.activeMessages.single.id, '0');
      fail = false;
      await chat.loadOlderMessages();
      expect(pages, ['0', '1', '1']);
      expect(chat.activeMessages.map((m) => m.id), ['0', '1']);
      expect(chat.olderMessagesError, isNull);
    },
  );

  testWidgets(
    'typing events expire and typing sends are throttled with idle stop',
    (tester) async {
      final sent = <bool>[];
      final api = ApiClient(
        baseUrl: 'https://chat.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/typing')) {
            sent.add(jsonDecode(request.body)['typing'] as bool);
          }
          return http.Response(jsonEncode({'content': [], 'last': true}), 200);
        }),
      );
      final notifications = EventNotifications(api);
      final chat = ChatProvider(api: api, notificationProvider: notifications);
      addTearDown(chat.dispose);
      addTearDown(notifications.dispose);
      await chat.loadMessages('c1');
      expect(notifications.watched, 'c1');
      notifications.events.add({
        'type': 'TYPING',
        'conversationId': 'c1',
        'payload': {'userId': 'other', 'typing': true},
      });
      await tester.pump();
      expect(chat.typingUserIds, contains('other'));
      chat.updateTyping(true);
      chat.updateTyping(true);
      await tester.pump();
      expect(sent, [true]);
      await tester.pump(const Duration(seconds: 3));
      expect(sent, [true, false]);
      await tester.pump(const Duration(seconds: 4));
      expect(chat.typingUserIds, isEmpty);
      chat.clearActiveChat();
      expect(notifications.watched, isNull);
    },
  );

  test(
    'group management uses backend contracts and leaving clears active chat',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://chat.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'id': 'c1',
              'type': 'GROUP',
              'name': 'Group',
              'members': [],
              'unreadCount': 0,
            }),
            200,
          );
        }),
      );
      final notifications = NotificationProvider(api: api);
      final chat = ChatProvider(api: api, notificationProvider: notifications);
      addTearDown(chat.dispose);
      addTearDown(notifications.dispose);
      await chat.addMembers('c1', ['other']);
      await chat.updateMemberRole('c1', 'other', 'ADMIN');
      await chat.removeMember('c1', 'other');
      chat.activeConversationId = 'c1';
      await chat.leaveConversation('c1');
      expect(requests.map((r) => r.method), [
        'POST',
        'PATCH',
        'DELETE',
        'POST',
      ]);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/conversations/c1/members',
        '/api/v1/conversations/c1/members/other/role',
        '/api/v1/conversations/c1/members/other',
        '/api/v1/conversations/c1/leave',
      ]);
      expect(jsonDecode(requests.first.body), {
        'memberIds': ['other'],
      });
      expect(jsonDecode(requests[1].body), {'role': 'ADMIN'});
      expect(chat.activeConversationId, isNull);
      expect(chat.conversations, isEmpty);
    },
  );
  test('older pages deduplicate messages and stop at last page', () async {
    final pages = <String>[];
    final api = ApiClient(
      baseUrl: 'https://chat.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/read')) return http.Response('{}', 200);
        final page = request.url.queryParameters['page'] ?? '0';
        pages.add(page);
        return http.Response(
          jsonEncode({
            'content': page == '0'
                ? [message('new', 'c1')]
                : [message('new', 'c1'), message('old', 'c1')],
            'last': page == '1',
          }),
          200,
        );
      }),
    );
    final notifications = NotificationProvider(api: api);
    final chat = ChatProvider(api: api, notificationProvider: notifications);
    addTearDown(chat.dispose);
    addTearDown(notifications.dispose);
    await chat.loadMessages('c1');
    await chat.loadOlderMessages();
    await chat.loadOlderMessages();
    expect(pages, ['0', '1']);
    expect(chat.activeMessages.map((m) => m.id), ['new', 'old']);
    expect(chat.hasMoreMessages, isFalse);
  });

  test(
    'older page from previous conversation cannot replace current messages',
    () async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: 'https://chat.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/read')) {
            return http.Response('{}', 200);
          }
          if (request.url.queryParameters['page'] == '1') return pending.future;
          final id = request.url.path.split('/')[4];
          return http.Response(
            jsonEncode({
              'content': [message(id, id)],
              'last': false,
            }),
            200,
          );
        }),
      );
      final notifications = NotificationProvider(api: api);
      final chat = ChatProvider(api: api, notificationProvider: notifications);
      addTearDown(chat.dispose);
      addTearDown(notifications.dispose);
      await chat.loadMessages('old');
      final load = chat.loadOlderMessages();
      await chat.loadMessages('new');
      pending.complete(
        http.Response(
          jsonEncode({
            'content': [message('stale', 'old')],
            'last': true,
          }),
          200,
        ),
      );
      await load;
      expect(chat.activeMessages.single.id, 'new');
      expect(chat.hasMoreMessages, isTrue);
      expect(chat.isLoadingOlderMessages, isFalse);
    },
  );
}
