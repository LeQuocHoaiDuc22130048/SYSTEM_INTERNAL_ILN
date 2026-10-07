import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/smooth_tab_stack.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('Count $value'),
  );
}

void main() {
  testWidgets('transparent incoming page cannot reveal outgoing content during fade', (tester) async {
    const capture = ValueKey('transition-capture');
    Widget tabs(int index) => MaterialApp(theme: ThemeData(scaffoldBackgroundColor: Colors.white), home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: capture,
        child: SizedBox(width: 200, height: 200, child: SmoothTabStack(index: index, isForward: true,
          children: const [ColoredBox(color: Colors.red), SizedBox.expand()],
        )),
      )),
    ));
    await tester.pumpWidget(tabs(0));
    await tester.pumpWidget(tabs(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    // At the overlap, a transparent incoming page must have an opaque white
    // surface, rather than leaking any red from the outgoing page.
    final pixel = (130 * 200 + 150) * 4;
    expect(bytes!.buffer.asUint8List(bytes.offsetInBytes + pixel, 4), [255, 255, 255, 255]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final forward in [true, false]) {
    testWidgets('outgoing fades before incoming slides in, direction $forward', (tester) async {
      Widget tabs(int index) => MaterialApp(home: Scaffold(body: SmoothTabStack(index: index, isForward: forward,
        children: const [Text('First'), Text('Second')],
      )));
      await tester.pumpWidget(tabs(1));
      await tester.pumpWidget(tabs(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('First'), findsNothing);
      final outgoingFade = tester.widget<FadeTransition>(find.ancestor(of: find.text('Second'), matching: find.byType(FadeTransition)).first);
      expect(outgoingFade.opacity.value, greaterThan(0));
      expect(outgoingFade.opacity.value, lessThan(.5));
      final leaving = tester.widget<SlideTransition>(find.ancestor(of: find.text('Second'), matching: find.byType(SlideTransition)).first);
      expect(leaving.position.value.dx * (forward ? 1 : -1), lessThan(0));
      await tester.pump(const Duration(milliseconds: 270));
      expect(find.text('Second'), findsNothing);
      final entering = tester.widget<SlideTransition>(find.ancestor(of: find.text('First'), matching: find.byType(SlideTransition)).first);
      expect(entering.position.value.dx * (forward ? 1 : -1), greaterThan(0));
      final incomingFade = tester.widget<FadeTransition>(find.ancestor(of: find.text('First'), matching: find.byType(FadeTransition)).first);
      expect(incomingFade.opacity.value, greaterThan(0));
      expect(incomingFade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
    });
  }

  testWidgets(
    'tab animation preserves state and follows the most recent selection',
    (tester) async {
      Widget tabs(int index) => MaterialApp(
        home: Scaffold(
          body: SmoothTabStack(
            index: index,
            children: const [_Counter(), Text('Other')],
          ),
        ),
      );
      await tester.pumpWidget(tabs(0));
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      await tester.pumpWidget(tabs(1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(tabs(0));
      await tester.pumpAndSettle();
      expect(find.text('Count 1'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
