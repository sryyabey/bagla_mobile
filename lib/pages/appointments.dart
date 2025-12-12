import 'dart:convert';

import 'package:bagla_mobile/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard_page.dart';
import 'sms_packs.dart';

class AppointmentsPage extends StatefulWidget {
  final String? initialQuickDate;
  final String? initialQuickTime;
  final bool autoShowQuick;

  const AppointmentsPage({
    super.key,
    this.initialQuickDate,
    this.initialQuickTime,
    this.autoShowQuick = false,
  });

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  // Palette for consistent look
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color accentColor = Color(0xFF10B981);
  static const Color backgroundColor = Color(0xFFF8FAFC);

  final TextEditingController _quickNameController = TextEditingController();
  final TextEditingController _quickLastNameController =
      TextEditingController();
  final TextEditingController _quickCountryIdController =
      TextEditingController();
  final TextEditingController _quickPhoneController = TextEditingController();
  final TextEditingController _quickEmailController = TextEditingController();
  final TextEditingController _quickDateController = TextEditingController();
  final TextEditingController _quickTimeController = TextEditingController();
  final TextEditingController _quickNoteController = TextEditingController();

  List<Map<String, dynamic>> _appointments = [];
  bool _loadingList = true;
  bool _savingAppointment = false;
  bool _savingQuick = false;
  bool _creatingRebook = false;
  bool _loadingCustomerInfo = false;
  String? _error;
  bool _quickIsFirstAppointment = false;
  bool _quickNoSms = false;
  bool _quickNoReminder = false;
  bool _showQuickForm = false;
  bool _loadingSlots = false;
  String? _slotsError;
  List<Map<String, dynamic>> _timeSlots = [];
  String? _selectedSlotTime;
  List<Map<String, dynamic>> _countries = [];
  bool _loadingCountries = false;
  String? _countriesError;
  int? _selectedCountryId;
  bool _isFormattingPhone = false;
  List<Map<String, dynamic>> _appointmentStatuses = [];
  bool _loadingStatuses = false;
  String? _statusesError;
  // Filters
  final TextEditingController _filterNameController = TextEditingController();
  final TextEditingController _filterLastNameController =
      TextEditingController();
  final TextEditingController _filterPhoneController = TextEditingController();
  final TextEditingController _filterDateFromController =
      TextEditingController();
  final TextEditingController _filterDateToController = TextEditingController();
  final TextEditingController _filterTimeFromController =
      TextEditingController();
  final TextEditingController _filterTimeToController = TextEditingController();
  Map<String, String> _activeFilters = {};
  bool _showFilters = false;
  final List<String> _timeOptions = List.generate(
      24 * 12,
      (i) =>
          '${(i ~/ 12).toString().padLeft(2, '0')}:${((i % 12) * 5).toString().padLeft(2, '0')}');
  String _lastPhoneDigits = '';
  int _lastPhoneTextLength = 0;
  bool _hasUserPack = true;

