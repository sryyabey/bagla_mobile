import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/dashboard_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  factory WeeklyCalendarData.fromJson(Map<String, dynamic> json) {
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
    final rawColors = json['status_colors'] as Map? ?? {};
    rawColors.forEach((k, v) {
      statusColorsMap[k.toString()] = v?.toString() ?? '';
    });

    return WeeklyCalendarData(
      weekStart: parseDate(json['week_start_date']?.toString() ?? ''),
      weekEnd: parseDate(json['week_end_date']?.toString() ?? ''),
      weekRangeText: json['week_range_text']?.toString() ?? '',
      weekDays: weekDays,
      timeSlotsByDay: slotsMap,
      timeGrid: (json['time_grid'] as List? ?? [])
          .map((e) => e?.toString() ?? '')
          .toList(),
      appointmentsBySlot: appointmentsBySlot,
      statusColors: statusColorsMap,
      workingPreferences: Map<String, dynamic>.from(
        json['working_preferences'] as Map? ?? {},
      ),
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
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _weekStart;
  String? _lastErrorMessage;

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
    final prefWorking = pref is Map ? (pref['is_working'] == true || pref['is_working'] == 1) : true;
    return day.isWorking && prefWorking;
  }

  Widget _buildDayChips(List<WeekDayInfo> days) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: days.map((d) {
          final selected = d.isToday;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.shortLabel),
                  Text(
                    d.displayDate,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor:
                  selected ? Colors.indigo.shade100 : Colors.grey.shade200,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(WeeklyCalendarData data) {
    final days = data.weekDays;
    final timeGrid = data.timeGrid;
    final appointmentsBySlot = data.appointmentsBySlot;
    final statusColors = data.statusColors;
    final workingPrefs = data.workingPreferences;

    Color statusColorFor(Map<String, dynamic>? appointment) {
      final alias =
          appointment?['appointment_status']?['alias']?.toString() ?? '';
      final mapped = statusColors[alias] ?? '';
      return _bootstrapColor(mapped);
    }

    Widget buildCell(WeekDayInfo day, String time) {
      final working = _dayWorking(day, workingPrefs);
      if (!working) {
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Center(
            child: Text(
              'Kapalı',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
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
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isNotEmpty ? fullName : 'Müşteri',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.circle, color: color, size: 10),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      phone.isNotEmpty ? phone : '',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showSnack('Bu slota randevu ekleme burada henüz bağlı değil.');
            },
          ),
        ),
      );
    }

    return Expanded(
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: (days.length + 1) * 140,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                itemCount: timeGrid.length + 1,
                itemBuilder: (context, rowIndex) {
                  if (rowIndex == 0) {
                    return Row(
                      children: [
                        Container(
                          width: 120,
                          padding: const EdgeInsets.all(8),
                          color: Colors.grey.shade200,
                          child: const Text(
                            'Saat',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...days.map((d) {
                          return Container(
                            width: 140,
                            padding: const EdgeInsets.all(8),
                            color: d.isToday
                                ? Colors.indigo.shade50
                                : Colors.grey.shade100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  d.displayDate,
                                  style:
                                      const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }

                  final time = timeGrid[rowIndex - 1];
                  return Row(
                    children: [
                      Container(
                        width: 120,
                        height: 64,
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.shade100,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            time,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      ...days.map((d) {
                        final slots = data.timeSlotsByDay[d.date] ?? const [];
                        final hasSlot = slots.any((s) => s.time == time);
                        if (!hasSlot) {
                          return Container(
                            width: 140,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border:
                                  Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Text(
                                '-',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        return SizedBox(
                          width: 140,
                          child: buildCell(d, time),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
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
                _showSnack('Oturum süresi doldu, lütfen tekrar giriş yapın.');
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
        title: const Text('Haftalık Takvim'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            },
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Dashboard',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Önceki'),
                ),
                ElevatedButton(
                  onPressed: _goToday,
                  child: const Text('Bugün'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Sonraki'),
                ),
                asyncData.when(
                  data: (d) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      d.weekRangeText,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Yükleniyor...'),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            asyncData.when(
              data: (d) => _buildDayChips(d.weekDays),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Hata: ${e.toString()}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            asyncData.when(
              data: (d) {
                if (d.timeGrid.isEmpty || d.weekDays.isEmpty) {
                  return const Text('Bu hafta için veri yok.');
                }
                return _buildGrid(d);
              },
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
