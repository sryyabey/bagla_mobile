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

  // Onboarding ile uyumlu marka renkleri
  static const Color _accent = Color(0xFF38BDF8);
  static const List<Color> _bgGradient = [
    Color(0xFF0A0E1A),
    Color(0xFF0D2137),
    Color(0xFF0B3D5E),
  ];

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: _accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.55), size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: _locale,
      child: Builder(
        builder: (ctx) {
          final loc = AppLocalizations.of(ctx);
          final isTr = _locale.languageCode == 'tr';
          final subtitle = isTr
              ? 'Hesabına giriş yap, kaldığın yerden devam et'
              : 'Sign in to your account and pick up where you left off';
          final orLabel = isTr ? 'veya' : 'or';
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: _bgGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo hero — onboarding ikon kartı diliyle
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/mobile_logo.png',
                                height: 64,
                                width: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          loc.loginTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _buildField(
                          controller: emailController,
                          label: loc.emailLabel,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: passwordController,
                          label: loc.passwordLabel,
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFF87171), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Primary CTA — gradyan buton
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      loc.loginTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Ayraç
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                orLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
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
                                    height: 22,
                                    width: 22,
                                  ),
                            label: Text(
                              _isGoogleLoading
                                  ? loc.googleConnecting
                                  : loc.googleLoginButton,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        if (_isAppleAvailable ||
                            kIsWeb ||
                            defaultTargetPlatform == TargetPlatform.android) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: SignInWithAppleButton(
                              onPressed: () {
                                if (_isAppleLoading) return;
                                _loginWithApple();
                              },
                              style: SignInWithAppleButtonStyle.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: isTr ? 'Hesabın yok mu?  ' : "Don't have an account?  ",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: loc.createAccountEmail,
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
