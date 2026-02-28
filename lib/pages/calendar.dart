import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/dashboard_page.dart';
import 'package:bagla_mobile/login_page.dart';
import 'package:bagla_mobile/pages/working_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'sms_packs.dart';
import '../utils/appointment_date_utils.dart';
import '../widgets/main_nav.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

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
    final c = (code ?? '').toUpperCase();
    if (c == 'OK' || c == 'CREATED' || c == 'UPDATED') return true;
    return statusCode >= 200 && statusCode < 300;
  }
}

DateTime _startOfWeek(DateTime date) {
  final weekday = date.weekday; // 1 = Mon
  return DateTime(date.year, date.month, date.day).subtract(
    Duration(days: weekday - 1),
  );
}

Future<String?> _getToken() async {
  return getAccessToken();
}

const _authRetriedKey = '__auth_retried__';

Future<Dio> _buildAuthedDio({bool includeJsonContentType = false}) async {
  final token = await _getToken();
  if (token == null || token.isEmpty) {
    throw const AuthRequiredException();
  }

  final headers = <String, dynamic>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };
  if (includeJsonContentType) {
    headers['Content-Type'] = 'application/json';
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      headers: headers,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) async {
        final alreadyRetried =
            err.requestOptions.extra[_authRetriedKey] == true;
        if (err.response?.statusCode != 401 || alreadyRetried) {
          return handler.next(err);
        }

        final refreshed = await refreshAccessToken();
        if (refreshed == null || refreshed.isEmpty) {
          return handler.next(err);
        }

        final req = err.requestOptions;
        req.extra[_authRetriedKey] = true;
        req.headers['Authorization'] = 'Bearer $refreshed';
        try {
          final retryResp = await dio.fetch(req);
          return handler.resolve(retryResp);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      },
    ),
  );

  return dio;
}

Color _bootstrapColor(String? alias) {
  switch (alias) {
    case 'primary':
      return const Color(0xFF0D6EFD);
    case 'secondary':
      return const Color(0xFF6C757D);
    case 'success':
      return const Color(0xFF198754);
    case 'danger':
      return const Color(0xFFDC3545);
    case 'warning':
      return const Color(0xFFFFC107);
    case 'info':
      return const Color(0xFF0DCAF0);
    case 'light':
      return const Color(0xFFF8F9FA);
    case 'dark':
      return const Color(0xFF212529);
    default:
      return Colors.blueGrey;
  }
}

class _PhoneMaskFormatter extends TextInputFormatter {
  static final RegExp _digitsOnly = RegExp(r'\D');

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

  String _applyMask(String raw) {
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
      b.write(limited.substring(6, limited.length.clamp(6, 10)));
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = _applyMask(newValue.text);
    final digitsBefore = _digitCount(newValue.text, newValue.selection.end);
    final target = _offsetForDigits(masked, digitsBefore);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: target),
      composing: TextRange.empty,
    );
  }
}

class WeekDayInfo {
  final String date; // YYYY-MM-DD
  final int dayOfWeekIso;
  final String label;
  final String shortLabel;
  final String displayDate; // e.g. 27.05
  final bool isToday;
  final bool isWorking;

  const WeekDayInfo({
    required this.date,
    required this.dayOfWeekIso,
    required this.label,
    required this.shortLabel,
    required this.displayDate,
    required this.isToday,
    required this.isWorking,
  });

  factory WeekDayInfo.fromJson(Map<String, dynamic> json) {
    return WeekDayInfo(
      date: json['date']?.toString() ?? '',
      dayOfWeekIso: json['day_of_week_iso'] is int
          ? json['day_of_week_iso'] as int
          : int.tryParse(json['day_of_week_iso']?.toString() ?? '') ?? 1,
      label: json['label']?.toString() ?? '',
      shortLabel: json['short_label']?.toString() ?? '',
      displayDate: json['display_date']?.toString() ?? '',
      isToday: json['is_today'] == true || json['is_today'] == 1,
      isWorking: json['is_working'] == true || json['is_working'] == 1,
    );
  }
}

class SlotInfo {
  final String time; // HH:MM
  final bool booked;
  final int slotIndex;
  final int period;

  const SlotInfo({
    required this.time,
    required this.booked,
    required this.slotIndex,
    required this.period,
  });

  factory SlotInfo.fromJson(Map<String, dynamic> json) {
    return SlotInfo(
      time: json['time']?.toString() ?? '',
      booked: json['booked'] == true || json['booked'] == 1,
      slotIndex: json['slot_index'] is int
          ? json['slot_index'] as int
          : int.tryParse(json['slot_index']?.toString() ?? '') ?? 0,
      period: json['period'] is int
          ? json['period'] as int
          : int.tryParse(json['period']?.toString() ?? '') ?? 0,
    );
  }
}

class WeeklyCalendarData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final String weekRangeText;
  final List<WeekDayInfo> weekDays;
  final Map<String, List<SlotInfo>> timeSlotsByDay;
  final List<String> timeGrid;
  final Map<String, List<Map<String, dynamic>>> appointmentsBySlot;
  final Map<String, String> statusColors;
  final Map<String, dynamic> workingPreferences;
  final bool hasTimeSlots;
  final bool? hasUserPack;

  WeeklyCalendarData({
    required this.weekStart,
    required this.weekEnd,
    required this.weekRangeText,
    required this.weekDays,
    required this.timeSlotsByDay,
    required this.timeGrid,
    required this.appointmentsBySlot,
    required this.statusColors,
    required this.workingPreferences,
    required this.hasTimeSlots,
    required this.hasUserPack,
  });

  factory WeeklyCalendarData.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final str = value.toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    final weekDays = (json['week_days'] as List? ?? [])
        .map((e) => WeekDayInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final slotsMap = <String, List<SlotInfo>>{};
    final rawSlotsAny = json['time_slots_by_day'];
    if (rawSlotsAny is Map) {
      rawSlotsAny.forEach((key, value) {
        if (value is List) {
          slotsMap[key.toString()] = value
              .map((e) => SlotInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          slotsMap[key.toString()] = const <SlotInfo>[];
        }
      });
    }
    final appointmentsBySlot = <String, List<Map<String, dynamic>>>{};
    final rawApptsAny = json['appointments_by_slot'];
    if (rawApptsAny is Map) {
      rawApptsAny.forEach((key, value) {
        if (value is List) {
          appointmentsBySlot[key.toString()] = value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    }

    DateTime parseDate(String v) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return DateTime.now();
      }
    }

    final statusColorsMap = <String, String>{};
    final rawColors = json['status_colors'];
    if (rawColors is Map) {
      rawColors.forEach((k, v) {
        statusColorsMap[k.toString()] = v?.toString() ?? '';
      });
    }
    final timeGrid = (json['time_grid'] as List? ?? [])
        .map((e) => e?.toString() ?? '')
        .toList();

    final rawTimeSlot = json['time_slot'];
    bool hasTimeSlots = parseBool(rawTimeSlot, defaultValue: true);
    bool? hasUserPack;
    final rawUserPack = json['user_pack'] ?? json['userPack'];
    if (rawUserPack != null) {
      hasUserPack = parseBool(rawUserPack);
    }

    // Eğer API boş zaman aralığı haritası döndüyse uyarıyı göster
    final hasAnySlot = slotsMap.values.any((slots) => slots.isNotEmpty);
    if (!hasAnySlot || timeGrid.isEmpty) {
      hasTimeSlots = false;
    }

    return WeeklyCalendarData(
      weekStart: parseDate(json['week_start_date']?.toString() ?? ''),
      weekEnd: parseDate(json['week_end_date']?.toString() ?? ''),
      weekRangeText: json['week_range_text']?.toString() ?? '',
      weekDays: weekDays,
      timeSlotsByDay: slotsMap,
      timeGrid: timeGrid,
      appointmentsBySlot: appointmentsBySlot,
      statusColors: statusColorsMap,
      workingPreferences: json['working_preferences'] is Map
          ? Map<String, dynamic>.from(json['working_preferences'])
          : <String, dynamic>{},
      hasTimeSlots: hasTimeSlots,
      hasUserPack: hasUserPack,
    );
  }
}

final weeklyCalendarProvider =
    FutureProvider.autoDispose.family<WeeklyCalendarData, DateTime>(
  (ref, weekStart) async {
    Dio dio;
    try {
      dio = await _buildAuthedDio();
    } on AuthRequiredException {
      throw Exception('Oturum bulunamadı.');
    }

    final weekStartStr =
        '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    Response resp;
    try {
      resp = await dio.get(
        '/api/appointments/weekly',
        queryParameters: {'week_start_date': weekStartStr},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ??
              e.response?.data['error']?.toString())
          : null;
      throw Exception(
          'Haftalık takvim alınamadı${status != null ? ' (HTTP $status)' : ''}${msg != null ? ': $msg' : ''}');
    }

    if (resp.statusCode == 401) {
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        message: 'unauthorized',
      );
    }

    if (resp.statusCode != 200) {
      throw Exception(
          'Haftalık takvim alınamadı (HTTP ${resp.statusCode ?? '??'}).');
    }

    final data = resp.data is Map
        ? resp.data
        : (resp.data is String ? jsonDecode(resp.data) : {});
    final payload = data['data'] ?? data;
    if (payload is! Map) {
      throw Exception('Beklenmedik yanıt formatı.');
    }
    return WeeklyCalendarData.fromJson(Map<String, dynamic>.from(payload));
  },
);

