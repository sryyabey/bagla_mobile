import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';

enum AppleAuthErrorType {
  canceled,
  identityTokenMissing,
  validation,
  server,
  unknown,
}

class AppleAuthException implements Exception {
  final String message;
  final AppleAuthErrorType type;

  const AppleAuthException(this.message, this.type);

  factory AppleAuthException.canceled() {
    return const AppleAuthException(
      'Apple giriş iptal edildi.',
      AppleAuthErrorType.canceled,
    );
  }

  factory AppleAuthException.identityTokenMissing() {
    return const AppleAuthException(
      'Apple idToken alınamadı.',
      AppleAuthErrorType.identityTokenMissing,
    );
  }

  factory AppleAuthException.validation(String message) {
    return AppleAuthException(message, AppleAuthErrorType.validation);
  }

  factory AppleAuthException.server(String message) {
    return AppleAuthException(message, AppleAuthErrorType.server);
  }

  factory AppleAuthException.unknown(String message) {
    return AppleAuthException(message, AppleAuthErrorType.unknown);
  }

  @override
  String toString() => message;
}

class AppleAuthResult {
  final String token;
  final Map<String, dynamic>? user;

  const AppleAuthResult({required this.token, this.user});
}

class AppleAuthService {
  final http.Client _client;

  AppleAuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<AppleAuthResult> login() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: _webAuthOptionsIfNeeded(),
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw AppleAuthException.identityTokenMissing();
      }

      final fullName = _formatFullName(
        credential.givenName,
        credential.familyName,
      );

      final payload = <String, dynamic>{
        'id_token': idToken,
        'device_name': _deviceName(),
        'name': fullName,
        'email': credential.email,
      }..removeWhere((key, value) => value == null);

      final response = await _client.post(
        Uri.parse('$apiBaseUrl/api/login/apple'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ??
            data['access_token'] ??
            (data['data'] != null ? data['data']['token'] : null);
        if (token == null) {
          throw AppleAuthException.server('Token alınamadı.');
        }
        final user = data['user'] ??
            (data['data'] != null ? data['data']['user'] : null);
        return AppleAuthResult(
          token: token.toString(),
          user: user is Map ? Map<String, dynamic>.from(user) : null,
        );
      }

      if (response.statusCode == 422) {
        final decoded = jsonDecode(response.body);
        final message =
            decoded is Map ? decoded['message']?.toString() : null;
        final errors = decoded is Map ? decoded['errors'] : null;
        throw AppleAuthException.validation(
          message ?? _formatValidationErrors(errors),
        );
      }

      final message = _extractMessage(response.body);
      throw AppleAuthException.server(
        message ?? 'Apple giriş başarısız (HTTP ${response.statusCode}).',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AppleAuthException.canceled();
      }
      throw AppleAuthException.server(
        'Apple girişi başarısız: ${e.message}',
      );
    } on AppleAuthException {
      rethrow;
    } catch (e) {
      throw AppleAuthException.unknown('Apple girişi başarısız: $e');
    }
  }

  WebAuthenticationOptions? _webAuthOptionsIfNeeded() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return WebAuthenticationOptions(
        clientId: 'com.bagla.app.web',
        redirectUri: Uri.parse('$apiBaseUrl/auth/apple/callback'),
      );
    }
    return null;
  }

  String _deviceName() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'mobile';
  }

  String? _formatFullName(String? givenName, String? familyName) {
    final fullNameParts = [
      givenName,
      familyName,
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    if (fullNameParts.isEmpty) return null;
    return fullNameParts.join(' ').trim();
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  String _formatValidationErrors(dynamic errors) {
    if (errors is Map) {
      final messages = <String>[];
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List) {
          messages.addAll(value.map((e) => e.toString()));
        } else if (value != null) {
          messages.add(value.toString());
        }
      }
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return 'Apple girişi sırasında hata oluştu.';
  }
}
