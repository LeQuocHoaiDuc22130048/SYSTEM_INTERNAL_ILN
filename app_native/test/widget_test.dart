import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/main.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';

void main() {
  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, Minh 👋'), findsOneWidget);
    expect(find.text('Tổng đơn hôm nay'), findsOneWidget);
    expect(find.text('Thống kê đơn theo tuần'), findsOneWidget);
  });
}
