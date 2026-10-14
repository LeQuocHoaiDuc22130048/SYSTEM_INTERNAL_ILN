import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/chat/chat_message_gestures.dart';

void main() {
  Widget host({
    required VoidCallback reply,
    VoidCallback? longPress,
    VoidCallback? doubleTap,
    VoidCallback? tap,
    bool enabled = true,
    Widget? child,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ChatMessageGestures(
          onReply: reply,
          onLongPress: longPress ?? () {},
          onDoubleTap: doubleTap ?? () {},
          onTap: tap,
          enabled: enabled,
          child:
              child ??
              const SizedBox(
                key: Key('message'),
                width: 200,
                height: 100,
                child: ColoredBox(color: Colors.blue),
              ),
        ),
      ),
    ),
  );

  for (final direction in [-1.0, 1.0]) {
    testWidgets('replies once after horizontal swipe $direction and returns', (
      tester,
    ) async {
      var replies = 0;
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(host(reply: () => replies++));
      final original = tester.getCenter(find.byKey(const Key('message')));
      final gesture = await tester.startGesture(original);
      await gesture.moveBy(Offset(60 * direction, 0));
      await tester.pump();
      await gesture.moveBy(Offset(15 * direction, 0));
      expect(replies, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 1);
      expect(
        haptics
            .where(
              (call) =>
                  call.method == 'HapticFeedback.vibrate' &&
                  call.arguments == 'HapticFeedbackType.lightImpact',
            )
            .length,
        1,
      );
      expect(tester.getCenter(find.byKey(const Key('message'))), original);
    });
  }
  testWidgets('short horizontal swipe does not reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(reply: () => replies++));
    await tester.drag(find.byKey(const Key('message')), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
  });
  testWidgets('tap long press and double tap perform separate actions', (
    tester,
  ) async {
    var taps = 0;
    var menus = 0;
    var reactions = 0;
    await tester.pumpWidget(
      host(
        reply: () {},
        tap: () => taps++,
        longPress: () => menus++,
        doubleTap: () => reactions++,
      ),
    );
    final target = find.byKey(const Key('message'));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.longPress(target);
    await tester.pumpAndSettle();
    expect(menus, 1);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(reactions, 1);
    expect(taps, 1);
    expect(
      tester
          .widget<Transform>(
            find.ancestor(of: target, matching: find.byType(Transform)).first,
          )
          .transform
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'exact fifty pixels replies but retreat below threshold does not',
    (tester) async {
      var replies = 0;
      await tester.pumpWidget(host(reply: () => replies++));
      var gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('message'))),
      );
      await gesture.moveBy(const Offset(50, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 1);
      gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('message'))),
      );
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 1);
    },
  );
  testWidgets('cancelled swipe never replies', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(reply: () => replies++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('message'))),
    );
    await gesture.moveBy(const Offset(80, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(replies, 0);
  });
  testWidgets('disabled message does not react open menu or toggle metadata', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      host(
        enabled: false,
        reply: () => actions++,
        longPress: () => actions++,
        doubleTap: () => actions++,
        tap: () => actions++,
      ),
    );
    final target = find.byKey(const Key('message'));
    await tester.longPress(target);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(actions, 0);
  });
  testWidgets(
    'child media tap works while parent gestures are enabled or disabled',
    (tester) async {
      for (final enabled in [true, false]) {
        var opened = 0;
        var replies = 0;
        var taps = 0;
        await tester.pumpWidget(
          host(
            enabled: enabled,
            reply: () => replies++,
            tap: () => taps++,
            child: GestureDetector(
              onTap: () => opened++,
              child: const SizedBox(
                key: Key('media'),
                width: 200,
                height: 100,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('media')));
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(taps, 0);
        if (!enabled) {
          await tester.drag(
            find.byKey(const Key('media')),
            const Offset(80, 0),
          );
          await tester.pumpAndSettle();
          expect(replies, 0);
        }
      }
    },
  );
  testWidgets('vertical drag scrolls the enclosing message list', (
    tester,
  ) async {
    var replies = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              ChatMessageGestures(
                onReply: () => replies++,
                onLongPress: () {},
                onDoubleTap: () {},
                child: const SizedBox(
                  key: Key('message'),
                  height: 200,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('message')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(replies, 0);
  });
}
