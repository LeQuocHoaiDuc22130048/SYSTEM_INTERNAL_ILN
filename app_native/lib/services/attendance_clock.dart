import 'package:flutter/services.dart';

class AttendanceClock {
  static const _channel = MethodChannel('attendance/device_clock');
  Future<({int elapsed, int boot})> snapshot() async {
    final value = await _channel.invokeMapMethod<String, dynamic>('snapshot');
    return (
      elapsed: (value?['elapsedRealtimeMillis'] as num?)?.toInt() ?? -1,
      boot: (value?['bootCount'] as num?)?.toInt() ?? -1,
    );
  }
}
