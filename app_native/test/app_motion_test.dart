import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/theme/app_motion.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('$platform pops pages immediately while pushes animate', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            pageTransitionsTheme: AppMotion.transitions,
          ),
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail')),
      );
      Navigator.of(context).push(route);
      await tester.pump();
      expect(route.transitionDuration, const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      Navigator.of(context).pop();
      await tester.pump();
      expect(find.text('Detail'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
