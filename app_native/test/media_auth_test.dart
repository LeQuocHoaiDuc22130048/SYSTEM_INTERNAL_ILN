import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/chat_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';
import 'package:system_inverter_likenew/screens/messages_page.dart';
import 'package:system_inverter_likenew/widgets/chat/chat_media_image.dart';
import 'package:system_inverter_likenew/widgets/image_preview_dialog.dart';
import 'package:system_inverter_likenew/widgets/video_player_dialog.dart';
// Native playback is external; inspect the actual player data source it receives.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _RecordingVideoPlatform extends VideoPlayerPlatform {
  DataSource? source;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      Stream.error(PlatformException(code: 'offline', message: 'Offline'));
  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  testWidgets('inline chat video authenticates its native request', (
    tester,
  ) async {
    final native = _RecordingVideoPlatform();
    final original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = native;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final api = ApiClient(
      baseUrl: 'https://backend.test',
      client: MockClient((request) async {
        dynamic response = {};
        if (request.url.path == '/api/v1/conversations') {
          response = [
            {
              'id': 'c1',
              'name': 'Authenticated chat',
              'members': [],
              'createdAt': '2026-10-13T10:00:00',
            },
          ];
        } else if (request.url.path.endsWith('/messages')) {
          response = {
            'content': [
              {
                'id': 'v1',
                'conversationId': 'c1',
                'sender': {'id': 'sender', 'fullName': 'Sender'},
                'content': '',
                'messageType': 'VIDEO',
                'mediaUrl': '/api/v1/message-media/video.mp4',
                'sentAt': '2026-10-13T10:00:00',
                'readByUserIds': [],
              },
            ],
          };
        }
        return http.Response(jsonEncode(response), 200);
      }),
    )..accessToken = 'inline-token';
    final auth = AuthProvider(apiClient: api);
    final notifications = NotificationProvider(api: api);
    final chat = ChatProvider(api: api, notificationProvider: notifications);
    final backend = BackendDataProvider(api: api);
    addTearDown(() {
      chat.dispose();
      notifications.dispose();
      auth.dispose();
      backend.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: backend),
        ],
        child: const MaterialApp(home: MessagesPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Authenticated chat'));
    await tester.pumpAndSettle();
    expect(
      native.source!.uri,
      'https://backend.test/api/v1/message-media/video.mp4',
    );
    expect(native.source!.httpHeaders, {
      'Authorization': 'Bearer inline-token',
    });
    expect(tester.takeException(), isNull);
  });

  test(
    'media headers are restricted to backend protected paths and current token',
    () {
      final api = ApiClient(baseUrl: 'https://backend.test')
        ..accessToken = 'first-token';
      for (final url in [
        'https://outside.test/api/v1/message-media/file.png',
        'https://backend.test.outside.test/api/v1/message-media/file.png',
        'https://backend.test:444/api/v1/message-media/file.png',
        'http://backend.test/api/v1/message-media/file.png',
        'https://backend.test/public/photo.png',
        'https://backend.test/api/v1/message-media-lookalike/photo.png',
        'https://user@backend.test/api/v1/message-media/photo.png',
        'data:image/png;base64,AA==',
      ]) {
        expect(api.mediaHeadersFor(url), isEmpty, reason: url);
      }
      const url = 'https://backend.test/api/v1/message-media/photo.png';
      expect(api.mediaHeadersFor(url), {'Authorization': 'Bearer first-token'});
      api.accessToken = 'refreshed-token';
      expect(api.mediaHeadersFor(url), {
        'Authorization': 'Bearer refreshed-token',
      });
      api.accessToken = null;
      expect(api.mediaHeadersFor(url), isEmpty);
    },
  );

  for (final path in [
    '/api/v1/message-media/photo.png',
    '/api/v1/repair-media/photo.png',
  ]) {
    testWidgets(
      'protected image $path authenticates thumbnail and full screen',
      (tester) async {
        final api = ApiClient(baseUrl: 'https://backend.test')
          ..accessToken = 'test-token';
        final auth = AuthProvider(apiClient: api);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home: Scaffold(
                body: ChatMediaImage(imageUrl: 'https://backend.test$path'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as NetworkImage).headers, {
          'Authorization': 'Bearer test-token',
        });
        await tester.tap(find.byType(ChatMediaImage));
        await tester.pumpAndSettle();
        final viewer = find.byType(ImagePreviewDialog);
        final fullImage = tester.widget<Image>(
          find.descendant(of: viewer, matching: find.byType(Image)),
        );
        expect((fullImage.image as NetworkImage).headers, {
          'Authorization': 'Bearer test-token',
        });
      },
    );
  }

  testWidgets('native video receives backend auth headers', (tester) async {
    final native = _RecordingVideoPlatform();
    final original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = native;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final auth = AuthProvider(
      apiClient: ApiClient(baseUrl: 'https://backend.test')
        ..accessToken = 'video-token',
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
          home: VideoPlayerDialog(
            videoUrl: 'https://backend.test/api/v1/message-media/video.mp4',
            title: 'Video',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(native.source!.httpHeaders, {'Authorization': 'Bearer video-token'});
  });

  testWidgets('external image receives no backend token', (tester) async {
    final auth = AuthProvider(
      apiClient: ApiClient(baseUrl: 'https://backend.test')
        ..accessToken = 'private-token',
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
          home: Scaffold(
            body: ChatMediaImage(imageUrl: 'https://media.giphy.com/image.gif'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(find.byType(Image)).image as NetworkImage)
              .headers ??
          {},
      isEmpty,
    );
  });
}
