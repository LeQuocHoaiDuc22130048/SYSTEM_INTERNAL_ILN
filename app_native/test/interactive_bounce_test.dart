import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/interactive_bounce.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('InteractiveBounce renders child widget correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InteractiveBounce(
            child: Text('Test Button'),
          ),
        ),
      ),
    );

    expect(find.text('Test Button'), findsOneWidget);
  });

  testWidgets('InteractiveBounce scales down on tap down and triggers onTap on tap up', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveBounce(
              scaleDown: 0.90,
              onTap: () => tapped = true,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Center(child: Text('Click Me')),
              ),
            ),
          ),
        ),
      ),
    );

    final transformFinder = find.descendant(
      of: find.byType(InteractiveBounce),
      matching: find.byType(Transform),
    );

    // Initial scale on X-axis is 1.0
    Transform transform = tester.widget(transformFinder);
    expect(transform.transform.entry(0, 0), equals(1.0));

    // Press down
    final gesture = await tester.startGesture(tester.getCenter(find.text('Click Me')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Scale on X-axis should have shrunk to 0.90
    transform = tester.widget(transformFinder);
    expect(transform.transform.entry(0, 0), lessThan(1.0));
    expect(transform.transform.entry(0, 0), closeTo(0.90, 0.01));
    expect(tapped, isFalse);

    // Release tap
    await gesture.up();
    await tester.pump();
    expect(tapped, isTrue);

    // After animation completes, scale returns to 1.0
    await tester.pumpAndSettle();
    transform = tester.widget(transformFinder);
    expect(transform.transform.entry(0, 0), equals(1.0));
  });

  testWidgets('InteractiveBounce cancels animation and does not trigger onTap if gesture cancels', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveBounce(
              scaleDown: 0.90,
              onTap: () => tapped = true,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Center(child: Text('Drag Me')),
              ),
            ),
          ),
        ),
      ),
    );

    final transformFinder = find.descendant(
      of: find.byType(InteractiveBounce),
      matching: find.byType(Transform),
    );

    // Press down
    final gesture = await tester.startGesture(tester.getCenter(find.text('Drag Me')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pressedTransform = tester.widget<Transform>(transformFinder);
    expect(pressedTransform.transform.entry(0, 0), lessThan(1.0));

    // Cancel gesture (e.g. pointer cancel or scrolling away)
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
    final finalTransform = tester.widget<Transform>(transformFinder);
    expect(finalTransform.transform.entry(0, 0), equals(1.0));
  });

  testWidgets('InteractiveBounce remains inert when disabled (no onTap or onLongPress)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveBounce(
              child: Text('Disabled Element'),
            ),
          ),
        ),
      ),
    );

    // No Transform created inside InteractiveBounce if not interactive
    final bounceTransformFinder = find.descendant(
      of: find.byType(InteractiveBounce),
      matching: find.byType(Transform),
    );
    expect(bounceTransformFinder, findsNothing);
    expect(find.text('Disabled Element'), findsOneWidget);
  });
}
