import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:bagla_mobile/main_tabs_page.dart';

class WorkingPreferencesPage extends StatefulWidget {
  const WorkingPreferencesPage({super.key});

  @override
  State<WorkingPreferencesPage> createState() => _WorkingPreferencesPageState();
}

class _WorkingPreferencesPageState extends State<WorkingPreferencesPage> {
  AppLocalizations get loc => AppLocalizations.of(context);
  static const Color _bg = Color(0xFFF5F6FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceAlt = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFE8EAF0);
  static const Color _accent = Color(0xFF5B5FD9);
  static const Color _accentLight = Color(0xFFEEEEFF);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFFB0B7C3);
  static const Color _success = Color(0xFF10B981);
  static const Color _successBg = Color(0xFFECFDF5);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dangerBg = Color(0xFFFEF2F2);

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _firstAppointmentSessionCount = 1;
  List<_DayPreference> _preferences = _defaultPreferences();
  List<_Holiday> _holidays = [];
  final List<int> _periodOptions =
      List.generate(24, (index) => (index + 1) * 5);
  late final List<String> _timeOptions = _buildTimeOptions();

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

  static List<_DayPreference> _defaultPreferences() {
    return List.generate(
      7,
      (index) => _DayPreference(
        dayOfWeek: index + 1,
        isWorking: true,
        timeSlots: [
          _TimeSlot(start: '09:00:00', end: '17:00:00', period: 20),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> _getToken() async {
    return getAccessToken();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = loc.workingPrefsSessionMissing;
      });
      return;
    }

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/working-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        final List<dynamic> prefList = data['preferences'] ?? [];
        final Map<int, _DayPreference> parsedPrefs = {};
        for (final item in prefList) {
          final pref = _DayPreference.fromJson(item);
          parsedPrefs[pref.dayOfWeek] = pref;
        }
        final merged = List<_DayPreference>.generate(7, (index) {
          final day = index + 1;
          return parsedPrefs[day] ??
              _DayPreference(
                dayOfWeek: day,
                isWorking: true,
                timeSlots: [
                  _TimeSlot(start: '09:00:00', end: '17:00:00', period: 20)
                ],
              );
        });

        final List<dynamic> holidayList = data['holidays'] ?? [];
        final holidays = holidayList
            .map((e) => _Holiday.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final rawFirst = data['first_appointment_session_count'];
        final parsedFirst = rawFirst is int
            ? rawFirst
            : int.tryParse(rawFirst?.toString() ?? '') ?? 1;
        final firstSession =
            (parsedFirst >= 1 && parsedFirst <= 3) ? parsedFirst : 1;

        if (!mounted) return;
        setState(() {
          _preferences = merged;
          _holidays = holidays;
          _firstAppointmentSessionCount = firstSession;
          _loading = false;
        });
      } else {
        setState(() {
          _error = loc.workingPrefsLoadFailedStatus(response.statusCode);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.workingPrefsLoadFailed(e.toString());
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_saving) return;

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.workingPrefsSessionMissing);
      return;
    }

    setState(() {
      _saving = true;
    });

    final normalizedPrefs = _preferences
        .map((e) => e.toJson(normalizeTime: _normalizeTime))
        .toList();

    final payload = {
      'first_appointment_session_count': _firstAppointmentSessionCount,
      'preferences': normalizedPrefs,
      'holidays': _holidays.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await authPost(
        Uri.parse('$apiBaseUrl/api/working-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        _showSnack(loc.workingPrefsSaveSuccess, success: true);
        await _loadPreferences();
      } else {
        String message = loc.workingPrefsSaveFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.workingPrefsSaveFailed(e.toString()));
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
    final color = success ? _success : _danger;
    final bg = success ? _successBg : _dangerBg;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    bool compact = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      filled: true,
      fillColor: _surfaceAlt,
      labelStyle: TextStyle(
        fontSize: compact ? 12 : 13,
        color: _textSecondary,
      ),
      isDense: compact,
      contentPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 8 : 11),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 8 : 11),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 8 : 11),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
    String? title,
    String? subtitle,
    IconData? icon,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: _accent),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(
                subtitle,
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
            )
          else if (title != null)
            const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _applyTemplate(_ScheduleTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.workingPrefsTemplatesConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              template.description,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(loc.workingPrefsTemplatesConfirmBody),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.workingPrefsTemplatesCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              loc.workingPrefsTemplatesApply,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _preferences = template.build();
      });
      _showSnack(
        loc.workingPrefsTemplatesApplied(template.name),
        success: true,
      );
    }
  }

  Widget _buildTemplatesCard() {
    final templates = _buildTemplates();
    return _sectionCard(
      title: loc.workingPrefsTemplatesTitle,
      subtitle: loc.workingPrefsTemplatesSubtitle,
      icon: Icons.auto_awesome_rounded,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: templates.map((t) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _TemplateChip(
                template: t,
                onTap: () => _applyTemplate(t),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _addSlot(_DayPreference pref) {
    setState(() {
      pref.timeSlots.add(
        _TimeSlot(start: '09:00:00', end: '17:00:00', period: 20),
      );
    });
  }

  void _removeSlot(_DayPreference pref, int index) {
    if (pref.timeSlots.length <= 1) return;
    setState(() {
      pref.timeSlots.removeAt(index);
    });
  }

  void _addHoliday() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    setState(() {
      _holidays.add(
        _Holiday(
          holidayBegin: _formatDate(today),
          holidayEnd: _formatDate(tomorrow),
          reason: '',
        ),
      );
    });
  }

  void _removeHoliday(int index) {
    setState(() {
      _holidays.removeAt(index);
    });
  }

  Future<void> _pickHolidayDate(int index, bool isBegin) async {
    final holiday = _holidays[index];
    final current = DateTime.tryParse(
          isBegin ? holiday.holidayBegin : holiday.holidayEnd,
        ) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isBegin) {
          holiday.holidayBegin = _formatDate(picked);
        } else {
          holiday.holidayEnd = _formatDate(picked);
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _normalizeTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00';
    }
    if (parts.length >= 3) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:${parts[2].padLeft(2, '0')}';
    }
    return value;
  }

  static List<String> _buildTimeOptions() {
    // 15 dakikalık adımlar 00:00'dan 23:45'e kadar
    return List.generate(96, (index) {
      final hour = index ~/ 4;
      final minute = (index % 4) * 15;
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m:00';
    });
  }

  List<String> _timeOptionsWithCurrent(String current) {
    if (current.isNotEmpty && !_timeOptions.contains(current)) {
      return [current, ..._timeOptions];
    }
    return _timeOptions;
  }

  String _initialTimeValue(List<String> options, String current) {
    if (current.isNotEmpty && options.contains(current)) return current;
    return options.first;
  }

  List<int> _periodOptionsWithCurrent(int current) {
    if (!_periodOptions.contains(current)) {
      return [current, ..._periodOptions];
    }
    return _periodOptions;
  }

  int _initialPeriodValue(List<int> options, int current) {
    if (options.contains(current)) return current;
    return options.first;
  }

  String _dayLabel(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return loc.dayMonFull;
      case 2:
        return loc.dayTueFull;
      case 3:
        return loc.dayWedFull;
      case 4:
        return loc.dayThuFull;
      case 5:
        return loc.dayFriFull;
      case 6:
        return loc.daySatFull;
      case 7:
        return loc.daySunFull;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surface,
        foregroundColor: _textSecondary,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: Text(
          loc.workingPrefsTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: loc.dashboardHome,
            onPressed: _goHome,
            icon: const Icon(Icons.home_rounded, size: 20),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          (!_loading && _error == null) ? _buildStickySaveBar() : null,
    );
  }

  Widget _buildStickySaveBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: _PrimaryButton(
          onPressed: _savePreferences,
          icon: Icons.save_rounded,
          label: loc.workingPrefsSave,
          loadingLabel: loc.workingPrefsSaving,
          isLoading: _saving,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            _PrimaryButton(
              onPressed: _loadPreferences,
              icon: Icons.refresh_rounded,
              label: loc.workingPrefsRetry,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPreferences,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 108),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildTemplatesCard(),
            const SizedBox(height: 12),
            _sectionCard(
              title: loc.workingPrefsFirstSessionTitle,
              icon: Icons.tune_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(text: loc.workingPrefsSessionLabel),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _firstAppointmentSessionCount,
                    decoration: _inputDecoration(
                      labelText: loc.workingPrefsSelect,
                    ),
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: _textMuted,
                    ),
                    dropdownColor: _surface,
                    items: [
                      DropdownMenuItem(
                          value: 1,
                          child: Text(loc.workingPrefsSessionOption(1))),
                      DropdownMenuItem(
                          value: 2,
                          child: Text(loc.workingPrefsSessionOption(2))),
                      DropdownMenuItem(
                          value: 3,
                          child: Text(loc.workingPrefsSessionOption(3))),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _firstAppointmentSessionCount = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._preferences.map(_buildDayCard),
            const SizedBox(height: 12),
            _buildHolidaysCard(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(_DayPreference pref) {
    final dayName = _dayLabel(pref.dayOfWeek);
    return _sectionCard(
      title: dayName,
      subtitle: loc.workingPrefsDaySubtitle,
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: loc.workingPrefsStatusLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                loc.workingPrefsWorking,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _ToggleSwitch(
                value: pref.isWorking,
                onChanged: (val) {
                  setState(() {
                    pref.isWorking = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectionLabel(text: loc.workingPrefsTimeSlotsLabel),
          const SizedBox(height: 8),
          Column(
            children: pref.timeSlots
                .asMap()
                .entries
                .map((entry) => _buildSlotRow(pref, entry.key, entry.value))
                .toList(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addSlot(pref),
              icon: const Icon(Icons.add_rounded),
              label: Text(loc.workingPrefsAddSlot),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(_DayPreference pref, int index, _TimeSlot slot) {
    final startOptions = _timeOptionsWithCurrent(slot.start);
    final endOptions = _timeOptionsWithCurrent(slot.end);
    final periodOptions = _periodOptionsWithCurrent(slot.period);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey('start-${pref.dayOfWeek}-$index-${slot.start}'),
              isExpanded: true,
              isDense: true,
              initialValue: _initialTimeValue(startOptions, slot.start),
              icon: const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: _textMuted,
              ),
              dropdownColor: _surface,
              items: startOptions
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.substring(0, 5)),
                    ),
                  )
                  .toList(),
              decoration: _inputDecoration(
                labelText: loc.workingPrefsStart,
                compact: true,
              ),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  slot.start = val;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey('end-${pref.dayOfWeek}-$index-${slot.end}'),
              isExpanded: true,
              isDense: true,
              initialValue: _initialTimeValue(endOptions, slot.end),
              icon: const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: _textMuted,
              ),
              dropdownColor: _surface,
              items: endOptions
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.substring(0, 5)),
                    ),
                  )
                  .toList(),
              decoration: _inputDecoration(
                labelText: loc.workingPrefsEnd,
                compact: true,
              ),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  slot.end = val;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: DropdownButtonFormField<int>(
              key: ValueKey('period-${pref.dayOfWeek}-$index-${slot.period}'),
              isDense: true,
              isExpanded: true,
              iconSize: 20,
              icon: const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: _textMuted,
              ),
              dropdownColor: _surface,
              initialValue: _initialPeriodValue(periodOptions, slot.period),
              items: periodOptions
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text('$p'),
                    ),
                  )
                  .toList(),
              decoration: _inputDecoration(
                  labelText: loc.workingPrefsPeriod, compact: true),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  slot.period = val;
                });
              },
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              tooltip: loc.workingPrefsDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              visualDensity: VisualDensity.compact,
              onPressed: pref.timeSlots.length <= 1
                  ? null
                  : () => _removeSlot(pref, index),
              icon: const Icon(Icons.delete_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysCard() {
    return _sectionCard(
      title: loc.workingPrefsHolidaysTitle,
      icon: Icons.event_available_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_holidays.isEmpty) Text(loc.workingPrefsHolidaysEmpty),
          ..._holidays.asMap().entries.map((entry) {
            final index = entry.key;
            final holiday = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('begin-$index-${holiday.holidayBegin}'),
                          readOnly: true,
                          initialValue: holiday.holidayBegin,
                          decoration: _inputDecoration(
                            labelText: loc.workingPrefsHolidayStart,
                            compact: true,
                          ),
                          onTap: () => _pickHolidayDate(index, true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('end-$index-${holiday.holidayEnd}'),
                          readOnly: true,
                          initialValue: holiday.holidayEnd,
                          decoration: _inputDecoration(
                            labelText: loc.workingPrefsHolidayEnd,
                            compact: true,
                          ),
                          onTap: () => _pickHolidayDate(index, false),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          tooltip: loc.workingPrefsDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 36),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeHoliday(index),
                          icon: const Icon(Icons.delete_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('reason-$index-${holiday.reason}'),
                    initialValue: holiday.reason,
                    decoration: _inputDecoration(
                      labelText: loc.workingPrefsHolidayReason,
                      compact: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        holiday.reason = val;
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addHoliday,
              icon: const Icon(Icons.add_rounded),
              label: Text(loc.workingPrefsHolidayAdd),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final _ScheduleTemplate template;
  final VoidCallback onTap;

  const _TemplateChip({required this.template, required this.onTap});

  static const Color _accent = Color(0xFF5B5FD9);
  static const Color _accentLight = Color(0xFFEEEEFF);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE8EAF0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(template.icon, size: 18, color: _accent),
              ),
              const SizedBox(height: 8),
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                template.description,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: Color(0xFFB0B7C3),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF5B5FD9) : const Color(0xFFE8EAF0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String? loadingLabel;
  final IconData icon;
  final bool isLoading;

  const _PrimaryButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.loadingLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final bg = enabled ? const Color(0xFF5B5FD9) : const Color(0xFFEEEEFF);
    final fg = enabled ? Colors.white : const Color(0xFF5B5FD9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF5B5FD9).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5B5FD9),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  isLoading ? (loadingLabel ?? label) : label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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

class _DayPreference {
  _DayPreference({
    required this.dayOfWeek,
    required this.isWorking,
    required this.timeSlots,
  });

  int dayOfWeek;
  bool isWorking;
  List<_TimeSlot> timeSlots;

  factory _DayPreference.fromJson(Map<String, dynamic> json) {
    final slots = (json['time_slots'] as List? ?? [])
        .map((e) => _TimeSlot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return _DayPreference(
      dayOfWeek: json['day_of_week'] is int
          ? json['day_of_week']
          : int.tryParse(json['day_of_week'].toString()) ?? 1,
      isWorking: json['is_working'] == true,
      timeSlots: slots.isNotEmpty
          ? slots
          : [
              _TimeSlot(start: '09:00:00', end: '17:00:00', period: 20),
            ],
    );
  }

  Map<String, dynamic> toJson({String Function(String value)? normalizeTime}) {
    return {
      'day_of_week': dayOfWeek,
      'is_working': isWorking,
      'time_slots': timeSlots
          .map(
            (e) => {
              'start': normalizeTime != null ? normalizeTime(e.start) : e.start,
              'end': normalizeTime != null ? normalizeTime(e.end) : e.end,
              'period': e.period,
            },
          )
          .toList(),
    };
  }
}

class _TimeSlot {
  _TimeSlot({
    required this.start,
    required this.end,
    required this.period,
  });

  String start;
  String end;
  int period;

  factory _TimeSlot.fromJson(Map<String, dynamic> json) {
    return _TimeSlot(
      start: json['start']?.toString() ?? '09:00:00',
      end: json['end']?.toString() ?? '17:00:00',
      period: json['period'] is int
          ? json['period']
          : int.tryParse(json['period']?.toString() ?? '') ?? 15,
    );
  }
}

class _ScheduleTemplate {
  final String name;
  final String description;
  final IconData icon;
  final List<_DayPreference> Function() build;

  const _ScheduleTemplate({
    required this.name,
    required this.description,
    required this.icon,
    required this.build,
  });
}

List<_ScheduleTemplate> _buildTemplates() {
  _TimeSlot slot(String start, String end, int period) =>
      _TimeSlot(start: '$start:00', end: '$end:00', period: period);

  return [
    _ScheduleTemplate(
      name: 'Standart',
      description: 'Pzt–Cum  09:00–12:00 / 13:00–17:00  •  20 dk',
      icon: Icons.work_outline_rounded,
      build: () => List.generate(7, (i) {
        final day = i + 1;
        final working = day <= 5;
        return _DayPreference(
          dayOfWeek: day,
          isWorking: working,
          timeSlots: [
            slot('09:00', '12:00', 20),
            slot('13:00', '17:00', 20),
          ],
        );
      }),
    ),
    _ScheduleTemplate(
      name: 'Öğleden Sonra',
      description: 'Pzt–Cum  13:00–17:00  •  20 dk',
      icon: Icons.wb_sunny_outlined,
      build: () => List.generate(7, (i) {
        final day = i + 1;
        final working = day <= 5;
        return _DayPreference(
          dayOfWeek: day,
          isWorking: working,
          timeSlots: [slot('13:00', '17:00', 20)],
        );
      }),
    ),
    _ScheduleTemplate(
      name: 'Uzman',
      description: 'Pzt–Cmt  09:00–12:00 / 13:00–17:00  •  20 dk',
      icon: Icons.star_outline_rounded,
      build: () => List.generate(7, (i) {
        final day = i + 1;
        final working = day <= 6;
        return _DayPreference(
          dayOfWeek: day,
          isWorking: working,
          timeSlots: [
            slot('09:00', '12:00', 20),
            slot('13:00', '17:00', 20),
          ],
        );
      }),
    ),
    _ScheduleTemplate(
      name: 'Akşam',
      description: 'Pzt–Cmt  17:00–21:00  •  45 dk',
      icon: Icons.nights_stay_outlined,
      build: () => List.generate(7, (i) {
        final day = i + 1;
        final working = day <= 6;
        return _DayPreference(
          dayOfWeek: day,
          isWorking: working,
          timeSlots: [slot('17:00', '21:00', 45)],
        );
      }),
    ),
    _ScheduleTemplate(
      name: 'Hafta Sonu',
      description: 'Cmt–Paz  10:00–17:00  •  30 dk',
      icon: Icons.weekend_outlined,
      build: () => List.generate(7, (i) {
        final day = i + 1;
        final working = day >= 6;
        return _DayPreference(
          dayOfWeek: day,
          isWorking: working,
          timeSlots: [slot('10:00', '17:00', 30)],
        );
      }),
    ),
  ];
}

class _Holiday {
  _Holiday({
    required this.holidayBegin,
    required this.holidayEnd,
    required this.reason,
  });

  String holidayBegin;
  String holidayEnd;
  String reason;

  factory _Holiday.fromJson(Map<String, dynamic> json) {
    return _Holiday(
      holidayBegin: json['holiday_begin']?.toString() ?? '',
      holidayEnd: json['holiday_end']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holiday_begin': holidayBegin,
      'holiday_end': holidayEnd,
      'reason': reason,
    };
  }
}
