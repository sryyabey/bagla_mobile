import 'dart:async';
import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:bagla_mobile/main_tabs_page.dart';

class SmsTemplatesPage extends StatefulWidget {
  const SmsTemplatesPage({super.key});

  @override
  State<SmsTemplatesPage> createState() => _SmsTemplatesPageState();
}

class _SmsTemplatesPageState extends State<SmsTemplatesPage> {
  AppLocalizations get loc => AppLocalizations.of(context);
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
  bool _mainExpanded = true;
  bool _reminderExpanded = false;
  bool _cancelExpanded = false;
  bool _updateExpanded = false;
  Timer? _autoSaveTimer;
  String? _lastSavedSelectionKey;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainTabsPage(initialIndex: 0),
      ),
      (_) => false,
    );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _goHome();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTemplates();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
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
        _error = loc.smsTemplatesSessionMissing;
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
          _lastSavedSelectionKey = _currentSelectionKey();
          _loading = false;
        });
      } else {
        setState(() {
          _error = loc.smsTemplatesFetchFailedStatus(response.statusCode);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.smsTemplatesFetchFailed(e.toString());
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

  String _templateTitle(Map<String, dynamic> tpl) {
    final dynamic rawId = tpl['id'];
    final int? id = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
    final title = (tpl['title'] ?? tpl['name'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    return loc.smsTemplatesFallbackTitle(id?.toString() ?? '-');
  }

  String _templateContent(Map<String, dynamic> tpl) {
    final content = (tpl['content'] ?? tpl['content_raw'] ?? '').toString().trim();
    if (content.isNotEmpty) return content;
    return _templateTitle(tpl);
  }

  Map<String, dynamic>? _selectedTemplateById(
    List<Map<String, dynamic>> options,
    int? selectedId,
  ) {
    if (selectedId == null) return null;
    for (final tpl in options) {
      final id = tpl['id'];
      if (id is int && id == selectedId) return tpl;
      if (id != null && int.tryParse(id.toString()) == selectedId) return tpl;
    }
    return null;
  }

  String? _currentSelectionKey() {
    if (_selectedMain == null ||
        _selectedReminder == null ||
        _selectedCancel == null ||
        _selectedUpdate == null) {
      return null;
    }
    return '$_selectedMain-$_selectedReminder-$_selectedCancel-$_selectedUpdate';
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    final key = _currentSelectionKey();
    if (key == null || key == _lastSavedSelectionKey) return;
    _autoSaveTimer = Timer(const Duration(milliseconds: 450), () {
      _saveSelection(autoTriggered: true);
    });
  }

  Future<void> _saveSelection({bool autoTriggered = false}) async {
    if (_saving) return;
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (!autoTriggered) _showSnack(loc.smsTemplatesSessionMissing);
      return;
    }
    if (_selectedMain == null ||
        _selectedReminder == null ||
        _selectedCancel == null ||
        _selectedUpdate == null) {
      if (!autoTriggered) _showSnack(loc.smsTemplatesSelect);
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
        _lastSavedSelectionKey = _currentSelectionKey();
        _showSnack(loc.smsTemplatesUpdated, success: true);
      } else {
        String msg = loc.smsTemplatesSaveFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          msg = decoded['message']?.toString() ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack(loc.smsTemplatesSaveFailed(e.toString()));
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: success ? 1 : 3),
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
            color: Colors.black.withValues(alpha: 0.03),
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

  Widget _buildTemplateAccordion({
    required String label,
    required String description,
    required String category,
    required int? selectedId,
    required ValueChanged<int?> onChanged,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final options = _filterByCategory(category);
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: options.isEmpty
                  ? Text(
                      loc.smsTemplatesNotFound,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Column(
                      children: options.map((tpl) {
                        final rawId = tpl['id'];
                        final int? id = rawId is int ? rawId : int.tryParse('$rawId');
                        final isSelected = id != null && id == selectedId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: id == null ? null : () => onChanged(id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryColor.withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      isSelected ? _primaryColor : const Color(0xFFD1D5DB),
                                  width: isSelected ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _templateTitle(tpl),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _templateContent(tpl),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF4B5563),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _primaryColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              loc.smsTemplatesSelected,
                                              style: const TextStyle(
                                                color: Color(0xFF4338CA),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: isSelected
                                        ? _primaryColor
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            crossFadeState:
                isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return _sectionCard(
      title: loc.smsTemplatesGuideTitle,
      subtitle: loc.smsTemplatesGuideBody,
      child: Text(
        loc.smsTemplatesGuideHint,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildPreviewRow({
    required String title,
    required String category,
    required int? selectedId,
  }) {
    final options = _filterByCategory(category);
    final selected = _selectedTemplateById(options, selectedId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selected == null
                ? loc.smsTemplatesPreviewEmpty
                : _templateContent(selected),
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: selected == null
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _sectionCard(
      title: loc.smsTemplatesPreviewTitle,
      child: Column(
        children: [
          _buildPreviewRow(
            title: loc.smsTemplatesMain,
            category: 'appointment',
            selectedId: _selectedMain,
          ),
          _buildPreviewRow(
            title: loc.smsTemplatesReminder,
            category: 'reminder',
            selectedId: _selectedReminder,
          ),
          _buildPreviewRow(
            title: loc.smsTemplatesCancel,
            category: 'cancel',
            selectedId: _selectedCancel,
          ),
          _buildPreviewRow(
            title: loc.smsTemplatesUpdate,
            category: 'update',
            selectedId: _selectedUpdate,
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
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          loc.smsTemplatesTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: loc.dashboardHome,
            onPressed: _goHome,
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            onPressed: _fetchTemplates,
            icon: const Icon(Icons.refresh),
            tooltip: loc.smsTemplatesRefresh,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionCard(
                          title: loc.smsTemplatesCustomerTemplates,
                          subtitle: _selectedTemplatesMeta != null
                              ? loc.smsTemplatesSelectionId(
                                  _selectedTemplatesMeta?['id']?.toString() ?? '')
                              : null,
                          child: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        _buildGuideCard(),
                        const SizedBox(height: 12),
                        _buildTemplateAccordion(
                          label: loc.smsTemplatesMain,
                          description: loc.smsTemplatesMainDescription,
                          category: 'appointment',
                          selectedId: _selectedMain,
                          isExpanded: _mainExpanded,
                          onToggle: () {
                            setState(() {
                              _mainExpanded = !_mainExpanded;
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedMain = val;
                            });
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTemplateAccordion(
                          label: loc.smsTemplatesReminder,
                          description: loc.smsTemplatesReminderDescription,
                          category: 'reminder',
                          selectedId: _selectedReminder,
                          isExpanded: _reminderExpanded,
                          onToggle: () {
                            setState(() {
                              _reminderExpanded = !_reminderExpanded;
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedReminder = val;
                            });
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTemplateAccordion(
                          label: loc.smsTemplatesCancel,
                          description: loc.smsTemplatesCancelDescription,
                          category: 'cancel',
                          selectedId: _selectedCancel,
                          isExpanded: _cancelExpanded,
                          onToggle: () {
                            setState(() {
                              _cancelExpanded = !_cancelExpanded;
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedCancel = val;
                            });
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTemplateAccordion(
                          label: loc.smsTemplatesUpdate,
                          description: loc.smsTemplatesUpdateDescription,
                          category: 'update',
                          selectedId: _selectedUpdate,
                          isExpanded: _updateExpanded,
                          onToggle: () {
                            setState(() {
                              _updateExpanded = !_updateExpanded;
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedUpdate = val;
                            });
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildPreviewCard(),
                        if (_saving)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.smsTemplatesSaving,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
