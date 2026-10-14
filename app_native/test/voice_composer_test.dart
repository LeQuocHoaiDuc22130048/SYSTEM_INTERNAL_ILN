import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/services/voice_recorder.dart';
import 'package:system_inverter_likenew/utils/voice_composer_controller.dart';
import 'package:system_inverter_likenew/widgets/chat/voice_record_button.dart';
import 'package:flutter/material.dart';

class FakeRecorder implements VoiceRecorder {
  Completer<void>? starting;
  bool denied = false;
  bool canceled = false;
  @override
  Future<void> start() async {
    if (denied) throw Exception('Permission denied');
    await starting?.future;
  }

  @override
  Future<RecordedVoice> stop() async => RecordedVoice(
    bytes: Uint8List.fromList([1, 2, 3]),
    filename: 'voice.m4a',
    duration: const Duration(seconds: 1),
  );
  @override
  Future<void> cancel() async {
    canceled = true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('canceled start cannot be changed to send by a later release', () async {
    final recorder = FakeRecorder()..starting = Completer<void>();
    var sent = false;
    final controller = VoiceComposerController(
      recorder: recorder,
      onSend: (_) async {
        sent = true;
      },
    );
    final starting = controller.start();
    await controller.finish(cancel: true);
    await controller.finish();
    recorder.starting!.complete();
    await starting;
    expect(sent, isFalse);
    expect(recorder.canceled, isTrue);
    controller.dispose();
  });

  test('leaving while microphone starts never sends pending audio', () async {
    final recorder = FakeRecorder()..starting = Completer<void>();
    var sent = false;
    final controller = VoiceComposerController(
      recorder: recorder,
      onSend: (_) async {
        sent = true;
      },
    );
    final starting = controller.start();
    controller.dispose();
    recorder.starting!.complete();
    await starting;
    expect(sent, isFalse);
    expect(recorder.canceled, isTrue);
  });

  testWidgets('hold and release sends voice and dragging left cancels', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VoiceRecordButton(
              recorder: recorder,
              onSend: (_) async {
                sends++;
              },
            ),
          ),
        ),
      ),
    );
    final button = find.byIcon(Icons.mic_none);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sends, 1);
    final cancel = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await cancel.moveBy(const Offset(-100, 0));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(recorder.canceled, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'release while recorder starts still stops and sends once ready',
    () async {
      final recorder = FakeRecorder()..starting = Completer<void>();
      final sent = <RecordedVoice>[];
      final controller = VoiceComposerController(
        recorder: recorder,
        onSend: (voice) async {
          sent.add(voice);
        },
      );
      final starting = controller.start();
      await controller.finish();
      recorder.starting!.complete();
      await starting;
      expect(sent.single.bytes, [1, 2, 3]);
      expect(controller.state, VoiceComposerState.idle);
      controller.dispose();
    },
  );

  test(
    'cancel does not send a recording and upload failure retains retry',
    () async {
      final recorder = FakeRecorder();
      var fail = true;
      var sends = 0;
      final controller = VoiceComposerController(
        recorder: recorder,
        onSend: (_) async {
          sends++;
          if (fail) throw Exception('Offline');
        },
      );
      await controller.start();
      await controller.finish(cancel: true);
      expect(recorder.canceled, isTrue);
      expect(sends, 0);
      await controller.start();
      await controller.finish();
      expect(controller.state, VoiceComposerState.failed);
      expect(controller.pending, isNotNull);
      fail = false;
      await controller.retry();
      expect(sends, 2);
      expect(controller.pending, isNull);
      expect(controller.state, VoiceComposerState.idle);
      controller.dispose();
    },
  );

  test(
    'denied microphone permission sends nothing and returns actionable error',
    () async {
      final recorder = FakeRecorder()..denied = true;
      var sent = false;
      final controller = VoiceComposerController(
        recorder: recorder,
        onSend: (_) async {
          sent = true;
        },
      );
      await controller.start();
      expect(sent, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.state, VoiceComposerState.idle);
      controller.dispose();
    },
  );
}
