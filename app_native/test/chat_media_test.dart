import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/widgets/image_preview_dialog.dart';
import 'package:system_inverter_likenew/widgets/chat/chat_media_image.dart';
import 'package:system_inverter_likenew/widgets/video_player_dialog.dart';
// The native player is external to these widget interactions.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _UnavailableVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      Stream.error(PlatformException(code: 'offline', message: 'Offline'));
  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  testWidgets('landscape video keeps error and close button within safe area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 300);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    final original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _UnavailableVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoPlayerDialog(
          videoUrl: 'https://example.test/landscape.mp4',
          title: 'Video',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Không thể phát video'), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Đóng')).top,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester.getRect(find.textContaining('Không thể phát video')).bottom,
      lessThanOrEqualTo(284),
    );
  });
  for (final cancel in [false, true]) {
    testWidgets(
      cancel
          ? 'canceled downward video drag keeps viewer open'
          : 'video opens fullscreen and downward swipe closes its error state',
      (tester) async {
        final original = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = _UnavailableVideoPlatform();
        addTearDown(() => VideoPlayerPlatform.instance = original);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const VideoPlayerDialog(
                      videoUrl: 'https://example.test/video.mp4',
                      title: 'Video',
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(Dialog)), const Size(800, 600));
        expect(find.textContaining('Không thể phát video'), findsOneWidget);
        if (cancel) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(VideoPlayerDialog)),
          );
          await gesture.moveBy(const Offset(0, 30));
          await gesture.moveBy(const Offset(0, 180));
          await gesture.cancel();
        } else {
          await tester.drag(
            find.byType(VideoPlayerDialog),
            const Offset(0, 180),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(VideoPlayerDialog),
          cancel ? findsOneWidget : findsNothing,
        );
      },
    );
  }
  testWidgets('image thumbnail opens fullscreen with one tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMediaImage(
            imageUrl: 'https://example.test/thumbnail.png',
            caption: 'Chi tiết ảnh',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChatMediaImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsOneWidget);
    expect(find.text('Chi tiết ảnh'), findsOneWidget);
  });

  testWidgets('failed thumbnail remains readable within narrow constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: const ChatMediaImage(
              imageUrl: 'https://example.test/unavailable.png',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final error = find.text('Không thể tải ảnh');
    expect(error, findsOneWidget);
    final context = tester.element(error);
    expect(
      tester.widget<Text>(error).style!.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
    expect(
      tester.getSize(find.byType(ChatMediaImage)).width,
      lessThanOrEqualTo(120),
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> openViewer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ImagePreviewDialog(
                      imageUrl: 'https://example.test/photo.png',
                      caption: 'Ảnh đính kèm',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('fullscreen image shows caption and accessible close control', (
    tester,
  ) async {
    await openViewer(tester);
    expect(find.text('Ảnh đính kèm'), findsOneWidget);
    expect(find.byTooltip('Đóng'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsNothing);
  });

  testWidgets('downward swipe dismisses unzoomed image', (tester) async {
    await openViewer(tester);
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsNothing);
  });

  testWidgets('canceled downward image drag keeps viewer open', (tester) async {
    await openViewer(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveViewer)),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 180));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsOneWidget);
  });

  testWidgets('downward pan preserves zoomed image', (tester) async {
    await openViewer(tester);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(find.byType(ImagePreviewDialog), findsOneWidget);
  });
}
