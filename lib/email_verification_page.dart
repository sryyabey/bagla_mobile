import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'config.dart';
import 'main_tabs_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final String token;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _checking = false;
  bool _resending = false;
  String? _error;
  String? _successMsg;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() { _checking = true; _error = null; _successMsg = null; });
    try {
      await saveTokens(accessToken: widget.token);
      final res = await authGet(
        Uri.parse('$apiBaseUrl/api/email/verification-status'),
        headers: {'Accept': 'application/json'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final verified = body['data']?['email_verified'] == true ||
            body['email_verified'] == true ||
            body['verified'] == true;
        if (verified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainTabsPage()),
          );
        } else {
          setState(() => _error = 'E-posta henüz doğrulanmadı. Gelen kutunu kontrol et.');
        }
      } else {
        setState(() => _error = 'Doğrulama kontrol edilemedi (HTTP ${res.statusCode}).');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Sunucuya bağlanılamadı.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() { _resending = true; _error = null; _successMsg = null; });
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/email/resend-verification'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _successMsg = 'Doğrulama e-postası tekrar gönderildi.');
        _startCooldown();
      } else {
        final body = jsonDecode(res.body);
        setState(() => _error = body['message']?.toString() ?? 'Gönderilemedi.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Sunucuya bağlanılamadı.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0A84FF),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'E-postanı Doğrula',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.email} adresine bir doğrulama bağlantısı gönderdik.\nBağlantıya tıkladıktan sonra aşağıdaki butona bas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.yellowAccent, fontSize: 13),
                      ),
                    ),

                  if (_successMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _successMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFB9F6CA), fontSize: 13),
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _checking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text(
                              'E-postamı Doğruladım',
                              style: TextStyle(
                                color: Color(0xFF0A84FF),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (_resending || _resendCooldown > 0)
                          ? null
                          : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _resending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'Tekrar gönder ($_resendCooldown s)'
                                  : 'Tekrar gönder',
                              style: const TextStyle(fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Farklı bir hesapla giriş yap',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
