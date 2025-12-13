import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagla_mobile/config.dart';
import 'orders.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Form controller'ları: profil & SEO
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _seoTitleController = TextEditingController();
  final TextEditingController _seoDescriptionController =
      TextEditingController();
  final TextEditingController _seoKeywordsController = TextEditingController();

  // Form controller'ları: parola
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _profileSavedRecently = false;
  bool _passwordSavedRecently = false;

  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String _avatarMimeType = 'image/jpeg';
  Map<String, dynamic>? _packInfo;
  static const Color _backgroundColor = Color(0xFFF7F9FC);
  static const Color _primaryColor = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _footerController.dispose();
    _seoTitleController.dispose();
    _seoDescriptionController.dispose();
    _seoKeywordsController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  // Profil verisini API'den çekip formu doldurur
  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      setState(() {
        _loadingProfile = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        setState(() {
          _nameController.text = data['name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _footerController.text = data['footer'] ?? '';
          final seo = data['seo'] as Map<String, dynamic>?;
          _seoTitleController.text = seo?['title'] ?? '';
          _seoDescriptionController.text = seo?['description'] ?? '';
          _seoKeywordsController.text = seo?['keywords'] ?? '';
          _avatarUrl = data['avatar']?.toString();
          _packInfo = data['pack_info'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['pack_info'])
              : null;
        });
      } else {
        _showSnack('Profil alınamadı (${response.statusCode}).');
      }
    } catch (e) {
      _showSnack('Profil yüklenirken hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  // Avatar seçer ve bytes'ı hazırlar (ham halde gönderiyoruz)
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null) return;

    try {
      // Boyut ve format doğrulama
      final sizeBytes = await picked.length();
      const maxSize = 3 * 1024 * 1024; // 3MB
      if (sizeBytes > maxSize) {
        _showSnack('Avatar 3MB\'tan küçük olmalı.');
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      final isJpeg = ext == 'jpg' || ext == 'jpeg';
      final isPng = ext == 'png';
      final isWebp = ext == 'webp';
      if (!isJpeg && !isPng && !isWebp) {
        _showSnack('Yalnızca JPG, PNG veya WEBP yükleyin.');
        return;
      }

      setState(() {
        _avatarBytes = null;
      });
      final rawBytes = await picked.readAsBytes();
      setState(() {
        _avatarBytes = rawBytes;
        _avatarFileName =
            picked.name.isNotEmpty ? picked.name : 'avatar.${ext.isNotEmpty ? ext : 'jpg'}';
        _avatarMimeType =
            isPng ? 'image/png' : isWebp ? 'image/webp' : 'image/jpeg';
      });
    } catch (e) {
      _showSnack('Avatar hazırlanamadı: $e');
    }
  }

  // Profil bilgilerini ve avatarı multipart POST ile gönderir
  Future<void> _saveProfile() async {
    if (_savingProfile) return;

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _savingProfile = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/api/user/profile'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'name': _nameController.text,
        'username': _usernameController.text,
        'description': _descriptionController.text,
        'footer': _footerController.text,
        'seo_title': _seoTitleController.text,
        'seo_description': _seoDescriptionController.text,
        'seo_keywords': _seoKeywordsController.text,
      });

      if (_avatarBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            _avatarBytes!,
            filename: _avatarFileName ?? 'avatar.jpg',
            contentType: MediaType.parse(_avatarMimeType),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showSnack('Profil güncellendi.', success: true);
        _avatarBytes = null;
        setState(() {
          _profileSavedRecently = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _profileSavedRecently = false;
            });
          }
        });
        await _loadProfile();
      } else {
        String message = 'Güncelleme başarısız.';
        try {
          final body = jsonDecode(response.body);
          message = body['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack('$message (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Profil güncellenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  // Parola güncelleme isteği
  Future<void> _changePassword() async {
    if (_savingPassword) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack('Yeni parola ve doğrulama eşleşmiyor.');
      return;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _savingPassword = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/user/password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text,
          'password': _newPasswordController.text,
          'password_confirmation': _confirmPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Parola güncellendi.', success: true);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _passwordSavedRecently = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _passwordSavedRecently = false;
            });
          }
        });
      } else {
        String message = 'Parola güncellenemedi.';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack('$message (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Parola güncellenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _savingPassword = false;
        });
      }
    }
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
    String? title,
    String? subtitle,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
            )
          else if (title != null)
            const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatarChild;
    if (_avatarBytes != null) {
      avatarChild = Image.memory(
        _avatarBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarChild = Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      avatarChild = const Icon(Icons.person, size: 48);
    }

    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(child: avatarChild),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickAvatar,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Avatar Yükle'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return _sectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty
                      ? 'İsim girilmemiş'
                      : _nameController.text,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  _usernameController.text.isEmpty
                      ? '@kullanici'
                      : '@${_usernameController.text}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (_packInfo != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (_packInfo?['active_pack'] != null)
                        _infoChip(
                          Icons.local_fire_department,
                          _packInfo!['active_pack'].toString(),
                        ),
                      if (_packInfo?['expiry_date'] != null)
                        _infoChip(
                          Icons.schedule,
                          _packInfo!['expiry_date'].toString(),
                        ),
                      if (_packInfo?['remaining_sms'] != null)
                        _infoChip(
                          Icons.sms,
                          'SMS: ${_packInfo!['remaining_sms']}',
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16, color: _primaryColor),
      label: Text(text),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _primaryColor.withOpacity(0.2)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 1.2),
      ),
    );
  }

  Widget _buildProfileForm() {
    return _sectionCard(
      title: 'Profil Bilgileri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: _inputDecoration('İsim'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: _inputDecoration('Kullanıcı adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: _inputDecoration('Açıklama'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footerController,
            decoration: _inputDecoration('Footer'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'SEO',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seoTitleController,
            decoration: _inputDecoration('Başlık'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seoDescriptionController,
            maxLines: 2,
            decoration: _inputDecoration('Açıklama'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seoKeywordsController,
            decoration: _inputDecoration('Anahtar kelimeler'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savingProfile ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _savingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_savingProfile ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _profileSavedRecently
                    ? const Icon(Icons.check_circle,
                        key: ValueKey('profile_saved'),
                        color: Colors.green,
                        size: 28)
                    : const SizedBox(
                        key: ValueKey('profile_unsaved'),
                        width: 28,
                        height: 28,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return _sectionCard(
      title: 'Parola Güncelle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: _inputDecoration('Mevcut parola'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: _inputDecoration('Yeni parola'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: _inputDecoration('Yeni parola tekrar'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _savingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _savingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset),
                  label: Text(
                      _savingPassword ? 'Gönderiliyor...' : 'Parolayı Güncelle'),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _passwordSavedRecently
                    ? const Icon(Icons.check_circle,
                        key: ValueKey('password_saved'),
                        color: Colors.green,
                        size: 28)
                    : const SizedBox(
                        key: ValueKey('password_unsaved'),
                        width: 28,
                        height: 28,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildProfileForm(),
                    const SizedBox(height: 12),
                    _buildPasswordForm(),
                  ],
                ),
              ),
            ),
    );
  }
}
