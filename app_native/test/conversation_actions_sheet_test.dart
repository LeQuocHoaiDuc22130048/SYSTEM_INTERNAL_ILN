import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/conversation.dart';
import 'package:system_inverter_likenew/widgets/chat/conversation_actions_sheet.dart';

ChatConversation conversation({String type = 'DIRECT', int unread = 2,
    bool pinned = false, bool muted = false}) => ChatConversation(
  id: 'chat', type: type, name: 'Nguyễn Văn An', members: [
    ConversationMemberInfo(userId: '1', fullName: 'An', isAdmin: false),
    ConversationMemberInfo(userId: '2', fullName: 'Bình', isAdmin: false),
  ], unreadCount: unread, isPinned: pinned, notificationsMuted: muted,
  createdAt: DateTime(2026),
);

Future<void> pumpSheet(WidgetTester tester, ChatConversation chat,
    {List<String>? actions, double scale = 1, double height = 750}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(width: 320, height: height, child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: ConversationActionsSheet(conversation: chat,
        onPin: () => actions?.add('pin'),
        onMute: () => actions?.add('mute'),
        onRead: () => actions?.add('read'),
        onGallery: () => actions?.add('gallery'),
        onSearch: () => actions?.add('search'),
        onInfo: () => actions?.add('info')),
    )),
  ))));
}

void main() {
  testWidgets('direct context and unread actions invoke the supplied callbacks', (tester) async {
    final actions = <String>[];
    await pumpSheet(tester, conversation(), actions: actions);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Cuộc trò chuyện riêng'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    for (final label in ['Ghim hội thoại', 'Tắt thông báo', 'Đánh dấu đã đọc',
      'Xem ảnh, file & liên kết', 'Tìm kiếm tin nhắn', 'Thông tin cuộc trò chuyện']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(actions, ['pin', 'mute', 'read', 'gallery', 'search', 'info']);
    expect(find.byType(ConversationActionsSheet), findsOneWidget);
  });

  testWidgets('group context reflects selected state and hides read when already read', (tester) async {
    await pumpSheet(tester, conversation(type: 'GROUP', unread: 0, pinned: true, muted: true));
    expect(find.text('2 thành viên'), findsOneWidget);
    expect(find.text('Bỏ ghim hội thoại'), findsOneWidget);
    expect(find.text('Bật thông báo'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsNothing);
    expect(find.text('Thành viên nhóm'), findsOneWidget);
    expect(find.text('Thông tin cuộc trò chuyện'), findsNothing);
  });

  testWidgets('large text at narrow width scrolls to the final action without overflow', (tester) async {
    final actions = <String>[];
    await pumpSheet(tester, conversation(), scale: 2, height: 420, actions: actions);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Thông tin cuộc trò chuyện'), 200,
      scrollable: find.byType(Scrollable));
    await tester.tap(find.text('Thông tin cuộc trò chuyện'));
    await tester.pump();
    expect(actions, ['info']);
    expect(tester.takeException(), isNull);
  });
}
