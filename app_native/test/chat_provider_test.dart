import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/chat_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';

void main() {
  test('stale message response does not overwrite the active conversation', () async {
    late ChatProvider provider;
    final client = MockClient((request) async {
      final conversationId = request.url.path.split('/')[4];
      if (conversationId == 'old') {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return http.Response(
        jsonEncode({
          'content': [
            {
              'id': conversationId,
              'conversationId': conversationId,
              'sender': {'id': 'sender', 'fullName': 'Sender'},
              'content': conversationId,
              'messageType': 'TEXT',
              'sentAt': '2026-01-01T00:00:00Z',
              'readByUserIds': [],
            },
          ],
        }),
        200,
      );
    });
    final api = ApiClient(client: client, baseUrl: 'https://test.api.local');
    final notifications = NotificationProvider(api: api);
    provider = ChatProvider(api: api, notificationProvider: notifications);

    final oldRequest = provider.loadMessages('old');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final newRequest = provider.loadMessages('new');
    await Future.wait([oldRequest, newRequest]);

    expect(provider.activeConversationId, 'new');
    expect(provider.activeMessages.single.conversationId, 'new');

    provider.dispose();
    notifications.dispose();
  });
}
