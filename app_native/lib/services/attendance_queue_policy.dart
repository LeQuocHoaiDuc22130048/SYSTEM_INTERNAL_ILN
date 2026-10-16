import 'dart:convert';

class AttendanceQueuePolicy {
  static List<Map<String, Object?>> eligible(
    List<Map<String, Object?>> rows, {
    required String? accountId,
    required String? deviceId,
    int limit = 20,
  }) {
    final selected = <Map<String, Object?>>[];
    for (final row in rows) {
      final raw = row['tablet_context'];
      if (accountId == null) {
        if (raw != null) continue;
      } else {
        if (raw == null) continue;
        try {
          final owner = jsonDecode(raw as String) as Map;
          if (owner['accountId'] != accountId || owner['deviceId'] != deviceId) {
            continue;
          }
        } catch (_) {
          continue;
        }
      }
      selected.add(row);
      if (selected.length == limit) break;
    }
    return selected;
  }
}
