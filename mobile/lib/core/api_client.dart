/// HTTP client with JWT bearer injection and transparent silent refresh.
/// On 401: tries POST /auth/refresh once with the stored refresh token,
/// persists rotated tokens, replays the original request. On refresh failure
/// the session is cleared and an [UnauthenticatedException] is thrown so the
/// UI can route to Login.
///
/// Refresh calls are coalesced (see [_tryRefresh]): the backend rotates the
/// refresh token on every use (revokes the old session), so if two requests
/// hit a 401 around the same moment and both raced to refresh independently,
/// whichever reached the server second would get "Session revoked" and wipe
/// out the tokens the first one just legitimately saved — silently logging
/// the user out despite a valid session. Every 401 that arrives while a
/// refresh is already in flight awaits that same attempt instead.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'secure_store.dart';

class UnauthenticatedException implements Exception {}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _http;
  final SecureStore _store;
  Future<bool>? _refreshInFlight;

  ApiClient({http.Client? httpClient, SecureStore? store})
      : _http = httpClient ?? http.Client(),
        _store = store ?? SecureStore();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _store.readAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null) return false;
    final resp = await _http.post(
      Uri.parse('${AppConfig.apiV1}/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    await _store.saveTokens(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
    return true;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    bool retried = false,
  }) async {
    var uri = Uri.parse('${AppConfig.apiV1}$path');
    if (query != null) uri = uri.replace(queryParameters: query);

    final headers = await _headers(auth: auth);
    late http.Response resp;
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        resp = await _http.get(uri, headers: headers);
      case 'POST':
        resp = await _http.post(uri, headers: headers, body: encoded);
      case 'PUT':
        resp = await _http.put(uri, headers: headers, body: encoded);
      case 'PATCH':
        resp = await _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        resp = await _http.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError('Unsupported method $method');
    }

    if (resp.statusCode == 401 && auth && !retried) {
      if (await _tryRefresh()) {
        return request(method, path,
            body: body, query: query, auth: auth, retried: true);
      }
      await _store.clear();
      throw UnauthenticatedException();
    }

    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, resp.body);
    }
    if (resp.body.isEmpty) return null;
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      request('POST', path, body: body, auth: auth);
  Future<dynamic> put(String path, {Object? body}) =>
      request('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) =>
      request('PATCH', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) =>
      request('DELETE', path, body: body);
}
