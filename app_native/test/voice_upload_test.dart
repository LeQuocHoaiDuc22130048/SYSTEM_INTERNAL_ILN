import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';

void main() {
  testWidgets('voice upload uses authenticated client and audio MIME type', (
    tester,
  ) async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: 'https://chat.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"id":"voice"}', 200);
      }),
    )..accessToken = 'test-token';
    final result = await api.postMultipart(
      '/api/v1/conversations/c1/messages/media',
      fields: {'messageType': 'FILE'},
      filename: 'voice.m4a',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'audio/mp4',
    );
    expect(result['id'], 'voice');
    expect(captured.headers['Authorization'], 'Bearer test-token');
    expect(captured.body.toLowerCase(), contains('content-type: audio/mp4'));
    expect(captured.bodyBytes, containsAllInOrder([1, 2, 3]));
  });
}
