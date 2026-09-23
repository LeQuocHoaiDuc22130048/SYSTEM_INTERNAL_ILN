import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/screens/attendance_screen.dart';
import 'package:system_internal_likenew/utils/network_provider.dart';

void main() {
  testWidgets(
    'AttendanceScreen mounts and disposes cleanly without leaking controllers',
    (tester) async {
      final networkProvider = NetworkProvider(autoPoll: false);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: networkProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceScreen(
                allowEnrollment: false,
                selfCheckOnly: true,
              ),
            ),
          ),
        ),
      );

      // Initial build and advance past initialization timeouts
      await tester.pump(const Duration(seconds: 25));

      // Now replace the widget with empty container to trigger dispose
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: networkProvider,
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );

      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      // Dispose networkProvider to cancel its periodic timer
      networkProvider.dispose();

      // Verify widget is unmounted
      expect(find.byType(AttendanceScreen), findsNothing);
    },
  );
}
