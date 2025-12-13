import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _accessKey = 'bearer_token';
const _refreshKey = 'refresh_token';
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
  return prefs.getString(_accessKey);
}

Future<String?> getRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_refreshKey);
}

Future<void> clearTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_accessKey);
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
