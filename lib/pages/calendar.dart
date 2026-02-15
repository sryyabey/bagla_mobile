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
import '../utils/appointment_date_utils.dart';
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
  String? _expandedDayDate;
  String? _autoFocusedWeekKey;
  String? _autoExpandedWeekKey;
  final Map<String, GlobalKey> _daySectionKeys = {};
  bool _slotActionBusy = false;
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

  String? _nearestUpcomingSlotTime(List<SlotInfo> slots, String dayIso) {
    if (slots.isEmpty) return null;
    final todayIso = _toIsoDate(DateTime.now());
    if (dayIso != todayIso) return null;
    final now = DateFormat('HH:mm').format(DateTime.now());
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

  Future<void> _refreshWeek() async {
    ref.invalidate(weeklyCalendarProvider(_weekStart));
  }

  Future<void> _showSlotActionSheet({
    required Map<String, dynamic> appointment,
    required String initialDate,
    required String initialTime,
    required bool createNewForCustomer,
  }) async {
    final appointmentId = _asInt(appointment['id']);
    final customerId = _asInt(appointment['customer_id']);
    final statusId = _resolveStatusId(appointment);
    if (customerId == null) {
      _showSnack('Müşteri bilgisi bulunamadı.');
      return;
    }
    if (!createNewForCustomer && appointmentId == null) {
      _showSnack('Randevu bilgisi bulunamadı.');
      return;
    }
    if (statusId == null) {
      _showSnack('Randevu durumu bulunamadı.');
      return;
    }

    final parsedInitialDate = _parseInputDateOrNow(initialDate);
    final dateCtrl = TextEditingController(
      text: _formatDateDisplay(parsedInitialDate),
    );
    final timeCtrl = TextEditingController(text: initialTime);
    final notesCtrl =
        TextEditingController(text: appointment['notes']?.toString() ?? '');
    bool localNoSms = appointment['no_sms'] == true || appointment['no_sms'] == 1;
    bool localNoReminder =
        appointment['no_reminder'] == true || appointment['no_reminder'] == 1;
    List<Map<String, dynamic>> localSlots = [];
    bool localLoadingSlots = false;
    String? localSlotsError;
    String? localSelectedTime = initialTime;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack(loc.calendarSessionMissing);
                return;
              }

              setModalState(() {
                localLoadingSlots = true;
                localSlotsError = null;
                localSlots = [];
              });

              final dio = Dio(
                BaseOptions(
                  baseUrl: apiBaseUrl,
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                ),
              );

              try {
                final resp = await dio.get(
                  '/api/appointments/time-slots',
                  queryParameters: {'date': date},
                );
                final raw = resp.data is Map
                    ? ((resp.data as Map)['data'] ?? resp.data)
                    : resp.data;
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

            Future<void> submit() async {
              if (_slotActionBusy) return;
              final dateInput = dateCtrl.text.trim();
              final time = (localSelectedTime ?? timeCtrl.text).trim();
              final apiDate = _normalizeDateToApi(dateInput);
              final createDate = _normalizeSlotDate(dateInput);
              if ((apiDate == null && !createNewForCustomer) ||
                  createDate.isEmpty ||
                  time.isEmpty) {
                _showSnack(loc.calendarDateTimeRequired);
                return;
              }

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack(loc.calendarSessionMissing);
                return;
              }

              setState(() {
                _slotActionBusy = true;
              });

              final dio = Dio(
                BaseOptions(
                  baseUrl: apiBaseUrl,
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                  },
                ),
              );

              try {
                final payload = {
                  'customer_id': customerId,
                  'appointment_status_id': statusId,
                  'date': createNewForCustomer ? createDate : apiDate,
                  'time': time,
                  'notes': notesCtrl.text.trim(),
                  'no_sms': localNoSms,
                  'no_reminder': localNoReminder,
                };

                if (createNewForCustomer) {
                  await dio.post('/api/appointments', data: payload);
                  _showSnack(loc.calendarCreateSuccess, success: true);
                } else {
                  await dio.put('/api/appointments/$appointmentId', data: payload);
                  _showSnack(loc.calendarUpdateSuccess, success: true);
                }

                if (ctx.mounted) Navigator.of(ctx).pop();
                await _refreshWeek();
              } on DioException catch (e) {
                final status = e.response?.statusCode;
                final msg = e.response?.data is Map
                    ? (e.response?.data['message']?.toString() ??
                        e.response?.data['error']?.toString())
                    : null;
                _showSnack(
                  '${createNewForCustomer ? loc.calendarCreateFailed : loc.calendarUpdateFailed}'
                  '${status != null ? ' (HTTP $status)' : ''}${msg != null ? ': $msg' : ''}',
                );
              } finally {
                if (mounted) {
                  setState(() {
                    _slotActionBusy = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      createNewForCustomer
                          ? loc.rescheduleAppointment
                          : loc.editAppointment,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            onTap: pickDate,
                            decoration: InputDecoration(
                              labelText: loc.date,
                              hintText: loc.calendarDateHint,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: loc.timeSelect,
                              hintText: loc.calendarTimeSlotHint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: localLoadingSlots ? null : loadSlots,
                          icon: localLoadingSlots
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.schedule),
                          label: Text(loc.calendarFetchAvailableSlots),
                        ),
                        const SizedBox(width: 12),
                        if (localSlotsError != null)
                          Expanded(
                            child: Text(
                              localSlotsError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (localLoadingSlots)
                      const LinearProgressIndicator(minHeight: 2),
                    if (localSlots.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: localSlots.map((slot) {
                          final slotTime = slot['time']?.toString() ?? '';
                          final booked = slot['booked'] == true || slot['booked'] == 1;
                          final canUseBooked =
                              !createNewForCustomer && slotTime == initialTime;
                          final disabled = booked && !canUseBooked;
                          final selected = localSelectedTime == slotTime;
                          return ChoiceChip(
                            label: Text(slotTime),
                            selected: selected,
                            onSelected: disabled
                                ? null
                                : (val) {
                                    if (!val) return;
                                    setModalState(() {
                                      localSelectedTime = slotTime;
                                      timeCtrl.text = slotTime;
                                      localSlotsError = null;
                                    });
                                  },
                            disabledColor: Colors.grey.shade300,
                            selectedColor: Colors.green.shade200,
                            labelStyle: TextStyle(
                              color: disabled
                                  ? Colors.grey
                                  : (selected ? Colors.black : Colors.black87),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: loc.note,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(loc.doNotSendSms),
                      value: localNoSms,
                      onChanged: (val) => setModalState(() => localNoSms = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text(loc.doNotSendReminder),
                      value: localNoReminder,
                      onChanged: (val) =>
                          setModalState(() => localNoReminder = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _slotActionBusy ? null : submit,
                        icon: _slotActionBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(createNewForCustomer ? Icons.add : Icons.save),
                        label: Text(
                          createNewForCustomer ? loc.rescheduleAppointment : loc.save,
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

  Widget _buildDayList(WeeklyCalendarData data) {
    _syncExpandedDayAndFocus(data);
    final appointmentsBySlot = data.appointmentsBySlot;
    final statusColors = data.statusColors;
    final workingPrefs = data.workingPreferences;

    Color statusColorFor(Map<String, dynamic>? appointment) {
      final alias =
          appointment?['appointment_status']?['alias']?.toString() ?? '';
      final mapped = statusColors[alias] ?? '';
      return _bootstrapColor(mapped);
    }

    Widget buildSlotCard(
      WeekDayInfo day,
      String time, {
      bool isNowFocus = false,
    }) {
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
        final statusName =
            appointment['appointment_status']?['name']?.toString() ?? 'Randevu';

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

    Widget buildDaySection(WeekDayInfo day) {
      final sectionKey = _daySectionKeys.putIfAbsent(day.date, () => GlobalKey());
      final slots = data.timeSlotsByDay[day.date] ?? const [];
      final working = _dayWorking(day, workingPrefs);
      final isExpanded = _expandedDayDate == day.date;
      final focusSlot = _nearestUpcomingSlotTime(slots, day.date);
      final bookedCount = slots.where((slot) {
        final key = '${day.date}_${slot.time}';
        final appts = appointmentsBySlot[key] ?? const [];
        return appts.isNotEmpty;
      }).length;

      return Container(
        key: sectionKey,
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
              onTap: () {
                setState(() {
                  _expandedDayDate =
                      _expandedDayDate == day.date ? null : day.date;
                });
              },
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dayFullLabel(day),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.calendarSlotsFilled(bookedCount, slots.length),
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
                                loc.calendarClosed,
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
                                    loc.calendarNoData,
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(
                                  children: slots.map((slot) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: buildSlotCard(
                                        day,
                                        slot.time,
                                        isNowFocus: slot.time == focusSlot,
                                      ),
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

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: widget.showBottomNav ? 96 : 20),
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