  ButtonStyle _mainButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().trim().toLowerCase();
    return str == '1' || str == 'true' || str == 'yes';
  }

  int _countToday() {
    final today = DateTime.now();
    return _appointments.where((appt) {
      final dateStr = appt['date']?.toString();
      if (dateStr == null) return false;
      try {
        final d = DateTime.parse(dateStr);
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      } catch (_) {
        return false;
      }
    }).length;
  }

  Widget _sectionCard({
    required Widget child,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null ||
                subtitle != null ||
                (actions != null && actions.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (actions != null && actions.isNotEmpty) ...actions,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, IconData icon, Color color) {
    final bool isLight = color.computeLuminance() > 0.7;
    final Color iconColor = isLight ? primaryColor : color;
    final Color bgColor =
        isLight ? Colors.white.withOpacity(0.16) : color.withOpacity(0.08);
    final Color borderColor =
        isLight ? Colors.white.withOpacity(0.3) : color.withOpacity(0.2);
    final Color labelColor = isLight ? Colors.white70 : Colors.black54;
    final Color valueColor = isLight ? Colors.white : Colors.black87;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderHero() {
    final todayCount = _countToday();
    final totalCount = _appointments.length;
    final buttonStyleOnLight = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Randevu Yönetimi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Günlük randevularını takip et, hızlıca yeni randevu oluştur.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchAppointments,
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statPill('Bugün', '$todayCount', Icons.event_available,
                  Colors.white70.withOpacity(0.95)),
              const SizedBox(width: 12),
              _statPill('Toplam', '$totalCount', Icons.calendar_today,
                  Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (!_hasUserPack) {
                    _showSnack('Randevu işlemleri için paket alınız.');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmsPacksPage()),
                    );
                    return;
                  }
                  setState(() {
                    _showQuickForm = true;
                  });
                },
                style: buttonStyleOnLight,
                icon: const Icon(Icons.flash_on),
                label: const Text('Hızlı Randevu'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                  color: Colors.white,
                ),
                label: Text(
                  _showFilters ? 'Filtreyi Gizle' : 'Filtrele',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _fetchAppointments,
                icon: const Icon(Icons.sync, color: Colors.white),
                label: const Text(
                  'Listeyi Yenile',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, String> _buildValidFilters() {
    final Map<String, String> params = {};
    final dateFrom = _normalizeDateToApi(_filterDateFromController.text);
    final dateTo = _normalizeDateToApi(_filterDateToController.text);
    final timeFrom = _filterTimeFromController.text.trim();
    final timeTo = _filterTimeToController.text.trim();

    if (_filterNameController.text.trim().isNotEmpty) {
      params['customer_name'] = _filterNameController.text.trim();
    }
    if (_filterLastNameController.text.trim().isNotEmpty) {
      params['customer_lastname'] = _filterLastNameController.text.trim();
    }
    if (_filterPhoneController.text.trim().isNotEmpty) {
      params['customer_phone'] = _filterPhoneController.text.trim();
    }
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (timeFrom.isNotEmpty && _isValidTime(timeFrom)) {
      params['time_from'] = timeFrom;
    }
    if (timeTo.isNotEmpty && _isValidTime(timeTo)) {
      params['time_to'] = timeTo;
    }
    return params;
  }

  @override
  void initState() {
    super.initState();
    _quickPhoneController.addListener(_formatPhoneInput);
    if (widget.initialQuickDate != null) {
      _quickDateController.text = widget.initialQuickDate!;
    }
    if (widget.initialQuickTime != null) {
      _quickTimeController.text = widget.initialQuickTime!;
      _selectedSlotTime = widget.initialQuickTime;
    }
    if (widget.autoShowQuick ||
        widget.initialQuickDate != null ||
        widget.initialQuickTime != null) {
      _showQuickForm = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAppointments();
      _fetchCountries();
      _fetchStatuses();
      if (_showQuickForm && _quickDateController.text.trim().isNotEmpty) {
        _fetchTimeSlots();
      }
    });
  }

  @override
  void dispose() {
    _quickPhoneController.removeListener(_formatPhoneInput);
    _quickNameController.dispose();
    _quickLastNameController.dispose();
    _quickCountryIdController.dispose();
    _quickPhoneController.dispose();
    _quickEmailController.dispose();
    _quickDateController.dispose();
    _quickTimeController.dispose();
    _quickNoteController.dispose();
    _filterNameController.dispose();
    _filterLastNameController.dispose();
    _filterPhoneController.dispose();
    _filterDateFromController.dispose();
    _filterDateToController.dispose();
    _filterTimeFromController.dispose();
    _filterTimeToController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token');
  }

  Future<void> _fetchAppointments({Map<String, String>? filters}) async {
    setState(() {
      _loadingList = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loadingList = false;
        _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      });
      return;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/api/appointments').replace(
          queryParameters: (filters ?? _activeFilters).isNotEmpty
              ? (filters ?? _activeFilters)
              : null);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawData = decoded['data'] ?? decoded;
        bool? extractedUserPack;
        if (decoded is Map) {
          final candidate = decoded['user_pack'] ?? decoded['userPack'];
          if (candidate != null) extractedUserPack = _asBool(candidate);
        }
        if (rawData is Map) {
          final candidate = rawData['user_pack'] ?? rawData['userPack'];
          if (candidate != null) extractedUserPack = _asBool(candidate);
        }
        final hasUserPack = extractedUserPack ?? true;
        List<Map<String, dynamic>> list = [];
        if (rawData is List) {
          list = List<Map<String, dynamic>>.from(
            rawData.map((e) => Map<String, dynamic>.from(e)),
          );
        } else if (rawData is Map && rawData['data'] is List) {
          list = List<Map<String, dynamic>>.from(
            (rawData['data'] as List).map((e) => Map<String, dynamic>.from(e)),
          );
        }

        if (!mounted) return;
        setState(() {
          _appointments = list;
          _loadingList = false;
          _hasUserPack = hasUserPack;
          if (!_hasUserPack) {
            _showQuickForm = false;
          }
        });
      } else {
        setState(() {
          _error = 'Randevular alınamadı (HTTP ${response.statusCode}).';
          _loadingList = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Randevular alınamadı: $e';
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
        _countriesError = 'Oturum bulunamadı.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/settings/countries'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        List<Map<String, dynamic>> list = [];
        if (data is List) {
          list = List<Map<String, dynamic>>.from(
              data.map((e) => Map<String, dynamic>.from(e)));
        }
        if (!mounted) return;
        setState(() {
          _countries = list;
          if (_selectedCountryId == null && _countries.isNotEmpty) {
            _selectedCountryId = _countries.first['id'] as int?;
            _quickCountryIdController.text =
                _selectedCountryId != null ? '$_selectedCountryId' : '';
          }
          _loadingCountries = false;
        });
      } else {
        setState(() {
          _loadingCountries = false;
          _countriesError = 'Ülkeler alınamadı (HTTP ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _loadingCountries = false;
        _countriesError = 'Ülkeler alınamadı: $e';
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
        _statusesError = 'Oturum bulunamadı.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/settings/appointment-statuses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        List<Map<String, dynamic>> list = [];
        if (data is List) {
          list = List<Map<String, dynamic>>.from(
              data.map((e) => Map<String, dynamic>.from(e)));
        }
        if (!mounted) return;
        setState(() {
          _appointmentStatuses = list;
          _loadingStatuses = false;
        });
      } else {
        setState(() {
          _loadingStatuses = false;
          _statusesError = 'Durumlar alınamadı (HTTP ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _loadingStatuses = false;
        _statusesError = 'Durumlar alınamadı: $e';
      });
    }
  }

  int? _defaultStatusId() {
    if (_appointmentStatuses.isEmpty) return null;
    try {
      final pending = _appointmentStatuses.firstWhere(
        (s) => (s['alias'] ?? '').toString().toLowerCase() == 'pending',
      );
      return pending['id'] as int?;
    } catch (_) {
      return _appointmentStatuses.first['id'] as int?;
    }
  }

  void _resetQuickForm() {
    setState(() {
      _quickNameController.clear();
      _quickLastNameController.clear();
      _quickCountryIdController.clear();
      _quickPhoneController.clear();
      _quickEmailController.clear();
      _quickDateController.clear();
      _quickTimeController.clear();
      _quickNoteController.clear();
      _lastPhoneDigits = '';
      _lastPhoneTextLength = 0;
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
    final filters = _buildValidFilters();
    if (_filterTimeFromController.text.trim().isNotEmpty &&
        !_isValidTime(_filterTimeFromController.text.trim())) {
      _showSnack('Geçersiz başlangıç saati. Format HH:MM');
      return;
    }
    if (_filterTimeToController.text.trim().isNotEmpty &&
        !_isValidTime(_filterTimeToController.text.trim())) {
      _showSnack('Geçersiz bitiş saati. Format HH:MM');
      return;
    }
    setState(() {
      _activeFilters = filters;
    });
    await _fetchAppointments(filters: filters);
  }

  void _clearFilters() {
    setState(() {
      _filterNameController.clear();
      _filterLastNameController.clear();
      _filterPhoneController.clear();
      _filterDateFromController.clear();
      _filterDateToController.clear();
      _filterTimeFromController.clear();
      _filterTimeToController.clear();
      _activeFilters = {};
    });
    _fetchAppointments(filters: {});
  }

  Future<void> _submitQuickAppointment() async {
    if (_savingQuick) return;
    if (!_hasUserPack) {
      _showSnack('Randevu işlemleri için paket alınız.');
      return;
    }

    final firstName = _quickNameController.text.trim();
    final lastName = _quickLastNameController.text.trim();
    final countryId = _selectedCountryId ??
        int.tryParse(_quickCountryIdController.text.trim());
    final phone = _quickPhoneController.text.trim();
    final email = _quickEmailController.text.trim();
    final date = _quickDateController.text.trim();
    final time = (_selectedSlotTime ?? _quickTimeController.text).trim();
    final note = _quickNoteController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        countryId == null ||
        phone.isEmpty ||
        date.isEmpty ||
        time.isEmpty) {
      _showSnack('İsim, soyisim, ülke, telefon, tarih ve saat zorunludur.');
      return;
    }
    if (_timeSlots.isNotEmpty && time.isEmpty) {
      _showSnack('Lütfen uygun bir saat seçin.');
      return;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _savingQuick = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/appointments/quick_appointment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'customer_name': firstName,
          'customer_lastname': lastName,
          'country_id': countryId,
          'phone': phone,
          'email': email,
          'date': date,
          'time': time,
          'note': note,
          'is_first_appointment': _quickIsFirstAppointment ? 1 : 0,
          'no_sms': _quickNoSms,
          'no_reminder': _quickNoReminder,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Quick randevu oluşturuldu.', success: true);
        await _fetchAppointments();
        _resetQuickForm();
      } else {
        String message =
            'Quick randevu oluşturulamadı (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Quick randevu oluşturulamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _savingQuick = false;
        });
      }
    }
  }

  Color _statusColor(String? hex) {
    if (hex == null) return Colors.blueGrey;
    final cleaned = hex.replaceAll('#', '');
    final buffer = StringBuffer();
    if (cleaned.length == 6) buffer.write('ff');
    buffer.write(cleaned);
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    } catch (_) {
      return date;
    }
  }

  String _localizedStatusLabel(Map<String, dynamic> status) {
    final alias = status['alias']?.toString();
    const trMap = {
      'pending': 'Beklemede',
      'confirmed': 'Onaylandı',
      'rescheduled': 'Yeniden Planlandı',
      'completed': 'Tamamlandı',
      'cancelled': 'İptal',
      'no_show': 'Gelmedi',
    };
    if (alias != null && trMap.containsKey(alias)) {
      return trMap[alias]!;
    }
    return status['name']?.toString() ?? (alias ?? 'Durum');
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    final str = time.toString();
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
    }
    return str;
  }

  String _normalizeSlotDate(String rawDate) {
    final trimmed = rawDate.trim();
    // If already in dd-MM-yyyy return as-is.
    final parts = trimmed.split('-');
    if (parts.length == 3 && parts[0].length == 2 && parts[1].length == 2) {
      return trimmed;
    }
    try {
      final parsed = DateTime.parse(trimmed);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year.toString();
      return '$day-$month-$year';
    } catch (_) {
      return trimmed;
    }
  }

  DateTime _parseInputDateOrNow(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return DateTime.now();
    final parts = trimmed.split('-');
    if (parts.length == 3) {
      // Try dd-MM-yyyy
      try {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      } catch (_) {}
      // Try yyyy-MM-dd
      try {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return DateTime(year, month, day);
      } catch (_) {}
    }
    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      return DateTime.now();
    }
  }

  String? _normalizeDateToApi(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    try {
      if (parts.length == 3) {
        if (parts[0].length == 2) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final dt = DateTime(year, month, day);
          return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        } else if (parts[0].length == 4) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final dt = DateTime(year, month, day);
          return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        }
      }
      final parsed = DateTime.parse(trimmed);
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  bool _isValidTime(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final reg = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    return reg.hasMatch(trimmed);
  }

  DateTime _clampDate(DateTime date, DateTime min, DateTime max) {
    if (date.isBefore(min)) return min;
    if (date.isAfter(max)) return max;
    return date;
  }

  String _formatDateDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    int idx = 0;
    if (digits.length > 0) {
      buffer.write('(');
      for (; idx < digits.length && idx < 3; idx++) {
        buffer.write(digits[idx]);
      }
      if (digits.length >= 3) buffer.write(')');
    }
    if (digits.length > 3) {
      buffer.write(' ');
      for (; idx < digits.length && idx < 6; idx++) {
        buffer.write(digits[idx]);
      }
    }
    if (digits.length > 6) {
      buffer.write(' ');
      for (; idx < digits.length && idx < 8; idx++) {
        buffer.write(digits[idx]);
      }
    }
    if (digits.length > 8) {
      buffer.write(' ');
      for (; idx < digits.length && idx < 10; idx++) {
        buffer.write(digits[idx]);
      }
    }
    return buffer.toString();
  }

  void _formatPhoneInput() {
    if (_isFormattingPhone) return;
    _isFormattingPhone = true;
    final currentRaw = _quickPhoneController.text;
    final currentDigits = currentRaw.replaceAll(RegExp(r'\D'), '');

    // Allow backspace on formatting chars by trimming a digit when only mask chars were removed.
    String normalizedDigits = currentDigits;
    if (currentRaw.length < _lastPhoneTextLength &&
        currentDigits.length == _lastPhoneDigits.length &&
        _lastPhoneDigits.isNotEmpty) {
      normalizedDigits =
          _lastPhoneDigits.substring(0, _lastPhoneDigits.length - 1);
    }

    final formatted = _maskPhone(normalizedDigits);
    _quickPhoneController.value = _quickPhoneController.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _lastPhoneDigits = normalizedDigits;
    _lastPhoneTextLength = formatted.length;
    _isFormattingPhone = false;
  }

  Future<void> _pickQuickDate() async {
    final today = DateTime.now();
    final minDate = DateTime(today.year, today.month, today.day);
    final maxDate = DateTime(today.year + 5, 12, 31);
    final initial = _clampDate(
      _parseInputDateOrNow(_quickDateController.text),
      minDate,
      maxDate,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _quickDateController.text = _formatDateDisplay(picked);
        _selectedSlotTime = null;
        _quickTimeController.clear();
        _timeSlots = [];
      });
      await _fetchTimeSlots();
    }
  }

  Future<void> _fetchTimeSlots() async {
    final dateInput = _quickDateController.text.trim();
    if (dateInput.isEmpty) {
      _showSnack('Önce tarih girin.');
      return;
    }
    final formattedDate = _normalizeSlotDate(dateInput);

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _timeSlots = [];
      _selectedSlotTime = null;
      _quickTimeController.clear();
    });

    try {
      final response = await http.get(
        Uri.parse(
            '$apiBaseUrl/api/appointments/time-slots?date=$formattedDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (!mounted) return;
        setState(() {
          _timeSlots = data is List
              ? List<Map<String, dynamic>>.from(
                  data.map((e) => Map<String, dynamic>.from(e)))
              : <Map<String, dynamic>>[];
          _loadingSlots = false;
        });
      } else {
        setState(() {
          _slotsError = 'Saatler alınamadı (HTTP ${response.statusCode}).';
          _loadingSlots = false;
        });
      }
    } catch (e) {
      setState(() {
        _slotsError = 'Saatler alınamadı: $e';
        _loadingSlots = false;
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
  }) async {
    if (_savingAppointment) return;

    if (date.isEmpty || time.isEmpty) {
      _showSnack('Tarih ve saat zorunludur.');
      return;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _savingAppointment = true;
    });

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/appointments/$appointmentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'appointment_status_id': statusId,
          'date': date,
          'time': time,
          'notes': notes,
          'no_sms': noSms,
          'no_reminder': noReminder,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Randevu güncellendi.', success: true);
        await _fetchAppointments();
      } else {
        String message =
            'Randevu güncellenemedi (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Randevu güncellenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _savingAppointment = false;
        });
      }
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
      _showSnack('Randevu işlemleri için paket alınız.');
      return;
    }

    if (date.isEmpty || time.isEmpty) {
      _showSnack('Tarih ve saat zorunludur.');
      return;
    }

    final statusId = appointmentStatusId ?? _defaultStatusId();
    if (statusId == null) {
      _showSnack('Randevu durumu bulunamadı.');
      return;
    }

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _creatingRebook = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/appointments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'appointment_status_id': statusId,
          'date': date,
          'time': time,
          'notes': notes,
          'no_sms': noSms,
          'no_reminder': noReminder,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('Yeni randevu oluşturuldu.', success: true);
        await _fetchAppointments();
      } else {
        String message =
            'Randevu oluşturulamadı (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Randevu oluşturulamadı: $e');
    } finally {
      if (mounted) {
        setState(() {
          _creatingRebook = false;
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

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

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

    final TextEditingController dateCtrl =
        TextEditingController(text: appt['date']?.toString() ?? '');
    final TextEditingController timeCtrl =
        TextEditingController(text: _formatTime(appt['time']));
    final TextEditingController notesCtrl =
        TextEditingController(text: appt['notes']?.toString() ?? '');
    final String customerName =
        (appt['customer']?['name'] ?? '').toString().isNotEmpty
            ? appt['customer']['name'].toString()
            : 'Müşteri #${appt["customer_id"] ?? ""}';

    bool localNoSms = _asBool(appt['no_sms']);
    bool localNoReminder = _asBool(appt['no_reminder']);

    List<Map<String, dynamic>> localSlots = [];
    String? localSlotsError;
    bool localLoadingSlots = false;
    String? localSelectedTime =
        timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null;
    int? localSelectedStatusId = statusId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int? effectiveStatusId =
                localSelectedStatusId ?? statusId ?? _defaultStatusId();

            Future<void> loadSlots() async {
              final dateInput = dateCtrl.text.trim();
              if (dateInput.isEmpty) {
                _showSnack('Önce tarih girin.');
                return;
              }

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
                return;
              }

              final formattedDate = _normalizeSlotDate(dateInput);
              setModalState(() {
                localLoadingSlots = true;
                localSlotsError = null;
                localSlots = [];
                localSelectedTime = null;
                timeCtrl.clear();
              });

              try {
                final response = await http.get(
                  Uri.parse(
                      '$apiBaseUrl/api/appointments/time-slots?date=$formattedDate'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                );

                if (response.statusCode == 200) {
                  final decoded = jsonDecode(response.body);
                  final data = decoded['data'] ?? decoded;
                  final slots = data is List
                      ? List<Map<String, dynamic>>.from(
                          data.map((e) => Map<String, dynamic>.from(e)))
                      : <Map<String, dynamic>>[];
                  setModalState(() {
                    localSlots = slots;
                    localSlotsError = null;
                    localLoadingSlots = false;
                  });
                } else {
                  setModalState(() {
                    localSlotsError =
                        'Saatler alınamadı (HTTP ${response.statusCode}).';
                    localLoadingSlots = false;
                  });
                }
              } catch (e) {
                setModalState(() {
                  localSlotsError = 'Saatler alınamadı: $e';
                  localLoadingSlots = false;
                });
              }
            }

            Future<void> pickDate() async {
              final today = DateTime.now();
              final minDate = DateTime(today.year, today.month, today.day);
              final maxDate = DateTime(today.year + 5, 12, 31);
              DateTime initial = _clampDate(
                _parseInputDateOrNow(dateCtrl.text),
                minDate,
                maxDate,
              );
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: minDate,
                lastDate: maxDate,
              );
              if (picked != null) {
                setModalState(() {
                  dateCtrl.text = _formatDateDisplay(picked);
                  localSelectedTime = null;
                  timeCtrl.clear();
                  localSlots = [];
                  localSlotsError = null;
                });
                await loadSlots();
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Randevu Düzenle',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dateCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Tarih',
                                hintText: 'Takvimden seçin',
                              ),
                              onTap: pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: timeCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Saat (seçim yapınız)',
                                hintText: 'Slot seçin',
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.schedule),
                            label: const Text('Saatleri Getir'),
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
                      DropdownButtonFormField<int>(
                        value: effectiveStatusId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Durum',
                          hintText: _loadingStatuses
                              ? 'Yükleniyor...'
                              : 'Durum seçin',
                          errorText: _statusesError,
                        ),
                        items: _appointmentStatuses
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s['id'] as int?,
                                child: Text(_localizedStatusLabel(s)),
                              ),
                            )
                            .toList(),
                        onChanged: _loadingStatuses
                            ? null
                            : (val) {
                                setModalState(() {
                                  localSelectedStatusId = val;
                                  _statusesError = null;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      if (localSlots.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: localSlots.map((slot) {
                            final time = slot['time']?.toString() ?? '';
                            final booked = slot['booked'] == true;
                            final selected = localSelectedTime == time;
                            return ChoiceChip(
                              label: Text(time),
                              selected: selected,
                              onSelected: booked
                                  ? null
                                  : (val) {
                                      if (val) {
                                        setModalState(() {
                                          localSelectedTime = time;
                                          timeCtrl.text = time;
                                          localSlotsError = null;
                                        });
                                      }
                                    },
                              disabledColor: Colors.grey.shade300,
                              selectedColor: Colors.green.shade200,
                              labelStyle: TextStyle(
                                color: booked
                                    ? Colors.grey
                                    : (selected
                                        ? Colors.black
                                        : Colors.black87),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Not'),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('SMS Gönderilmesin'),
                        value: localNoSms,
                        onChanged: (val) {
                          setModalState(() {
                            localNoSms = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Hatırlatıcı Gönderilmesin'),
                        value: localNoReminder,
                        onChanged: (val) {
                          setModalState(() {
                            localNoReminder = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (appointmentId == null ||
                                  customerId == null ||
                                  effectiveStatusId == null ||
                                  _savingAppointment)
                              ? null
                              : () async {
                                  Navigator.of(ctx).pop();
                                  await _updateAppointment(
                                    appointmentId: appointmentId,
                                    customerId: customerId,
                                    statusId: effectiveStatusId!,
                                    date: dateCtrl.text.trim(),
                                    time: (localSelectedTime ?? timeCtrl.text)
                                        .trim(),
                                    notes: notesCtrl.text.trim(),
                                    noSms: localNoSms,
                                    noReminder: localNoReminder,
                                  );
                                },
                          icon: _savingAppointment
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
                          label: const Text('Kaydet'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerInfo(Map<String, dynamic> appt) {
    final int? appointmentId = appt['id'] is int
        ? appt['id'] as int
        : int.tryParse(appt['id']?.toString() ?? '');
    if (appointmentId == null) {
      _showSnack('Randevu bilgisi bulunamadı.');
      return;
    }

    Map<String, dynamic>? info;
    String? loadError;

    Future<void> fetchInfo(StateSetter setModalState) async {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setModalState(() {
          loadError = 'Oturum bulunamadı.';
        });
        return;
      }

      setModalState(() {
        _loadingCustomerInfo = true;
        loadError = null;
      });

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/appointments/customer-info'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'appointment_id': appointmentId}),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'] ?? decoded;
          setModalState(() {
            info = Map<String, dynamic>.from(data);
            _loadingCustomerInfo = false;
          });
        } else {
          String message = 'Bilgiler alınamadı (HTTP ${response.statusCode}).';
          try {
            final decoded = jsonDecode(response.body);
            message = decoded['message']?.toString() ?? message;
          } catch (_) {}
          setModalState(() {
            loadError = message;
            _loadingCustomerInfo = false;
          });
        }
      } catch (e) {
        setModalState(() {
          loadError = 'Bilgiler alınamadı: $e';
          _loadingCustomerInfo = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (info == null && loadError == null && !_loadingCustomerInfo) {
              fetchInfo(setModalState);
            }
            final recent = (info?['recent_appointments'] is List)
                ? List<Map<String, dynamic>>.from(
                    (info!['recent_appointments'] as List)
                        .map((e) => Map<String, dynamic>.from(e)))
                : <Map<String, dynamic>>[];
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Müşteri Önizleme',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      if (_loadingCustomerInfo)
                        const LinearProgressIndicator(minHeight: 2),
                      if (loadError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  loadError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => fetchInfo(setModalState),
                              ),
                            ],
                          ),
                        ),
                      if (info != null) ...[
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          color: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade50,
                                  child: const Icon(Icons.person,
                                      color: Colors.blueGrey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${info?['customer_name'] ?? ''} ${info?['customer_lastname'] ?? ''}'
                                            .trim(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if ((info?['customer_phone'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.phone,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(info?['customer_phone'] ?? ''),
                                          ],
                                        ),
                                      if ((info?['customer_email'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(Icons.email,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(info?['customer_email'] ?? ''),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Son Randevular',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.history, size: 18, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (recent.isEmpty)
                          const Text('Kayıt bulunamadı.')
                        else
                          ...recent.map((r) {
                            final date = _formatDate(r['date']?.toString());
                            final time = _formatTime(r['time']);
                            final status = (r['status'] ?? '').toString();
                            final notes = (r['notes'] ?? '').toString();
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$date • $time',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        if (status.isNotEmpty)
                                          Chip(
                                            label: Text(
                                              status.toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            backgroundColor:
                                                Colors.blueGrey.shade50,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 0),
                                          ),
                                      ],
                                    ),
                                    if (notes.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        notes,
                                        style: const TextStyle(
                                            color: Colors.black87),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRebookSheet(Map<String, dynamic> appt) {
    final int? customerId = appt['customer_id'] is int
        ? appt['customer_id'] as int
        : int.tryParse(appt['customer_id']?.toString() ?? '');
    final customer = appt['customer'] is Map ? appt['customer'] : null;
    final String customerName = (customer?['name'] ?? '').toString().isNotEmpty
        ? customer['name'].toString()
        : 'Müşteri #${appt["customer_id"] ?? ""}';

    final TextEditingController dateCtrl = TextEditingController();
    final TextEditingController timeCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> loadSlots() async {
              final dateInput = dateCtrl.text.trim();
              if (dateInput.isEmpty) {
                _showSnack('Önce tarih girin.');
                return;
              }

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
                return;
              }

              final formattedDate = _normalizeSlotDate(dateInput);
              setModalState(() {
                localLoadingSlots = true;
                localSlotsError = null;
                localSlots = [];
                localSelectedTime = null;
                timeCtrl.clear();
              });

              try {
                final response = await http.get(
                  Uri.parse(
                      '$apiBaseUrl/api/appointments/time-slots?date=$formattedDate'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                );

                if (response.statusCode == 200) {
                  final decoded = jsonDecode(response.body);
                  final data = decoded['data'] ?? decoded;
                  final slots = data is List
                      ? List<Map<String, dynamic>>.from(
                          data.map((e) => Map<String, dynamic>.from(e)))
                      : <Map<String, dynamic>>[];
                  setModalState(() {
                    localSlots = slots;
                    localSlotsError = null;
                    localLoadingSlots = false;
                  });
                } else {
                  setModalState(() {
                    localSlotsError =
                        'Saatler alınamadı (HTTP ${response.statusCode}).';
                    localLoadingSlots = false;
                  });
                }
              } catch (e) {
                setModalState(() {
                  localSlotsError = 'Saatler alınamadı: $e';
                  localLoadingSlots = false;
                });
              }
            }

            Future<void> pickDate() async {
              final today = DateTime.now();
              final minDate = DateTime(today.year, today.month, today.day);
              final maxDate = DateTime(today.year + 5, 12, 31);
              DateTime initial = _clampDate(
                _parseInputDateOrNow(dateCtrl.text),
                minDate,
                maxDate,
              );
              final picked = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: minDate,
                lastDate: maxDate,
              );
              if (picked != null) {
                setModalState(() {
                  dateCtrl.text = _formatDateDisplay(picked);
                  localSelectedTime = null;
                  timeCtrl.clear();
                  localSlots = [];
                  localSlotsError = null;
                });
                await loadSlots();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yeniden Randevu Ver',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Tarih',
                              hintText: 'Takvimden seçin',
                            ),
                            onTap: pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: timeCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Saat (seçim yapınız)',
                              hintText: 'Slot seçin',
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.schedule),
                          label: const Text('Saatleri Getir'),
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
                    DropdownButtonFormField<int>(
                      value: localSelectedStatusId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Durum',
                        hintText:
                            _loadingStatuses ? 'Yükleniyor...' : 'Durum seçin',
                        errorText: _statusesError,
                      ),
                      items: _appointmentStatuses
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s['id'] as int?,
                              child: Text(_localizedStatusLabel(s)),
                            ),
                          )
                          .toList(),
                      onChanged: _loadingStatuses
                          ? null
                          : (val) {
                              setModalState(() {
                                localSelectedStatusId = val;
                                _statusesError = null;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    if (localSlots.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: localSlots.map((slot) {
                          final time = slot['time']?.toString() ?? '';
                          final booked = slot['booked'] == true;
                          final selected = localSelectedTime == time;
                          return ChoiceChip(
                            label: Text(time),
                            selected: selected,
                            onSelected: booked
                                ? null
                                : (val) {
                                    if (val) {
                                      setModalState(() {
                                        localSelectedTime = time;
                                        timeCtrl.text = time;
                                        localSlotsError = null;
                                      });
                                    }
                                  },
                            disabledColor: Colors.grey.shade300,
                            selectedColor: Colors.green.shade200,
                            labelStyle: TextStyle(
                              color: booked
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
                      decoration: const InputDecoration(labelText: 'Not'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('SMS gönderme'),
                      subtitle:
                          const Text('Bu randevu için SMS gönderimi kapalı'),
                      value: localNoSms,
                      onChanged: (val) {
                        setModalState(() {
                          localNoSms = val;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hatırlatma gönderme'),
                      subtitle: const Text(
                          'Bu randevu için hatırlatma bildirimi kapalı'),
                      value: localNoReminder,
                      onChanged: (val) {
                        setModalState(() {
                          localNoReminder = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (customerId == null || _creatingRebook)
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                await _createAppointmentForCustomer(
                                  customerId: customerId,
                                  date: dateCtrl.text.trim(),
                                  time: (localSelectedTime ?? timeCtrl.text)
                                      .trim(),
                                  notes: notesCtrl.text.trim(),
                                  noSms: localNoSms,
                                  noReminder: localNoReminder,
                                  appointmentStatusId: localSelectedStatusId,
                                );
                              },
                        icon: _creatingRebook
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.flash_on),
                        label: const Text('Yeni Randevu Oluştur'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final customer = appt['customer'] is Map ? appt['customer'] : null;
    final status =
        appt['appointment_status'] is Map ? appt['appointment_status'] : null;
    final rawCustomerName = customer?['name']?.toString() ?? '';
    final customerName = rawCustomerName.isNotEmpty
        ? rawCustomerName
        : 'Müşteri #${appt["customer_id"] ?? ""}';
    final statusName = status == null
        ? ''
        : _localizedStatusLabel(Map<String, dynamic>.from(status));
    final statusColor = _statusColor(status?['color']?.toString());
    final phone =
        (customer?['phone'] ?? customer?['formatted_phone'] ?? appt['phone'])
            ?.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditSheet(appt),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(Icons.event, color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    if (statusName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          statusName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      color: primaryColor,
                      tooltip: 'Müşteri önizleme',
                      onPressed: () => _showCustomerInfo(appt),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_task),
                      color: secondaryColor,
                      tooltip: 'Yeniden randevu ver',
                      onPressed: () => _showRebookSheet(appt),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: Colors.black87,
                      tooltip: 'Düzenle',
                      onPressed: () => _showEditSheet(appt),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(appt['date'])} • ${_formatTime(appt['time'])}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(phone),
                    ],
                  ),
                ],
                if ((appt['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    appt['notes'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentList() {
    if (_loadingList) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_appointments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Henüz randevu yok.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Randevular',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._appointments.map(_buildAppointmentCard).toList(),
      ],
    );
  }

  Widget _buildEditForm() {
    return const SizedBox.shrink();
  }

  Widget _buildFilterForm() {
    final activeCount = _activeFilters.length;
    if (!_showFilters) return const SizedBox.shrink();

    return _sectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    hintText: 'Müşteri adı',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _filterLastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Soyad',
                    hintText: 'Müşteri soyadı',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filterPhoneController,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              hintText: 'Telefon',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterDateFromController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç Tarihi',
                    hintText: 'Takvimden seçin',
                  ),
                  onTap: () async {
                    final today = DateTime.now();
                    final minDate = DateTime(today.year - 1, 1, 1);
                    final maxDate = DateTime(today.year + 5, 12, 31);
                    final initial = _clampDate(
                        _parseInputDateOrNow(_filterDateFromController.text),
                        minDate,
                        maxDate);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                    if (picked != null) {
                      setState(() {
                        _filterDateFromController.text =
                            _formatDateDisplay(picked);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _filterDateToController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş Tarihi',
                    hintText: 'Takvimden seçin',
                  ),
                  onTap: () async {
                    final today = DateTime.now();
                    final minDate = DateTime(today.year - 1, 1, 1);
                    final maxDate = DateTime(today.year + 5, 12, 31);
                    final initial = _clampDate(
                        _parseInputDateOrNow(_filterDateToController.text),
                        minDate,
                        maxDate);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                    if (picked != null) {
                      setState(() {
                        _filterDateToController.text =
                            _formatDateDisplay(picked);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterTimeFromController.text.isNotEmpty
                      ? _filterTimeFromController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç Saati',
                    hintText: 'HH:MM',
                  ),
                  items: _timeOptions
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterTimeFromController.text = val ?? '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterTimeToController.text.isNotEmpty
                      ? _filterTimeToController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş Saati',
                    hintText: 'HH:MM',
                  ),
                  items: _timeOptions
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterTimeToController.text = val ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search),
                  style: _mainButtonStyle(),
                  label: const Text('Filtrele'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _clearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Temizle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickForm() {
    if (!_hasUserPack) {
      return _sectionCard(
        title: 'Hızlı Randevu',
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmsPacksPage()),
              );
            },
            child: const Text('Paket Al'),
          ),
        ],
        child: const Text(
          'Randevu işlemleri için paket alınız.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (!_showQuickForm) return const SizedBox.shrink();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hızlı Randevu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showQuickForm = false;
                  });
                },
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.tips_and_updates, color: Colors.blueGrey),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Müşteri ve randevu bilgilerini tek ekrandan doldurup kaydedin.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Müşteri Bilgisi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quickNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad',
                          hintText: 'Örn: Ali',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickLastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Soyad',
                          hintText: 'Örn: Kara',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _selectedCountryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Ülke',
                    hintText:
                        _loadingCountries ? 'Yükleniyor...' : 'Ülke seçin',
                    errorText: _countriesError,
                  ),
                  items: _countries
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int?,
                          child: Text(
                            '${c['name'] ?? ''} (${c['phone_code'] ?? ''})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingCountries
                      ? null
                      : (val) {
                          setState(() {
                            _selectedCountryId = val;
                            _quickCountryIdController.text =
                                val != null ? '$val' : '';
                            _countriesError = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quickPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          hintText: 'Örn: 5554443322',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Opsiyonel',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Randevu Bilgisi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quickDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Tarih',
                          hintText: 'Takvimden seçin',
                        ),
                        onTap: _pickQuickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Saat',
                          hintText: 'Slot seçin',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadingSlots ? null : _fetchTimeSlots,
                      icon: _loadingSlots
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.schedule),
                      label: const Text('Uygun Saatleri Getir'),
                    ),
                    const SizedBox(width: 12),
                    if (_slotsError != null)
                      Expanded(
                        child: Text(
                          _slotsError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingSlots) const LinearProgressIndicator(minHeight: 2),
                if (_timeSlots.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((slot) {
                      final time = slot['time']?.toString() ?? '';
                      final booked = slot['booked'] == true;
                      final selected = _selectedSlotTime == time;
                      return ChoiceChip(
                        label: Text(time),
                        selected: selected,
                        onSelected: booked
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    _selectedSlotTime = time;
                                    _quickTimeController.text = time;
                                    _slotsError = null;
                                  });
                                }
                              },
                        disabledColor: Colors.grey.shade300,
                        selectedColor: Colors.green.shade200,
                        labelStyle: TextStyle(
                          color: booked
                              ? Colors.grey
                              : (selected ? Colors.black : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _quickNoteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Not',
                    hintText: 'Opsiyonel',
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('İlk randevu mu?'),
                  value: _quickIsFirstAppointment,
                  onChanged: (val) {
                    setState(() {
                      _quickIsFirstAppointment = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('SMS gönderme'),
                  subtitle: const Text('Bu randevu için SMS gönderimi kapalı'),
                  value: _quickNoSms,
                  onChanged: (val) {
                    setState(() {
                      _quickNoSms = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hatırlatma gönderme'),
                  subtitle:
                      const Text('Bu randevu için hatırlatma bildirimi kapalı'),
                  value: _quickNoReminder,
                  onChanged: (val) {
                    setState(() {
                      _quickNoReminder = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingQuick ? null : _submitQuickAppointment,
              style: _mainButtonStyle(),
              icon: _savingQuick
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.flash_on),
              label: Text(
                  _savingQuick ? 'Gönderiliyor...' : 'Quick Randevu Oluştur'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_today, color: primaryColor),
            ),
            const SizedBox(width: 10),
            const Text(
              'Randevular',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _navigateToDashboard,
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Dashboard',
          ),
          IconButton(
            onPressed: _fetchAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAppointments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          clipBehavior: Clip.none,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderHero(),
              _buildQuickForm(),
              _buildFilterForm(),
              const SizedBox(height: 16),
              _buildAppointmentList(),
            ],
          ),
        ),
      ),
    );
  }
}
