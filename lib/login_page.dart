import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'config.dart';
import 'auth.dart';
import 'services/apple_auth_service.dart';
import 'register_page.dart';
import 'main_tabs_page.dart';

class LoginPage extends StatefulWidget {
  final Function(Locale) onLocaleChange;

  const LoginPage({super.key, required this.onLocaleChange});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    // Use the Web client ID here so the backend can verify idToken audience.
    serverClientId: googleWebServerClientId,
    // On iOS, the native clientId is read from GoogleService-Info.plist.
  );
  Locale _locale = const Locale('tr');
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isAppleAvailable = false;
  String? _error;
  final AppleAuthService _appleAuthService = AppleAuthService();

  @override
  void initState() {
    super.initState();
    _checkAppleAvailability();
    // Başlangıçta mevcut locale ile eşitle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = Localizations.localeOf(context);
      if (mounted && current != _locale) {
        setState(() {
          _locale = current;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Üstteki MaterialApp locale değiştiyse dropdown ve metinleri senkronla
    final current = Localizations.localeOf(context);
    if (current != _locale) {
      setState(() {
        _locale = current;
      });
    }
  }

  Future<void> _checkAppleAvailability() async {
    final available = await SignInWithApple.isAvailable();
    if (!mounted) return;
    setState(() {
      _isAppleAvailable = available;
    });
  }

  Future<void> _storeToken(String token, {String? refresh}) async {
    await saveTokens(accessToken: token, refreshToken: refresh);
  }

  Future<void> _handleLoginSuccess(String token) async {
    await _storeToken(token);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainTabsPage(),
      ),
    );
  }

  void _showError(String message) {
    setState(() {
      _error = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ??
            (data['data'] != null ? data['data']['token'] : null) ??
            data['access_token'];
        final refresh = data['refresh_token'] ??
            data['refreshToken'] ??
            (data['data'] != null ? data['data']['refresh_token'] : null);
        if (token != null) {
          await _storeToken(token, refresh: refresh?.toString());
          await _handleLoginSuccess(token);
        } else {
          _showError('Token alınamadı.');
        }
      } else if (response.statusCode == 401) {
        final msg = _extractMessage(response.body) ?? 'Yetkisiz giriş.';
        _showError(msg);
      } else {
        final msg = _extractMessage(response.body) ??
            'Giriş başarısız (HTTP ${response.statusCode}).';
        _showError(msg);
      }
    } catch (e) {
      _showError('Sunucuya bağlanılamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _showError('Google giriş iptal edildi.');
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _showError('Google idToken alınamadı.');
        return;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/login/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          'device_name': 'bagla_mobile',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ??
            (data['data'] != null ? data['data']['token'] : null) ??
            data['access_token'];
        if (token != null) {
          await _handleLoginSuccess(token);
        } else {
          _showError('Token alınamadı.');
        }
      } else {
        final msg = _extractMessage(response.body) ??
            'Google giriş başarısız (HTTP ${response.statusCode}).';
        _showError(msg);
      }
    } catch (e) {
      _showError('Google girişi başarısız: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _isAppleLoading = true;
      _error = null;
    });

    try {
      final result = await _appleAuthService.login();
      await _handleLoginSuccess(result.token);
    } on AppleAuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Apple girişi başarısız: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: _locale,
      child: Builder(
        builder: (ctx) {
          final loc = AppLocalizations.of(ctx);
          return Scaffold(
            body: Container(
              color: const Color(0xFF0A84FF),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Language Switcher Dropdown
                      /*
                      Align(
                        alignment: Alignment.topRight,
                        child: DropdownButton<Locale>(
                          dropdownColor: Colors.white,
                          value: _locale,
                          underline: const SizedBox(),
                          iconEnabledColor: Colors.white,
                          items: const [
                            DropdownMenuItem(
                              value: Locale('tr'),
                              child: Text('TR'),
                            ),
                            DropdownMenuItem(
                              value: Locale('en'),
                              child: Text('EN'),
                            ),
                          ],
                          onChanged: _onLocaleChanged,
                        ),
                      ),
                      */
                      const SizedBox(height: 30),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/mobile_logo.png',
                              height: 96,
                              width: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.loginTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: loc.emailLabel,
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.email, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: loc.passwordLabel,
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                )
                              : Text(
                                  loc.loginTitle,
                                  style: const TextStyle(
                                    color: Color(0xFF2575FC),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.yellowAccent),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.black),
                                  ),
                                )
                              : Image.asset(
                                  'assets/google_icon.png',
                                  height: 24,
                                  width: 24,
                                ),
                          label: Text(
                            _isGoogleLoading
                                ? loc.googleConnecting
                                : loc.googleLoginButton,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isAppleAvailable ||
                          kIsWeb ||
                          defaultTargetPlatform == TargetPlatform.android) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SignInWithAppleButton(
                            onPressed: () {
                              if (_isAppleLoading) return;
                              _loginWithApple();
                            },
                            style: SignInWithAppleButtonStyle.black,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: Text(
                          loc.createAccountEmail,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