class CalendarPage extends ConsumerStatefulWidget {
  final bool showBottomNav;
  final ValueChanged<int>? onTabSelected;

  const CalendarPage({
    super.key,
    this.showBottomNav = true,
    this.onTabSelected,
  });

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _weekStart;
  String? _lastErrorMessage;
  String? _expandedDayDate;
  String? _autoFocusedWeekKey;
  String? _autoExpandedWeekKey;
  final Map<String, GlobalKey> _daySectionKeys = {};
  bool _slotActionBusy = false;
  int? _cachedDefaultStatusId;
  String? _appointmentsLookupCacheKey;
  Map<String, List<Map<String, dynamic>>> _appointmentsLookupCache =
      const <String, List<Map<String, dynamic>>>{};
  static final RegExp _timeKeyPattern = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$');
  static const Color _primaryColor = Color(0xFF6366F1);
  bool? _hasUserPack;

  AppLocalizations get loc => AppLocalizations.of(context);
  bool get _isIosPaymentRestricted =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().trim().toLowerCase();
    return str == '1' || str == 'true' || str == 'yes';
  }

  _ApiEnvelope _parseEnvelope(
    dynamic body, {
    int statusCode = 200,
  }) {
    Map<String, dynamic> payload = <String, dynamic>{};
    if (body is Map) {
      payload = Map<String, dynamic>.from(body);
    } else if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        } else {
          payload = <String, dynamic>{'data': decoded};
        }
      } catch (_) {
        payload = <String, dynamic>{'message': body};
      }
    } else {
      payload = <String, dynamic>{'data': body};
    }

    final rawErrors = payload['errors'];
    final rawMeta = payload['meta'];
    return _ApiEnvelope(
      statusCode: statusCode,
      payload: payload,
      code: payload['code']?.toString(),
      message: payload['message']?.toString(),
      type: payload['type']?.toString(),
      data: payload.containsKey('data') ? payload['data'] : payload,
      meta: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null,
      errors: rawErrors is Map ? Map<String, dynamic>.from(rawErrors) : null,
    );
  }

  String? _firstFieldError(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) return null;
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) return first.first?.toString();
    return first?.toString();
  }

  String _holidayWarningMessage(_ApiEnvelope envelope) {
    final holiday = envelope.meta?['holiday'] ??
        (envelope.data is Map ? envelope.data['holiday'] : null) ??
        envelope.payload['holiday'];
    if (holiday is Map) {
      final msg = holiday['message']?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg;
      final name = holiday['name']?.toString() ?? '';
      final date = holiday['date']?.toString() ?? '';
      final joined = [name, date].where((e) => e.isNotEmpty).join(' - ');
      if (joined.isNotEmpty) return joined;
    } else if (holiday != null && holiday.toString().trim().isNotEmpty) {
      return holiday.toString();
    }
    return envelope.message?.trim().isNotEmpty == true
        ? envelope.message!
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

  Future<bool> _handleIssueByCode(
    _ApiEnvelope envelope, {
    bool allowPackageNavigation = true,
    bool firstAppointmentFlow = false,
    VoidCallback? onSlotBusy,
  }) async {
    final code = _normalizedIssueCode(envelope);
    if (code.isEmpty &&
        envelope.statusCode >= 200 &&
        envelope.statusCode < 300) {
      return false;
    }
    switch (code) {
      case 'NO_PACKAGE':
        _hasUserPack = false;
        _showSnack(
          _isIosPaymentRestricted
              ? loc.iosSmsPurchaseRestrictionMessage
              : loc.appointmentsPackageRequired,
        );
        if (!_isIosPaymentRestricted && allowPackageNavigation && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmsPacksPage()),
          );
        }
        return true;
      case 'HOLIDAY':
        _showSnack(_holidayWarningMessage(envelope));
        return true;
      case 'SLOT_BUSY':
        onSlotBusy?.call();
        final message = envelope.message?.trim();
        _showSnack(
          message != null && message.isNotEmpty
              ? message
              : (firstAppointmentFlow
                  ? loc.appointmentsConsecutiveSlotsUnavailable
                  : loc.calendarSlotBusy),
        );
        return true;
      case 'VALIDATION_ERROR':
        _showSnack(
          _firstFieldError(envelope.errors) ??
              envelope.message ??
              loc.calendarDateTimeRequired,
        );
        return true;
      case 'UNAUTHORIZED':
        _showSnack(loc.calendarSessionExpired);
        await _redirectToLogin();
        return true;
      case 'FORBIDDEN':
        _showSnack(loc.commonForbiddenAction);
        return true;
      default:
        if (envelope.statusCode == 401) {
          _showSnack(loc.calendarSessionExpired);
          await _redirectToLogin();
          return true;
        }
        if (envelope.statusCode == 403) {
          _showSnack(loc.commonForbiddenAction);
          return true;
        }
        return false;
    }
  }

  String _issueMessageForCode(
    _ApiEnvelope envelope, {
    bool firstAppointmentFlow = false,
    String? fallback,
  }) {
    final code = _normalizedIssueCode(envelope);
    switch (code) {
      case 'NO_PACKAGE':
        return _isIosPaymentRestricted
            ? loc.iosSmsPurchaseRestrictionMessage
            : loc.appointmentsPackageRequired;
      case 'HOLIDAY':
        return _holidayWarningMessage(envelope);
      case 'SLOT_BUSY':
        final msg = envelope.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return firstAppointmentFlow
            ? loc.appointmentsConsecutiveSlotsUnavailable
            : loc.calendarSlotBusy;
      case 'VALIDATION_ERROR':
        return _firstFieldError(envelope.errors) ??
            envelope.message ??
            fallback ??
            loc.calendarDateTimeRequired;
      case 'UNAUTHORIZED':
        return loc.calendarSessionExpired;
      case 'FORBIDDEN':
        return loc.commonForbiddenAction;
      default:
        return envelope.message ??
            _firstFieldError(envelope.errors) ??
            fallback ??
            loc.calendarFetchFailed('');
    }
  }

  String _normalizedIssueCode(_ApiEnvelope envelope) {
    final rawCode = (envelope.code ?? '').toUpperCase().trim();
    if (rawCode.isNotEmpty) return rawCode;

    if (envelope.statusCode == 409) return 'SLOT_BUSY';
    if (envelope.statusCode == 422) return 'VALIDATION_ERROR';
    if (envelope.statusCode == 401) return 'UNAUTHORIZED';
    if (envelope.statusCode == 403) {
      final msg = (envelope.message ?? '').toLowerCase();
      if (msg.contains('package')) return 'NO_PACKAGE';
      return 'FORBIDDEN';
    }
    return '';
  }

  String? _normalizeTimeToApi(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final reg = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$');
    final m = reg.firstMatch(trimmed);
    if (m == null) return null;
    return '${m.group(1)}:${m.group(2)}';
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
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

  Future<bool> _ensurePackageForAppointmentActions() async {
    _hasUserPack = await _fetchUserPackStatus();
    if (_hasUserPack == true) return true;
    if (!mounted) return false;

    final navigateToPackagePage = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.appointmentsBuyPackage),
            content: Text(
              _isIosPaymentRestricted
                  ? loc.iosSmsPurchaseRestrictionMessage
                  : loc.appointmentsPackageRequired,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(loc.appointmentsClose),
              ),
              if (!_isIosPaymentRestricted)
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(loc.appointmentsBuyPackage),
                ),
            ],
          ),
        ) ??
        false;

    if (navigateToPackagePage && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SmsPacksPage()),
      );
    }
    return false;
  }

  Future<bool> _fetchUserPackStatus() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return true;
    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/appointments')
            .replace(queryParameters: {'per_page': '1'}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final envelope = _parseEnvelope(
        response.body,
        statusCode: response.statusCode,
      );
      final code = (envelope.code ?? '').toUpperCase();
      if (code == 'NO_PACKAGE') return false;
      if (code == 'UNAUTHORIZED' || response.statusCode == 401) {
        await _redirectToLogin();
        return false;
      }
      if (!envelope.isSuccess) return true;

      final rawData = envelope.data;
      dynamic candidate;
      candidate = envelope.payload['user_pack'] ?? envelope.payload['userPack'];
      if (candidate == null && rawData is Map) {
        candidate = rawData['user_pack'] ?? rawData['userPack'];
      }
      if (candidate == null) return true;
      return _asBool(candidate);
    } catch (_) {
      return true;
    }
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _expandedDayDate = null;
      _autoFocusedWeekKey = null;
      _autoExpandedWeekKey = null;
      _daySectionKeys.clear();
    });
  }

  void _setWeekStartFromDate(DateTime date) {
    setState(() {
      _weekStart = _startOfWeek(date);
      _expandedDayDate = null;
      _autoFocusedWeekKey = null;
      _autoExpandedWeekKey = null;
      _daySectionKeys.clear();
    });
  }

  Future<void> _pickWeekFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDatePickerMode: DatePickerMode.day,
    );
    if (picked == null) return;
    _setWeekStartFromDate(picked);
  }

  String _toIsoDate(DateTime dt) {
    return AppointmentDateUtils.toIsoDate(dt);
  }

  String _formatDateDisplay(DateTime date) {
    return AppointmentDateUtils.formatDateDisplay(date);
  }

  DateTime _parseInputDateOrNow(String value) {
    return AppointmentDateUtils.parseInputDateOrNow(value);
  }

  String _normalizeSlotDate(String rawDate) {
    return AppointmentDateUtils.normalizeSlotDate(rawDate);
  }

  DateTime _clampDate(DateTime date, DateTime min, DateTime max) {
    if (date.isBefore(min)) return min;
    if (date.isAfter(max)) return max;
    return date;
  }

  String? _normalizeDateToApi(String input) {
    return AppointmentDateUtils.normalizeDateToApi(input);
  }

  String _weekIdentity(WeeklyCalendarData data) => _toIsoDate(data.weekStart);

  void _syncExpandedDayAndFocus(WeeklyCalendarData data) {
    if (data.weekDays.isEmpty) return;

    final weekKey = _weekIdentity(data);
    final dates = data.weekDays.map((d) => d.date).toSet();
    final hasValidExpanded =
        _expandedDayDate != null && dates.contains(_expandedDayDate);

    String? selected = hasValidExpanded ? _expandedDayDate : null;
    if (!hasValidExpanded && _autoExpandedWeekKey != weekKey) {
      final todayIso = _toIsoDate(DateTime.now());
      selected = dates.contains(todayIso) ? todayIso : data.weekDays.first.date;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _expandedDayDate = selected;
          _autoExpandedWeekKey = weekKey;
        });
      });
    }

    if (_autoFocusedWeekKey == weekKey) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || selected == null) return;
      final targetKey = _daySectionKeys[selected];
      final targetContext = targetKey?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
      _autoFocusedWeekKey = weekKey;
    });
  }

  String? _nearestUpcomingSlotTime(
    List<SlotInfo> slots,
    String dayIso, {
    String? currentTime,
  }) {
    if (slots.isEmpty) return null;
    final todayIso = _toIsoDate(DateTime.now());
    if (dayIso != todayIso) return null;
    final now = currentTime ?? DateFormat('HH:mm').format(DateTime.now());
    for (final slot in slots) {
      if (slot.time.compareTo(now) >= 0) return slot.time;
    }
    return slots.first.time;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  int? _resolveStatusId(Map<String, dynamic> appointment) {
    final topLevel = _asInt(appointment['appointment_status_id']);
    if (topLevel != null) return topLevel;
    if (appointment['appointment_status'] is Map) {
      return _asInt((appointment['appointment_status'] as Map)['id']);
    }
    return null;
  }

  String _localizedStatusLabel(Map<String, dynamic> status) {
    final alias = status['alias']?.toString();
    final trMap = {
      'pending': loc.statusPending,
      'confirmed': loc.statusConfirmed,
      'rescheduled': loc.statusRescheduled,
      'completed': loc.statusCompleted,
      'cancelled': loc.statusCancelled,
      'no_show': loc.statusNoShow,
    };
    if (alias != null && trMap.containsKey(alias)) {
      return trMap[alias]!;
    }
    return status['name']?.toString() ?? (alias ?? loc.status);
  }

  Future<void> _refreshWeek() async {
    final refreshFuture =
        ref.refresh(weeklyCalendarProvider(_weekStart).future);
    await refreshFuture;
  }

  InputDecoration _modalInputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 1.2),
      ),
    );
  }

  Future<int?> _resolveDefaultStatusId() async {
    if (_cachedDefaultStatusId != null) return _cachedDefaultStatusId;
    Dio dio;
    try {
      dio = await _buildAuthedDio();
    } on AuthRequiredException {
      return null;
    }

    try {
      final resp = await dio.get('/api/settings/appointment-statuses');
      final raw = resp.data is Map
          ? ((resp.data as Map)['data'] ?? resp.data)
          : resp.data;
      if (raw is! List) return null;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (list.isEmpty) return null;

      int? parseId(Map<String, dynamic> s) {
        final id = s['id'];
        if (id is int) return id;
        return int.tryParse(id?.toString() ?? '');
      }

      for (final s in list) {
        final alias = s['alias']?.toString().toLowerCase();
        final id = parseId(s);
        if (alias == 'pending' && id != null) {
          _cachedDefaultStatusId = id;
          return id;
        }
      }
      final fallback = parseId(list.first);
      _cachedDefaultStatusId = fallback;
      return fallback;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _showCustomerPickerSheet() async {
    Dio dio;
    try {
      dio = await _buildAuthedDio();
    } on AuthRequiredException {
      _showSnack(loc.calendarSessionMissing);
      return null;
    }
    if (!mounted) return null;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.9;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: maxSheetHeight,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        const letters = [
          '#',
          'A',
          'B',
          'C',
          'Ç',
          'D',
          'E',
          'F',
          'G',
          'Ğ',
          'H',
          'I',
          'İ',
          'J',
          'K',
          'L',
          'M',
          'N',
          'O',
          'Ö',
          'P',
          'R',
          'S',
          'Ş',
          'T',
          'U',
          'Ü',
          'V',
          'Y',
          'Z',
        ];
        List<Map<String, dynamic>> customers = [];
        bool loading = false;
        String? error;
        int page = 1;
        int lastPage = 1;
        String selectedLetter = '#';
        bool initialized = false;

        Future<void> load(StateSetter setModalState,
            {bool reset = false}) async {
          if (reset) {
            page = 1;
            lastPage = 1;
            customers = [];
          } else if (page > lastPage) {
            return;
          }

          setModalState(() {
            loading = true;
            error = null;
          });

          try {
            final resp = await dio.get(
              '/api/customers',
              queryParameters: {
                'search': searchCtrl.text.trim(),
                if (selectedLetter != '#') 'starts_with': selectedLetter,
                'sort_field': 'name',
                'sort_direction': 'asc',
                'per_page': 30,
                'page': page,
              },
            );
            final body = resp.data;
            final data = body is Map ? (body['data'] ?? const []) : const [];
            final meta = body is Map && body['meta'] is Map
                ? Map<String, dynamic>.from(body['meta'] as Map)
                : <String, dynamic>{};
            final fetched = data is List
                ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : <Map<String, dynamic>>[];

            setModalState(() {
              customers.addAll(fetched);
              page = (meta['current_page'] as int?) != null
                  ? (meta['current_page'] as int) + 1
                  : page + 1;
              lastPage = (meta['last_page'] as int?) ?? 1;
              loading = false;
            });
          } catch (e) {
            setModalState(() {
              loading = false;
              error = e.toString();
            });
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!initialized) {
              initialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                load(setModalState, reset: true);
              });
            }

            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom + 12;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        loc.calendarGuideTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    decoration: _modalInputDecoration(
                      labelText: loc.calendarPerson,
                      hintText: loc.customersSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => load(setModalState, reset: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    onSubmitted: (_) => load(setModalState, reset: true),
                    onChanged: (_) => load(setModalState, reset: true),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            children: letters.map((letter) {
                              final active = selectedLetter == letter;
                              return InkWell(
                                onTap: () {
                                  if (selectedLetter == letter) return;
                                  setModalState(() {
                                    selectedLetter = letter;
                                  });
                                  load(setModalState, reset: true);
                                },
                                child: Container(
                                  height: 20,
                                  alignment: Alignment.center,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 1),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? _primaryColor.withValues(alpha: 0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active
                                          ? _primaryColor
                                          : Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          child: loading && customers.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : error != null
                                  ? Center(
                                      child: Text(
                                        error!,
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: customers.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == customers.length) {
                                          if (page > lastPage) {
                                            return const SizedBox(height: 12);
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: OutlinedButton(
                                              onPressed: loading
                                                  ? null
                                                  : () => load(setModalState),
                                              child: loading
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(loc.customersLoadMore),
                                            ),
                                          );
                                        }
                                        final c = customers[index];
                                        final name =
                                            c['name']?.toString().trim() ?? '-';
                                        final lastname =
                                            c['lastname']?.toString().trim() ??
                                                '';
                                        final phone =
                                            c['phone']?.toString().trim() ?? '';
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: ListTile(
                                            title: Text(
                                              '$name $lastname'.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: phone.isEmpty
                                                ? null
                                                : Text(phone),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                              size: 18,
                                            ),
                                            onTap: () =>
                                                Navigator.of(ctx).pop(c),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateSlotSheet({
    required String initialDate,
    required String initialTime,
  }) async {
    if (!await _ensurePackageForAppointmentActions()) return;

    final dateCtrl = TextEditingController(
      text: _formatDateDisplay(_parseInputDateOrNow(initialDate)),
    );
    final timeCtrl = TextEditingController(text: initialTime);
    final notesCtrl = TextEditingController();
    final newNameCtrl = TextEditingController();
    final newLastNameCtrl = TextEditingController();
    final newPhoneCtrl = TextEditingController();
    final newEmailCtrl = TextEditingController();
    final phoneMaskFormatter = _PhoneMaskFormatter();
    String? selectedTime = initialTime;
    Map<String, dynamic>? selectedCustomer;
    bool createForNewCustomer = false;
    bool localNoSms = false;
    bool localNoReminder = false;
    bool localIsFirstAppointment = false;
    List<Map<String, dynamic>> localSlots = [];
    List<Map<String, dynamic>> localCountries = [];
    int? localSelectedCountryId;
    bool localLoadingSlots = false;
    bool localLoadingCountries = false;
    String? localSlotsError;
    String? localCountriesError;
    String? localSaveError;
    bool countriesInitialized = false;
    // ── Design tokens ────────────────────────────────────────────────────────
    const bg = Color(0xFFF9F9F9);
    const surface = Colors.white;
    const accent = Color(0xFF111111);
    const muted = Color(0xFF8A8A8A);
    const border = Color(0xFFE8E8E8);
    const success = Color(0xFF18A058);
    const danger = Color(0xFFE53935);
    const radius = 14.0;

    InputDecoration field({
      required String label,
      String? hint,
      Widget? prefix,
    }) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefix,
          labelStyle: const TextStyle(fontSize: 13, color: muted),
          hintStyle: const TextStyle(fontSize: 13, color: muted),
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: bg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.96,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> loadSlots() async {
              final rawDate = dateCtrl.text.trim();
              if (rawDate.isEmpty) {
                _showSnack(loc.calendarSelectDateFirst);
                return;
              }
              final date = _normalizeSlotDate(rawDate);
              setModalState(() {
                localLoadingSlots = true;
                localSlotsError = null;
                localSlots = [];
              });
              try {
                final dio = await _buildAuthedDio();
                final resp = await dio.get(
                  '/api/appointments/time-slots',
                  queryParameters: {'date': date},
                );
                final envelope = _parseEnvelope(
                  resp.data,
                  statusCode: resp.statusCode ?? 200,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                );
                if (handled) {
                  setModalState(() {
                    localLoadingSlots = false;
                    localSlotsError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                  return;
                }
                if (envelope.isSuccess) {
                  final raw = envelope.data;
                  final slots = raw is List
                      ? raw
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList()
                      : <Map<String, dynamic>>[];
                  setModalState(() {
                    localSlots = slots;
                    localLoadingSlots = false;
                    localSlotsError = null;
                    final hasSelected = localSlots.any(
                        (s) => (s['time']?.toString() ?? '') == selectedTime);
                    if (!hasSelected) {
                      selectedTime = null;
                      timeCtrl.clear();
                    }
                  });
                } else {
                  setModalState(() {
                    localLoadingSlots = false;
                    localSlotsError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                }
              } on AuthRequiredException {
                setModalState(() {
                  localLoadingSlots = false;
                  localSlotsError = loc.calendarSessionMissing;
                });
              } catch (e) {
                setModalState(() {
                  localLoadingSlots = false;
                  localSlotsError = loc.calendarFetchFailed(e.toString());
                });
              }
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final minDate = DateTime(now.year, now.month, now.day);
              final maxDate = DateTime(now.year + 5, 12, 31);
              final initial = _clampDate(
                _parseInputDateOrNow(dateCtrl.text.trim()),
                minDate,
                maxDate,
              );
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: minDate,
                lastDate: maxDate,
              );
              if (picked == null) return;
              setModalState(() {
                dateCtrl.text = _formatDateDisplay(picked);
                localSlots = [];
                localSlotsError = null;
                selectedTime = null;
                timeCtrl.clear();
              });
              await loadSlots();
            }

            Future<void> pickCustomer() async {
              final picked = await _showCustomerPickerSheet();
              if (picked == null) return;
              setModalState(() => selectedCustomer = picked);
              final customerId = _asInt(picked['id']);
              if (customerId == null) return;
              try {
                final dio = await _buildAuthedDio();
                final resp = await dio
                    .get('/api/customers/$customerId/appointment-defaults');
                final envelope = _parseEnvelope(
                  resp.data,
                  statusCode: resp.statusCode ?? 200,
                );
                if (!envelope.isSuccess) {
                  await _handleIssueByCode(
                    envelope,
                    allowPackageNavigation: false,
                  );
                  return;
                }
                final raw = envelope.data;
                if (raw is Map) {
                  setModalState(() {
                    if ((raw['last_note']?.toString().trim() ?? '')
                        .isNotEmpty) {
                      notesCtrl.text = raw['last_note'].toString();
                    }
                    localNoSms = raw['default_no_sms'] == true ||
                        raw['default_no_sms'] == 1;
                    localNoReminder = raw['default_no_reminder'] == true ||
                        raw['default_no_reminder'] == 1;
                  });
                }
              } catch (_) {}
            }

            Future<void> loadCountries() async {
              setModalState(() {
                localLoadingCountries = true;
                localCountriesError = null;
              });
              try {
                final dio = await _buildAuthedDio();
                final resp = await dio.get('/api/settings/countries');
                final envelope = _parseEnvelope(
                  resp.data,
                  statusCode: resp.statusCode ?? 200,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                );
                if (handled) {
                  setModalState(() {
                    localLoadingCountries = false;
                    localCountriesError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                  return;
                }
                final raw = envelope.data;
                final countries = raw is List
                    ? raw
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList()
                    : <Map<String, dynamic>>[];
                setModalState(() {
                  localCountries = countries;
                  localLoadingCountries = false;
                  localCountriesError = null;
                  if (localSelectedCountryId == null && countries.isNotEmpty) {
                    localSelectedCountryId = _asInt(countries.first['id']);
                  }
                });
              } on AuthRequiredException {
                setModalState(() {
                  localLoadingCountries = false;
                  localCountriesError = loc.calendarSessionMissing;
                });
              } catch (e) {
                setModalState(() {
                  localLoadingCountries = false;
                  localCountriesError = loc.calendarFetchFailed(e.toString());
                });
              }
            }

            Future<void> submit() async {
              if (_slotActionBusy) return;
              setModalState(() => localSaveError = null);
              final token = await _getToken();
              if (token == null || token.isEmpty) {
                setModalState(
                    () => localSaveError = loc.calendarSessionMissing);
                return;
              }
              final dateInput = dateCtrl.text.trim();
              final createDate = _normalizeSlotDate(dateInput);
              final time =
                  _normalizeTimeToApi(selectedTime ?? timeCtrl.text) ?? '';
              if (createDate.isEmpty || time.isEmpty) {
                setModalState(
                    () => localSaveError = loc.calendarDateTimeRequired);
                return;
              }
              setState(() => _slotActionBusy = true);
              try {
                final dio = await _buildAuthedDio(includeJsonContentType: true);
                if (createForNewCustomer) {
                  final firstName = newNameCtrl.text.trim();
                  final lastName = newLastNameCtrl.text.trim();
                  final phone = newPhoneCtrl.text.trim();
                  final email = newEmailCtrl.text.trim();
                  if (firstName.isEmpty ||
                      lastName.isEmpty ||
                      phone.isEmpty ||
                      localSelectedCountryId == null) {
                    setModalState(
                        () => localSaveError = loc.appointmentsRequiredFields);
                    return;
                  }
                  final quickResp = await dio
                      .post('/api/appointments/quick_appointment', data: {
                    'customer_name': firstName,
                    'customer_lastname': lastName,
                    'country_id': localSelectedCountryId,
                    'phone': phone,
                    'email': email.isEmpty ? null : email,
                    'date': createDate,
                    'time': time,
                    'note': notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                    'is_first_appointment': localIsFirstAppointment,
                    'no_sms': localNoSms,
                    'no_reminder': localNoReminder,
                  });
                  final quickEnvelope = _parseEnvelope(
                    quickResp.data,
                    statusCode: quickResp.statusCode ?? 200,
                  );
                  if (!quickEnvelope.isSuccess) {
                    final handled = await _handleIssueByCode(
                      quickEnvelope,
                      allowPackageNavigation: false,
                      firstAppointmentFlow: localIsFirstAppointment,
                      onSlotBusy: () {
                        setModalState(() {
                          selectedTime = null;
                          timeCtrl.clear();
                        });
                      },
                    );
                    if (!handled) {
                      setModalState(() {
                        localSaveError = _issueMessageForCode(
                          quickEnvelope,
                          firstAppointmentFlow: localIsFirstAppointment,
                          fallback: loc.calendarCreateFailed,
                        );
                      });
                    }
                    return;
                  }
                } else {
                  final customerId = _asInt(selectedCustomer?['id']);
                  if (customerId == null) {
                    setModalState(
                        () => localSaveError = loc.calendarSelectPerson);
                    return;
                  }
                  final defaultStatusId = await _resolveDefaultStatusId();
                  if (defaultStatusId == null) {
                    setModalState(
                        () => localSaveError = loc.appointmentsStatusMissing);
                    return;
                  }
                  try {
                    final validateResp = await dio.post(
                      '/api/appointments/validate',
                      data: {
                        'customer_id': customerId,
                        'date': createDate,
                        'time': time,
                      },
                    );
                    final validateEnvelope = _parseEnvelope(
                      validateResp.data,
                      statusCode: validateResp.statusCode ?? 200,
                    );
                    if (!validateEnvelope.isSuccess) {
                      final handled = await _handleIssueByCode(
                        validateEnvelope,
                        allowPackageNavigation: false,
                        firstAppointmentFlow: localIsFirstAppointment,
                        onSlotBusy: () {
                          setModalState(() {
                            selectedTime = null;
                            timeCtrl.clear();
                          });
                        },
                      );
                      if (!handled) {
                        setModalState(() {
                          localSaveError = _issueMessageForCode(
                            validateEnvelope,
                            firstAppointmentFlow: localIsFirstAppointment,
                            fallback: loc.calendarDateTimeRequired,
                          );
                        });
                      } else if (_normalizedIssueCode(validateEnvelope) ==
                          'SLOT_BUSY') {
                        setModalState(() {
                          localSaveError = localIsFirstAppointment
                              ? loc.appointmentsConsecutiveSlotsUnavailable
                              : loc.calendarSlotBusy;
                        });
                      } else {
                        setModalState(() {
                          localSaveError = _issueMessageForCode(
                            validateEnvelope,
                            firstAppointmentFlow: localIsFirstAppointment,
                            fallback: loc.calendarDateTimeRequired,
                          );
                        });
                      }
                      return;
                    }
                  } on DioException catch (e) {
                    final envelope = _parseEnvelope(
                      e.response?.data,
                      statusCode: e.response?.statusCode ?? 0,
                    );
                    final handled = await _handleIssueByCode(
                      envelope,
                      allowPackageNavigation: false,
                      firstAppointmentFlow: localIsFirstAppointment,
                      onSlotBusy: () {
                        setModalState(() {
                          selectedTime = null;
                          timeCtrl.clear();
                        });
                      },
                    );
                    if (!handled) {
                      setModalState(() {
                        localSaveError = _issueMessageForCode(
                          envelope,
                          firstAppointmentFlow: localIsFirstAppointment,
                          fallback: loc.calendarSlotBusy,
                        );
                      });
                    }
                    return;
                  }
                  final createResp = await dio.post('/api/appointments', data: {
                    'customer_id': customerId,
                    'appointment_status_id': defaultStatusId,
                    'date': createDate,
                    'time': time,
                    'notes': notesCtrl.text.trim(),
                    'is_first_appointment': localIsFirstAppointment,
                    'no_sms': localNoSms,
                    'no_reminder': localNoReminder,
                  });
                  final createEnvelope = _parseEnvelope(
                    createResp.data,
                    statusCode: createResp.statusCode ?? 200,
                  );
                  if (!createEnvelope.isSuccess) {
                    await _handleIssueByCode(
                      createEnvelope,
                      allowPackageNavigation: false,
                      firstAppointmentFlow: localIsFirstAppointment,
                    );
                    setModalState(() {
                      localSaveError = _issueMessageForCode(
                        createEnvelope,
                        firstAppointmentFlow: localIsFirstAppointment,
                        fallback: loc.calendarCreateFailed,
                      );
                    });
                    return;
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                _showSnack(loc.calendarCreateSuccess, success: true);
                await _refreshWeek();
              } on DioException catch (e) {
                final envelope = _parseEnvelope(
                  e.response?.data,
                  statusCode: e.response?.statusCode ?? 0,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                  firstAppointmentFlow: localIsFirstAppointment,
                );
                final msg = _issueMessageForCode(
                  envelope,
                  firstAppointmentFlow: localIsFirstAppointment,
                  fallback: loc.calendarCreateFailed,
                );
                if (handled && msg.isNotEmpty) {
                  setModalState(() => localSaveError = msg);
                  return;
                }
                setModalState(() {
                  localSaveError = msg;
                });
              } finally {
                if (mounted) setState(() => _slotActionBusy = false);
              }
            }

            if (createForNewCustomer && !countriesInitialized) {
              countriesInitialized = true;
              Future.microtask(loadCountries);
            }

            final media = MediaQuery.of(ctx);
            final bottomInset =
                media.viewInsets.bottom + media.viewPadding.bottom + 24;
            final selectedCustomerName = selectedCustomer == null
                ? ''
                : '${selectedCustomer!['name'] ?? ''} ${selectedCustomer!['lastname'] ?? ''}'
                    .trim();

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.calendarAddAppointment,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: accent,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: loc.appointmentsClose,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SectionLabel(text: loc.calendarPerson),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          _TabButton(
                            label: loc.calendarExistingPerson,
                            selected: !createForNewCustomer,
                            onTap: () => setModalState(() {
                              createForNewCustomer = false;
                            }),
                          ),
                          _TabButton(
                            label: loc.calendarNewPerson,
                            selected: createForNewCustomer,
                            onTap: () => setModalState(() {
                              createForNewCustomer = true;
                              selectedCustomer = null;
                              if (!countriesInitialized) {
                                countriesInitialized = true;
                                Future.microtask(loadCountries);
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!createForNewCustomer) ...[
                      GestureDetector(
                        onTap: pickCustomer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 18, color: muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedCustomerName.isEmpty
                                      ? loc.calendarSelectPerson
                                      : selectedCustomerName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selectedCustomerName.isEmpty
                                        ? muted
                                        : accent,
                                    fontWeight: selectedCustomerName.isEmpty
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: muted),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newNameCtrl,
                              decoration: field(
                                label: loc.appointmentsFieldName,
                                hint: loc.appointmentsFieldNameHint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: newLastNameCtrl,
                              decoration: field(
                                label: loc.appointmentsFieldLastName,
                                hint: loc.appointmentsFieldLastNameHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: localCountries.any((c) =>
                                _asInt(c['id']) == localSelectedCountryId)
                            ? localSelectedCountryId
                            : null,
                        isExpanded: true,
                        decoration: field(
                          label: loc.appointmentsCountry,
                          hint: localLoadingCountries
                              ? loc.calendarLoading
                              : loc.appointmentsSelectCountry,
                          prefix: const Icon(Icons.public, size: 18),
                        ),
                        items: localCountries
                            .map((c) {
                              final id = _asInt(c['id']);
                              if (id == null) return null;
                              final name =
                                  (c['name']?.toString().trim().isNotEmpty ==
                                          true)
                                      ? c['name'].toString()
                                      : id.toString();
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(name),
                              );
                            })
                            .whereType<DropdownMenuItem<int>>()
                            .toList(),
                        onChanged: localLoadingCountries
                            ? null
                            : (value) => setModalState(() {
                                  localSelectedCountryId = value;
                                  localCountriesError = null;
                                }),
                      ),
                      if (localCountriesError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          localCountriesError!,
                          style: const TextStyle(fontSize: 12, color: danger),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: newPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9() ]')),
                          phoneMaskFormatter,
                        ],
                        decoration: field(
                          label: loc.appointmentsFieldPhone,
                          hint: '(555) 545 4444',
                          prefix: const Icon(Icons.phone_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: newEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: field(
                          label: loc.customersEmail,
                          hint: loc.appointmentsFieldEmailHint,
                          prefix: const Icon(Icons.mail_outline, size: 18),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 20),
                    _SectionLabel(text: loc.calendarDateTimeSection),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            onTap: pickDate,
                            decoration: field(
                              label: loc.date,
                              hint: loc.calendarDateHint,
                              prefix: const Icon(Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            readOnly: true,
                            decoration: field(
                              label: loc.timeSelect,
                              hint: loc.calendarTimeSlotHint,
                              prefix: const Icon(Icons.access_time, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: localLoadingSlots ? null : loadSlots,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: const BorderSide(color: border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: localLoadingSlots
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    loc.calendarFetchAvailableSlots,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (localSlotsError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: danger.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localSlotsError!,
                                style: const TextStyle(
                                    fontSize: 12, color: danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (localSlots.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: localSlots.map((slot) {
                          final slotTime = slot['time']?.toString() ?? '';
                          final booked =
                              slot['booked'] == true || slot['booked'] == 1;
                          final selected = selectedTime == slotTime;
                          return GestureDetector(
                            onTap: booked
                                ? null
                                : () => setModalState(() {
                                      selectedTime = slotTime;
                                      timeCtrl.text = slotTime;
                                      localSlotsError = null;
                                    }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: booked
                                    ? const Color(0xFFF3F3F3)
                                    : selected
                                        ? success
                                        : surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: booked
                                      ? border
                                      : selected
                                          ? success
                                          : border,
                                ),
                              ),
                              child: Text(
                                slotTime,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: booked
                                      ? muted
                                      : selected
                                          ? Colors.white
                                          : accent,
                                  decoration: booked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 20),
                    _SectionLabel(text: loc.note),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: field(label: '', hint: loc.calendarNoteHint)
                          .copyWith(labelText: null),
                    ),
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 8),
                    _MinimalSwitch(
                      label: loc.appointmentsFirstAppointment,
                      value: localIsFirstAppointment,
                      onChanged: (v) =>
                          setModalState(() => localIsFirstAppointment = v),
                    ),
                    _MinimalSwitch(
                      label: loc.doNotSendSms,
                      value: localNoSms,
                      onChanged: (v) => setModalState(() => localNoSms = v),
                    ),
                    _MinimalSwitch(
                      label: loc.doNotSendReminder,
                      value: localNoReminder,
                      onChanged: (v) =>
                          setModalState(() => localNoReminder = v),
                    ),
                    if (localSaveError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: danger.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.error_outline,
                                size: 14,
                                color: danger,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localSaveError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _slotActionBusy ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black26,
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: _slotActionBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                loc.save,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSlotActionSheet({
    required Map<String, dynamic> appointment,
    required String initialDate,
    required String initialTime,
    required bool createNewForCustomer,
  }) async {
    if (!await _ensurePackageForAppointmentActions()) return;

    final appointmentId = _asInt(appointment['id']);
    final customerId = _asInt(appointment['customer_id']);
    final statusId = _resolveStatusId(appointment);
    if (customerId == null) {
      _showSnack(loc.calendarCustomerInfoMissing);
      return;
    }
    if (!createNewForCustomer && appointmentId == null) {
      _showSnack(loc.calendarAppointmentInfoMissing);
      return;
    }
    if (statusId == null) {
      _showSnack(loc.calendarAppointmentStatusMissing);
      return;
    }

    final parsedInitialDate = _parseInputDateOrNow(initialDate);
    final dateCtrl = TextEditingController(
      text: _formatDateDisplay(parsedInitialDate),
    );
    final timeCtrl = TextEditingController(text: initialTime);
    final notesCtrl =
        TextEditingController(text: appointment['notes']?.toString() ?? '');
    bool localNoSms =
        appointment['no_sms'] == true || appointment['no_sms'] == 1;
    bool localNoReminder =
        appointment['no_reminder'] == true || appointment['no_reminder'] == 1;
    int? localSelectedStatusId = statusId;
    List<Map<String, dynamic>> localStatuses = [];
    bool localLoadingStatuses = false;
    String? localStatusesError;
    bool statusesInitialized = false;
    List<Map<String, dynamic>> localSlots = [];
    bool localLoadingSlots = false;
    String? localSlotsError;
    String? localSelectedTime = initialTime;
    const bg = Color(0xFFF9F9F9);
    const surface = Colors.white;
    const accent = Color(0xFF111111);
    const muted = Color(0xFF8A8A8A);
    const border = Color(0xFFE8E8E8);
    const success = Color(0xFF18A058);
    const danger = Color(0xFFE53935);
    const radius = 14.0;

    InputDecoration field({
      required String label,
      String? hint,
      Widget? prefix,
    }) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefix,
          labelStyle: const TextStyle(fontSize: 13, color: muted),
          hintStyle: const TextStyle(fontSize: 13, color: muted),
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: bg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.96,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> loadSlots() async {
              final rawDate = dateCtrl.text.trim();
              if (rawDate.isEmpty) {
                _showSnack(loc.calendarSelectDateFirst);
                return;
              }
              final date = _normalizeSlotDate(rawDate);

              setModalState(() {
                localLoadingSlots = true;
                localSlotsError = null;
                localSlots = [];
              });

              try {
                final dio = await _buildAuthedDio();
                final resp = await dio.get(
                  '/api/appointments/time-slots',
                  queryParameters: {'date': date},
                );
                final envelope = _parseEnvelope(
                  resp.data,
                  statusCode: resp.statusCode ?? 200,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                );
                if (handled) {
                  setModalState(() {
                    localLoadingSlots = false;
                    localSlotsError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                  return;
                }
                if (envelope.isSuccess) {
                  final raw = envelope.data;
                  final slots = raw is List
                      ? raw
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList()
                      : <Map<String, dynamic>>[];

                  setModalState(() {
                    localSlots = slots;
                    localLoadingSlots = false;
                    localSlotsError = null;
                    final hasSelected = localSlots.any(
                      (s) => (s['time']?.toString() ?? '') == localSelectedTime,
                    );
                    if (!hasSelected) {
                      localSelectedTime = null;
                      timeCtrl.clear();
                    }
                  });
                } else {
                  setModalState(() {
                    localLoadingSlots = false;
                    localSlotsError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                }
              } on AuthRequiredException {
                setModalState(() {
                  localLoadingSlots = false;
                  localSlotsError = loc.calendarSessionMissing;
                });
              } on DioException catch (e) {
                final status = e.response?.statusCode;
                final msg = e.response?.data is Map
                    ? (e.response?.data['message']?.toString() ??
                        e.response?.data['error']?.toString())
                    : null;
                setModalState(() {
                  localLoadingSlots = false;
                  localSlotsError =
                      '${loc.calendarFetchFailedStatus(status ?? '??')}${msg != null ? ': $msg' : ''}';
                });
              } catch (e) {
                setModalState(() {
                  localLoadingSlots = false;
                  localSlotsError = loc.calendarFetchFailed(e.toString());
                });
              }
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final minDate = DateTime(now.year, now.month, now.day);
              final maxDate = DateTime(now.year + 5, 12, 31);
              final initial = _clampDate(
                _parseInputDateOrNow(dateCtrl.text.trim()),
                minDate,
                maxDate,
              );
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: minDate,
                lastDate: maxDate,
              );
              if (picked == null) return;
              setModalState(() {
                dateCtrl.text = _formatDateDisplay(picked);
                localSlots = [];
                localSlotsError = null;
                localSelectedTime = null;
                timeCtrl.clear();
              });
              await loadSlots();
            }

            Future<void> loadStatuses() async {
              setModalState(() {
                localLoadingStatuses = true;
                localStatusesError = null;
              });

              try {
                final dio = await _buildAuthedDio();
                final resp =
                    await dio.get('/api/settings/appointment-statuses');
                final envelope = _parseEnvelope(
                  resp.data,
                  statusCode: resp.statusCode ?? 200,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                );
                if (handled) {
                  setModalState(() {
                    localLoadingStatuses = false;
                    localStatusesError = _issueMessageForCode(
                      envelope,
                      fallback: loc.calendarFetchFailed(''),
                    );
                  });
                  return;
                }
                final raw = envelope.data;
                final fetched = raw is List
                    ? raw
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList()
                    : <Map<String, dynamic>>[];
                setModalState(() {
                  localStatuses = fetched;
                  localLoadingStatuses = false;
                  localStatusesError = null;
                  final hasSelected = localStatuses.any(
                    (s) => _asInt(s['id']) == localSelectedStatusId,
                  );
                  if (!hasSelected && localSelectedStatusId != null) {
                    localStatuses.insert(0, {
                      'id': localSelectedStatusId,
                      'alias': appointment['appointment_status']?['alias']
                          ?.toString(),
                      'name': appointment['appointment_status']?['name']
                              ?.toString() ??
                          loc.status,
                    });
                  }
                });
              } on DioException catch (e) {
                final status = e.response?.statusCode;
                final msg = e.response?.data is Map
                    ? (e.response?.data['message']?.toString() ??
                        e.response?.data['error']?.toString())
                    : null;
                setModalState(() {
                  localLoadingStatuses = false;
                  localStatusesError =
                      '${loc.calendarFetchFailedStatus(status ?? '??')}${msg != null ? ': $msg' : ''}';
                });
              } on AuthRequiredException {
                setModalState(() {
                  localLoadingStatuses = false;
                  localStatusesError = loc.calendarSessionMissing;
                });
              } catch (e) {
                setModalState(() {
                  localLoadingStatuses = false;
                  localStatusesError = loc.calendarFetchFailed(e.toString());
                });
              }
            }

            Future<void> submit() async {
              if (_slotActionBusy) return;
              final dateInput = dateCtrl.text.trim();
              final time =
                  _normalizeTimeToApi(localSelectedTime ?? timeCtrl.text) ?? '';
              final apiDate = _normalizeDateToApi(dateInput);
              final createDate = _normalizeSlotDate(dateInput);
              final initialDateNormalized =
                  _normalizeDateToApi(initialDate) ?? _normalizeSlotDate(initialDate);
              final initialTimeNormalized =
                  _normalizeTimeToApi(initialTime) ?? initialTime.trim();
              if (localSelectedStatusId == null) {
                _showSnack(loc.appointmentsStatusSelectHint);
                return;
              }
              if ((apiDate == null && !createNewForCustomer) ||
                  createDate.isEmpty ||
                  time.isEmpty) {
                _showSnack(loc.calendarDateTimeRequired);
                return;
              }

              setState(() {
                _slotActionBusy = true;
              });

              try {
                final dio = await _buildAuthedDio(includeJsonContentType: true);
                final payload = {
                  'customer_id': customerId,
                  'appointment_status_id': localSelectedStatusId,
                  'date': createNewForCustomer ? createDate : apiDate,
                  'time': time,
                  'notes': notesCtrl.text.trim(),
                  'no_sms': localNoSms,
                  'no_reminder': localNoReminder,
                };

                final selectedDateForValidation =
                    createNewForCustomer ? createDate : (apiDate ?? createDate);
                final shouldValidateSlot = createNewForCustomer ||
                    selectedDateForValidation != initialDateNormalized ||
                    time != initialTimeNormalized;

                if (shouldValidateSlot) {
                  final validateResp = await dio.post(
                    '/api/appointments/validate',
                    data: {
                      'customer_id': customerId,
                      'date': selectedDateForValidation,
                      'time': time,
                    },
                  );
                  final validateEnvelope = _parseEnvelope(
                    validateResp.data,
                    statusCode: validateResp.statusCode ?? 200,
                  );
                  if (!validateEnvelope.isSuccess) {
                    final handled = await _handleIssueByCode(
                      validateEnvelope,
                      allowPackageNavigation: false,
                      onSlotBusy: () {
                        setModalState(() {
                          localSelectedTime = null;
                          timeCtrl.clear();
                        });
                      },
                    );
                    if (!handled) {
                      _showSnack(
                        _issueMessageForCode(
                          validateEnvelope,
                          fallback: loc.calendarSlotBusy,
                        ),
                      );
                    }
                    return;
                  }
                }

                if (createNewForCustomer) {
                  final createResp =
                      await dio.post('/api/appointments', data: payload);
                  final createEnvelope = _parseEnvelope(
                    createResp.data,
                    statusCode: createResp.statusCode ?? 200,
                  );
                  if (!createEnvelope.isSuccess) {
                    final handled = await _handleIssueByCode(
                      createEnvelope,
                      allowPackageNavigation: false,
                    );
                    if (!handled) {
                      _showSnack(
                        _issueMessageForCode(
                          createEnvelope,
                          fallback: loc.calendarCreateFailed,
                        ),
                      );
                    }
                    return;
                  }
                  _showSnack(loc.calendarCreateSuccess, success: true);
                } else {
                  final updateResp = await dio
                      .put('/api/appointments/$appointmentId', data: payload);
                  final updateEnvelope = _parseEnvelope(
                    updateResp.data,
                    statusCode: updateResp.statusCode ?? 200,
                  );
                  if (!updateEnvelope.isSuccess) {
                    final handled = await _handleIssueByCode(
                      updateEnvelope,
                      allowPackageNavigation: false,
                    );
                    if (!handled) {
                      _showSnack(
                        _issueMessageForCode(
                          updateEnvelope,
                          fallback: loc.calendarUpdateFailed,
                        ),
                      );
                    }
                    return;
                  }
                  _showSnack(loc.calendarUpdateSuccess, success: true);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                await _refreshWeek();
              } on DioException catch (e) {
                final envelope = _parseEnvelope(
                  e.response?.data,
                  statusCode: e.response?.statusCode ?? 0,
                );
                final handled = await _handleIssueByCode(
                  envelope,
                  allowPackageNavigation: false,
                  onSlotBusy: () {
                    setModalState(() {
                      localSelectedTime = null;
                      timeCtrl.clear();
                    });
                  },
                );
                if (!handled) {
                  _showSnack(
                    _issueMessageForCode(
                      envelope,
                      fallback: createNewForCustomer
                          ? loc.calendarCreateFailed
                          : loc.calendarUpdateFailed,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _slotActionBusy = false;
                  });
                }
              }
            }

            final media = MediaQuery.of(ctx);
            final bottomInset =
                media.viewInsets.bottom + media.viewPadding.bottom + 24;
            if (!statusesInitialized) {
              statusesInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadStatuses();
              });
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            createNewForCustomer
                                ? loc.rescheduleAppointment
                                : loc.editAppointment,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: accent,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: loc.appointmentsClose,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(text: loc.calendarDateTimeSection),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            onTap: pickDate,
                            decoration: field(
                              label: loc.date,
                              hint: loc.calendarDateHint,
                              prefix: const Icon(Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            readOnly: true,
                            decoration: field(
                              label: loc.timeSelect,
                              hint: loc.calendarTimeSlotHint,
                              prefix: const Icon(Icons.access_time, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: localLoadingSlots ? null : loadSlots,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: const BorderSide(color: border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: localLoadingSlots
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    loc.calendarFetchAvailableSlots,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (localSlotsError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: danger.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 14, color: danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localSlotsError!,
                                style: const TextStyle(
                                    fontSize: 12, color: danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (localSlots.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: localSlots.map((slot) {
                          final slotTime = slot['time']?.toString() ?? '';
                          final booked =
                              slot['booked'] == true || slot['booked'] == 1;
                          final canUseBooked =
                              !createNewForCustomer && slotTime == initialTime;
                          final disabled = booked && !canUseBooked;
                          final selected = localSelectedTime == slotTime;
                          return GestureDetector(
                            onTap: disabled
                                ? null
                                : () {
                                    setModalState(() {
                                      localSelectedTime = slotTime;
                                      timeCtrl.text = slotTime;
                                      localSlotsError = null;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: disabled
                                    ? const Color(0xFFF3F3F3)
                                    : selected
                                        ? success
                                        : surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: disabled
                                      ? border
                                      : selected
                                          ? success
                                          : border,
                                ),
                              ),
                              child: Text(
                                slotTime,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: disabled
                                      ? muted
                                      : selected
                                          ? Colors.white
                                          : accent,
                                  decoration: disabled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 20),
                    _SectionLabel(text: loc.status),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: localSelectedStatusId,
                      isExpanded: true,
                      decoration: field(
                        label: loc.status,
                        hint: localLoadingStatuses
                            ? loc.calendarLoading
                            : loc.appointmentsStatusSelectHint,
                        prefix: const Icon(Icons.flag_outlined, size: 18),
                      ),
                      items: localStatuses
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: _asInt(s['id']),
                              child: Text(_localizedStatusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: localLoadingStatuses
                          ? null
                          : (val) => setModalState(() {
                                localSelectedStatusId = val;
                                localStatusesError = null;
                              }),
                    ),
                    if (localStatusesError != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: localLoadingStatuses ? null : loadStatuses,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          localStatusesError!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 20),
                    _SectionLabel(text: loc.note),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration:
                          field(label: '', hint: loc.calendarNoteHint).copyWith(
                        labelText: null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _ThinDivider(),
                    const SizedBox(height: 8),
                    _MinimalSwitch(
                      label: loc.doNotSendSms,
                      value: localNoSms,
                      onChanged: (val) => setModalState(() => localNoSms = val),
                    ),
                    _MinimalSwitch(
                      label: loc.doNotSendReminder,
                      value: localNoReminder,
                      onChanged: (val) =>
                          setModalState(() => localNoReminder = val),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _slotActionBusy ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              accent.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 0,
                        ),
                        child: _slotActionBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                loc.save,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _dayWorking(WeekDayInfo day, Map<String, dynamic> prefs) {
    final pref = prefs[day.dayOfWeekIso.toString()];
    final prefWorking = pref is Map
        ? (pref['is_working'] == true || pref['is_working'] == 1)
        : true;
    return day.isWorking && prefWorking;
  }

  String _dayFullLabel(WeekDayInfo day) {
    switch (day.dayOfWeekIso) {
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
      default:
        return loc.daySunFull;
    }
  }

  String _monthTitle() {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat('MMMM yyyy', localeTag);
    final text = formatter.format(_weekStart);
    return text[0].toUpperCase() + text.substring(1);
  }

  String _localizedWeekRangeText(WeeklyCalendarData data) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat('d MMM', localeTag);
    return '${formatter.format(data.weekStart)} - ${formatter.format(data.weekEnd)}';
  }

  int _dayNumber(WeekDayInfo day) {
    final parts = day.date.split('-');
    if (parts.length == 3) {
      return int.tryParse(parts[2]) ?? 0;
    }
    return 0;
  }

  String _normalizeDateKey(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return value.substring(0, 10);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _normalizeTimeKey(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final match = _timeKeyPattern.firstMatch(value);
    if (match != null) {
      return '${match.group(1)}:${match.group(2)}';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final h = parsed.hour.toString().padLeft(2, '0');
    final m = parsed.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, List<Map<String, dynamic>>> _appointmentsLookupFor(
      WeeklyCalendarData data) {
    final key =
        '${_weekIdentity(data)}:${data.appointmentsBySlot.length}:${data.appointmentsBySlot.hashCode}';
    if (_appointmentsLookupCacheKey == key) return _appointmentsLookupCache;

    final lookup = <String, List<Map<String, dynamic>>>{};
    data.appointmentsBySlot.forEach((slotKey, list) {
      lookup[slotKey] = list;
      final idx = slotKey.lastIndexOf('_');
      if (idx <= 0) return;
      final normalizedKey =
          '${_normalizeDateKey(slotKey.substring(0, idx))}_${_normalizeTimeKey(slotKey.substring(idx + 1))}';
      lookup.putIfAbsent(normalizedKey, () => list);
    });

    _appointmentsLookupCacheKey = key;
    _appointmentsLookupCache = lookup;
    return lookup;
  }

  Widget _buildDayList(WeeklyCalendarData data) {
    _syncExpandedDayAndFocus(data);
    final appointmentsLookup = _appointmentsLookupFor(data);
    final statusColors = data.statusColors;
    final workingPrefs = data.workingPreferences;
    final currentTimeLabel = DateFormat('HH:mm').format(DateTime.now());

    List<Map<String, dynamic>> appointmentsForSlot(
      String dayDate,
      String slotTime,
    ) {
      final rawKey = '${dayDate}_$slotTime';
      return appointmentsLookup[rawKey] ??
          appointmentsLookup[
              '${_normalizeDateKey(dayDate)}_${_normalizeTimeKey(slotTime)}'] ??
          const [];
    }

    Color statusColorFor(Map<String, dynamic>? appointment) {
      final alias =
          appointment?['appointment_status']?['alias']?.toString() ?? '';
      final mapped = statusColors[alias] ?? '';
      return _bootstrapColor(mapped);
    }

    Widget buildSlotCard(
      WeekDayInfo day,
      String time, {
      List<Map<String, dynamic>>? appts,
      bool isNowFocus = false,
    }) {
      final working = _dayWorking(day, workingPrefs);
      if (!working) {
        return const SizedBox.shrink();
      }

      final slotAppts = appts ?? appointmentsForSlot(day.date, time);
      final appointment = slotAppts.isNotEmpty ? slotAppts.first : null;

      if (appointment != null) {
        final customer = appointment['customer'] is Map<String, dynamic>
            ? appointment['customer'] as Map<String, dynamic>
            : (appointment['customer'] is Map
                ? (appointment['customer'] as Map).cast<String, dynamic>()
                : null);
        final fullName =
            '${customer?['name'] ?? ''} ${customer?['lastname'] ?? ''}'.trim();
        final phone = customer?['phone']?.toString() ?? '';
        final color = statusColorFor(appointment);
        final statusMap =
            appointment['appointment_status'] is Map<String, dynamic>
                ? appointment['appointment_status'] as Map<String, dynamic>
                : (appointment['appointment_status'] is Map
                    ? (appointment['appointment_status'] as Map)
                        .cast<String, dynamic>()
                    : null);
        final statusName =
            statusMap == null ? 'Randevu' : _localizedStatusLabel(statusMap);

        return Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isNowFocus
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : loc.calendarPerson,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? phone : '',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 30,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        side: BorderSide(color: color.withValues(alpha: 0.6)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _slotActionBusy
                          ? null
                          : () => _showSlotActionSheet(
                                appointment: appointment,
                                initialDate: day.date,
                                initialTime: time,
                                createNewForCustomer: true,
                              ),
                      child: Text(
                        loc.calendarActionNew,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: color.withValues(alpha: 0.95),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _slotActionBusy
                          ? null
                          : () => _showSlotActionSheet(
                                appointment: appointment,
                                initialDate: day.date,
                                initialTime: time,
                                createNewForCustomer: false,
                              ),
                      child: Text(
                        loc.calendarActionEdit,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCreateSlotSheet(
          initialDate: day.date,
          initialTime: time,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.calendarAddAppointment,
                  style: TextStyle(
                    color: _primaryColor.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.add_circle_outline, color: _primaryColor),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _refreshWeek,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.showBottomNav ? 96 : 20),
          itemCount: data.weekDays.length,
          itemBuilder: (context, index) {
            final day = data.weekDays[index];
            final sectionKey =
                _daySectionKeys.putIfAbsent(day.date, () => GlobalKey());
            final slots = data.timeSlotsByDay[day.date] ?? const <SlotInfo>[];
            final dayApptsByTime = <String, List<Map<String, dynamic>>>{};
            for (final slot in slots) {
              dayApptsByTime[slot.time] =
                  appointmentsForSlot(day.date, slot.time);
            }
            final working = _dayWorking(day, workingPrefs);
            final isExpanded = _expandedDayDate == day.date;
            final focusSlot = _nearestUpcomingSlotTime(
              slots,
              day.date,
              currentTime: currentTimeLabel,
            );
            final bookedCount =
                dayApptsByTime.values.where((appts) => appts.isNotEmpty).length;

            return _CalendarDaySection(
              key: ValueKey('day_${day.date}'),
              anchorKey: sectionKey,
              day: day,
              slots: slots,
              working: working,
              isExpanded: isExpanded,
              dayNumber: _dayNumber(day),
              dayLabel: _dayFullLabel(day),
              slotsFilledLabel:
                  loc.calendarSlotsFilled(bookedCount, slots.length),
              closedLabel: loc.calendarClosed,
              noDataLabel: loc.calendarNoData,
              primaryColor: _primaryColor,
              onToggle: () {
                setState(() {
                  _expandedDayDate =
                      _expandedDayDate == day.date ? null : day.date;
                });
              },
              slotBuilder: (slot) => buildSlotCard(
                day,
                slot.time,
                appts: dayApptsByTime[slot.time],
                isNowFocus: slot.time == focusSlot,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkingPrefCallout() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.calendarWorkingHoursPrompt,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkingPreferencesPage(),
                ),
              );
            },
            child: Text(loc.calendarWorkingHoursButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<WeeklyCalendarData>>(
      weeklyCalendarProvider(_weekStart),
      (previous, next) {
        _hasUserPack = next.asData?.value.hasUserPack ?? _hasUserPack;
        if (next.hasError) {
          final msg = next.error.toString();
          if (msg != _lastErrorMessage) {
            _lastErrorMessage = msg;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (msg.contains('unauthorized') || msg.contains('401')) {
                _showSnack(loc.calendarSessionExpired);
              } else {
                _showSnack(msg);
              }
            });
          }
        }
      },
    );

    final asyncData = ref.watch(weeklyCalendarProvider(_weekStart));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.calendarTitle),
        actions: widget.showBottomNav
            ? [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  tooltip: 'Anasayfa',
                ),
              ]
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 350) {
            _changeWeek(-1);
          } else if (velocity < -350) {
            _changeWeek(1);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickWeekFromCalendar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _monthTitle(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeWeek(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: asyncData.when(
                          data: (d) => Text(
                            _localizedWeekRangeText(d),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          loading: () => Text(loc.calendarLoading),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeWeek(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              asyncData.when(
                data: (d) => d.hasTimeSlots
                    ? const SizedBox.shrink()
                    : _buildWorkingPrefCallout(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
              asyncData.when(
                data: (d) {
                  if (d.weekDays.isEmpty) {
                    return Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshWeek,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Center(child: Text(loc.calendarNoData)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _buildDayList(d);
                },
                loading: () => const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshWeek,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text(
                              'Hata: ${e.toString()}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? MainNavBar(
              currentIndex: 2,
              onIndexSelected: widget.onTabSelected,
            )
          : null,
    );
  }
}

class _CalendarDaySection extends StatelessWidget {
  final GlobalKey anchorKey;
  final WeekDayInfo day;
  final List<SlotInfo> slots;
  final bool working;
  final bool isExpanded;
  final int dayNumber;
  final String dayLabel;
  final String slotsFilledLabel;
  final String closedLabel;
  final String noDataLabel;
  final Color primaryColor;
  final VoidCallback onToggle;
  final Widget Function(SlotInfo slot) slotBuilder;

  const _CalendarDaySection({
    super.key,
    required this.anchorKey,
    required this.day,
    required this.slots,
    required this.working,
    required this.isExpanded,
    required this.dayNumber,
    required this.dayLabel,
    required this.slotsFilledLabel,
    required this.closedLabel,
    required this.noDataLabel,
    required this.primaryColor,
    required this.onToggle,
    required this.slotBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: Radius.circular(isExpanded ? 0 : 14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.isToday
                          ? primaryColor.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                    ),
                    child: Center(
                      child: Text(
                        dayNumber.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: day.isToday ? primaryColor : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slotsFilledLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: isExpanded ? 0.5 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: !isExpanded
                  ? const SizedBox.shrink()
                  : (!working)
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              closedLabel,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                      : (slots.isEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  noDataLabel,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                children: slots.map((slot) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: slotBuilder(slot),
                                  );
                                }).toList(),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF8A8A8A),
        ),
      );
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE));
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? const Color(0xFF111111) : const Color(0xFF8A8A8A),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MinimalSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF111111),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
