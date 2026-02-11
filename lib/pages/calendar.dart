import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/dashboard_page.dart';
import 'package:bagla_mobile/pages/appointments.dart';
import 'package:bagla_mobile/pages/working_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/main_nav.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

DateTime _startOfWeek(DateTime date) {
  final weekday = date.weekday; // 1 = Mon
  return DateTime(date.year, date.month, date.day).subtract(
    Duration(days: weekday - 1),
  );
}

Future<String?> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('bearer_token');
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
  final Map<String, List<dynamic>> appointmentsBySlot;
  final Map<String, String> statusColors;
  final Map<String, dynamic> workingPreferences;
  final bool hasTimeSlots;

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
    final appointmentsBySlot = <String, List<dynamic>>{};
    final rawApptsAny = json['appointments_by_slot'];
    if (rawApptsAny is Map) {
      rawApptsAny.forEach((key, value) {
        if (value is List) {
          appointmentsBySlot[key.toString()] = value;
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
    );
  }
}

final weeklyCalendarProvider =
    FutureProvider.autoDispose.family<WeeklyCalendarData, DateTime>(
  (ref, weekStart) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Oturum bulunamadı.');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

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
  static const Color _primaryColor = Color(0xFF6366F1);

  AppLocalizations get loc => AppLocalizations.of(context);

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

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
    });
  }

  void _goToday() {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
    });
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

  int _dayNumber(WeekDayInfo day) {
    final parts = day.date.split('-');
    if (parts.length == 3) {
      return int.tryParse(parts[2]) ?? 0;
    }
    return 0;
  }

  Widget _buildDayList(WeeklyCalendarData data) {
    final appointmentsBySlot = data.appointmentsBySlot;
    final statusColors = data.statusColors;
    final workingPrefs = data.workingPreferences;

    Color statusColorFor(Map<String, dynamic>? appointment) {
      final alias =
          appointment?['appointment_status']?['alias']?.toString() ?? '';
      final mapped = statusColors[alias] ?? '';
      return _bootstrapColor(mapped);
    }

    Widget buildSlotCard(WeekDayInfo day, String time) {
      final working = _dayWorking(day, workingPrefs);
      if (!working) {
        return const SizedBox.shrink();
      }

      final key = '${day.date}_$time';
      final appts = appointmentsBySlot[key] ?? const [];
      final appointment = appts.isNotEmpty && appts.first is Map
          ? Map<String, dynamic>.from(appts.first as Map)
          : null;

      if (appointment != null) {
        final customer = appointment['customer'] as Map?;
        final fullName =
            '${customer?['name'] ?? ''} ${customer?['lastname'] ?? ''}'.trim();
        final phone = customer?['phone']?.toString() ?? '';
        final color = statusColorFor(appointment);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
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
                      fullName.isNotEmpty ? fullName : loc.calendarCustomer,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? phone : '',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.check, color: color),
            ],
          ),
        );
      }

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppointmentsPage(
                initialQuickDate: day.date,
                initialQuickTime: time,
                autoShowQuick: true,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
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
                  loc.calendarCustomer,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const Icon(Icons.add_circle_outline, color: _primaryColor),
            ],
          ),
        ),
      );
    }

    Widget buildDaySection(WeekDayInfo day) {
      final slots = data.timeSlotsByDay[day.date] ?? const [];
      final working = _dayWorking(day, workingPrefs);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
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
                          ? _primaryColor.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                    ),
                    child: Center(
                      child: Text(
                        _dayNumber(day).toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: day.isToday ? _primaryColor : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dayFullLabel(day),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_up, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.blueGrey),
                ],
              ),
            ),
            if (!working)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.calendarClosed,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else if (slots.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.calendarNoData,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: slots.map((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: buildSlotCard(day, slot.time),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: data.weekDays.length,
        itemBuilder: (context, index) => buildDaySection(data.weekDays[index]),
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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _monthTitle(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                const Spacer(),
                TextButton(
                  onPressed: _goToday,
                  child: Text(loc.calendarToday),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                          d.weekRangeText,
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
              data: (d) =>
                  d.hasTimeSlots ? const SizedBox.shrink() : _buildWorkingPrefCallout(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            asyncData.when(
              data: (d) {
                if (d.weekDays.isEmpty) {
                  return Text(loc.calendarNoData);
                }
                return _buildDayList(d);
              },
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Expanded(
                child: Center(
                  child: Text(
                    'Hata: ${e.toString()}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
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
