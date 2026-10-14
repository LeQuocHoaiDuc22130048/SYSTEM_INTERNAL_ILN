import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/chat_repair_order_card.dart';
import 'package:system_inverter_likenew/models/repair_order.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/widgets/chat/repair_order_message_card.dart';

RepairOrder order({List<RepairMedia> media = const []}) => RepairOrder(
  id: '12345678-1234-1234-1234-123456789abc',
  orderNumber: 'RO-001',
  deviceName: 'Biến tần Siemens',
  customerName: 'Nguyễn Văn An',
  customerPhone: '0901234567',
  status: RepairOrderStatus.inProgress,
  createdAt: DateTime(2026),
  media: media,
);

void main() {
  testWidgets(
    'larger card displays customer details and default image without photos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepairOrderMessageCard(
                card: ChatRepairOrderCard.fromOrder(order()),
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('Chưa có ảnh'), findsOneWidget);
      expect(
        tester.getSize(find.byType(RepairOrderMessageCard)).width,
        greaterThan(240),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first protected photo uses backend URL and auth; failure displays default image',
    (tester) async {
      final auth = AuthProvider(
        apiClient: ApiClient(baseUrl: 'https://backend.test')
          ..accessToken = 'photo-token',
      );
      addTearDown(auth.dispose);
      final card = ChatRepairOrderCard.fromOrder(
        order(
          media: const [
            RepairMedia(
              id: 'first',
              url: '/api/v1/repair-media/first.jpg',
              type: 'IMAGE',
            ),
            RepairMedia(
              id: 'second',
              url: '/api/v1/repair-media/second.jpg',
              type: 'IMAGE',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: RepairOrderMessageCard(card: card, color: Colors.black),
            ),
          ),
        ),
      );
      final image =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(image.url, 'https://backend.test/api/v1/repair-media/first.jpg');
      expect(image.headers, {'Authorization': 'Bearer photo-token'});
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ảnh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card fits narrow message bubble and enlarged text without overflowing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 210,
                  child: RepairOrderMessageCard(
                    card: ChatRepairOrderCard.fromOrder(order()),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Chưa có ảnh'), findsOneWidget);
      expect(tester.getSize(find.byType(RepairOrderMessageCard)).width, 210);
      expect(tester.takeException(), isNull);
    },
  );
}
