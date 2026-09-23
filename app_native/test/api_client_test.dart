import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_internal_likenew/utils/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test(
      'TC1: ApiClient can be initialized with custom baseUrl and make requests',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/test') {
            return http.Response(
              jsonEncode({
                'data': {'status': 'ok'},
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          client: mockClient,
          baseUrl: 'https://test.api.local',
        );

        final result = await apiClient.get('/api/v1/test');
        expect(result, {'status': 'ok'});
      },
    );

    test(
      'TC2: Concurrent 401 requests both succeed after single token refresh',
      () async {
        int refreshCallCount = 0;
        int resource1CallCount = 0;
        int resource2CallCount = 0;

        late ApiClient apiClient;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            refreshCallCount++;
            // Simulate network delay for refresh
            await Future.delayed(const Duration(milliseconds: 50));
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'new_access_token',
                  'refreshToken': 'new_refresh_token',
                },
              }),
              200,
            );
          }

          if (request.url.path == '/api/v1/resource1') {
            resource1CallCount++;
            final authHeader = request.headers['Authorization'];
            if (authHeader == 'Bearer new_access_token') {
              return http.Response(
                jsonEncode({'data': 'resource1_success'}),
                200,
              );
            }
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }

          if (request.url.path == '/api/v1/resource2') {
            resource2CallCount++;
            final authHeader = request.headers['Authorization'];
            if (authHeader == 'Bearer new_access_token') {
              return http.Response(
                jsonEncode({'data': 'resource2_success'}),
                200,
              );
            }
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }

          return http.Response('Not found', 404);
        });

        apiClient = ApiClient(
          client: mockClient,
          baseUrl: 'https://test.api.local',
        );
        apiClient.accessToken = 'expired_access_token';
        apiClient.refreshToken = 'valid_refresh_token';

        // Fire two concurrent requests simultaneously while token is expired
        final future1 = apiClient.get('/api/v1/resource1');
        final future2 = apiClient.get('/api/v1/resource2');

        final results = await Future.wait([future1, future2]);

        expect(results[0], 'resource1_success');
        expect(results[1], 'resource2_success');
        expect(
          resource1CallCount,
          2,
          reason: 'Resource 1 should be attempted twice (initial + retry)',
        );
        expect(
          resource2CallCount,
          2,
          reason: 'Resource 2 should be attempted twice (initial + retry)',
        );
        expect(
          refreshCallCount,
          1,
          reason: 'Token should only be refreshed once for concurrent requests',
        );
        expect(apiClient.accessToken, 'new_access_token');
      },
    );
  });
}
