import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/user.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:system_inverter_likenew/screens/messages_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/chat_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';

class _ChatAuth extends AuthProvider {
  _ChatAuth(ApiClient api) : super(apiClient: api);
  bool canViewOrders = true;
  @override
  bool can(AppPermission permission) =>
      permission == AppPermission.viewRepairOrders
      ? canViewOrders
      : super.can(permission);
  @override
  User get currentUser => User(
    id: 'me',
    name: 'Me',
    email: '',
    employeeId: '',
    role: UserRole.technician,
    status: UserStatus.active,
  );
}

class _RealtimeNotifications extends NotificationProvider {
  _RealtimeNotifications(ApiClient api) : super(api: api);
  final events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get conversationEventStream => events.stream;
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

class _ChatFixture {
  bool pinned = false;
  bool muted = false;
  bool empty = false;
  bool rejectActions = false;
  int unreadCount = 0;
  int reads = 0;
  bool group = false;
  bool admin = true;
  bool paginated = false;
  final List<Map<String, dynamic>> members = [
    {'userId': 'me', 'fullName': 'Me', 'isAdmin': true, 'role': 'ADMIN'},
    {
      'userId': 'other',
      'fullName': 'Other',
      'isAdmin': false,
      'role': 'MEMBER',
    },
  ];
  final List<int> messagePages = [];
  final List<Map<String, dynamic>> additionalConversations = [];
  int orderDetailReads = 0;
  int loads = 0;
  final List<http.Request> actions = [];
  final List<Map<String, dynamic>> messages;
  late final ApiClient api;
  late final NotificationProvider notifications;
  late final ChatProvider chat;
  late final BackendDataProvider backend;
  late final _ChatAuth auth;

