import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _accessKey = 'bearer_token';
const _refreshKey = 'refresh_token';
const _legacyAccessKey = 'authToken';
const _secureStorage = FlutterSecureStorage();

Future<void> _writeSecure(String key, String? value) async {
  try {
    if (value == null) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  } catch (_) {}
}

Future<void> saveTokens({String? accessToken, String? refreshToken}) async {
  final prefs = await SharedPreferences.getInstance();
  if (accessToken != null) {
    await prefs.setString(_accessKey, accessToken);
    await _writeSecure(_accessKey, accessToken);
  }
  if (refreshToken != null) {
    await prefs.setString(_refreshKey, refreshToken);
    await _writeSecure(_refreshKey, refreshToken);
  }
}

Future<String?> getAccessToken() async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getString(_accessKey);
  if (current != null && current.isNotEmpty) return current;

  // Backward compatibility for older app versions.
  final legacy = prefs.getString(_legacyAccessKey);
  if (legacy != null && legacy.isNotEmpty) {
    await prefs.setString(_accessKey, legacy);
    await _writeSecure(_accessKey, legacy);
    return legacy;
  }
  return null;
}

Future<String?> getRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_refreshKey);
}

Future<void> clearTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_accessKey);
  await prefs.remove(_legacyAccessKey);
  await prefs.remove(_refreshKey);
  await _writeSecure(_accessKey, null);
  await _writeSecure(_refreshKey, null);
}

Future<String?> refreshAccessToken() async {
  final refreshToken = await getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) return null;

  try {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/refresh'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final data = decoded['data'] ?? decoded;
      final newAccess =
          data['token'] ?? data['access_token'] ?? decoded['access_token'];
      final newRefresh =
          data['refresh_token'] ?? data['refreshToken'] ?? decoded['refresh_token'];
      if (newAccess != null) {
        await saveTokens(
          accessToken: newAccess.toString(),
          refreshToken: newRefresh?.toString() ?? refreshToken,
        );
        return newAccess.toString();
      }
    } else if (res.statusCode == 401) {
      await clearTokens();
    }
  } catch (_) {}
  return null;
}

class AuthRequiredException implements Exception {
  const AuthRequiredException();

  @override
  String toString() => 'AuthRequiredException';
}

Map<String, String> _authHeaders(
  String token, [
  Map<String, String>? headers,
]) {
  final merged = <String, String>{
    if (headers != null) ...headers,
  };
  merged['Authorization'] = 'Bearer $token';
  return merged;
}

Future<http.Response> _sendWithAuthRetry(
  Future<http.Response> Function(String token) sender,
) async {
  final token = await getAccessToken();
  if (token == null || token.isEmpty) {
    throw const AuthRequiredException();
  }

  var response = await sender(token);
  if (response.statusCode != 401) return response;

  final refreshed = await refreshAccessToken();
  if (refreshed == null || refreshed.isEmpty) {
    return response;
  }
  response = await sender(refreshed);
  return response;
}

Future<http.Response> authGet(
  Uri url, {
  Map<String, String>? headers,
}) {
  return _sendWithAuthRetry(
    (token) => http.get(url, headers: _authHeaders(token, headers)),
  );
}

Future<http.Response> authPost(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _sendWithAuthRetry(
    (token) => http.post(
      url,
      headers: _authHeaders(token, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<http.Response> authPut(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _sendWithAuthRetry(
    (token) => http.put(
      url,
      headers: _authHeaders(token, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<http.Response> authDelete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return _sendWithAuthRetry(
    (token) => http.delete(
      url,
      headers: _authHeaders(token, headers),
      body: body,
      encoding: encoding,
    ),
  );
}

Future<http.Response> authMultipart(
  Future<http.MultipartRequest> Function(String token) requestBuilder,
) {
  return _sendWithAuthRetry((token) async {
    final request = await requestBuilder(token);
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  });
}
