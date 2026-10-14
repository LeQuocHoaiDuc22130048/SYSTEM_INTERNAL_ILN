import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/video_player_dialog.dart';
// Native decoding is external; the controller and viewer remain real.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  Duration position = Duration.zero;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

void main() {
  late _VideoPlatform native;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    native = _VideoPlatform();
    VideoPlayerPlatform.instance = native;
    addTearDown(() async {
      VideoPlayerPlatform.instance = original;
      await native.events.close();
    });
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoPlayerDialog(
          videoUrl: 'https://example.test/video.mp4',
          title: 'Video',
        ),
      ),
    );
    await tester.pump();
    native.events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 84),
        size: const Size(1920, 1080),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('header and timeline stay at screen edges in portrait', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await open(tester);
    expect(tester.getRect(find.byTooltip('Đóng')).top, lessThan(100));
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('01:24'), findsOneWidget);
    expect(tester.getRect(find.byType(Slider)).bottom, greaterThan(750));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'playing controls hide and tapping restores them; pause keeps them visible',
    (tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Tạm dừng').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(100, 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Tạm dừng').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pump(const Duration(seconds: 4));
      expect(find.byTooltip('Phát').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('double taps seek ten seconds and clamp to start and end', (
    tester,
  ) async {
    await open(tester);
    Future<void> doubleTap(Offset point) async {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await doubleTap(const Offset(700, 200));
    expect(find.text('00:10'), findsOneWidget);
    await doubleTap(const Offset(100, 200));
    expect(find.text('00:00'), findsOneWidget);
    await doubleTap(const Offset(100, 200));
    expect(find.text('00:00'), findsOneWidget);
    native.position = const Duration(seconds: 80);
    await tester.pump(const Duration(milliseconds: 600));
    await doubleTap(const Offset(700, 200));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 84000);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mute toggles and scrubbing preserves paused playback', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Tắt tiếng'));
    await tester.pump();
    expect(find.byTooltip('Bật tiếng'), findsOneWidget);
    await tester.tap(find.byTooltip('Tạm dừng'));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, greaterThan(0));
    expect(find.byTooltip('Phát'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('short and canceled drags restore video position', (
    tester,
  ) async {
    await open(tester);
    final gesture = await tester.startGesture(const Offset(100, 200));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    final during = tester.getRect(find.byType(AspectRatio));
    expect(during.center.dy, greaterThan(300));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AspectRatio)).center.dy, closeTo(300, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swipe starting on play control still moves the video', (
    tester,
  ) async {
    await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Tạm dừng')),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();
    expect(
      tester.getRect(find.byType(AspectRatio)).center.dy,
      greaterThan(350),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AspectRatio)).center.dy, closeTo(300, 1));
    await tester.pumpWidget(const SizedBox());
  });
}