  _ChatFixture({int count = 3})
    : messages = List.generate(
        count,
        (index) => {
          'id': 'm$index',
          'conversationId': 'c1',
          'sender': {'id': 'me', 'fullName': 'Me'},
          'content': 'Message $index',
          'messageType': 'TEXT',
          'sentAt': DateTime(
            2026,
            10,
            13,
            11,
            17,
            50 - index,
          ).toIso8601String(),
          'readByUserIds': ['me', 'other'],
          'reactions': [],
        },
      ) {
    api = ApiClient(
      baseUrl: 'https://chat.test',
      client: MockClient((request) async {
        dynamic response = {};
        final path = request.url.path;
        if (rejectActions &&
            request.method != 'GET' &&
            !path.endsWith('/read')) {
          return http.Response('{"message":"Rejected"}', 403);
        }
        if (path == '/api/v1/conversations') {
          loads++;
          response = empty ? [] : [conversation, ...additionalConversations];
        } else if (path.endsWith('/messages') && request.method == 'GET') {
          final page = int.parse(request.url.queryParameters['page'] ?? '0');
          messagePages.add(page);
          response = {
            'content': paginated
                ? messages.skip(page * 30).take(30).toList()
                : messages,
            'last': !paginated || (page + 1) * 30 >= messages.length,
          };
        } else if (path.endsWith('/read')) {
          reads++;
          unreadCount = 0;
        } else if (path.endsWith('/pin')) {
          actions.add(request);
          pinned = request.method == 'PUT';
          response = conversation;
        } else if (path.endsWith('/mute')) {
          actions.add(request);
          muted = request.method == 'PUT';
          response = conversation;
        } else if (path.endsWith('/reactions')) {
          actions.add(request);
          final message = messages.firstWhere(
            (m) => path.contains('/${m['id']}/'),
          );
          message['reactions'] = [
            {
              'emoji': jsonDecode(request.body)['emoji'],
              'count': 1,
              'userIds': ['me'],
            },
          ];
          response = message;
        } else if (path.endsWith('/messages') && request.method == 'POST') {
          actions.add(request);
          response = {
            ...messages.first,
            ...jsonDecode(request.body),
            'id': 'sent',
          };
        } else if (path.endsWith('/members') && request.method == 'POST') {
          actions.add(request);
          members.add({
            'userId': 'new',
            'fullName': 'New member',
            'isAdmin': false,
            'role': 'MEMBER',
          });
          response = conversation;
        } else if (path.endsWith('/leave')) {
          actions.add(request);
          empty = true;
        } else if (path.endsWith('/role')) {
          actions.add(request);
          final member = members.firstWhere(
            (m) => path.contains('/${m['userId']}/'),
          );
          member['role'] = jsonDecode(request.body)['role'];
          member['isAdmin'] = member['role'] == 'ADMIN';
          response = conversation;
        } else if (path.contains('/members/') && request.method == 'DELETE') {
          actions.add(request);
          members.removeWhere((m) => path.endsWith('/${m['userId']}'));
          response = conversation;
        } else if (path.endsWith('/employees')) {
          response = {
            'content': group
                ? [
                    {
                      'id': 'new',
                      'fullName': 'New member',
                      'status': 'ACTIVE',
                      'role': 'TECHNICIAN',
                    },
                  ]
                : [],
          };
        } else if (path == '/api/v1/repair-orders') {
          response = {
            'content': [repairOrder],
            'last': true,
          };
        } else if (path.startsWith('/api/v1/repair-orders/')) {
          orderDetailReads++;
          response = repairOrder;
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode(response)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    notifications = _RealtimeNotifications(api);
    chat = ChatProvider(api: api, notificationProvider: notifications);
    backend = BackendDataProvider(api: api);
    auth = _ChatAuth(api);
  }

  Map<String, dynamic> get conversation => {
    'id': 'c1',
    'type': group ? 'GROUP' : 'DIRECT',
    'name': 'Phòng kỹ thuật',
    'members': group
        ? members
              .map(
                (member) => member['userId'] == 'me'
                    ? {
                        ...member,
                        'isAdmin': admin,
                        'role': admin ? 'ADMIN' : 'MEMBER',
                      }
                    : member,
              )
              .toList()
        : [],
    'pinned': pinned,
    'notificationsMuted': muted,
    'unreadCount': unreadCount,
    'createdAt': '2026-10-13T11:00:00',
  };

  Map<String, dynamic> get repairOrder => {
    'id': '12345678-1234-1234-1234-123456789abc',
    'orderCode': 'RO-001',
    'deviceName': 'Biến tần Siemens',
    'customerName': 'Customer',
    'status': 'IN_PROGRESS',
    'createdAt': '2026-10-13T11:00:00',
  };

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      chat.dispose();
      backend.dispose();
      auth.dispose();
      notifications.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: backend),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: MessagesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Phòng kỹ thuật'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('order card respects denied repair access and sharing is hidden', (
    tester,
  ) async {
    final fixture = _ChatFixture();
    fixture.auth.canViewOrders = false;
    fixture.messages.first['content'] =
        'Đơn sửa chữa: RO-001\nThiết bị: Máy\nTrạng thái: Đang sửa\nsystem-inverter://repair-orders/12345678-1234-1234-1234-123456789abc';
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.text('Xem chi tiết ›'));
    await tester.pumpAndSettle();
    expect(fixture.orderDetailReads, 0);
    expect(find.text('Bạn không có quyền xem đơn sửa chữa.'), findsOneWidget);
    await tester.tap(find.byTooltip('Thêm nội dung'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi thẻ đơn sửa chữa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed card send preserves selected order for retry', (
    tester,
  ) async {
    final fixture = _ChatFixture();
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.byTooltip('Thêm nội dung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi thẻ đơn sửa chữa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RO-001'));
    await tester.pump();
    fixture.rejectActions = true;
    await tester.tap(find.text('Gửi thẻ'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể gửi thẻ đơn. Vui lòng thử lại.'),
      findsOneWidget,
    );
    fixture.rejectActions = false;
    await tester.tap(find.text('Gửi thẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Xem chi tiết ›'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from chat retains group filter', (tester) async {
    final fixture = _ChatFixture();
    fixture.additionalConversations.add({
      ...fixture.conversation,
      'id': 'c2',
      'name': 'Nhóm kho',
      'type': 'GROUP',
    });
    await fixture.mount(tester);
    await tester.tap(find.text('Nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhóm kho'));
    await tester.pumpAndSettle();
    fixture.chat.clearActiveChat();
    await tester.pumpAndSettle();
    expect(find.text('Nhóm kho'), findsOneWidget);
    expect(find.text('Phòng kỹ thuật'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting a repair order sends a readable card and opens current detail',
    (tester) async {
      final fixture = _ChatFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      await tester.tap(find.byTooltip('Thêm nội dung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi thẻ đơn sửa chữa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RO-001'));
      await tester.pump();
      await tester.tap(find.text('Gửi thẻ'));
      await tester.pumpAndSettle();
      expect(
        fixture.actions.where((r) => r.url.path.endsWith('/messages')).length,
        1,
      );
      expect(find.text('RO-001'), findsOneWidget);
      await tester.tap(find.text('Xem chi tiết ›'));
      await tester.pumpAndSettle();
      expect(find.textContaining('RO-001'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conversation filters combine unread and group selection with search',
    (tester) async {
      final fixture = _ChatFixture();
      fixture.additionalConversations.add({
        ...fixture.conversation,
        'id': 'c2',
        'name': 'Nhóm kho',
        'type': 'GROUP',
        'unreadCount': 2,
      });
      await fixture.mount(tester);
      await tester.tap(find.text('Chưa đọc (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Nhóm kho'), findsOneWidget);
      expect(find.text('Phòng kỹ thuật'), findsNothing);
      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kỹ thuật');
      await tester.pumpAndSettle();
      expect(find.text('Nhóm kho'), findsNothing);
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(find.text('Phòng kỹ thuật'), findsOneWidget);
      expect(find.text('Nhóm kho'), findsNothing);
    },
  );

  testWidgets(
    'only latest outgoing message shows delivery status across groups',
    (tester) async {
      final fixture = _ChatFixture();
      fixture.messages[1]['sentAt'] = '2026-10-13T09:00:00';
      fixture.messages[2]['sentAt'] = '2026-10-13T08:00:00';
      await fixture.mount(tester);
      await fixture.open(tester);
      expect(find.textContaining('Đã xem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed leave keeps group open and offers server reason', (
    tester,
  ) async {
    final fixture = _ChatFixture()..group = true;
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    fixture.rejectActions = true;
    await tester.ensureVisible(find.text('Rời khỏi nhóm'));
    await tester.tap(find.text('Rời khỏi nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rời nhóm'));
    await tester.pumpAndSettle();
    expect(fixture.chat.activeConversationId, 'c1');
    expect(fixture.chat.conversations.length, 1);
    expect(find.text('Rejected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'admin promotes another member and removes them after confirmation',
    (tester) async {
      final fixture = _ChatFixture()..group = true;
      await fixture.mount(tester);
      await fixture.open(tester);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Quản lý Other'));
      await tester.tap(find.byTooltip('Quản lý Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt làm quản trị viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(fixture.chat.conversations.single.members.last.isAdmin, isTrue);
      await tester.tap(find.byTooltip('Quản lý Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa khỏi nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(fixture.chat.conversations.single.members.length, 1);
      expect(find.text('Other'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typing composer sends state and incoming event identifies member',
    (tester) async {
      final fixture = _ChatFixture()..group = true;
      await fixture.mount(tester);
      await fixture.open(tester);
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      (fixture.notifications as _RealtimeNotifications).events.add({
        'type': 'TYPING',
        'conversationId': 'c1',
        'payload': {'userId': 'other', 'typing': true},
      });
      await tester.pump();
      expect(find.text('Other đang soạn tin...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Other đang soạn tin...'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scrolling toward oldest messages loads next page', (
    tester,
  ) async {
    final fixture = _ChatFixture(count: 60)..paginated = true;
    await fixture.mount(tester);
    await fixture.open(tester);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('chat-message-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(fixture.messagePages, [0, 1]);
    expect(fixture.chat.activeMessages.length, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin adds members and leaves group from info page', (
    tester,
  ) async {
    final fixture = _ChatFixture()..group = true;
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm thành viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New member'));
    await tester.pump();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(fixture.chat.conversations.single.members.length, 3);
    await tester.ensureVisible(find.text('Rời khỏi nhóm'));
    await tester.tap(find.text('Rời khỏi nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rời nhóm'));
    await tester.pumpAndSettle();
    expect(fixture.chat.activeConversationId, isNull);
    expect(fixture.chat.conversations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary member does not see admin management actions', (
    tester,
  ) async {
    final fixture = _ChatFixture()
      ..group = true
      ..admin = false;
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text('Thêm thành viên'), findsNothing);
    expect(find.byIcon(Icons.manage_accounts_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('conversation respects reduced motion setting', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final fixture = _ChatFixture();
    await fixture.mount(tester);
    await tester.tap(find.text('Phòng kỹ thuật'));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('c1'))).dx, 0);
    await tester.pumpAndSettle();
    fixture.chat.clearActiveChat();
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('conversation-list'))).dx,
      0,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening conversation animates and closing restores list immediately',
    (tester) async {
      final fixture = _ChatFixture();
      await fixture.mount(tester);
      await tester.tap(find.text('Phòng kỹ thuật'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final openingX = tester.getTopLeft(find.byKey(const ValueKey('c1'))).dx;
      expect(openingX, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('c1'))).dx, 0);
      fixture.chat.clearActiveChat();
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('conversation-list'))).dx,
        0,
      );
      expect(find.byKey(const ValueKey('c1')), findsNothing);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('conversation-list'))).dx,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conversation menu marks unread conversation read without opening chat',
    (tester) async {
      final fixture = _ChatFixture()..unreadCount = 3;
      await fixture.mount(tester);
      await tester.longPress(find.text('Phòng kỹ thuật'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đánh dấu đã đọc'));
      await tester.pumpAndSettle();
      expect(fixture.reads, 1);
      expect(fixture.chat.conversations.single.unreadCount, 0);
      expect(fixture.chat.activeConversationId, isNull);
      expect(find.text('Đánh dấu đã đọc'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conversation menu toggles pin and notifications', (
    tester,
  ) async {
    final fixture = _ChatFixture();
    await fixture.mount(tester);
    for (final label in [
      'Ghim hội thoại',
      'Bỏ ghim hội thoại',
      'Tắt thông báo',
      'Bật thông báo',
    ]) {
      await tester.longPress(find.text('Phòng kỹ thuật'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(fixture.actions.map((request) => request.method), [
      'PUT',
      'DELETE',
      'PUT',
      'DELETE',
    ]);
    expect(fixture.pinned, isFalse);
    expect(fixture.muted, isFalse);
    expect(fixture.chat.activeConversationId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conversation menu identifies selection and offers shortcuts', (
    tester,
  ) async {
    final fixture = _ChatFixture();
    await fixture.mount(tester);
    await tester.longPress(find.text('Phòng kỹ thuật'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng kỹ thuật'), findsNWidgets(2));
    expect(find.text('Xem ảnh, file & liên kết'), findsOneWidget);
    expect(find.text('Tìm kiếm tin nhắn'), findsOneWidget);
    expect(find.text('Thông tin cuộc trò chuyện'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsNothing);
    await tester.tap(find.text('Tìm kiếm tin nhắn'));
    await tester.pumpAndSettle();
    expect(fixture.chat.activeConversationId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed message action shows retry feedback and leaves chat open',
    (tester) async {
      final fixture = _ChatFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      fixture.rejectActions = true;
      await tester.longPress(find.text('Message 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghim tin nhắn'));
      await tester.pumpAndSettle();
      expect(
        find.text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(fixture.chat.activeConversationId, 'c1');
      expect(find.byKey(const ValueKey('chat-message-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swiping the left edge returns to conversations and emoji has no colored bubble',
    (tester) async {
      final fixture = _ChatFixture();
      fixture.messages.first['content'] = '👍';
      await fixture.mount(tester);
      await fixture.open(tester);
      final emoji = find.text('👍');
      expect(tester.widget<Text>(emoji).style!.fontSize, 42);
      final bubble = tester.widget<Container>(
        find.ancestor(of: emoji, matching: find.byType(Container)).first,
      );
      expect(bubble.decoration, isNull);
      final listTop = tester
          .getTopLeft(find.byKey(const ValueKey('chat-message-list')))
          .dy;
      await tester.dragFrom(Offset(8, listTop + 100), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(fixture.chat.activeConversationId, isNull);
      expect(find.text('Tin nhắn'), findsOneWidget);
    },
  );

  testWidgets(
    'conversation swipe pin/mute retains row; empty list can refresh',
    (tester) async {
      final fixture = _ChatFixture();
      await fixture.mount(tester);
      final row = find.byKey(const ValueKey('conversation-row-c1'));
      expect(row, findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('conversation-avatar-c1')))
            .dx,
        22,
      );
      await tester.drag(row, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(fixture.pinned, isTrue);
      expect(row, findsOneWidget);
      await tester.drag(row, const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(fixture.muted, isTrue);
      expect(row, findsOneWidget);
      fixture.empty = true;
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy cuộc trò chuyện'), findsOneWidget);
      fixture.empty = false;
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(fixture.loads, greaterThanOrEqualTo(3));
      expect(row, findsOneWidget);
    },
  );

  testWidgets('info has one action per function and mute stays on info route', (
    tester,
  ) async {
    final fixture = _ChatFixture();
    await fixture.mount(tester);
    await fixture.open(tester);
    await tester.tap(find.byKey(const ValueKey('chat-header-info')));
    await tester.pumpAndSettle();
    final title = find.text('Chi tiết cuộc trò chuyện');
    final titleElement = tester.element(title);
    expect(find.text('Tắt thông báo'), findsOneWidget);
    expect(find.text('Tìm kiếm'), findsNothing);
    expect(find.text('Tài nguyên'), findsNothing);
    await tester.tap(find.text('Tắt thông báo'));
    await tester.pumpAndSettle();
    expect(fixture.muted, isTrue);
    expect(tester.element(title), same(titleElement));
    expect(find.text('Bật thông báo'), findsOneWidget);
    await tester.tap(find.text('Bật thông báo'));
    await tester.pumpAndSettle();
    expect(fixture.muted, isFalse);
    expect(title, findsOneWidget);
  });

  testWidgets(
    'grouped messages expose metadata on tap, swipe replies, double tap reacts and long press copies',
    (tester) async {
      final fixture = _ChatFixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byKey(const ValueKey('message-metadata-m0')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-metadata-m1')), findsNothing);
      await tester.tap(find.text('Message 1'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('message-metadata-m1')), findsOneWidget);
      await tester.drag(find.text('Message 1'), const Offset(90, 0));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'Nhập tin nhắn...');
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.enterText(input, 'Reply body');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      final sent = fixture.actions.lastWhere((r) => r.method == 'POST');
      expect(jsonDecode(sent.body)['parentMessageId'], 'm1');
      await tester.tap(find.text('Message 2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Message 2'));
      await tester.pumpAndSettle();
      expect(
        jsonDecode(
          fixture.actions
              .lastWhere((r) => r.url.path.endsWith('/reactions'))
              .body,
        )['emoji'],
        '❤️',
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.longPress(find.text('Message 2'));
      await tester.pumpAndSettle();
      expect(find.text('Ghim tin nhắn'), findsOneWidget);
      await tester.tap(find.text('Sao chép'));
      await tester.pumpAndSettle();
      expect(copied, 'Message 2');
    },
  );

  testWidgets(
    'drag dismisses composer keyboard and scroll button returns to latest message',
    (tester) async {
      final fixture = _ChatFixture(count: 40);
      await fixture.mount(tester);
      await fixture.open(tester);
      final input = find.widgetWithText(TextField, 'Nhập tin nhắn...');
      await tester.tap(input);
      await tester.pump();
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      final list = find.byKey(const ValueKey('chat-message-list'));
      await tester.drag(list, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isFalse);
      final down = find.byTooltip('Tin nhắn mới nhất');
      expect(down, findsOneWidget);
      await tester.tap(down);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(list).controller!.offset,
        closeTo(0, 0.01),
      );
      expect(down, findsNothing);
    },
  );
}
