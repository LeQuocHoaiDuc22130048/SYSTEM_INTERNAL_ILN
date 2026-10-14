import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_inverter_likenew/models/app_banner.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/widgets/banner_canvas.dart';

void main() {
  test(
    'first request does not expose the default blue banner while pending',
    () async {
      final response = Completer<http.Response>();
      final provider = BackendDataProvider(
        api: ApiClient(client: MockClient((_) => response.future)),
      );
      expect(provider.banners, isEmpty);
      final loading = provider.loadBanners();
      expect(provider.banners, isEmpty);
      response.complete(
        http.Response('{"data":[{"id":"real","title":"Real banner"}]}', 200),
      );
      await loading;
      expect(provider.banners.single.id, 'real');
      provider.clear();
      expect(provider.banners, isEmpty);
      provider.dispose();
    },
  );

  test('empty response still supplies the fallback after loading', () async {
    final provider = BackendDataProvider(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{"data":[]}', 200)),
      ),
    );
    await provider.loadBanners();
    expect(provider.banners.single.id, 'default');
    provider.dispose();
  });

  testWidgets('canvas with a background image does not paint a blue gradient', (
    tester,
  ) async {
    const image = NetworkImage('https://example.com/banner.png');
    final pendingImage = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(
      image,
      () => OneFrameImageStreamCompleter(pendingImage.future),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(image));
    const banner = AppBanner(
      id: 'image',
      title: '',
      imagePosition: 'NONE',
      backgroundImageUrl: 'https://example.com/banner.png',
      designJson:
          '{"version":1,"nodes":{"title":{"x":5,"y":5,"width":80,"height":30}}}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
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
    );
    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>();
    final background = decorations.singleWhere(
      (decoration) => decoration.image != null,
    );
    expect(background.gradient, isNull);
  });
}
