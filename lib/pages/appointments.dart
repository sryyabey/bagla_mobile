import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utils/appointment_date_utils.dart';
import '../dashboard_page.dart';
import '../login_page.dart';
import 'pack_page_router.dart';
import 'working_preferences.dart';
import '../widgets/main_nav.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

// ─────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────
class _T {
  // Background layers
  static const bg = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F4F7);

  // Brand
  static const primary = Color(0xFF4F6EF7);
  static const primarySoft = Color(0xFFEEF1FE);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFFFBEB);

  // Ink
  static const ink = Color(0xFF111827);
  static const inkSecondary = Color(0xFF6B7280);
  static const inkDisabled = Color(0xFFB0B7C3);

  // Stroke
  static const border = Color(0xFFE5E7EB);
  static const borderFocus = Color(0xFF4F6EF7);

  // Radii
  static const r4 = 4.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r10 = 10.0;
  static const r14 = 14.0;

  // Elevation shadow
  static List<BoxShadow> shadow1 = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2)),
  ];
}

// ─────────────────────────────────────────────
// Shared Input Decoration helper
// ─────────────────────────────────────────────
InputDecoration _fieldDecor({
  required String label,
  String? hint,
  Widget? prefix,
  String? error,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    prefixIcon: prefix,
    labelStyle: const TextStyle(
        fontSize: 13, color: _T.inkSecondary, fontWeight: FontWeight.w500),
    hintStyle: const TextStyle(fontSize: 13, color: _T.inkDisabled),
    errorStyle: const TextStyle(fontSize: 12, color: _T.danger),
    filled: true,
    fillColor: _T.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_T.r12),
      borderSide: const BorderSide(color: _T.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_T.r12),
      borderSide: const BorderSide(color: _T.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_T.r12),
      borderSide: const BorderSide(color: _T.borderFocus, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_T.r12),
      borderSide: const BorderSide(color: _T.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_T.r12),
      borderSide: const BorderSide(color: _T.danger, width: 1.5),
    ),
  );
}

// ─────────────────────────────────────────────
// Phone mask formatter (unchanged)
// ─────────────────────────────────────────────
class _PhoneMaskFormatter extends TextInputFormatter {
  static final RegExp _digitsOnly = RegExp(r'\D');

  String _mask(String raw) {
    final digits = raw.replaceAll(_digitsOnly, '');
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final b = StringBuffer();
    if (limited.isNotEmpty) {
      b.write('(');
      b.write(limited.substring(0, limited.length.clamp(0, 3)));
      if (limited.length >= 3) b.write(')');
    }
    if (limited.length > 3) {
      b.write(' ');
      b.write(limited.substring(3, limited.length.clamp(3, 6)));
    }
    if (limited.length > 6) {
      b.write(' ');
      b.write(limited.substring(6, limited.length.clamp(6, 8)));
    }
    if (limited.length > 8) {
      b.write(' ');
      b.write(limited.substring(8, limited.length.clamp(8, 10)));
    }
    return b.toString();
  }

  int _digitCount(String text, int endOffset) {
    final left = text.substring(0, endOffset.clamp(0, text.length));
    return left.replaceAll(_digitsOnly, '').length;
  }

  int _offsetForDigits(String masked, int digits) {
    if (digits <= 0) return 0;
    int seen = 0;
    for (int i = 0; i < masked.length; i++) {
      final c = masked.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        seen++;
        if (seen == digits) return i + 1;
      }
    }
    return masked.length;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final masked = _mask(newValue.text);
    final digitsBefore = _digitCount(newValue.text, newValue.selection.end);
    final target = _offsetForDigits(masked, digitsBefore);
    return TextEditingValue(
        text: masked,
        selection: TextSelection.collapsed(offset: target),
        composing: TextRange.empty);
  }
}

// ─────────────────────────────────────────────
// API envelope (unchanged)
// ─────────────────────────────────────────────
class _ApiEnvelope {
  final int statusCode;
  final Map<String, dynamic> payload;
  final String? code;
  final String? message;
  final String? type;
  final dynamic data;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? errors;

  const _ApiEnvelope({
    required this.statusCode,
    required this.payload,
    required this.code,
    required this.message,
    required this.type,
    required this.data,
    required this.meta,
    required this.errors,
  });

  bool get isSuccessType => (type ?? '').toLowerCase() == 'success';
  bool get isSuccess {
    if (isSuccessType) return true;
    final upper = (code ?? '').toUpperCase();
    if (upper == 'OK' || upper == 'CREATED' || upper == 'UPDATED') return true;
    return statusCode >= 200 && statusCode < 300;
  }
}

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────
class AppointmentsPage extends StatefulWidget {
  final String? initialQuickDate;
  final String? initialQuickTime;
  final bool autoShowQuick;
  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  const AppointmentsPage({
    super.key,
    this.initialQuickDate,
    this.initialQuickTime,
    this.autoShowQuick = false,
    this.showBottomNav = true,
    this.onTabSelected,
  });

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  AppLocalizations get loc => AppLocalizations.of(context);

  // Controllers
  final _quickNameCtrl = TextEditingController();
  final _quickLastNameCtrl = TextEditingController();
  final _quickCountryIdCtrl = TextEditingController();
  final _quickPhoneCtrl = TextEditingController();
  final _quickEmailCtrl = TextEditingController();
  final _quickDateCtrl = TextEditingController();
  final _quickTimeCtrl = TextEditingController();
  final _quickNoteCtrl = TextEditingController();
  final _filterNameCtrl = TextEditingController();
  final _filterLastNameCtrl = TextEditingController();
  final _filterPhoneCtrl = TextEditingController();
  final _filterDateFromCtrl = TextEditingController();
  final _filterDateToCtrl = TextEditingController();
  final _filterTimeFromCtrl = TextEditingController();
  final _filterTimeToCtrl = TextEditingController();
  final _phoneMaskFormatter = _PhoneMaskFormatter();

  // State
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _appointmentStatuses = [];
  List<Map<String, dynamic>> _timeSlots = [];
  Map<String, String> _activeFilters = {};

  bool _loadingList = true;
  bool _savingAppointment = false;
  bool _savingQuick = false;
  bool _creatingRebook = false;
  bool _loadingCustomerInfo = false;
  bool _quickIsFirstAppointment = false;
  bool _quickNoSms = false;
  bool _quickNoReminder = false;
  bool _showQuickForm = false;
  bool _loadingSlots = false;
  bool _slotsRequested = false;
  bool _loadingCountries = false;
  bool _loadingStatuses = false;
  bool _showFilters = false;
  bool _hasUserPack = true;

  String? _error;
  String? _slotsError;
  String? _countriesError;
  String? _statusesError;
  String? _selectedSlotTime;
  int? _selectedCountryId;

  final List<String> _timeOptions = List.generate(
    24 * 12,
    (i) =>
        '${(i ~/ 12).toString().padLeft(2, '0')}:${((i % 12) * 5).toString().padLeft(2, '0')}',
  );

  // ── lifecycle ──────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.initialQuickDate != null)
      _quickDateCtrl.text = _normalizeSlotDate(widget.initialQuickDate!);
    if (widget.initialQuickTime != null) {
      _quickTimeCtrl.text = widget.initialQuickTime!;
      _selectedSlotTime = widget.initialQuickTime;
    }
    if (widget.autoShowQuick ||
        widget.initialQuickDate != null ||
        widget.initialQuickTime != null) _showQuickForm = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAppointments();
      _fetchCountries();
      _fetchStatuses();
      if (_showQuickForm && _quickDateCtrl.text.trim().isNotEmpty)
        _fetchTimeSlots();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _quickNameCtrl,
      _quickLastNameCtrl,
      _quickCountryIdCtrl,
      _quickPhoneCtrl,
      _quickEmailCtrl,
      _quickDateCtrl,
      _quickTimeCtrl,
      _quickNoteCtrl,
      _filterNameCtrl,
      _filterLastNameCtrl,
      _filterPhoneCtrl,
      _filterDateFromCtrl,
      _filterDateToCtrl,
      _filterTimeFromCtrl,
      _filterTimeToCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── helpers (unchanged logic) ───────────────
  bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  _ApiEnvelope _parseEnvelope(http.Response r) {
    Map<String, dynamic> payload = {};
    try {
      final d = jsonDecode(r.body);
      payload = d is Map ? Map<String, dynamic>.from(d) : {'data': d};
    } catch (_) {
      payload = {'message': r.body};
    }
    final rawErrors = payload['errors'];
    final rawMeta = payload['meta'];
    return _ApiEnvelope(
      statusCode: r.statusCode,
      payload: payload,
      code: payload['code']?.toString(),
      message: payload['message']?.toString(),
      type: payload['type']?.toString(),
      data: payload.containsKey('data') ? payload['data'] : payload,
      meta: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null,
      errors: rawErrors is Map ? Map<String, dynamic>.from(rawErrors) : null,
    );
  }

