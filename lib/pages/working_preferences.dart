import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkingPreferencesPage extends StatefulWidget {
  const WorkingPreferencesPage({super.key});

  @override
  State<WorkingPreferencesPage> createState() => _WorkingPreferencesPageState();
}

class _WorkingPreferencesPageState extends State<WorkingPreferencesPage> {
  final TextEditingController _firstSessionCountController =
      TextEditingController(text: '1');

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _firstAppointmentSessionCount = 1;
  List<_DayPreference> _preferences = _defaultPreferences();
  List<_Holiday> _holidays = [];
  final List<int> _periodOptions =
      List.generate(24, (index) => (index + 1) * 5);
  late final List<String> _timeOptions = _buildTimeOptions();

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

  final List<String> _dayNames = const [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  @override
  void dispose() {
    _firstSessionCountController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
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
        _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      });
      return;
    }

    try {
      final response = await http.get(
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
        final firstSession = rawFirst is int
            ? rawFirst
            : int.tryParse(rawFirst?.toString() ?? '') ?? 1;

        if (!mounted) return;
        setState(() {
          _preferences = merged;
          _holidays = holidays;
          _firstAppointmentSessionCount = firstSession;
          _firstSessionCountController.text =
              _firstAppointmentSessionCount.toString();
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              'Çalışma saatleri alınamadı (HTTP ${response.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Çalışma saatleri alınamadı: $e';
        _loading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_saving) return;

    final parsedCount = int.tryParse(_firstSessionCountController.text);
    _firstAppointmentSessionCount =
        parsedCount != null && parsedCount > 0 ? parsedCount : 1;

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
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
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/working-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        _showSnack('Kaydedildi', success: true);
        await _loadPreferences();
      } else {
        String message = 'Kaydedilemedi (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışma Saatleri'),
      ),
      body: _buildBody(),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
            ElevatedButton(
              onPressed: _loadPreferences,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPreferences,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'İlk randevu için oturum sayısı',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _firstSessionCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Örn: 1',
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        _firstAppointmentSessionCount = parsed;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._preferences.map(_buildDayCard).toList(),
          const SizedBox(height: 12),
          _buildHolidaysCard(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _savePreferences,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDayCard(_DayPreference pref) {
    final dayName = _dayNames[pref.dayOfWeek - 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text('Çalışıyor'),
                Switch(
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
                icon: const Icon(Icons.add),
                label: const Text('Saat aralığı ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(
      _DayPreference pref, int index, _TimeSlot slot) {
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
              value: _initialTimeValue(startOptions, slot.start),
              items: startOptions
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.substring(0, 5)),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Başlangıç',
                border: OutlineInputBorder(),
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
              value: _initialTimeValue(endOptions, slot.end),
              items: endOptions
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.substring(0, 5)),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Bitiş',
                border: OutlineInputBorder(),
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
              value: _initialPeriodValue(periodOptions, slot.period),
              items: periodOptions
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text('$p'),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Periyot',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
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
              tooltip: 'Sil',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              visualDensity: VisualDensity.compact,
              onPressed: pref.timeSlots.length <= 1
                  ? null
                  : () => _removeSlot(pref, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tatil Günleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_holidays.isEmpty)
              const Text('Henüz tatil eklenmedi.'),
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
                            decoration: const InputDecoration(
                              labelText: 'Başlangıç',
                              border: OutlineInputBorder(),
                              isDense: true,
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
                            decoration: const InputDecoration(
                              labelText: 'Bitiş',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onTap: () => _pickHolidayDate(index, false),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            tooltip: 'Sil',
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints.tightFor(width: 36, height: 36),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeHoliday(index),
                            icon: const Icon(Icons.delete),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('reason-$index-${holiday.reason}'),
                      initialValue: holiday.reason,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                icon: const Icon(Icons.add),
                label: const Text('Tatil ekle'),
              ),
            ),
          ],
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

  Map<String, dynamic> toJson(
      {String Function(String value)? normalizeTime}) {
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
