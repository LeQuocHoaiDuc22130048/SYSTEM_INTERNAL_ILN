import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/widgets/chat/voice_message_player.dart';
// The native decoder is external; keep the widget and authenticated source real.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _AudioPlatform extends VideoPlayerPlatform {
  VideoCreationOptions? options;
  int plays = 0;
  int pauses = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    this.options = options;
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: Size.zero,
    ),
  );
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  testWidgets('audio play and pause pass credentials to the media decoder', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = _AudioPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final api = ApiClient(baseUrl: 'https://chat.test')
      ..accessToken = 'voice-token';
    final auth = AuthProvider(apiClient: api);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(
          home: Scaffold(
            body: VoiceMessagePlayer(
              url: 'https://chat.test/api/v1/message-media/voice.m4a',
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Phát tin nhắn thoại'));
    await tester.pumpAndSettle();
    expect(
      platform.options!.dataSource.httpHeaders['Authorization'],
      'Bearer voice-token',
    );
    expect(platform.plays, 1);
    await tester.tap(find.byTooltip('Tạm dừng'));
    await tester.pumpAndSettle();
    expect(platform.pauses, greaterThan(0));
    await tester.tap(find.byTooltip('Phát tin nhắn thoại'));
    await tester.pumpAndSettle();
    final pausesBeforeBackground = platform.pauses;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.pauses, greaterThan(pausesBeforeBackground));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });
}
