import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SmsTemplatesPage extends StatefulWidget {
  const SmsTemplatesPage({super.key});

  @override
  State<SmsTemplatesPage> createState() => _SmsTemplatesPageState();
}

class _SmsTemplatesPageState extends State<SmsTemplatesPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  static const Color _backgroundColor = Color(0xFFF7F9FC);
  static const Color _primaryColor = Color(0xFF6366F1);

  List<Map<String, dynamic>> _templates = [];
  int? _selectedMain;
  int? _selectedReminder;
  int? _selectedCancel;
  int? _selectedUpdate;
  Map<String, dynamic>? _selectedTemplatesMeta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTemplates();
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  Future<void> _fetchTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/settings/sms-templates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final selected = decoded['selected_templates'] ??
            (decoded['data'] is Map
                ? decoded['data']['selected_templates']
                : null);
        List<Map<String, dynamic>> list = [];
        if (data is List) {
          list = List<Map<String, dynamic>>.from(
              data.map((e) => Map<String, dynamic>.from(e)));
        } else if (data is Map<String, dynamic>) {
          data.forEach((key, value) {
            if (value is List) {
              for (final item in value) {
                if (item is Map) {
                  final mapItem = Map<String, dynamic>.from(item);
                  mapItem['category'] ??= key;
                  list.add(mapItem);
                }
              }
            }
          });
        }
        if (!mounted) return;
        setState(() {
          _templates = list;
          _selectedTemplatesMeta = selected is Map<String, dynamic>
              ? Map<String, dynamic>.from(selected)
              : null;
          _selectedMain = _selectedTemplatesMeta?['main_template_id'] as int? ??
              _selectedMain;
          _selectedReminder =
              _selectedTemplatesMeta?['reminder_template_id'] as int? ??
                  _selectedReminder;
          _selectedCancel =
              _selectedTemplatesMeta?['cancel_template_id'] as int? ??
                  _selectedCancel;
          _selectedUpdate =
              _selectedTemplatesMeta?['update_template_id'] as int? ??
                  _selectedUpdate;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Şablonlar alınamadı (HTTP ${response.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Şablonlar alınamadı: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterByAlias(String alias) {
    final filtered = _templates
        .where((t) => t['alias']?.toString().toLowerCase() == alias)
        .toList();
    if (filtered.isNotEmpty) return filtered;
    return _templates;
  }

  List<Map<String, dynamic>> _filterByCategory(String category) {
    final filtered = _templates
        .where((t) => t['category']?.toString().toLowerCase() == category)
        .toList();
    if (filtered.isNotEmpty) return filtered;
    return _filterByAlias(category);
  }

  Future<void> _saveSelection() async {
    if (_saving) return;
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }
    if (_selectedMain == null ||
        _selectedReminder == null ||
        _selectedCancel == null ||
        _selectedUpdate == null) {
      _showSnack('Tüm şablon seçimlerini yapın.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/settings/user-message-template'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'main_template_id': _selectedMain,
          'reminder_template_id': _selectedReminder,
          'cancel_template_id': _selectedCancel,
          'update_template_id': _selectedUpdate,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('SMS şablonları güncellendi.', success: true);
      } else {
        String msg = 'Kaydedilemedi (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          msg = decoded['message']?.toString() ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Kaydedilemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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

  Widget _buildDropdown({
    required String label,
    required String category,
    required int? selectedId,
    required ValueChanged<int?> onChanged,
  }) {
    final options = _filterByCategory(category);
    String _templateLabel(Map<String, dynamic> tpl) {
      final content = (tpl['content'] ?? tpl['content_raw'] ?? '').toString();
      if (content.isNotEmpty) {
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      }
      final title =
          (tpl['title'] ?? tpl['name'] ?? 'Şablon #${tpl['id']}').toString();
      return title;
    }

    return DropdownButtonFormField<int>(
      value: selectedId,
      isExpanded: true,
      menuMaxHeight: 250,
      decoration: InputDecoration(
        labelText: label,
        hintText: options.isEmpty ? 'Şablon bulunamadı' : 'Seçiniz',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: options
          .map(
            (tpl) => DropdownMenuItem<int>(
              value: tpl['id'] as int?,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    (tpl['content'] ?? tpl['content_raw'] ?? '').toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ),
          )
          .toList(),
      onChanged: options.isEmpty ? null : onChanged,
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
          'SMS Şablonları',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _fetchTemplates,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : SingleChildScrollView(
                    child: _sectionCard(
                      title: 'Müşteri SMS Şablonları',
                      subtitle: _selectedTemplatesMeta != null
                          ? 'Seçim ID: ${_selectedTemplatesMeta?['id'] ?? ''}'
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdown(
                            label: 'Ana Mesaj',
                            category: 'appointment',
                            selectedId: _selectedMain,
                            onChanged: (val) {
                              setState(() {
                                _selectedMain = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'Hatırlatma',
                            category: 'reminder',
                            selectedId: _selectedReminder,
                            onChanged: (val) {
                              setState(() {
                                _selectedReminder = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'İptal',
                            category: 'cancel',
                            selectedId: _selectedCancel,
                            onChanged: (val) {
                              setState(() {
                                _selectedCancel = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'Güncelleme',
                            category: 'update',
                            selectedId: _selectedUpdate,
                            onChanged: (val) {
                              setState(() {
                                _selectedUpdate = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _saving ? 'Kaydediliyor...' : 'Kaydet',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
