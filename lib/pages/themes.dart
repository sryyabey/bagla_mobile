import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ThemesPage extends StatefulWidget {
  const ThemesPage({super.key});

  @override
  State<ThemesPage> createState() => _ThemesPageState();
}

class _ThemesPageState extends State<ThemesPage> {
  List<Map<String, dynamic>> _themes = [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  int? _selectedThemeId;
  String? _selectedThemeName;
  int? _userId;
  WebViewController? _previewController;
  bool _previewLoading = false;
  String? _previewUrl;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchThemesAndProfile();
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _findThemeIdByName(String? name) {
    if (name == null) return null;
    for (final theme in _themes) {
      final themeName =
          theme['name']?.toString() ?? theme['title']?.toString() ?? '';
      if (themeName == name) {
        return _parseInt(theme['id']);
      }
    }
    return null;
  }

  String? _resolveThemeNameById(int? id) {
    if (id == null) return null;
    final match = _themes.firstWhere(
      (theme) => _parseInt(theme['id']) == id,
      orElse: () => {},
    );
    if (match.isEmpty) return null;
    return match['name']?.toString() ??
        match['title']?.toString() ??
        match['slug']?.toString();
  }

  Future<void> _fetchThemesAndProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
        _loading = false;
      });
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('$apiBaseUrl/api/settings/themes'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$apiBaseUrl/api/user/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]);

      final themesResponse = responses[0];
      final profileResponse = responses[1];

      if (themesResponse.statusCode == 401 ||
          profileResponse.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
          _loading = false;
        });
        return;
      }

      List<Map<String, dynamic>> fetchedThemes = [];
      String? selectedThemeNameFromThemes;
      if (themesResponse.statusCode == 200) {
        final decoded = jsonDecode(themesResponse.body);
        final data = decoded is Map<String, dynamic>
            ? decoded['data'] ?? decoded['themes'] ?? decoded['results']
            : decoded;
        if (decoded is Map<String, dynamic>) {
          selectedThemeNameFromThemes =
              decoded['selected_theme_name']?.toString();
        }
        if (data is List) {
          fetchedThemes = List<Map<String, dynamic>>.from(data);
        } else if (data is Map<String, dynamic>) {
          fetchedThemes = [data];
        }
      }

      int? userId;
      int? currentThemeId;
      String? currentThemeName;
      if (profileResponse.statusCode == 200) {
        final decoded = jsonDecode(profileResponse.body);
        final data = decoded['data'] ?? decoded;
        userId = _parseInt(data['id'] ?? data['user_id']);
        currentThemeId =
            _parseInt(data['theme_id'] ?? data['selected_theme_id']);
        currentThemeName = data['theme']?.toString() ??
            data['theme_name']?.toString() ??
            data['selected_theme']?.toString();
      }

      if (!mounted) return;
      setState(() {
        _themes = fetchedThemes;
        _userId = userId;
        final defaultThemeName = 'success';
        final resolvedThemeName = currentThemeName ??
            selectedThemeNameFromThemes ??
            defaultThemeName;
        final resolvedThemeId = currentThemeId ??
            _findThemeIdByName(resolvedThemeName) ??
            (fetchedThemes.isNotEmpty
                ? _parseInt(fetchedThemes.first['id'])
                : null);

        _selectedThemeId = resolvedThemeId;
        _selectedThemeName =
            resolvedThemeName ?? _resolveThemeNameById(_selectedThemeId);
        _loading = false;
      });

      _updatePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Temalar yüklenemedi: $e';
        _loading = false;
      });
    }
  }

  String? _buildPreviewUrl() {
    if (_userId == null ||
        _selectedThemeName == null ||
        _selectedThemeName!.isEmpty) {
      return null;
    }

    final uri =
        Uri.parse('https://bagla.app/bio-pages/preview/$_userId').replace(
      queryParameters: {
        'theme': _selectedThemeName!,
      },
    );
    return uri.toString();
  }

  void _updatePreview() {
    final url = _buildPreviewUrl();
    if (url == null) {
      setState(() {
        _previewUrl = null;
        _previewController = null;
        _previewError = null;
        _previewLoading = false;
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _previewLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _previewLoading = false;
                _previewError = 'Önizleme yüklenirken sorun oluştu.';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _previewUrl = url;
      _previewController = controller;
      _previewLoading = true;
      _previewError = null;
    });
  }

  Future<void> _saveTheme() async {
    final themeId = _selectedThemeId;
    final token = await _getToken();

    if (themeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir tema seçin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı. Lütfen tekrar giriş yapın.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/settings/user-theme'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'theme_id': themeId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tema güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String message = 'Tema güncellenemedi (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema kaydedilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  void _onThemeTap(Map<String, dynamic> theme) {
    final id = _parseInt(theme['id']);
    final name = theme['name']?.toString() ??
        theme['title']?.toString() ??
        theme['slug']?.toString();
    setState(() {
      _selectedThemeId = id;
      _selectedThemeName = name;
    });
    _updatePreview();
  }

  Widget _buildThemeChip(Map<String, dynamic> theme) {
    final id = _parseInt(theme['id']);
    final name =
        theme['name']?.toString() ?? theme['title']?.toString() ?? 'Tema';
    final isSelected = id != null && id == _selectedThemeId;

    return ChoiceChip(
      label: Text(name),
      selected: isSelected,
      onSelected: (_) => _onThemeTap(theme),
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPreview() {
    if (_previewUrl == null) {
      return Center(
        child: Container(
          width: 320,
          constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
          height: 540,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Center(
            child: Text('Önizleme için bir tema seçin.'),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: 320,
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: Stack(
            children: [
              if (_previewController != null)
                WebViewWidget(controller: _previewController!),
              if (_previewLoading)
                const Center(child: CircularProgressIndicator()),
              if (_previewError != null && !_previewLoading)
                Center(
                  child: Text(
                    _previewError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temalar'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _fetchThemesAndProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchThemesAndProfile,
                          child: const Text('Tekrar Dene'),
                        )
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Temalar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (_themes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Kullanılabilir tema bulunamadı.'),
                              )
                            else
                              SizedBox(
                                height: 46,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: _themes
                                        .map(
                                          (theme) => Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: _buildThemeChip(theme),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Canlı Önizleme',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildPreview(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveTheme,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  _saving
                                      ? 'Kaydediliyor...'
                                      : 'Temayı Kaydet',
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
