import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/app_banner.dart';
import 'package:system_inverter_likenew/models/banner_canvas_design.dart';
import 'package:system_inverter_likenew/widgets/banner_canvas.dart';

void main() {
  final raw = jsonEncode({
    'version': 1,
    'nodes': {
      'title': {
        'x': 10,
        'y': 10,
        'width': 80,
        'height': 30,
        'fontSize': 20,
        'fontWeight': 800,
        'color': '#ffffff',
        'lineColors': ['#ffffff', '#facc15'],
        'align': 'center',
      },
      'mascot': {'x': 70, 'y': 45, 'width': 25, 'height': 50, 'flip': true},
      'button0': {
        'x': 30,
        'y': 75,
        'width': 40,
        'height': 20,
        'fontSize': 12,
        'color': '#ffffff',
        'gradient': '#2563eb,#7c3aed',
        'radius': 8,
        'icon': 'cart',
      },
    },
  });

  test('canvas config survives AppBanner serialization', () {
    final banner = AppBanner.fromJson({
      'id': 'canvas',
      'title': 'Test',
      'designJson': raw,
    });
    expect(banner.canvasDesign!.nodes['title']!.x, 10);
    expect(AppBanner.fromJson(banner.toJson()).designJson, raw);
  });
  test('partial design inherits the same layer defaults as web preview', () {
    final parsed = BannerCanvasDesign.parse(jsonEncode({'version': 1, 'nodes': {
      'badge': {'x': 5, 'y': 8, 'width': 58, 'height': 16, 'verticalAlign': 'center'},
    }}))!;
    expect(parsed.nodes.length, 7);
    expect(parsed.nodes['badge']!.style['verticalAlign'], 'center');
    expect(parsed.nodes['badge']!.style['fontSize'], 10);
    expect(parsed.nodes['badge']!.style['radius'], 16);
    expect(parsed.nodes['button0']!.style['icon'], 'arrow');
  });

  test('invalid canvas safely falls back to legacy rendering', () {
    expect(BannerCanvasDesign.parse('{'), isNull);
    expect(BannerCanvasDesign.parse('{"version":2,"nodes":{}}'), isNull);
    expect(
      BannerCanvasDesign.parse('{"version":1,"nodes":{"title":{"x":"bad"}}}'),
      isNull,
    );
    expect(BannerCanvasNode.color('#ffffff33'), const Color(0x33ffffff));
  });

  testWidgets('very small CTA with a large font and icon does not overflow', (
    tester,
  ) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    data['nodes']['button0']['width'] = 5;
    data['nodes']['button0']['height'] = 5;
    data['nodes']['button0']['fontSize'] = 48;
    final banner = AppBanner(
      id: 'small-cta',
      title: '',
      imagePosition: 'NONE',
      designJson: jsonEncode(data),
      buttons: const [AppBannerButton(text: 'Một nút có nội dung rất dài')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: BannerCanvas(
              banner: banner,
              design: banner.canvasDesign!,
              baseUrl: '',
              mascot: const SizedBox.shrink(),
              onTap: () {},
              onButtonTap: (_) {},
              textStyle: (_, style) => style,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 720.0]) {
    testWidgets('canvas scales positions and typography at width $width', (
      tester,
    ) async {
      AppBannerButton? clicked;
      final banner = AppBanner(
        id: 'canvas',
        title: 'Dòng một\nDòng hai',
        designJson: raw,
        buttons: const [
          AppBannerButton(
            text: 'Mua ngay',
            actionType: 'SCREEN',
            actionValue: 'warehouse',
          ),
        ],
      );
      final canvas = BannerCanvas(
        banner: banner,
        design: banner.canvasDesign!,
        baseUrl: '',
        mascot: const SizedBox(key: ValueKey('mascot-image')),
        onTap: () {},
        onButtonTap: (button) => clicked = button,
        textStyle: (_, style) => style,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: width / 2, child: canvas),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(BannerCanvas));
      final title = find.byKey(const ValueKey('canvas-title'));
      expect(
        tester.getTopLeft(title) - origin,
        Offset(width * .1, width / 2 * .1),
      );
      expect(tester.getSize(title).width, width * .8);
      final rich = tester.widget<RichText>(
        find.descendant(of: title, matching: find.byType(RichText)),
      );
      expect(rich.text.style!.fontSize, 20 * width / 360);
      expect(rich.textAlign, TextAlign.center);
      expect(
        ((rich.text as TextSpan).children![1] as TextSpan).style!.color,
        const Color(0xfffacc15),
      );
      final flip = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('mascot-image')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(flip.transform.entry(0, 0), -1);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      await tester.tap(find.text('Mua ngay'));
      expect(clicked!.actionValue, 'warehouse');
      expect(tester.takeException(), isNull);
    });
  }
}
