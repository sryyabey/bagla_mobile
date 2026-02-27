import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/appointment_date_utils.dart';
import '../dashboard_page.dart';
import 'sms_packs.dart';
import 'working_preferences.dart';
import '../widgets/main_nav.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

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
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = _mask(newValue.text);
    final digitsBefore = _digitCount(newValue.text, newValue.selection.end);
    final target = _offsetForDigits(masked, digitsBefore);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: target),
      composing: TextRange.empty,
    );
  }
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  AppLocalizations get loc => AppLocalizations.of(context);
  bool get _isIosPaymentRestricted =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
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
  bool _slotsRequested = false;
  String? _slotsError;
  List<Map<String, dynamic>> _timeSlots = [];
  String? _selectedSlotTime;
  List<Map<String, dynamic>> _countries = [];
  bool _loadingCountries = false;
  String? _countriesError;
  int? _selectedCountryId;
  final _phoneMaskFormatter = _PhoneMaskFormatter();
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
    IconData? leadingIcon,
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
            color: Colors.black.withValues(alpha: 0.03),
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
                            Row(
                              children: [
                                if (leadingIcon != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      leadingIcon,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (title == null && leadingIcon != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Icon(
                                leadingIcon,
                                size: 16,
                                color: primaryColor,
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
    final Color bgColor = isLight
        ? Colors.white.withValues(alpha: 0.16)
        : color.withValues(alpha: 0.08);
    final Color borderColor = isLight
        ? Colors.white.withValues(alpha: 0.3)
        : color.withValues(alpha: 0.2);
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
                    color: Colors.black.withValues(alpha: 0.05),
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
    final loc = AppLocalizations.of(context);
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
            color: Colors.black.withValues(alpha: 0.08),
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
                  children: [
                    Text(
                      loc.appointmentManagement,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.appointmentSubtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchAppointments,
                tooltip: loc.refresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statPill(loc.today, '$todayCount', Icons.event_available,
                  Colors.white70.withValues(alpha: 0.95)),
              const SizedBox(width: 12),
              _statPill(loc.total, '$totalCount', Icons.calendar_today,
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
                    _showSnack(
                      _isIosPaymentRestricted
                          ? loc.iosSmsPurchaseRestrictionMessage
                          : loc.appointmentsPackageRequired,
                    );
                    if (!_isIosPaymentRestricted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SmsPacksPage()),
                      );
                    }
                    return;
                  }
                  setState(() {
                    _showQuickForm = true;
                  });
                },
                style: buttonStyleOnLight,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(loc.quickAppointment),
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
                  _showFilters ? loc.hideFilter : loc.showFilter,
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
                label: Text(
                  loc.refreshList,
                  style: const TextStyle(color: Colors.white),
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
    if (widget.initialQuickDate != null) {
      _quickDateController.text = _normalizeSlotDate(widget.initialQuickDate!);
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
    return getAccessToken();
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
        _error = loc.appointmentsSessionMissingLogin;
      });
      return;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/api/appointments').replace(
          queryParameters: (filters ?? _activeFilters).isNotEmpty
              ? (filters ?? _activeFilters)
              : null);
      final response = await authGet(
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
          _error =
              loc.appointmentsFetchFailedStatus(response.statusCode.toString());
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
      final response = await authGet(
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
          _countriesError = loc.appointmentsCountriesFetchFailedStatus(
              response.statusCode.toString());
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
      final response = await authGet(
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
          _statusesError = loc.appointmentsStatusesFetchFailedStatus(
              response.statusCode.toString());
        });
      }
    } catch (e) {
      setState(() {
        _loadingStatuses = false;
        _statusesError = loc.appointmentsStatusesFetchFailed(e.toString());
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
      _showSnack(loc.appointmentsInvalidStartTime);
      return;
    }
    if (_filterTimeToController.text.trim().isNotEmpty &&
        !_isValidTime(_filterTimeToController.text.trim())) {
      _showSnack(loc.appointmentsInvalidEndTime);
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
      _showSnack(
        _isIosPaymentRestricted
            ? loc.iosSmsPurchaseRestrictionMessage
            : loc.appointmentsPackageRequired,
      );
      return;
    }

    final firstName = _quickNameController.text.trim();
    final lastName = _quickLastNameController.text.trim();
    final countryId = _selectedCountryId ??
        int.tryParse(_quickCountryIdController.text.trim());
    final phone = _quickPhoneController.text.trim();
    final email = _quickEmailController.text.trim();
    final date = _quickDateController.text.trim();
    final normalizedDate = _normalizeSlotDate(date);
    final time = (_selectedSlotTime ?? _quickTimeController.text).trim();
    final note = _quickNoteController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        countryId == null ||
        phone.isEmpty ||
        normalizedDate.isEmpty ||
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
      final response = await authPost(
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
          'date': normalizedDate,
          'time': time,
          'note': note,
          'is_first_appointment': _quickIsFirstAppointment ? 1 : 0,
          'no_sms': _quickNoSms,
          'no_reminder': _quickNoReminder,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(loc.appointmentsCreateSuccess, success: true);
        await _fetchAppointments();
        _resetQuickForm();
      } else {
        String message =
            loc.appointmentsCreateFailedStatus(response.statusCode.toString());
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.appointmentsCreateFailed(e.toString()));
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
    final loc = AppLocalizations.of(context);
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
    return AppointmentDateUtils.normalizeSlotDate(rawDate);
  }

  DateTime _parseInputDateOrNow(String value) {
    return AppointmentDateUtils.parseInputDateOrNow(value);
  }

  String? _normalizeDateToApi(String input) {
    return AppointmentDateUtils.normalizeDateToApi(input);
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
    return AppointmentDateUtils.formatDateDisplay(date);
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
      _showSnack(loc.appointmentsEnterDateFirst);
      return;
    }
    final formattedDate = _normalizeSlotDate(dateInput);

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
      _quickTimeController.clear();
    });

    try {
      final response = await authGet(
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
          _slotsError = loc.appointmentsSlotsFetchFailedStatus(
              response.statusCode.toString());
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

  Widget _buildWorkingPrefCallout() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.calendarWorkingHoursPrompt,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkingPreferencesPage(),
                      ),
                    );
                  },
                  child: Text(loc.setWorkingHours),
                ),
              ),
            ],
          );
        },
      ),
    );
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
      final response = await authPut(
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
        _showSnack(loc.appointmentsUpdateSuccess, success: true);
        await _fetchAppointments();
      } else {
        String message =
            loc.appointmentsUpdateFailedStatus(response.statusCode.toString());
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.appointmentsUpdateFailed(e.toString()));
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
      _showSnack(
        _isIosPaymentRestricted
            ? loc.iosSmsPurchaseRestrictionMessage
            : loc.appointmentsPackageRequired,
      );
      return;
    }

    if (date.isEmpty || time.isEmpty) {
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
      final response = await authPost(
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
        _showSnack(loc.appointmentsRebookSuccess, success: true);
        await _fetchAppointments();
      } else {
        String message =
            loc.appointmentsCreateFailedStatus(response.statusCode.toString());
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.appointmentsCreateFailed(e.toString()));
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

    final rawDate = appt['date']?.toString() ?? '';
    final TextEditingController dateCtrl = TextEditingController(
      text: rawDate.trim().isEmpty
          ? ''
          : _formatDateDisplay(_parseInputDateOrNow(rawDate)),
    );
    final TextEditingController timeCtrl =
        TextEditingController(text: _formatTime(appt['time']));
    final TextEditingController notesCtrl =
        TextEditingController(text: appt['notes']?.toString() ?? '');
    final String customerName = (appt['customer']?['name'] ?? '')
            .toString()
            .isNotEmpty
        ? appt['customer']['name'].toString()
        : loc.dashboardCustomerFallback(appt["customer_id"]?.toString() ?? '');

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
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.96,
      ),
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
                _showSnack(loc.appointmentsEnterDateFirst);
                return;
              }

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack(loc.appointmentsSessionMissingLogin);
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
                final response = await authGet(
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
                    localSlotsError = loc.appointmentsSlotsFetchFailedStatus(
                        response.statusCode.toString());
                    localLoadingSlots = false;
                  });
                }
              } catch (e) {
                setModalState(() {
                  localSlotsError =
                      loc.appointmentsSlotsFetchFailed(e.toString());
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

            final media = MediaQuery.of(ctx);
            final bottomInset =
                media.viewInsets.bottom + media.viewPadding.bottom + 16;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: bottomInset,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                              Text(
                                loc.editAppointment,
                                style: const TextStyle(
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
                              decoration: InputDecoration(
                                labelText: loc.date,
                                hintText: loc.calendarDateHint,
                              ),
                              onTap: pickDate,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.schedule),
                            label: Text(loc.getAvailableTimes),
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
                        initialValue: effectiveStatusId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: loc.status,
                          hintText: _loadingStatuses
                              ? loc.calendarLoading
                              : loc.appointmentsStatusSelectHint,
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
                        decoration: InputDecoration(labelText: loc.note),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text(loc.doNotSendSms),
                        value: localNoSms,
                        onChanged: (val) {
                          setModalState(() {
                            localNoSms = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: Text(loc.doNotSendReminder),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
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
                                    statusId: effectiveStatusId,
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
                          label: Text(loc.save),
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
      _showSnack(loc.appointmentsInfoMissing);
      return;
    }

    Map<String, dynamic>? info;
    String? loadError;

    Future<void> fetchInfo(StateSetter setModalState) async {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setModalState(() {
          loadError = loc.calendarSessionMissing;
        });
        return;
      }

      setModalState(() {
        _loadingCustomerInfo = true;
        loadError = null;
      });

      try {
        final response = await authPost(
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
          String message = loc.appointmentsInfoFetchFailedStatus(
              response.statusCode.toString());
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
          loadError = loc.appointmentsInfoFetchFailed(e.toString());
          _loadingCustomerInfo = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                          Text(
                            loc.customerPreview,
                            style: const TextStyle(
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
                          children: [
                            Text(
                              loc.recentAppointments,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.history,
                                size: 18, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (recent.isEmpty)
                          Text(loc.appointmentsNoRecords)
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
        : loc.dashboardCustomerFallback(appt["customer_id"]?.toString() ?? '');

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
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.96,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> loadSlots() async {
              final dateInput = dateCtrl.text.trim();
              if (dateInput.isEmpty) {
                _showSnack(loc.appointmentsEnterDateFirst);
                return;
              }

              final token = await _getToken();
              if (token == null || token.isEmpty) {
                _showSnack(loc.appointmentsSessionMissingLogin);
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
                final response = await authGet(
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
                    localSlotsError = loc.appointmentsSlotsFetchFailedStatus(
                        response.statusCode.toString());
                    localLoadingSlots = false;
                  });
                }
              } catch (e) {
                setModalState(() {
                  localSlotsError =
                      loc.appointmentsSlotsFetchFailed(e.toString());
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
              String? error,
            }) =>
                InputDecoration(
                  labelText: label,
                  hintText: hint,
                  errorText: error,
                  prefixIcon: prefix,
                  labelStyle: const TextStyle(fontSize: 13, color: muted),
                  hintStyle: const TextStyle(fontSize: 13, color: muted),
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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

            Widget minimalSwitch({
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              );
            }

            final media = MediaQuery.of(ctx);
            final bottomInset =
                media.viewInsets.bottom + media.viewPadding.bottom + 24;

            return SafeArea(
              top: false,
              child: Container(
                color: bg,
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
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.reschedule,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'TARIH & SAAT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dateCtrl,
                              readOnly: true,
                              decoration: field(
                                label: loc.date,
                                hint: loc.calendarDateHint,
                                prefix: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                              ),
                              onTap: pickDate,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.schedule, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      loc.getAvailableTimes,
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
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: danger.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: danger.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: danger,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  localSlotsError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: localSelectedStatusId,
                        isExpanded: true,
                        decoration: field(
                          label: loc.status,
                          hint: _loadingStatuses
                              ? loc.calendarLoading
                              : loc.appointmentsStatusSelectHint,
                          error: _statusesError,
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
                      if (localSlots.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: localSlots.map((slot) {
                            final time = slot['time']?.toString() ?? '';
                            final booked = slot['booked'] == true;
                            final selected = localSelectedTime == time;
                            return GestureDetector(
                              onTap: booked
                                  ? null
                                  : () => setModalState(() {
                                        localSelectedTime = time;
                                        timeCtrl.text = time;
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
                                  time,
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
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEEEEEE),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: field(
                          label: '',
                          hint: 'Not ekleyin...',
                        ).copyWith(labelText: null),
                      ),
                      const SizedBox(height: 16),
                      minimalSwitch(
                        title: loc.doNotSendSms,
                        subtitle: loc.smsOffForAppointment,
                        value: localNoSms,
                        onChanged: (val) {
                          setModalState(() {
                            localNoSms = val;
                          });
                        },
                      ),
                      minimalSwitch(
                        title: loc.doNotSendReminder,
                        subtitle: loc.reminderOffForAppointment,
                        value: localNoReminder,
                        onChanged: (val) {
                          setModalState(() {
                            localNoReminder = val;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                          child: _creatingRebook
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  loc.rescheduleAppointment,
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
        : loc.dashboardCustomerFallback(appt["customer_id"]?.toString() ?? '');
    final statusName = status == null
        ? ''
        : _localizedStatusLabel(Map<String, dynamic>.from(status));
    final statusColor = _statusColor(status?['color']?.toString());
    final phone =
        (customer?['phone'] ?? customer?['formatted_phone'] ?? appt['phone'])
            ?.toString();
    Widget actionBtn({
      required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                      backgroundColor: statusColor.withValues(alpha: 0.15),
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
                              accentColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.2),
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
                    actionBtn(
                      icon: Icons.visibility,
                      color: primaryColor,
                      tooltip: loc.appointmentsCustomerPreviewTooltip,
                      onPressed: () => _showCustomerInfo(appt),
                    ),
                    const SizedBox(width: 6),
                    actionBtn(
                      icon: Icons.add_task,
                      color: secondaryColor,
                      tooltip: loc.appointmentsRebookTooltip,
                      onPressed: () => _showRebookSheet(appt),
                    ),
                    const SizedBox(width: 6),
                    actionBtn(
                      icon: Icons.edit,
                      color: Colors.black87,
                      tooltip: loc.appointmentsEditTooltip,
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
      return _sectionCard(
        leadingIcon: Icons.error_outline,
        title: loc.appointmentsTitle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_appointments.isEmpty) {
      return _sectionCard(
        leadingIcon: Icons.event_busy_outlined,
        title: loc.appointmentsTitle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(loc.appointmentsEmpty),
        ),
      );
    }

    return _sectionCard(
      leadingIcon: Icons.event_note_outlined,
      title: loc.appointmentsTitle,
      subtitle: loc.appointmentsCountLabel(_appointments.length.toString()),
      child: Column(
        children: _appointments.map(_buildAppointmentCard).toList(),
      ),
    );
  }

  Widget _buildFilterForm() {
    if (!_showFilters) return const SizedBox.shrink();

    return _sectionCard(
      leadingIcon: Icons.filter_alt_outlined,
      title: loc.showFilter,
      subtitle: loc.appointmentsFilterSubtitle,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterNameController,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsFieldName,
                    hintText: loc.appointmentsFieldNameFilterHint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _filterLastNameController,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsFieldLastName,
                    hintText: loc.appointmentsFieldLastNameFilterHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filterPhoneController,
            decoration: InputDecoration(
              labelText: loc.appointmentsFieldPhone,
              hintText: loc.appointmentsFieldPhone,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterDateFromController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsStartDate,
                    hintText: loc.calendarDateHint,
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
                  decoration: InputDecoration(
                    labelText: loc.appointmentsEndDate,
                    hintText: loc.calendarDateHint,
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
                  initialValue: _filterTimeFromController.text.isNotEmpty
                      ? _filterTimeFromController.text
                      : null,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsStartTime,
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
                  initialValue: _filterTimeToController.text.isNotEmpty
                      ? _filterTimeToController.text
                      : null,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsEndTime,
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
                  label: Text(loc.showFilter),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _clearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
                child: Text(loc.appointmentsClear),
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
        title: loc.quickAppointmentTitle,
        actions: [
          if (!_isIosPaymentRestricted)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmsPacksPage()),
                );
              },
              child: Text(loc.appointmentsBuyPackage),
            ),
        ],
        child: Text(
          _isIosPaymentRestricted
              ? loc.iosSmsPurchaseRestrictionMessage
              : loc.appointmentsPackageRequired,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (!_showQuickForm) return const SizedBox.shrink();

    return _sectionCard(
      leadingIcon: Icons.add_circle_outline,
      title: loc.quickAppointmentTitle,
      subtitle: loc.quickAppointmentSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: loc.appointmentsClose,
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _showQuickForm = false;
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates, color: Colors.blueGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.quickAppointmentSubtitle,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            loc.customerInfo,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                        decoration: InputDecoration(
                          labelText: loc.appointmentsFieldName,
                          hintText: loc.appointmentsFieldNameHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickLastNameController,
                        decoration: InputDecoration(
                          labelText: loc.appointmentsFieldLastName,
                          hintText: loc.appointmentsFieldLastNameHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCountryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: loc.appointmentsCountry,
                    hintText: _loadingCountries
                        ? loc.calendarLoading
                        : loc.appointmentsSelectCountry,
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
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d()\s]'),
                          ),
                          _phoneMaskFormatter,
                        ],
                        decoration: InputDecoration(
                          labelText: loc.appointmentsFieldPhone,
                          hintText: loc.appointmentsFieldPhoneHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: loc.emailLabel,
                          hintText: loc.appointmentsFieldEmailHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            loc.appointmentInfo,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                        decoration: InputDecoration(
                          labelText: loc.date,
                          hintText: loc.calendarDateHint,
                        ),
                        onTap: _pickQuickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _quickTimeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: loc.timeSelect,
                          hintText: loc.calendarTimeSlotHint,
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
                      label: Text(loc.getAvailableTimes),
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
                if (_slotsRequested &&
                    !_loadingSlots &&
                    _slotsError == null &&
                    _timeSlots.isEmpty)
                  _buildWorkingPrefCallout(),
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
                  decoration: InputDecoration(
                    labelText: loc.note,
                    hintText: loc.appointmentsFieldEmailHint,
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.appointmentsFirstAppointment),
                  value: _quickIsFirstAppointment,
                  onChanged: (val) {
                    setState(() {
                      _quickIsFirstAppointment = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.doNotSendSms),
                  subtitle: Text(loc.smsOffForAppointment),
                  value: _quickNoSms,
                  onChanged: (val) {
                    setState(() {
                      _quickNoSms = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.appointmentsReminderDisableTitle),
                  subtitle: Text(loc.reminderOffForAppointment),
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
                  : const Icon(Icons.event_available),
              label: Text(
                _savingQuick
                    ? loc.appointmentsSubmitting
                    : loc.quickAppointmentTitle,
              ),
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
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today, color: primaryColor),
            ),
            const SizedBox(width: 10),
            Text(
              loc.appointmentsTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (widget.showBottomNav)
            IconButton(
              onPressed: _navigateToDashboard,
              icon: const Icon(Icons.home_outlined),
              tooltip: loc.appointmentsHomeTooltip,
            ),
          IconButton(
            onPressed: _fetchAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: loc.refresh,
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
      bottomNavigationBar: widget.showBottomNav
          ? MainNavBar(
              currentIndex: 1,
              onIndexSelected: widget.onTabSelected,
            )
          : null,
    );
  }
}