  String? _firstFieldError(Map<String, dynamic>? e) {
    if (e == null || e.isEmpty) return null;
    final first = e.values.first;
    return (first is List && first.isNotEmpty)
        ? first.first?.toString()
        : first?.toString();
  }

  String _holidayWarningMessage(_ApiEnvelope env) {
    final h = env.meta?['holiday'] ??
        (env.data is Map ? env.data['holiday'] : null) ??
        env.payload['holiday'];
    if (h is Map) {
      final msg = h['message']?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg;
      final joined = [h['name']?.toString() ?? '', h['date']?.toString() ?? '']
          .where((e) => e.isNotEmpty)
          .join(' - ');
      if (joined.isNotEmpty) return joined;
    } else if (h != null && h.toString().trim().isNotEmpty) {
      return h.toString();
    }
    return env.message?.trim().isNotEmpty == true
        ? env.message!
        : loc.commonHolidayDateUnavailable;
  }

  Future<void> _redirectToLogin() async {
    await clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(onLocaleChange: (_) {})),
      (_) => false,
    );
  }

  String _normalizedIssueCode(_ApiEnvelope env) {
    final raw = (env.code ?? '').toUpperCase().trim();
    if (raw.isNotEmpty) return raw;
    if (env.statusCode == 409) return 'SLOT_BUSY';
    if (env.statusCode == 422) return 'VALIDATION_ERROR';
    if (env.statusCode == 401) return 'UNAUTHORIZED';
    if (env.statusCode == 403)
      return (env.message ?? '').toLowerCase().contains('package')
          ? 'NO_PACKAGE'
          : 'FORBIDDEN';
    return '';
  }

  Future<bool> _handleIssueByCode(_ApiEnvelope env,
      {bool allowPackageNavigation = true,
      bool firstAppointmentFlow = false}) async {
    final code = _normalizedIssueCode(env);
    if (code.isEmpty && env.statusCode >= 200 && env.statusCode < 300)
      return false;
    switch (code) {
      case 'NO_PACKAGE':
        _hasUserPack = false;
        _showSnack(loc.appointmentsPackageRequired);
        if (allowPackageNavigation && mounted)
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => buildPackPageForPlatform()));
        return true;
      case 'HOLIDAY':
        _showSnack(_holidayWarningMessage(env));
        return true;
      case 'SLOT_BUSY':
        _selectedSlotTime = null;
        _quickTimeCtrl.clear();
        final msg = env.message?.trim();
        _showSnack(msg != null && msg.isNotEmpty
            ? msg
            : (firstAppointmentFlow
                ? loc.appointmentsConsecutiveSlotsUnavailable
                : loc.calendarSlotBusy));
        return true;
      case 'VALIDATION_ERROR':
        _showSnack(_firstFieldError(env.errors) ??
            env.message ??
            loc.appointmentsRequiredFields);
        return true;
      case 'UNAUTHORIZED':
        _showSnack(loc.appointmentsSessionMissingLogin);
        await _redirectToLogin();
        return true;
      case 'FORBIDDEN':
        _showSnack(loc.commonForbiddenAction);
        return true;
      default:
        if (env.statusCode == 401) {
          _showSnack(loc.appointmentsSessionMissingLogin);
          await _redirectToLogin();
          return true;
        }
        if (env.statusCode == 403) {
          _showSnack(loc.commonForbiddenAction);
          return true;
        }
        return false;
    }
  }

  dynamic _dataOrPayload(_ApiEnvelope env) => env.data ?? env.payload;

  int _countToday() {
    final today = DateTime.now();
    return _appointments.where((a) {
      try {
        final d = DateTime.parse(a['date']?.toString() ?? '');
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  Future<String?> _getToken() => getAccessToken();

  String _normalizeSlotDate(String raw) =>
      AppointmentDateUtils.normalizeSlotDate(raw);
  DateTime _parseInputDateOrNow(String v) =>
      AppointmentDateUtils.parseInputDateOrNow(v);
  String? _normalizeDateToApi(String i) =>
      AppointmentDateUtils.normalizeDateToApi(i);
  String _formatDateDisplay(DateTime d) =>
      AppointmentDateUtils.formatDateDisplay(d);

  bool _isValidTime(String i) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(i.trim());

  String? _normalizeTimeToApi(String i) {
    final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$')
        .firstMatch(i.trim());
    return m == null ? null : '${m.group(1)}:${m.group(2)}';
  }

  DateTime _clampDate(DateTime d, DateTime mn, DateTime mx) => d.isBefore(mn)
      ? mn
      : d.isAfter(mx)
          ? mx
          : d;

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final p = DateTime.parse(date);
      return '${p.day.toString().padLeft(2, '0')}.${p.month.toString().padLeft(2, '0')}.${p.year}';
    } catch (_) {
      return date;
    }
  }

  String _formatTime(dynamic t) {
    if (t == null) return '';
    final s = t.toString();
    if (s.contains(':')) {
      final p = s.split(':');
      if (p.length >= 2)
        return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
    }
    return s;
  }

  Color _statusColor(String? hex) {
    if (hex == null) return Colors.blueGrey;
    final cleaned = hex.replaceAll('#', '');
    final buf = StringBuffer();
    if (cleaned.length == 6) buf.write('ff');
    buf.write(cleaned);
    try {
      return Color(int.parse(buf.toString(), radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  String _localizedStatusLabel(Map<String, dynamic> s) {
    final alias = s['alias']?.toString();
    final map = {
      'pending': loc.statusPending,
      'confirmed': loc.statusConfirmed,
      'rescheduled': loc.statusRescheduled,
      'completed': loc.statusCompleted,
      'cancelled': loc.statusCancelled,
      'no_show': loc.statusNoShow,
    };
    return (alias != null && map.containsKey(alias))
        ? map[alias]!
        : s['name']?.toString() ?? (alias ?? loc.status);
  }

  int? _defaultStatusId() {
    if (_appointmentStatuses.isEmpty) return null;
    try {
      return _appointmentStatuses.firstWhere((s) =>
              (s['alias'] ?? '').toString().toLowerCase() == 'pending')['id']
          as int?;
    } catch (_) {
      return _appointmentStatuses.first['id'] as int?;
    }
  }

  Map<String, String> _buildValidFilters() {
    final p = <String, String>{};
    final df = _normalizeDateToApi(_filterDateFromCtrl.text);
    final dt = _normalizeDateToApi(_filterDateToCtrl.text);
    final tf = _filterTimeFromCtrl.text.trim();
    final tt = _filterTimeToCtrl.text.trim();
    if (_filterNameCtrl.text.trim().isNotEmpty)
      p['customer_name'] = _filterNameCtrl.text.trim();
    if (_filterLastNameCtrl.text.trim().isNotEmpty)
      p['customer_lastname'] = _filterLastNameCtrl.text.trim();
    if (_filterPhoneCtrl.text.trim().isNotEmpty)
      p['customer_phone'] = _filterPhoneCtrl.text.trim();
    if (df != null) p['date_from'] = df;
    if (dt != null) p['date_to'] = dt;
    if (tf.isNotEmpty && _isValidTime(tf)) p['time_from'] = tf;
    if (tt.isNotEmpty && _isValidTime(tt)) p['time_to'] = tt;
    return p;
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle_outline : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: success ? _T.success : _T.danger,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.r12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()));
  }

  // ── API calls ───────────────────────────────
  Future<void> _fetchAppointments({Map<String, String>? filters}) async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loadingList = false;
        _error = loc.appointmentsSessionMissingLogin;
      });
      return;
    }
    try {
      final uri = Uri.parse('$apiBaseUrl/api/appointments').replace(
          queryParameters: (filters ?? _activeFilters).isNotEmpty
              ? (filters ?? _activeFilters)
              : null);
      final resp = await authGet(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });
      final env = _parseEnvelope(resp);
      final handled = await _handleIssueByCode(env);
      if (handled) {
        if (!mounted) return;
        setState(() {
          _loadingList = false;
          _error = env.message ?? loc.appointmentsPackageRequired;
        });
        return;
      }
      if (env.isSuccess) {
        final raw = _dataOrPayload(env);
        bool? pack;
        final topC = env.payload['user_pack'] ?? env.payload['userPack'];
        if (topC != null) pack = _asBool(topC);
        if (raw is Map) {
          final nc = raw['user_pack'] ?? raw['userPack'];
          if (nc != null) pack = _asBool(nc);
        }
        List<Map<String, dynamic>> list = [];
        if (raw is List) {
          list = List<Map<String, dynamic>>.from(
              raw.map((e) => Map<String, dynamic>.from(e)));
        } else if (raw is Map && raw['data'] is List) {
          list = List<Map<String, dynamic>>.from(
              (raw['data'] as List).map((e) => Map<String, dynamic>.from(e)));
        }
        if (!mounted) return;
        setState(() {
          _appointments = list;
          _loadingList = false;
          _hasUserPack = pack ?? true;
          if (!_hasUserPack) _showQuickForm = false;
        });
      } else {
        setState(() {
          _error = env.message ??
              loc.appointmentsFetchFailedStatus(resp.statusCode.toString());
          _loadingList = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.appointmentsFetchFailed(e.toString());
        _loadingList = false;
      });
    }
  }

  Future<void> _fetchCountries() async {
    setState(() {
      _loadingCountries = true;
      _countriesError = null;
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loadingCountries = false;
        _countriesError = loc.calendarSessionMissing;
      });
      return;
    }
    try {
      final resp = await authGet(
          Uri.parse('$apiBaseUrl/api/settings/countries'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          });
      final env = _parseEnvelope(resp);
      if (await _handleIssueByCode(env)) {
        if (!mounted) return;
        setState(() {
          _loadingCountries = false;
          _countriesError = env.message ??
              loc.appointmentsCountriesFetchFailedStatus(
                  resp.statusCode.toString());
        });
        return;
      }
      if (env.isSuccess) {
        final data = _dataOrPayload(env);
        final list = data is List
            ? List<Map<String, dynamic>>.from(
                data.map((e) => Map<String, dynamic>.from(e)))
            : <Map<String, dynamic>>[];
        if (!mounted) return;
        setState(() {
          _countries = list;
          if (_selectedCountryId == null && _countries.isNotEmpty) {
            _selectedCountryId = _countries.first['id'] as int?;
            _quickCountryIdCtrl.text =
                _selectedCountryId != null ? '$_selectedCountryId' : '';
          }
          _loadingCountries = false;
        });
      } else {
        setState(() {
          _loadingCountries = false;
          _countriesError = env.message ??
              loc.appointmentsCountriesFetchFailedStatus(
                  resp.statusCode.toString());
        });
      }
    } catch (e) {
      setState(() {
        _loadingCountries = false;
        _countriesError = loc.appointmentsCountriesFetchFailed(e.toString());
      });
    }
  }

  Future<void> _fetchStatuses() async {
    setState(() {
      _loadingStatuses = true;
      _statusesError = null;
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loadingStatuses = false;
        _statusesError = loc.calendarSessionMissing;
      });
      return;
    }
    try {
      final resp = await authGet(
          Uri.parse('$apiBaseUrl/api/settings/appointment-statuses'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          });
      final env = _parseEnvelope(resp);
      if (await _handleIssueByCode(env)) {
        if (!mounted) return;
        setState(() {
          _loadingStatuses = false;
          _statusesError = env.message ??
              loc.appointmentsStatusesFetchFailedStatus(
                  resp.statusCode.toString());
        });
        return;
      }
      if (env.isSuccess) {
        final data = _dataOrPayload(env);
        final list = data is List
            ? List<Map<String, dynamic>>.from(
                data.map((e) => Map<String, dynamic>.from(e)))
            : <Map<String, dynamic>>[];
        if (!mounted) return;
        setState(() {
          _appointmentStatuses = list;
          _loadingStatuses = false;
        });
      } else {
        setState(() {
          _loadingStatuses = false;
          _statusesError = env.message ??
              loc.appointmentsStatusesFetchFailedStatus(
                  resp.statusCode.toString());
        });
      }
    } catch (e) {
      setState(() {
        _loadingStatuses = false;
        _statusesError = loc.appointmentsStatusesFetchFailed(e.toString());
      });
    }
  }

  void _resetQuickForm() {
    setState(() {
      for (final c in [
        _quickNameCtrl,
        _quickLastNameCtrl,
        _quickCountryIdCtrl,
        _quickPhoneCtrl,
        _quickEmailCtrl,
        _quickDateCtrl,
        _quickTimeCtrl,
        _quickNoteCtrl
      ]) {
        c.clear();
      }
      _selectedSlotTime = null;
      _timeSlots = [];
      _slotsError = null;
      _quickIsFirstAppointment = false;
      _quickNoSms = false;
      _quickNoReminder = false;
      _showQuickForm = false;
    });
  }

  Future<void> _applyFilters() async {
    if (_filterTimeFromCtrl.text.trim().isNotEmpty &&
        !_isValidTime(_filterTimeFromCtrl.text.trim())) {
      _showSnack(loc.appointmentsInvalidStartTime);
      return;
    }
    if (_filterTimeToCtrl.text.trim().isNotEmpty &&
        !_isValidTime(_filterTimeToCtrl.text.trim())) {
      _showSnack(loc.appointmentsInvalidEndTime);
      return;
    }
    final filters = _buildValidFilters();
    setState(() {
      _activeFilters = filters;
    });
    await _fetchAppointments(filters: filters);
  }

  void _clearFilters() {
    setState(() {
      for (final c in [
        _filterNameCtrl,
        _filterLastNameCtrl,
        _filterPhoneCtrl,
        _filterDateFromCtrl,
        _filterDateToCtrl,
        _filterTimeFromCtrl,
        _filterTimeToCtrl
      ]) {
        c.clear();
      }
      _activeFilters = {};
    });
    _fetchAppointments(filters: {});
  }

  Future<void> _pickQuickDate() async {
    final today = DateTime.now();
    final minDate = DateTime(today.year, today.month, today.day);
    final maxDate = DateTime(today.year + 5, 12, 31);
    final initial =
        _clampDate(_parseInputDateOrNow(_quickDateCtrl.text), minDate, maxDate);
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: minDate,
        lastDate: maxDate);
    if (picked != null) {
      setState(() {
        _quickDateCtrl.text = _formatDateDisplay(picked);
        _selectedSlotTime = null;
        _quickTimeCtrl.clear();
        _timeSlots = [];
      });
      await _fetchTimeSlots();
    }
  }

  Future<void> _fetchTimeSlots() async {
    final dateInput = _quickDateCtrl.text.trim();
    if (dateInput.isEmpty) {
      _showSnack(loc.appointmentsEnterDateFirst);
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.appointmentsSessionMissingLogin);
      return;
    }
    setState(() {
      _loadingSlots = true;
      _slotsRequested = true;
      _slotsError = null;
      _timeSlots = [];
      _selectedSlotTime = null;
      _quickTimeCtrl.clear();
    });
    try {
      final resp = await authGet(
          Uri.parse(
              '$apiBaseUrl/api/appointments/time-slots?date=${_normalizeSlotDate(dateInput)}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          });
      final env = _parseEnvelope(resp);
      if (await _handleIssueByCode(env)) {
        if (!mounted) return;
        setState(() {
          _slotsError = env.message ??
              loc.appointmentsSlotsFetchFailedStatus(
                  resp.statusCode.toString());
          _loadingSlots = false;
        });
        return;
      }
      if (env.isSuccess) {
        final data = _dataOrPayload(env);
        if (!mounted) return;
        setState(() {
          _timeSlots = data is List
              ? List<Map<String, dynamic>>.from(
                  data.map((e) => Map<String, dynamic>.from(e)))
              : [];
          _loadingSlots = false;
        });
      } else {
        setState(() {
          _slotsError = env.message ??
              loc.appointmentsSlotsFetchFailedStatus(
                  resp.statusCode.toString());
          _loadingSlots = false;
        });
      }
    } catch (e) {
      setState(() {
        _slotsError = loc.appointmentsSlotsFetchFailed(e.toString());
        _loadingSlots = false;
      });
    }
  }

  Future<void> _submitQuickAppointment() async {
    if (_savingQuick) return;
    if (!_hasUserPack) {
      _showSnack(loc.appointmentsPackageRequired);
      return;
    }
    final firstName = _quickNameCtrl.text.trim();
    final lastName = _quickLastNameCtrl.text.trim();
    final countryId =
        _selectedCountryId ?? int.tryParse(_quickCountryIdCtrl.text.trim());
    final phone = _quickPhoneCtrl.text.trim();
    final email = _quickEmailCtrl.text.trim();
    final date = _quickDateCtrl.text.trim();
    final normDate = _normalizeSlotDate(date);
    final time = (_selectedSlotTime ?? _quickTimeCtrl.text).trim();
    final note = _quickNoteCtrl.text.trim();
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        countryId == null ||
        phone.isEmpty ||
        normDate.isEmpty ||
        time.isEmpty) {
      _showSnack(loc.appointmentsRequiredFields);
      return;
    }
    if (_timeSlots.isNotEmpty && time.isEmpty) {
      _showSnack(loc.appointmentsSelectAvailableTime);
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.appointmentsSessionMissingLogin);
      return;
    }
    setState(() {
      _savingQuick = true;
    });
    try {
      final resp = await authPost(
          Uri.parse('$apiBaseUrl/api/appointments/quick_appointment'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'customer_name': firstName,
            'customer_lastname': lastName,
            'country_id': countryId,
            'phone': phone,
            'email': email.isEmpty ? null : email,
            'date': normDate,
            'time': time,
            'note': note,
            'is_first_appointment': _quickIsFirstAppointment,
            'no_sms': _quickNoSms,
            'no_reminder': _quickNoReminder
          }));
      final env = _parseEnvelope(resp);
      if (env.isSuccess) {
        _showSnack(loc.appointmentsCreateSuccess, success: true);
        await _fetchAppointments();
        _resetQuickForm();
      } else {
        final h = await _handleIssueByCode(env,
            firstAppointmentFlow: _quickIsFirstAppointment);
        if (!h)
          _showSnack(env.message ??
              loc.appointmentsCreateFailedStatus(resp.statusCode.toString()));
      }
    } catch (e) {
      _showSnack(loc.appointmentsCreateFailed(e.toString()));
    } finally {
      if (mounted)
        setState(() {
          _savingQuick = false;
        });
    }
  }

  Future<void> _updateAppointment({
    required int appointmentId,
    required int customerId,
    required int statusId,
    required String date,
    required String time,
    required String notes,
    required bool noSms,
    required bool noReminder,
    String? originalDate,
    String? originalTime,
    bool includeScheduleFields = true,
  }) async {
    if (_savingAppointment) return;
    final normDate = _normalizeDateToApi(date) ?? _normalizeSlotDate(date);
    final normTime = _normalizeTimeToApi(time) ?? time.trim();
    if (normDate.isEmpty || normTime.isEmpty) {
      _showSnack(loc.appointmentsDateTimeRequired);
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.appointmentsSessionMissingLogin);
      return;
    }
    setState(() {
      _savingAppointment = true;
    });
    try {
      final origDateNorm = originalDate == null
          ? null
          : (_normalizeDateToApi(originalDate) ??
              _normalizeSlotDate(originalDate));
      final origTimeNorm = originalTime == null
          ? null
          : (_normalizeTimeToApi(originalTime) ?? originalTime.trim());
      final schedChanged = origDateNorm == null ||
          origTimeNorm == null ||
          origDateNorm != normDate ||
          origTimeNorm != normTime;
      if (includeScheduleFields && schedChanged) {
        final vr = await authPost(
            Uri.parse('$apiBaseUrl/api/appointments/validate'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'customer_id': customerId,
              'date': normDate,
              'time': normTime
            }));
        final ve = _parseEnvelope(vr);
        if (!ve.isSuccess) {
          final h = await _handleIssueByCode(ve);
          if (!h) _showSnack(ve.message ?? loc.calendarSlotBusy);
          return;
        }
      }
      final resp = await authPut(
          Uri.parse('$apiBaseUrl/api/appointments/$appointmentId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'customer_id': customerId,
            'appointment_status_id': statusId,
            if (includeScheduleFields) 'date': normDate,
            if (includeScheduleFields) 'time': normTime,
            'notes': notes,
            'no_sms': noSms,
            'no_reminder': noReminder
          }));
      final env = _parseEnvelope(resp);
      if (env.isSuccess) {
        _showSnack(loc.appointmentsUpdateSuccess, success: true);
        await _fetchAppointments();
      } else {
        final h = await _handleIssueByCode(env);
        if (!h)
          _showSnack(env.message ??
              loc.appointmentsUpdateFailedStatus(resp.statusCode.toString()));
      }
    } catch (e) {
      _showSnack(loc.appointmentsUpdateFailed(e.toString()));
    } finally {
      if (mounted)
        setState(() {
          _savingAppointment = false;
        });
    }
  }

  Future<void> _createAppointmentForCustomer({
    required int customerId,
    required String date,
    required String time,
    required String notes,
    required bool noSms,
    required bool noReminder,
    int? appointmentStatusId,
  }) async {
    if (_creatingRebook) return;
    if (!_hasUserPack) {
      _showSnack(loc.appointmentsPackageRequired);
      return;
    }
    final normDate = _normalizeDateToApi(date) ?? _normalizeSlotDate(date);
    final normTime = _normalizeTimeToApi(time) ?? time.trim();
    if (normDate.isEmpty || normTime.isEmpty) {
      _showSnack(loc.appointmentsDateTimeRequired);
      return;
    }
    final statusId = appointmentStatusId ?? _defaultStatusId();
    if (statusId == null) {
      _showSnack(loc.appointmentsStatusMissing);
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.appointmentsSessionMissingLogin);
      return;
    }
    setState(() {
      _creatingRebook = true;
    });
    try {
      final vr = await authPost(
          Uri.parse('$apiBaseUrl/api/appointments/validate'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(
              {'customer_id': customerId, 'date': normDate, 'time': normTime}));
      final ve = _parseEnvelope(vr);
      if (!ve.isSuccess) {
        final h = await _handleIssueByCode(ve);
        if (!h) _showSnack(ve.message ?? loc.calendarSlotBusy);
        return;
      }
      final resp = await authPost(Uri.parse('$apiBaseUrl/api/appointments'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'customer_id': customerId,
            'appointment_status_id': statusId,
            'date': normDate,
            'time': normTime,
            'notes': notes,
            'no_sms': noSms,
            'no_reminder': noReminder
          }));
      final env = _parseEnvelope(resp);
      if (env.isSuccess) {
        _showSnack(loc.appointmentsRebookSuccess, success: true);
        await _fetchAppointments();
      } else {
        final h = await _handleIssueByCode(env);
        if (!h)
          _showSnack(env.message ??
              loc.appointmentsCreateFailedStatus(resp.statusCode.toString()));
      }
    } catch (e) {
      _showSnack(loc.appointmentsCreateFailed(e.toString()));
    } finally {
      if (mounted)
        setState(() {
          _creatingRebook = false;
        });
    }
  }

  // ═══════════════════════════════════════════
  // UI BUILDER METHODS
  // ═══════════════════════════════════════════

  // ── Section card ───────────────────────────
  Widget _card(
      {required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.r16),
          border: Border.all(color: _T.border),
          boxShadow: _T.shadow1),
      child: Padding(padding: padding, child: child),
    );
  }

  // ── Section header inside card ─────────────
  Widget _sectionHeader(String title,
      {String? subtitle, IconData? icon, List<Widget>? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _T.primarySoft,
                  borderRadius: BorderRadius.circular(_T.r8)),
              child: Icon(icon, size: 16, color: _T.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _T.ink,
                        letterSpacing: -0.2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _T.inkSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...trailing,
        ],
      ),
    );
  }

  // ── Stat chips in header ───────────────────
  Widget _statChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────
  Widget _buildHeaderHero() {
    final todayCount = _countToday();
    final totalCount = _appointments.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _T.primary,
        borderRadius: BorderRadius.circular(_T.r16),
        boxShadow: [
          BoxShadow(
              color: _T.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.appointmentManagement,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text(loc.appointmentSubtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.72))),
                  ],
                ),
              ),
              _iconBtn(Icons.refresh, onTap: _fetchAppointments, light: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip(loc.today, '$todayCount', Icons.today_outlined),
              const SizedBox(width: 10),
              _statChip(
                  loc.total, '$totalCount', Icons.calendar_month_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _headerBtn(
              label: loc.quickAppointment,
              icon: Icons.add,
              filled: true,
              onTap: () {
                if (!_hasUserPack) {
                  _showSnack(loc.appointmentsPackageRequired);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => buildPackPageForPlatform()));
                  return;
                }
                setState(() {
                  _showQuickForm = true;
                });
              },
            ),
            _headerBtn(
              label: _showFilters ? loc.hideFilter : loc.showFilter,
              icon: _showFilters
                  ? Icons.filter_alt_off_outlined
                  : Icons.filter_alt_outlined,
              onTap: () => setState(() {
                _showFilters = !_showFilters;
              }),
            ),
            _headerBtn(
              label: loc.refreshList,
              icon: Icons.sync,
              onTap: _fetchAppointments,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _headerBtn(
      {required String label,
      required IconData icon,
      bool filled = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(_T.r10),
          border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? _T.primary : Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filled ? _T.primary : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon,
      {required VoidCallback onTap, bool light = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.15) : _T.surfaceAlt,
          borderRadius: BorderRadius.circular(_T.r8),
          border: Border.all(
              color: light ? Colors.white.withValues(alpha: 0.25) : _T.border),
        ),
        child:
            Icon(icon, size: 18, color: light ? Colors.white : _T.inkSecondary),
      ),
    );
  }

  // ── Appointment card ───────────────────────
  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final customer = appt['customer'] is Map ? appt['customer'] : null;
    final status =
        appt['appointment_status'] is Map ? appt['appointment_status'] : null;
    final rawName = customer?['name']?.toString() ?? '';
    final name = rawName.isNotEmpty
        ? rawName
        : loc.dashboardCustomerFallback(appt['customer_id']?.toString() ?? '');
    final statusName = status == null
        ? ''
        : _localizedStatusLabel(Map<String, dynamic>.from(status));
    final statusColor = _statusColor(status?['color']?.toString());
    final phone =
        (customer?['phone'] ?? customer?['formatted_phone'] ?? appt['phone'])
            ?.toString();
    final notes = (appt['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(_T.r14),
          border: Border.all(color: _T.border),
          boxShadow: _T.shadow1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_T.r14),
          onTap: () => _showEditSheet(appt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with status color accent
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(_T.r10),
                      ),
                      child: Icon(Icons.person_outline,
                          color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _T.ink)),
                          if (statusName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _statusBadge(statusName, statusColor),
                          ],
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _cardActionBtn(
                            Icons.person_search_outlined,
                            _T.primary,
                            loc.appointmentsCustomerPreviewTooltip,
                            () => _showCustomerInfo(appt)),
                        const SizedBox(width: 6),
                        _cardActionBtn(
                            Icons.event_repeat_outlined,
                            const Color(0xFF7C3AED),
                            loc.appointmentsRebookTooltip,
                            () => _showRebookSheet(appt)),
                        const SizedBox(width: 6),
                        _cardActionBtn(
                            Icons.edit_outlined,
                            _T.inkSecondary,
                            loc.appointmentsEditTooltip,
                            () => _showEditSheet(appt)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: _T.surfaceAlt,
                      borderRadius: BorderRadius.circular(_T.r8)),
                  child: Row(
                    children: [
                      _metaItem(Icons.calendar_today_outlined,
                          _formatDate(appt['date'])),
                      const SizedBox(width: 16),
                      _metaItem(Icons.access_time_outlined,
                          _formatTime(appt['time'])),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _metaItem(Icons.phone_outlined, phone),
                      ],
                    ],
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: _T.inkSecondary, height: 1.4)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(_T.r4),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4)),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _T.inkSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: _T.inkSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _cardActionBtn(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(_T.r8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(_T.r8)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ── Appointment list ───────────────────────
  Widget _buildAppointmentList() {
    if (_loadingList) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child:
                CircularProgressIndicator(color: _T.primary, strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return _card(
          child: Column(
        children: [
          _sectionHeader(loc.appointmentsTitle,
              icon: Icons.calendar_today_outlined),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _T.dangerSoft,
                borderRadius: BorderRadius.circular(_T.r8),
                border: Border.all(color: _T.danger.withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.error_outline, color: _T.danger, size: 16),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 13, color: _T.danger))),
            ]),
          ),
        ],
      ));
    }
    if (_appointments.isEmpty) {
      return _card(
          child: Column(
        children: [
          _sectionHeader(loc.appointmentsTitle,
              icon: Icons.calendar_today_outlined),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            alignment: Alignment.center,
            child: Column(children: [
              const Icon(Icons.event_busy_outlined,
                  size: 40, color: _T.inkDisabled),
              const SizedBox(height: 10),
              Text(loc.appointmentsEmpty,
                  style: const TextStyle(fontSize: 13, color: _T.inkSecondary)),
            ]),
          ),
        ],
      ));
    }
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(loc.appointmentsTitle,
              subtitle:
                  loc.appointmentsCountLabel(_appointments.length.toString()),
              icon: Icons.event_note_outlined),
          ..._appointments.map(_buildAppointmentCard),
        ],
      ),
    );
  }

  // ── Filter form ────────────────────────────
  Widget _buildFilterForm() {
    if (!_showFilters) return const SizedBox.shrink();
    return _card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(loc.showFilter,
            subtitle: loc.appointmentsFilterSubtitle,
            icon: Icons.tune_outlined,
            trailing: [
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                        _showFilters = false;
                      }),
                  color: _T.inkSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints())
            ]),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _filterNameCtrl,
                  decoration: _fieldDecor(
                      label: loc.appointmentsFieldName,
                      hint: loc.appointmentsFieldNameFilterHint))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _filterLastNameCtrl,
                  decoration: _fieldDecor(
                      label: loc.appointmentsFieldLastName,
                      hint: loc.appointmentsFieldLastNameFilterHint))),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _filterPhoneCtrl,
            decoration: _fieldDecor(
                label: loc.appointmentsFieldPhone,
                prefix: const Icon(Icons.phone_outlined, size: 18))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: TextField(
            controller: _filterDateFromCtrl,
            readOnly: true,
            decoration: _fieldDecor(
                label: loc.appointmentsStartDate,
                hint: loc.calendarDateHint,
                prefix: const Icon(Icons.calendar_today_outlined, size: 17)),
            onTap: () async {
              final today = DateTime.now();
              final min = DateTime(today.year - 1, 1, 1);
              final max = DateTime(today.year + 5, 12, 31);
              final p = await showDatePicker(
                  context: context,
                  initialDate: _clampDate(
                      _parseInputDateOrNow(_filterDateFromCtrl.text), min, max),
                  firstDate: min,
                  lastDate: max);
              if (p != null)
                setState(() {
                  _filterDateFromCtrl.text = _formatDateDisplay(p);
                });
            },
          )),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
            controller: _filterDateToCtrl,
            readOnly: true,
            decoration: _fieldDecor(
                label: loc.appointmentsEndDate,
                hint: loc.calendarDateHint,
                prefix: const Icon(Icons.calendar_today_outlined, size: 17)),
            onTap: () async {
              final today = DateTime.now();
              final min = DateTime(today.year - 1, 1, 1);
              final max = DateTime(today.year + 5, 12, 31);
              final p = await showDatePicker(
                  context: context,
                  initialDate: _clampDate(
                      _parseInputDateOrNow(_filterDateToCtrl.text), min, max),
                  firstDate: min,
                  lastDate: max);
              if (p != null)
                setState(() {
                  _filterDateToCtrl.text = _formatDateDisplay(p);
                });
            },
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
            initialValue: _filterTimeFromCtrl.text.isNotEmpty
                ? _filterTimeFromCtrl.text
                : null,
            decoration:
                _fieldDecor(label: loc.appointmentsStartTime, hint: 'HH:MM'),
            items: _timeOptions
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() {
              _filterTimeFromCtrl.text = v ?? '';
            }),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: DropdownButtonFormField<String>(
            initialValue: _filterTimeToCtrl.text.isNotEmpty
                ? _filterTimeToCtrl.text
                : null,
            decoration:
                _fieldDecor(label: loc.appointmentsEndTime, hint: 'HH:MM'),
            items: _timeOptions
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() {
              _filterTimeToCtrl.text = v ?? '';
            }),
          )),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _primaryBtn(
                  label: loc.showFilter,
                  icon: Icons.search,
                  onTap: _applyFilters)),
          const SizedBox(width: 10),
          _outlineBtn(label: loc.appointmentsClear, onTap: _clearFilters),
        ]),
      ],
    ));
  }

  // ── Quick appointment form ─────────────────
  Widget _buildQuickForm() {
    if (!_hasUserPack) {
      return _card(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            loc.quickAppointmentTitle,
            icon: Icons.add_circle_outline,
            trailing: [
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => buildPackPageForPlatform()),
                ),
                child: Text(loc.appointmentsBuyPackage),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _T.warningSoft,
                borderRadius: BorderRadius.circular(_T.r8),
                border: Border.all(color: _T.warning.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: _T.warning, size: 16),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(loc.appointmentsPackageRequired,
                      style: const TextStyle(fontSize: 13, color: _T.ink))),
            ]),
          ),
        ],
      ));
    }
    if (!_showQuickForm) return const SizedBox.shrink();

    return _card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(loc.quickAppointmentTitle,
            subtitle: loc.quickAppointmentSubtitle,
            icon: Icons.add_circle_outline,
            trailing: [
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                        _showQuickForm = false;
                      }),
                  color: _T.inkSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints())
            ]),

        // Customer info group
        _groupLabel(loc.customerInfo),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _quickNameCtrl,
                  decoration: _fieldDecor(
                      label: loc.appointmentsFieldName,
                      hint: loc.appointmentsFieldNameHint))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _quickLastNameCtrl,
                  decoration: _fieldDecor(
                      label: loc.appointmentsFieldLastName,
                      hint: loc.appointmentsFieldLastNameHint))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _selectedCountryId,
          isExpanded: true,
          decoration: _fieldDecor(
              label: loc.appointmentsCountry,
              hint: _loadingCountries
                  ? loc.calendarLoading
                  : loc.appointmentsSelectCountry,
              error: _countriesError),
          items: _countries
              .map((c) => DropdownMenuItem<int>(
                  value: c['id'] as int?,
                  child: Text('${c['name'] ?? ''} (${c['phone_code'] ?? ''})',
                      style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: _loadingCountries
              ? null
              : (v) => setState(() {
                    _selectedCountryId = v;
                    _quickCountryIdCtrl.text = v != null ? '$v' : '';
                    _countriesError = null;
                  }),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: TextField(
            controller: _quickPhoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d()\s]')),
              _phoneMaskFormatter
            ],
            decoration: _fieldDecor(
                label: loc.appointmentsFieldPhone,
                hint: loc.appointmentsFieldPhoneHint,
                prefix: const Icon(Icons.phone_outlined, size: 17)),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
            controller: _quickEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecor(
                label: loc.emailLabel,
                hint: loc.appointmentsFieldEmailHint,
                prefix: const Icon(Icons.email_outlined, size: 17)),
          )),
        ]),
        const SizedBox(height: 18),

        // Appointment info group
        _groupLabel(loc.appointmentInfo),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextField(
            controller: _quickDateCtrl,
            readOnly: true,
            decoration: _fieldDecor(
                label: loc.date,
                hint: loc.calendarDateHint,
                prefix: const Icon(Icons.calendar_today_outlined, size: 17)),
            onTap: _pickQuickDate,
          )),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
            controller: _quickTimeCtrl,
            readOnly: true,
            decoration: _fieldDecor(
                label: loc.timeSelect,
                hint: loc.calendarTimeSlotHint,
                prefix: const Icon(Icons.access_time_outlined, size: 17)),
          )),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _outlineBtn(
              label: loc.getAvailableTimes,
              icon: Icons.schedule_outlined,
              onTap: _loadingSlots ? null : _fetchTimeSlots,
              loading: _loadingSlots),
        ),
        if (_slotsError != null) ...[
          const SizedBox(height: 8),
          _inlineError(_slotsError!),
        ],
        if (_loadingSlots) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
              color: _T.primary, backgroundColor: _T.primarySoft, minHeight: 2),
        ],
        if (_slotsRequested &&
            !_loadingSlots &&
            _slotsError == null &&
            _timeSlots.isEmpty) ...[
          const SizedBox(height: 8),
          _buildWorkingPrefCallout(),
        ],
        if (_timeSlots.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildTimeSlotGrid(
              _timeSlots,
              _selectedSlotTime,
              (t) => setState(() {
                    _selectedSlotTime = t;
                    _quickTimeCtrl.text = t;
                    _slotsError = null;
                  })),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _quickNoteCtrl,
          maxLines: 2,
          decoration: _fieldDecor(label: loc.note, hint: '...'),
        ),
        const SizedBox(height: 6),
        _minimalToggle(
            label: loc.appointmentsFirstAppointment,
            value: _quickIsFirstAppointment,
            onChanged: (v) => setState(() {
                  _quickIsFirstAppointment = v;
                })),
        _minimalToggle(
            label: loc.doNotSendSms,
            subtitle: loc.smsOffForAppointment,
            value: _quickNoSms,
            onChanged: (v) => setState(() {
                  _quickNoSms = v;
                })),
        _minimalToggle(
            label: loc.appointmentsReminderDisableTitle,
            subtitle: loc.reminderOffForAppointment,
            value: _quickNoReminder,
            onChanged: (v) => setState(() {
                  _quickNoReminder = v;
                })),
        const SizedBox(height: 14),
        _primaryBtn(
          label: _savingQuick
              ? loc.appointmentsSubmitting
              : loc.quickAppointmentTitle,
          icon: Icons.event_available_outlined,
          onTap: _savingQuick ? null : _submitQuickAppointment,
          loading: _savingQuick,
        ),
      ],
    ));
  }

  // ── Working pref callout ───────────────────
  Widget _buildWorkingPrefCallout() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(_T.r10),
          border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.calendarWorkingHoursPrompt,
                  style: const TextStyle(
                      fontSize: 13,
                      color: _T.ink,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WorkingPreferencesPage())),
                child: Text(loc.setWorkingHours,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline)),
              ),
            ],
          )),
        ],
      ),
    );
  }

  // ── Modals ─────────────────────────────────
  void _showEditSheet(Map<String, dynamic> appt) {
    final int? appointmentId = appt['id'] is int
        ? appt['id'] as int
        : int.tryParse(appt['id']?.toString() ?? '');
    final int? customerId = appt['customer_id'] is int
        ? appt['customer_id'] as int
        : int.tryParse(appt['customer_id']?.toString() ?? '');
    final int? statusId = appt['appointment_status_id'] is int
        ? appt['appointment_status_id'] as int
        : int.tryParse(appt['appointment_status_id']?.toString() ?? '');
    final rawDate = appt['date']?.toString() ?? '';
    final dateCtrl = TextEditingController(
        text: rawDate.trim().isEmpty
            ? ''
            : _formatDateDisplay(_parseInputDateOrNow(rawDate)));
    final timeCtrl = TextEditingController(text: _formatTime(appt['time']));
    final notesCtrl =
        TextEditingController(text: appt['notes']?.toString() ?? '');
    final customerName = (appt['customer']?['name'] ?? '').toString().isNotEmpty
        ? appt['customer']['name'].toString()
        : loc.dashboardCustomerFallback(appt['customer_id']?.toString() ?? '');
    bool localNoSms = _asBool(appt['no_sms']);
    bool localNoReminder = _asBool(appt['no_reminder']);
    bool localScheduleChanged = false;
    final origFormattedTime = _formatTime(appt['time']);
    List<Map<String, dynamic>> localSlots = [];
    String? localSlotsError;
    bool localLoadingSlots = false;
    String? localSelectedTime =
        timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null;
    int? localSelectedStatusId = statusId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.96),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        final effectiveStatusId =
            localSelectedStatusId ?? statusId ?? _defaultStatusId();

        Future<void> loadSlots() async {
          final di = dateCtrl.text.trim();
          if (di.isEmpty) {
            _showSnack(loc.appointmentsEnterDateFirst);
            return;
          }
          final token = await _getToken();
          if (token == null || token.isEmpty) {
            _showSnack(loc.appointmentsSessionMissingLogin);
            return;
          }
          setModal(() {
            localLoadingSlots = true;
            localSlotsError = null;
            localSlots = [];
            localSelectedTime = null;
            timeCtrl.clear();
          });
          try {
            final resp = await authGet(
                Uri.parse(
                    '$apiBaseUrl/api/appointments/time-slots?date=${_normalizeSlotDate(di)}'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json'
                });
            final env = _parseEnvelope(resp);
            if (await _handleIssueByCode(env)) {
              setModal(() {
                localSlotsError = env.message ??
                    loc.appointmentsSlotsFetchFailedStatus(
                        resp.statusCode.toString());
                localLoadingSlots = false;
              });
              return;
            }
            if (env.isSuccess) {
              final data = _dataOrPayload(env);
              setModal(() {
                localSlots = data is List
                    ? List<Map<String, dynamic>>.from(
                        data.map((e) => Map<String, dynamic>.from(e)))
                    : [];
                localLoadingSlots = false;
              });
            } else {
              setModal(() {
                localSlotsError = env.message ??
                    loc.appointmentsSlotsFetchFailedStatus(
                        resp.statusCode.toString());
                localLoadingSlots = false;
              });
            }
          } catch (e) {
            setModal(() {
              localSlotsError = loc.appointmentsSlotsFetchFailed(e.toString());
              localLoadingSlots = false;
            });
          }
        }

        Future<void> pickDate() async {
          final today = DateTime.now();
          final min = DateTime(today.year, today.month, today.day);
          final max = DateTime(today.year + 5, 12, 31);
          final p = await showDatePicker(
              context: ctx,
              initialDate:
                  _clampDate(_parseInputDateOrNow(dateCtrl.text), min, max),
              firstDate: min,
              lastDate: max);
          if (p != null) {
            setModal(() {
              dateCtrl.text = _formatDateDisplay(p);
              localSelectedTime = null;
              timeCtrl.clear();
              localSlots = [];
              localSlotsError = null;
              localScheduleChanged = true;
            });
            await loadSlots();
          }
        }

        final bottom = MediaQuery.of(ctx).viewInsets.bottom +
            MediaQuery.of(ctx).viewPadding.bottom +
            20;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.editAppointment,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _T.ink,
                                        letterSpacing: -0.3)),
                                const SizedBox(height: 2),
                                Text(customerName,
                                    style: const TextStyle(
                                        fontSize: 13, color: _T.inkSecondary)),
                              ]),
                          _iconBtn(Icons.close,
                              onTap: () => Navigator.of(ctx).pop()),
                        ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: dateCtrl,
                              readOnly: true,
                              onTap: pickDate,
                              decoration: _fieldDecor(
                                  label: loc.date,
                                  hint: loc.calendarDateHint,
                                  prefix: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 17)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: timeCtrl,
                              readOnly: true,
                              decoration: _fieldDecor(
                                  label: loc.timeSelect,
                                  hint: loc.calendarTimeSlotHint,
                                  prefix: const Icon(Icons.access_time_outlined,
                                      size: 17)))),
                    ]),
                    const SizedBox(height: 10),
                    _outlineBtn(
                        label: loc.getAvailableTimes,
                        icon: Icons.schedule_outlined,
                        onTap: localLoadingSlots ? null : loadSlots,
                        loading: localLoadingSlots,
                        fullWidth: true),
                    if (localSlotsError != null) ...[
                      const SizedBox(height: 8),
                      _inlineError(localSlotsError!)
                    ],
                    if (localLoadingSlots) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                          color: _T.primary,
                          backgroundColor: _T.primarySoft,
                          minHeight: 2)
                    ],
                    if (localSlots.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildTimeSlotGrid(localSlots, localSelectedTime, (t) {
                        setModal(() {
                          localSelectedTime = t;
                          timeCtrl.text = t;
                          localSlotsError = null;
                          localScheduleChanged = t != origFormattedTime;
                        });
                      }, originalTime: origFormattedTime),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: effectiveStatusId,
                      isExpanded: true,
                      decoration: _fieldDecor(
                          label: loc.status,
                          hint: _loadingStatuses
                              ? loc.calendarLoading
                              : loc.appointmentsStatusSelectHint,
                          error: _statusesError),
                      items: _appointmentStatuses
                          .map((s) => DropdownMenuItem<int>(
                              value: s['id'] as int?,
                              child: Text(_localizedStatusLabel(s),
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: _loadingStatuses
                          ? null
                          : (v) => setModal(() {
                                localSelectedStatusId = v;
                                _statusesError = null;
                              }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: _fieldDecor(label: loc.note, hint: '...')),
                    const SizedBox(height: 6),
                    _minimalToggle(
                        label: loc.doNotSendSms,
                        value: localNoSms,
                        onChanged: (v) => setModal(() {
                              localNoSms = v;
                            })),
                    _minimalToggle(
                        label: loc.doNotSendReminder,
                        value: localNoReminder,
                        onChanged: (v) => setModal(() {
                              localNoReminder = v;
                            })),
                    const SizedBox(height: 16),
                    _primaryBtn(
                      label: loc.save,
                      icon: Icons.save_outlined,
                      onTap: (appointmentId == null ||
                              customerId == null ||
                              effectiveStatusId == null ||
                              _savingAppointment)
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await _updateAppointment(
                                appointmentId: appointmentId,
                                customerId: customerId,
                                statusId: effectiveStatusId,
                                date: dateCtrl.text.trim(),
                                time:
                                    (localSelectedTime ?? timeCtrl.text).trim(),
                                notes: notesCtrl.text.trim(),
                                noSms: localNoSms,
                                noReminder: localNoReminder,
                                originalDate: rawDate,
                                originalTime: origFormattedTime,
                                includeScheduleFields: localScheduleChanged,
                              );
                            },
                      loading: _savingAppointment,
                      color: _T.success,
                    ),
                  ]),
            ),
          ),
        );
      }),
    );
  }

  void _showCustomerInfo(Map<String, dynamic> appt) {
    final int? appointmentId = appt['id'] is int
        ? appt['id'] as int
        : int.tryParse(appt['id']?.toString() ?? '');
    if (appointmentId == null) {
      _showSnack(loc.appointmentsInfoMissing);
      return;
    }
    Map<String, dynamic>? info;
    String? loadError;

    Future<void> fetchInfo(StateSetter setModal) async {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setModal(() {
          loadError = loc.calendarSessionMissing;
        });
        return;
      }
      setModal(() {
        _loadingCustomerInfo = true;
        loadError = null;
      });
      try {
        final resp = await authPost(
            Uri.parse('$apiBaseUrl/api/appointments/customer-info'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'appointment_id': appointmentId}));
        final env = _parseEnvelope(resp);
        if (await _handleIssueByCode(env)) {
          setModal(() {
            loadError = env.message ??
                loc.appointmentsInfoFetchFailedStatus(
                    resp.statusCode.toString());
            _loadingCustomerInfo = false;
          });
          return;
        }
        if (env.isSuccess) {
          final data = _dataOrPayload(env);
          setModal(() {
            info = data is Map ? Map<String, dynamic>.from(data) : null;
            _loadingCustomerInfo = false;
          });
        } else {
          setModal(() {
            loadError = env.message ??
                loc.appointmentsInfoFetchFailedStatus(
                    resp.statusCode.toString());
            _loadingCustomerInfo = false;
          });
        }
      } catch (e) {
        setModal(() {
          loadError = loc.appointmentsInfoFetchFailed(e.toString());
          _loadingCustomerInfo = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        if (info == null && loadError == null && !_loadingCustomerInfo)
          fetchInfo(setModal);
        final recent = (info?['recent_appointments'] is List)
            ? List<Map<String, dynamic>>.from(
                (info!['recent_appointments'] as List)
                    .map((e) => Map<String, dynamic>.from(e)))
            : <Map<String, dynamic>>[];
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.customerPreview,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _T.ink,
                                letterSpacing: -0.3)),
                        _iconBtn(Icons.close,
                            onTap: () => Navigator.of(ctx).pop()),
                      ]),
                  if (_loadingCustomerInfo) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                        color: _T.primary,
                        backgroundColor: _T.primarySoft,
                        minHeight: 2)
                  ],
                  if (loadError != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _inlineError(loadError!)),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.refresh, onTap: () => fetchInfo(setModal)),
                    ]),
                  ],
                  if (info != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: _T.surfaceAlt,
                          borderRadius: BorderRadius.circular(_T.r12),
                          border: Border.all(color: _T.border)),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: _T.primarySoft,
                              borderRadius: BorderRadius.circular(_T.r10)),
                          child: const Icon(Icons.person_outline,
                              color: _T.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  '${info?['customer_name'] ?? ''} ${info?['customer_lastname'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _T.ink)),
                              const SizedBox(height: 6),
                              if ((info?['customer_phone'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _metaItem(Icons.phone_outlined,
                                    info?['customer_phone'] ?? ''),
                              if ((info?['customer_email'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                _metaItem(Icons.email_outlined,
                                    info?['customer_email'] ?? '')
                              ],
                            ])),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Text(loc.recentAppointments,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _T.ink)),
                      const Spacer(),
                      const Icon(Icons.history,
                          size: 16, color: _T.inkSecondary),
                    ]),
                    const SizedBox(height: 10),
                    if (recent.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text(loc.appointmentsNoRecords,
                                  style: const TextStyle(
                                      fontSize: 13, color: _T.inkSecondary))))
                    else
                      ...recent.map((r) {
                        final date = _formatDate(r['date']?.toString());
                        final time = _formatTime(r['time']);
                        final status = (r['status'] ?? '').toString();
                        final notes = (r['notes'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: _T.surface,
                              borderRadius: BorderRadius.circular(_T.r10),
                              border: Border.all(color: _T.border)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        _metaItem(Icons.calendar_today_outlined,
                                            date),
                                        const SizedBox(width: 12),
                                        _metaItem(
                                            Icons.access_time_outlined, time),
                                      ]),
                                      if (status.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: _T.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(_T.r4),
                                              border:
                                                  Border.all(color: _T.border)),
                                          child: Text(status.toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: _T.inkSecondary)),
                                        ),
                                    ]),
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(notes,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: _T.inkSecondary,
                                          height: 1.4))
                                ],
                              ]),
                        );
                      }),
                  ],
                ])),
          ),
        );
      }),
    );
  }

  void _showRebookSheet(Map<String, dynamic> appt) {
    final int? customerId = appt['customer_id'] is int
        ? appt['customer_id'] as int
        : int.tryParse(appt['customer_id']?.toString() ?? '');
    final customer = appt['customer'] is Map ? appt['customer'] : null;
    final customerName = (customer?['name'] ?? '').toString().isNotEmpty
        ? customer!['name'].toString()
        : loc.dashboardCustomerFallback(appt['customer_id']?.toString() ?? '');
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    List<Map<String, dynamic>> localSlots = [];
    String? localSlotsError;
    bool localLoadingSlots = false;
    String? localSelectedTime;
    bool localNoSms = _asBool(appt['no_sms']);
    bool localNoReminder = _asBool(appt['no_reminder']);
    int? localSelectedStatusId = _defaultStatusId();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _T.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.96),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        Future<void> loadSlots() async {
          final di = dateCtrl.text.trim();
          if (di.isEmpty) {
            _showSnack(loc.appointmentsEnterDateFirst);
            return;
          }
          final token = await _getToken();
          if (token == null || token.isEmpty) {
            _showSnack(loc.appointmentsSessionMissingLogin);
            return;
          }
          setModal(() {
            localLoadingSlots = true;
            localSlotsError = null;
            localSlots = [];
            localSelectedTime = null;
            timeCtrl.clear();
          });
          try {
            final resp = await authGet(
                Uri.parse(
                    '$apiBaseUrl/api/appointments/time-slots?date=${_normalizeSlotDate(di)}'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json'
                });
            final env = _parseEnvelope(resp);
            if (await _handleIssueByCode(env)) {
              setModal(() {
                localSlotsError = env.message ??
                    loc.appointmentsSlotsFetchFailedStatus(
                        resp.statusCode.toString());
                localLoadingSlots = false;
              });
              return;
            }
            if (env.isSuccess) {
              final data = _dataOrPayload(env);
              setModal(() {
                localSlots = data is List
                    ? List<Map<String, dynamic>>.from(
                        data.map((e) => Map<String, dynamic>.from(e)))
                    : [];
                localLoadingSlots = false;
              });
            } else {
              setModal(() {
                localSlotsError = env.message ??
                    loc.appointmentsSlotsFetchFailedStatus(
                        resp.statusCode.toString());
                localLoadingSlots = false;
              });
            }
          } catch (e) {
            setModal(() {
              localSlotsError = loc.appointmentsSlotsFetchFailed(e.toString());
              localLoadingSlots = false;
            });
          }
        }

        Future<void> pickDate() async {
          final today = DateTime.now();
          final min = DateTime(today.year, today.month, today.day);
          final max = DateTime(today.year + 5, 12, 31);
          final p = await showDatePicker(
              context: ctx,
              initialDate:
                  _clampDate(_parseInputDateOrNow(dateCtrl.text), min, max),
              firstDate: min,
              lastDate: max);
          if (p != null) {
            setModal(() {
              dateCtrl.text = _formatDateDisplay(p);
              localSelectedTime = null;
              timeCtrl.clear();
              localSlots = [];
              localSlotsError = null;
            });
            await loadSlots();
          }
        }

        final bottom = MediaQuery.of(ctx).viewInsets.bottom +
            MediaQuery.of(ctx).viewPadding.bottom +
            24;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(loc.reschedule,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _T.ink,
                                  letterSpacing: -0.4)),
                          const SizedBox(height: 3),
                          Text(customerName,
                              style: const TextStyle(
                                  fontSize: 13, color: _T.inkSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ])),
                    _iconBtn(Icons.close, onTap: () => Navigator.of(ctx).pop()),
                  ]),
                  const SizedBox(height: 22),
                  _groupLabel('TARİH & SAAT'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            onTap: pickDate,
                            decoration: _fieldDecor(
                                label: loc.date,
                                hint: loc.calendarDateHint,
                                prefix: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 17)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: timeCtrl,
                            readOnly: true,
                            decoration: _fieldDecor(
                                label: loc.timeSelect,
                                hint: loc.calendarTimeSlotHint,
                                prefix: const Icon(Icons.access_time_outlined,
                                    size: 17)))),
                  ]),
                  const SizedBox(height: 10),
                  _outlineBtn(
                      label: loc.getAvailableTimes,
                      icon: Icons.schedule_outlined,
                      onTap: localLoadingSlots ? null : loadSlots,
                      loading: localLoadingSlots,
                      fullWidth: true),
                  if (localSlotsError != null) ...[
                    const SizedBox(height: 8),
                    _inlineError(localSlotsError!)
                  ],
                  if (localLoadingSlots) ...[
                    const SizedBox(height: 6),
                    const LinearProgressIndicator(
                        color: _T.primary,
                        backgroundColor: _T.primarySoft,
                        minHeight: 2)
                  ],
                  if (localSlots.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildTimeSlotGrid(
                        localSlots,
                        localSelectedTime,
                        (t) => setModal(() {
                              localSelectedTime = t;
                              timeCtrl.text = t;
                            })),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: localSelectedStatusId,
                    isExpanded: true,
                    decoration: _fieldDecor(
                        label: loc.status,
                        hint: _loadingStatuses
                            ? loc.calendarLoading
                            : loc.appointmentsStatusSelectHint,
                        error: _statusesError),
                    items: _appointmentStatuses
                        .map((s) => DropdownMenuItem<int>(
                            value: s['id'] as int?,
                            child: Text(_localizedStatusLabel(s),
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: _loadingStatuses
                        ? null
                        : (v) => setModal(() {
                              localSelectedStatusId = v;
                            }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: _fieldDecor(label: loc.note, hint: '...')),
                  const SizedBox(height: 8),
                  _minimalToggle(
                      label: loc.doNotSendSms,
                      subtitle: loc.smsOffForAppointment,
                      value: localNoSms,
                      onChanged: (v) => setModal(() {
                            localNoSms = v;
                          })),
                  _minimalToggle(
                      label: loc.doNotSendReminder,
                      subtitle: loc.reminderOffForAppointment,
                      value: localNoReminder,
                      onChanged: (v) => setModal(() {
                            localNoReminder = v;
                          })),
                  const SizedBox(height: 16),
                  _primaryBtn(
                    label: loc.rescheduleAppointment,
                    icon: Icons.event_available_outlined,
                    loading: _creatingRebook,
                    onTap: (customerId == null || _creatingRebook)
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await _createAppointmentForCustomer(
                                customerId: customerId,
                                date: dateCtrl.text.trim(),
                                time:
                                    (localSelectedTime ?? timeCtrl.text).trim(),
                                notes: notesCtrl.text.trim(),
                                noSms: localNoSms,
                                noReminder: localNoReminder,
                                appointmentStatusId: localSelectedStatusId);
                          },
                  ),
                ]),
          ),
        );
      }),
    );
  }

  // ── Shared small widgets ───────────────────
  Widget _sheetHandle() => Center(
      child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: _T.border, borderRadius: BorderRadius.circular(99))));

  Widget _groupLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _T.inkSecondary,
          letterSpacing: 0.6));

  Widget _inlineError(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: _T.dangerSoft,
            borderRadius: BorderRadius.circular(_T.r8),
            border: Border.all(color: _T.danger.withValues(alpha: 0.2))),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: _T.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 12, color: _T.danger))),
        ]),
      );

  Widget _minimalToggle(
      {required String label,
      String? subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _T.ink)),
          if (subtitle != null)
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: _T.inkSecondary)),
        ])),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: _T.primary,
          activeTrackColor: _T.primarySoft,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _primaryBtn(
      {required String label,
      IconData? icon,
      required VoidCallback? onTap,
      bool loading = false,
      Color color = _T.primary}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_T.r12)),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else if (icon != null)
                Icon(icon, size: 17),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1)),
            ]),
      ),
    );
  }

  Widget _outlineBtn(
      {required String label,
      IconData? icon,
      required VoidCallback? onTap,
      bool loading = false,
      bool fullWidth = false}) {
    final btn = OutlinedButton(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _T.ink,
        side: const BorderSide(color: _T.border, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(_T.r12)),
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _T.inkSecondary))
            else if (icon != null)
              Icon(icon, size: 16, color: _T.inkSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _T.inkSecondary)),
          ]),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _buildTimeSlotGrid(List<Map<String, dynamic>> slots,
      String? selectedTime, ValueChanged<String> onSelect,
      {String? originalTime}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final time = slot['time']?.toString() ?? '';
        final booked = slot['booked'] == true || slot['booked'] == 1;
        final canUse = originalTime != null && time == originalTime;
        final disabled = booked && !canUse;
        final selected = selectedTime == time;
        return GestureDetector(
          onTap: disabled ? null : () => onSelect(time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: disabled
                  ? _T.surfaceAlt
                  : selected
                      ? _T.success
                      : _T.surface,
              borderRadius: BorderRadius.circular(_T.r8),
              border: Border.all(
                  color: disabled
                      ? _T.border
                      : selected
                          ? _T.success
                          : _T.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? _T.inkDisabled
                    : selected
                        ? Colors.white
                        : _T.ink,
                decoration: disabled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _T.surface,
        foregroundColor: _T.ink,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _T.primarySoft,
                borderRadius: BorderRadius.circular(_T.r8)),
            child: const Icon(Icons.calendar_today_outlined,
                color: _T.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(loc.appointmentsTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _T.ink,
                  letterSpacing: -0.2)),
        ]),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _T.border)),
        actions: [
          if (widget.showBottomNav)
            IconButton(
                onPressed: _navigateToDashboard,
                icon: const Icon(Icons.home_outlined, color: _T.inkSecondary),
                tooltip: loc.appointmentsHomeTooltip),
          IconButton(
              onPressed: _fetchAppointments,
              icon: const Icon(Icons.refresh, color: _T.inkSecondary),
              tooltip: loc.refresh),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAppointments,
        color: _T.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeaderHero(),
            _buildQuickForm(),
            _buildFilterForm(),
            _buildAppointmentList(),
          ]),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? MainNavBar(currentIndex: 1, onIndexSelected: widget.onTabSelected)
          : null,
    );
  }
}
