/// Unit tests for ApiClient silent-refresh logic and repositories, using a
/// mocked http.Client and in-memory SecureStore.
/// Run with: flutter test  (not compiled in this build environment — see
/// docs/testing-report.md).
import 'dart:convert';

import 'package:bracelet_monitor/core/api_client.dart';
import 'package:bracelet_monitor/core/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStore extends Mock implements SecureStore {}

void main() {
  group('ApiClient', () {
    late MockSecureStore store;

    setUp(() {
      store = MockSecureStore();
      when(() => store.readAccessToken()).thenAnswer((_) async => 'old-access');
      when(() => store.readRefreshToken()).thenAnswer((_) async => 'refresh-1');
      when(() => store.saveTokens(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'))).thenAnswer((_) async {});
      when(() => store.clear()).thenAnswer((_) async {});
    });

    test('adds bearer header and parses JSON', () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer old-access');
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final api = ApiClient(httpClient: client, store: store);
      final data = await api.get('/babies/');
      expect(data['ok'], true);
    });

    test('silently refreshes on 401 then replays request', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
              jsonEncode({'access': 'new-access', 'refresh': 'refresh-2'}), 200);
        }
        // First data call: 401. Replay (with refreshed token): 200.
        if (calls == 1) return http.Response('{"detail":"expired"}', 401);
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final api = ApiClient(httpClient: client, store: store);
      final data = await api.get('/babies/');
      expect(data['ok'], true);
      verify(() => store.saveTokens(access: 'new-access', refresh: 'refresh-2'))
          .called(1);
    });

    test('throws UnauthenticatedException when refresh fails', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response('{"detail":"revoked"}', 401);
        }
        return http.Response('{"detail":"expired"}', 401);
      });
      final api = ApiClient(httpClient: client, store: store);
      expect(() => api.get('/babies/'),
          throwsA(isA<UnauthenticatedException>()));
    });

    test('coalesces concurrent refreshes into one call (regression: racing '
        'refreshes used to let the loser wipe out the winner\'s valid tokens, '
        'silently logging the user out)', () async {
      var refreshCalls = 0;
      var dataCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          // Slow refresh so both requests are genuinely in flight together.
          await Future.delayed(const Duration(milliseconds: 20));
          return http.Response(
              jsonEncode({'access': 'new-access', 'refresh': 'refresh-2'}), 200);
        }
        dataCallCount++;
        // Both requests' first attempt 401s; their replays (post-refresh) succeed.
        if (dataCallCount <= 2) return http.Response('{"detail":"expired"}', 401);
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final api = ApiClient(httpClient: client, store: store);

      final results =
          await Future.wait([api.get('/babies/'), api.get('/alerts/')]);

      expect(results[0]['ok'], true);
      expect(results[1]['ok'], true);
      expect(refreshCalls, 1); // deduplicated, not one per concurrent request
    });

    test('sends PATCH with encoded body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {'first_name': 'Updated'});
        return http.Response(jsonEncode({'first_name': 'Updated'}), 200);
      });
      final api = ApiClient(httpClient: client, store: store);
      final data = await api.patch('/me/', body: {'first_name': 'Updated'});
      expect(data['first_name'], 'Updated');
    });

    test('throws ApiException on 4xx/5xx', () async {
      final client =
          MockClient((_) async => http.Response('{"detail":"bad"}', 400));
      final api = ApiClient(httpClient: client, store: store);
      expect(() => api.get('/babies/'), throwsA(isA<ApiException>()));
    });
  });
}
