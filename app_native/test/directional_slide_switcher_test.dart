import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/directional_slide_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final hz in [60, 90, 120, 144]) {
    testWidgets('same animation progress after 450ms at $hz Hz', (
      tester,
    ) async {
      Widget page(String id) => MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(
            child: SizedBox(key: ValueKey(id), child: Text(id)),
          ),
        ),
      );
      await tester.pumpWidget(page('A'));
      await tester.pumpWidget(page('B'));
      await tester.pump();
      final frame = (1000000 / hz).round();
      var elapsed = 0;
      while (elapsed < 450000) {
        final step = (450000 - elapsed).clamp(0, frame);
        await tester.pump(Duration(microseconds: step));
        elapsed += step;
      }
      final slide = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('B'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(
        slide.position.value.dx,
        closeTo(.18 * (1 - Curves.easeInOutSine.transform(.5)), .0001),
      );
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });
  }

  testWidgets(
    'rapid page changes keep only the latest outgoing page and settle',
    (tester) async {
      Widget page(String id) => MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(child: Text(id, key: ValueKey(id))),
        ),
      );
      await tester.pumpWidget(page('A'));
      await tester.pumpWidget(page('B'));
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pumpWidget(page('C'));
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('B'), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('DirectionalSlideSwitcher slides forward (from right to left)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(
            isForward: true,
            child: SizedBox(key: ValueKey('page_1'), child: Text('Page 1')),
          ),
        ),
      ),
    );

    expect(find.text('Page 1'), findsOneWidget);

    // Switch to page 2 (forward)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(
            isForward: true,
            child: SizedBox(key: ValueKey('page_2'), child: Text('Page 2')),
          ),
        ),
      ),
    );

    // Mid-animation: Both pages exist in the transition Stack
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);

    final slideFinderPage2 = find.ancestor(
      of: find.text('Page 2'),
      matching: find.byType(SlideTransition),
    );
    final slidePage2 = tester.widget<SlideTransition>(slideFinderPage2.first);
    // Page 2 comes from right (X > 0)
    expect(slidePage2.position.value.dx, greaterThan(0.0));

    final slideFinderPage1 = find.ancestor(
      of: find.text('Page 1'),
      matching: find.byType(SlideTransition),
    );
    final slidePage1 = tester.widget<SlideTransition>(slideFinderPage1.first);
    // Page 1 exits to left (X < 0)
    expect(slidePage1.position.value.dx, lessThan(0.0));

    // Finish animation
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Page 1'), findsNothing);
  });

  testWidgets('DirectionalSlideSwitcher slides backward (from left to right)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(
            isForward: false,
            child: SizedBox(key: ValueKey('page_2'), child: Text('Page 2')),
          ),
        ),
      ),
    );

    expect(find.text('Page 2'), findsOneWidget);

    // Switch back to page 1 (backward)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DirectionalSlideSwitcher(
            isForward: false,
            child: SizedBox(key: ValueKey('page_1'), child: Text('Page 1')),
          ),
        ),
      ),
    );

    // Mid-animation
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);

    final slideFinderPage1 = find.ancestor(
      of: find.text('Page 1'),
      matching: find.byType(SlideTransition),
    );
    final slidePage1 = tester.widget<SlideTransition>(slideFinderPage1.first);
    // Page 1 enters from left (X < 0)
    expect(slidePage1.position.value.dx, lessThan(0.0));

    final slideFinderPage2 = find.ancestor(
      of: find.text('Page 2'),
      matching: find.byType(SlideTransition),
    );
    final slidePage2 = tester.widget<SlideTransition>(slideFinderPage2.first);
    // Page 2 exits to right (X > 0)
    expect(slidePage2.position.value.dx, greaterThan(0.0));

    // Finish animation
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsNothing);
  });
}
