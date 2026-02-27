import 'dart:async';
import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:bagla_mobile/main_tabs_page.dart';
import 'package:bagla_mobile/pages/sms_packs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _PhoneMaskFormatter extends TextInputFormatter {
  static final RegExp _digitsOnly = RegExp(r'\D');

  static String applyMask(String raw) {
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
    final masked = applyMask(newValue.text);
    final digitsBefore = _digitCount(newValue.text, newValue.selection.end);
    final target = _offsetForDigits(masked, digitsBefore);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: target),
      composing: TextRange.empty,
    );
  }
}

class _CustomersPageState extends State<CustomersPage> {
  AppLocalizations get loc => AppLocalizations.of(context);

  // Modern Color Palette
  static const Color _backgroundColor = Color(0xFFF7F9FC);
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _primaryLight = Color(0xFFEEF2FF);
  static const Color _secondaryColor = Color(0xFF8B5CF6);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _dangerColor = Color(0xFFEF4444);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;
  String? _error;

  int _currentPage = 1;
  int _lastPage = 1;
  final int _perPage = 20;
  final List<Map<String, dynamic>> _customers = [];
  String _selectedLetter = '#';
  static const List<String> _alphabetLetters = [
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
  static const Set<String> _alphabetLetterSet = {
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
  };

  List<Map<String, dynamic>>? _visibleCustomersCache;
  int _visibleCustomersCacheStamp = -1;
  String _visibleCustomersCacheLetter = '';
  int _customersMutationStamp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomers(reset: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    return getAccessToken();
  }

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

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? _successColor : _dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _customerName(Map<String, dynamic> customer) {
    return customer['name']?.toString().trim() ?? '';
  }

  String _normalizeInitial(String char) {
    const map = {
      'a': 'A',
      'b': 'B',
      'c': 'C',
      'ç': 'Ç',
      'd': 'D',
      'e': 'E',
      'f': 'F',
      'g': 'G',
      'ğ': 'Ğ',
      'h': 'H',
      'ı': 'I',
      'i': 'İ',
      'j': 'J',
      'k': 'K',
      'l': 'L',
      'm': 'M',
      'n': 'N',
      'o': 'O',
      'ö': 'Ö',
      'p': 'P',
      'r': 'R',
      's': 'S',
      'ş': 'Ş',
      't': 'T',
      'u': 'U',
      'ü': 'Ü',
      'v': 'V',
      'y': 'Y',
      'z': 'Z',
    };
    final lower = char.toLowerCase();
    return map[lower] ?? char.toUpperCase();
  }

  String _initialForName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '#';
    for (int i = 0; i < trimmed.length; i++) {
      final ch = trimmed[i];
      final normalized = _normalizeInitial(ch);
      if (_alphabetLetterSet.contains(normalized) && normalized != '#') {
        return normalized;
      }
    }
    return '#';
  }

  List<Map<String, dynamic>> _visibleCustomers() {
    if (_visibleCustomersCache != null &&
        _visibleCustomersCacheStamp == _customersMutationStamp &&
        _visibleCustomersCacheLetter == _selectedLetter) {
      return _visibleCustomersCache!;
    }
    final sorted = [..._customers];
    sorted.sort((a, b) {
      final an = _customerName(a).toLowerCase();
      final bn = _customerName(b).toLowerCase();
      return an.compareTo(bn);
    });
    final result = _selectedLetter == '#'
        ? sorted
        : sorted
            .where((c) => _initialForName(_customerName(c)) == _selectedLetter)
            .toList();
    _visibleCustomersCache = result;
    _visibleCustomersCacheStamp = _customersMutationStamp;
    _visibleCustomersCacheLetter = _selectedLetter;
    return result;
  }

  Future<void> _fetchCustomers({required bool reset}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = loc.customersSessionMissing;
      });
      return;
    }

    final pageToLoad = reset ? 1 : (_currentPage + 1);
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/customers').replace(
          queryParameters: {
            'search': _searchController.text.trim(),
            'per_page': _perPage.toString(),
            'sort_field': 'id',
            'sort_direction': 'desc',
            'page': pageToLoad.toString(),
          },
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        final Map<String, dynamic> meta =
            (decoded['meta'] is Map<String, dynamic>)
                ? Map<String, dynamic>.from(decoded['meta'])
                : <String, dynamic>{};

        final fetched =
            dataList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (!mounted) return;
        setState(() {
          if (reset) {
            _customers
              ..clear()
              ..addAll(fetched);
          } else {
            _customers.addAll(fetched);
          }
          _customersMutationStamp++;
          _currentPage = (meta['current_page'] as int?) ?? pageToLoad;
          _lastPage = (meta['last_page'] as int?) ?? _currentPage;
          _loading = false;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _error = loc.customersLoadFailedStatus(response.statusCode);
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.customersLoadFailed(e.toString());
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final id = customer['id'];
    if (id == null) return;
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.customersSessionMissing);
      return;
    }

    try {
      final response = await authDelete(
        Uri.parse('$apiBaseUrl/api/customers/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        _showSnack(loc.customersDeleteSuccess, success: true);
        await _fetchCustomers(reset: true);
      } else {
        String message = loc.customersDeleteFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.customersDeleteFailed(e.toString()));
    }
  }

  Future<void> _saveCustomer({
    Map<String, dynamic>? existing,
    required String name,
    required String phone,
    required String email,
    required String address,
    required String notes,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.customersSessionMissing);
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().isEmpty ? null : email.trim(),
      'address': address.trim().isEmpty ? null : address.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
    };

    final customerId = existing?['id'];

    try {
      final response = existing == null
          ? await authPost(
              Uri.parse('$apiBaseUrl/api/customers'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
          : await authPut(
              Uri.parse('$apiBaseUrl/api/customers/$customerId'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack(
          existing == null
              ? loc.customersCreateSuccess
              : loc.customersUpdateSuccess,
          success: true,
        );
        await _fetchCustomers(reset: true);
      } else {
        String message = loc.customersSaveFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.customersSaveFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openCustomerForm({Map<String, dynamic>? customer}) async {
    final nameController =
        TextEditingController(text: customer?['name']?.toString() ?? '');
    final phoneController = TextEditingController(
      text: _PhoneMaskFormatter.applyMask(customer?['phone']?.toString() ?? ''),
    );
    final emailController =
        TextEditingController(text: customer?['email']?.toString() ?? '');
    final addressController =
        TextEditingController(text: customer?['address']?.toString() ?? '');
    final notesController =
        TextEditingController(text: customer?['notes']?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          customer == null ? Icons.person_add : Icons.edit,
                          color: _primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer == null
                                  ? loc.customersAdd
                                  : loc.customersEdit,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              customer == null
                                  ? loc.customersAddSubtitle
                                  : loc.customersEditSubtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  _buildTextField(
                    controller: nameController,
                    label: loc.customersName,
                    icon: Icons.person_outline,
                    required: true,
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  _buildTextField(
                    controller: phoneController,
                    label: loc.customersPhone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    required: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9() ]')),
                      _PhoneMaskFormatter(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  _buildTextField(
                    controller: emailController,
                    label: loc.customersEmail,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Address Field
                  _buildTextField(
                    controller: addressController,
                    label: loc.customersAddress,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Notes Field
                  _buildTextField(
                    controller: notesController,
                    label: loc.customersNotes,
                    icon: Icons.note_outlined,
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty ||
                                  phoneController.text.trim().isEmpty) {
                                _showSnack(loc.customersValidation);
                                return;
                              }
                              Navigator.of(ctx).pop();
                              await _saveCustomer(
                                existing: customer,
                                name: nameController.text,
                                phone: phoneController.text,
                                email: emailController.text,
                                address: addressController.text,
                                notes: notesController.text,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_saving) ...[
                            const Icon(Icons.check_circle_outline),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _saving ? loc.customersSaving : loc.customersSave,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int minLines = 1,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: _dangerColor),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintStyle:
                  TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> customer) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_outlined, color: _dangerColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.customersDeleteConfirmTitle,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(loc.customersDeleteConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                loc.customersCancel,
                style: const TextStyle(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(loc.customersDelete),
            ),
          ],
        );
      },
    );
    if (approved == true) {
      await _deleteCustomer(customer);
    }
  }

  Widget _customerCard(Map<String, dynamic> customer) {
    final name = customer['name']?.toString() ?? '-';
    final phone = customer['phone']?.toString() ?? '-';
    final email = customer['email']?.toString() ?? '';
    final address = customer['address']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openCustomerForm(customer: customer),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name and Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Row(
                      children: [
                        IconButton(
                          tooltip: loc.customersEdit,
                          onPressed: () =>
                              _openCustomerForm(customer: customer),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: _primaryLight,
                            foregroundColor: _primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: loc.customersDelete,
                          onPressed: () => _confirmDelete(customer),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                _dangerColor.withValues(alpha: 0.1),
                            foregroundColor: _dangerColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Email and Address
                if (email.isNotEmpty || address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        if (email.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (email.isNotEmpty && address.isNotEmpty)
                          const SizedBox(height: 6),
                        if (address.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],

                // Appointments Button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CustomerAppointmentsSheet(
                          customer: customer,
                          tokenGetter: _getToken,
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(loc.customersAppointments),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: const BorderSide(color: _primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canLoadMore = !_loadingMore && _currentPage < _lastPage;
    final visibleCustomers = _visibleCustomers();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _cardColor,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text(
          loc.customersTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: loc.dashboardHome,
            onPressed: _goHome,
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: loc.customersRefresh,
            onPressed: () => _fetchCustomers(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _openCustomerForm(),
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(
          loc.customersAdd,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: _cardColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    if (_selectedLetter != '#') {
                      setState(() {
                        _selectedLetter = '#';
                      });
                    }
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 350), () {
                      _fetchCustomers(reset: true);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: loc.customersSearchHint,
                    prefixIcon: const Icon(Icons.search, color: _textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Customer List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchCustomers(reset: true),
                color: _primaryColor,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          _dangerColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: _dangerColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _fetchCustomers(reset: true),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(loc.customersRetry),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _customers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _primaryLight,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: _primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      loc.customersEmpty,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 34,
                                    margin:
                                        const EdgeInsets.fromLTRB(8, 8, 4, 12),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children:
                                            _alphabetLetters.map((letter) {
                                          final selected =
                                              _selectedLetter == letter;
                                          return InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () {
                                              if (_selectedLetter == letter) {
                                                return;
                                              }
                                              setState(() {
                                                _selectedLetter = letter;
                                              });
                                            },
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? _primaryColor
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                letter,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: selected
                                                      ? Colors.white
                                                      : _textSecondary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: visibleCustomers.isEmpty
                                        ? ListView(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 24, 16, 100),
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: _primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _selectedLetter == '#'
                                                      ? loc.customersEmpty
                                                      : loc
                                                          .customersEmptyForLetter(
                                                          _selectedLetter,
                                                        ),
                                                  style: const TextStyle(
                                                    color: _textSecondary,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (canLoadMore)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 12),
                                                  child: OutlinedButton(
                                                    onPressed: () =>
                                                        _fetchCustomers(
                                                            reset: false),
                                                    child: Text(
                                                      loc.customersLoadMore,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 8, 16, 100),
                                            itemCount: visibleCustomers.length +
                                                (_loadingMore ? 1 : 0) +
                                                (canLoadMore ? 1 : 0),
                                            itemBuilder: (context, index) {
                                              if (index <
                                                  visibleCustomers.length) {
                                                return _customerCard(
                                                  visibleCustomers[index],
                                                );
                                              }
                                              final footerIndex = index -
                                                  visibleCustomers.length;
                                              if (_loadingMore &&
                                                  footerIndex == 0) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 16),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _fetchCustomers(
                                                          reset: false),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 16,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    loc.customersLoadMore,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerAppointmentsSheet extends StatefulWidget {
  const _CustomerAppointmentsSheet({
    required this.customer,
    required this.tokenGetter,
  });

  final Map<String, dynamic> customer;
  final Future<String?> Function() tokenGetter;

  @override
  State<_CustomerAppointmentsSheet> createState() =>
      _CustomerAppointmentsSheetState();
}

class _CustomerAppointmentsSheetState
    extends State<_CustomerAppointmentsSheet> {
  AppLocalizations get loc => AppLocalizations.of(context);
  bool get _isIosPaymentRestricted =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _primaryLight = Color(0xFFEEF2FF);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _dangerColor = Color(0xFFEF4444);

  bool _loading = true;
  bool _creating = false;
  String? _error;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAppointments();
    });
  }

  String _fmtDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    try {
      final d = DateTime.parse(value);
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      return '$day.$month.${d.year}';
    } catch (_) {
      return value;
    }
  }

  String _fmtTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? _successColor : _dangerColor,
      ),
    );
  }

  Future<bool> _ensureActivePackage({bool navigateOnAndroid = true}) async {
    final token = await widget.tokenGetter();
    if (token == null || token.isEmpty) {
      _showSnack(loc.customersSessionMissing);
      return false;
    }

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/appointments')
            .replace(queryParameters: {'per_page': '1'}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        _showSnack(loc.appointmentsFetchFailedStatus(response.statusCode));
        return false;
      }

      final decoded = jsonDecode(response.body);
      final rawData = decoded['data'] ?? decoded;
      bool? extractedUserPack;
      if (decoded is Map) {
        final candidate = decoded['user_pack'] ?? decoded['userPack'];
        if (candidate != null) {
          extractedUserPack = candidate == true || candidate.toString() == '1';
        }
      }
      if (rawData is Map) {
        final candidate = rawData['user_pack'] ?? rawData['userPack'];
        if (candidate != null) {
          extractedUserPack = candidate == true || candidate.toString() == '1';
        }
      }

      final hasUserPack = extractedUserPack ?? true;
      if (hasUserPack) return true;

      if (_isIosPaymentRestricted) {
        _showSnack(loc.iosSmsPurchaseRestrictionMessage);
        return false;
      }

      _showSnack(loc.appointmentsPackageRequired);
      if (navigateOnAndroid && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SmsPacksPage()),
        );
      }
      return false;
    } catch (e) {
      _showSnack(loc.appointmentsFetchFailed(e.toString()));
      return false;
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await widget.tokenGetter();
    final customerId = widget.customer['id'];
    if (token == null || token.isEmpty || customerId == null) {
      setState(() {
        _loading = false;
        _error = loc.customersSessionMissing;
      });
      return;
    }

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/customers/$customerId/appointments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['data'] as List? ?? [];
        if (!mounted) return;
        setState(() {
          _appointments =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              loc.customersAppointmentsLoadFailedStatus(response.statusCode);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.customersAppointmentsLoadFailed(e.toString());
        _loading = false;
      });
    }
  }

  Future<void> _openCreateAppointmentDialog() async {
    final canCreate = await _ensureActivePackage();
    if (!canCreate) return;
    if (!mounted) return;

    DateTime selectedDate = DateTime.now();
    String? selectedSlotTime;
    List<Map<String, dynamic>> localSlots = [];
    bool slotsLoading = false;
    String? slotsError;
    bool initialSlotsRequested = false;
    final noteController = TextEditingController();
    bool isFirst = false;
    bool noSms = false;
    bool noReminder = false;

    String toApiDate(DateTime date) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> fetchSlotsForSelectedDate() async {
              final token = await widget.tokenGetter();
              if (token == null || token.isEmpty) {
                setModalState(() {
                  slotsError = loc.customersSessionMissing;
                  slotsLoading = false;
                  localSlots = [];
                });
                return;
              }

              setModalState(() {
                slotsLoading = true;
                slotsError = null;
                localSlots = [];
                selectedSlotTime = null;
              });

              try {
                final response = await authGet(
                  Uri.parse('$apiBaseUrl/api/appointments/time-slots')
                      .replace(queryParameters: {
                    'date': toApiDate(selectedDate),
                  }),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Accept': 'application/json',
                  },
                );

                if (response.statusCode == 200) {
                  final decoded = jsonDecode(response.body);
                  final data = decoded['data'] ?? decoded;
                  final parsed = data is List
                      ? List<Map<String, dynamic>>.from(
                          data.map((e) => Map<String, dynamic>.from(e)),
                        )
                      : <Map<String, dynamic>>[];
                  setModalState(() {
                    localSlots = parsed;
                    slotsLoading = false;
                  });
                } else {
                  setModalState(() {
                    slotsLoading = false;
                    slotsError = loc.appointmentsSlotsFetchFailedStatus(
                      response.statusCode.toString(),
                    );
                  });
                }
              } catch (e) {
                setModalState(() {
                  slotsLoading = false;
                  slotsError = loc.appointmentsSlotsFetchFailed(e.toString());
                });
              }
            }

            if (!initialSlotsRequested) {
              initialSlotsRequested = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fetchSlotsForSelectedDate();
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.customersCreateAppointment,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.customer['name']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Selector
                            Container(
                              decoration: BoxDecoration(
                                color: _primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        _primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  loc.customersAppointmentDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 1),
                                    ),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: _primaryColor,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedDate = picked;
                                    });
                                    await fetchSlotsForSelectedDate();
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Time Slots
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 18, color: _textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  loc.customersAppointmentTime,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (slotsLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (slotsError != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _dangerColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: _dangerColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        slotsError!,
                                        style: const TextStyle(
                                            color: _dangerColor),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (localSlots.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _textSecondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: _textSecondary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        loc.appointmentsSelectAvailableTime,
                                        style: const TextStyle(
                                            color: _textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: localSlots.map((slot) {
                                  final time = slot['time']?.toString() ?? '';
                                  final booked = slot['booked'] == true ||
                                      slot['booked'] == 1 ||
                                      slot['booked']?.toString() == '1';
                                  final selected = selectedSlotTime == time;
                                  return InkWell(
                                    onTap: booked
                                        ? null
                                        : () {
                                            setModalState(() {
                                              selectedSlotTime = time;
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _primaryColor
                                            : (booked
                                                ? _textSecondary.withValues(
                                                    alpha: 0.1)
                                                : _primaryLight),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? _primaryColor
                                              : (booked
                                                  ? _textSecondary.withValues(
                                                      alpha: 0.2)
                                                  : _primaryColor.withValues(
                                                      alpha: 0.3)),
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : (booked
                                                  ? _textSecondary
                                                  : _primaryColor),
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                            const SizedBox(height: 20),

                            // Note Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.note_outlined,
                                        size: 18, color: _textSecondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      loc.customersAppointmentNote,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: TextField(
                                    controller: noteController,
                                    minLines: 3,
                                    maxLines: 5,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(16),
                                      hintText:
                                          loc.customersAppointmentNoteHint,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Switches
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    value: isFirst,
                                    onChanged: (v) =>
                                        setModalState(() => isFirst = v),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.star_outline,
                                            size: 18, color: _textSecondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          loc.customersFirstAppointment,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    activeThumbColor: _primaryColor,
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    value: noSms,
                                    onChanged: (v) =>
                                        setModalState(() => noSms = v),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.sms_outlined,
                                            size: 18, color: _textSecondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          loc.customersNoSms,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    activeThumbColor: _primaryColor,
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    value: noReminder,
                                    onChanged: (v) =>
                                        setModalState(() => noReminder = v),
                                    title: Row(
                                      children: [
                                        const Icon(
                                            Icons.notifications_off_outlined,
                                            size: 18,
                                            color: _textSecondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          loc.customersNoReminder,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    activeThumbColor: _primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(loc.customersCancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _creating
                                  ? null
                                  : () async {
                                      final navigator = Navigator.of(ctx);
                                      setState(() {
                                        _creating = true;
                                      });
                                      final canCreate =
                                          await _ensureActivePackage(
                                        navigateOnAndroid: false,
                                      );
                                      if (!canCreate) {
                                        if (!mounted) return;
                                        setState(() {
                                          _creating = false;
                                        });
                                        return;
                                      }
                                      final token = await widget.tokenGetter();
                                      final customerId = widget.customer['id'];
                                      if (token == null ||
                                          token.isEmpty ||
                                          customerId == null) {
                                        if (!mounted) return;
                                        setState(() {
                                          _creating = false;
                                        });
                                        navigator.pop(false);
                                        return;
                                      }

                                      final date =
                                          '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                                      final time =
                                          selectedSlotTime?.trim() ?? '';
                                      if (time.isEmpty) {
                                        setState(() {
                                          _creating = false;
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(loc
                                                .appointmentsSelectAvailableTime),
                                            backgroundColor: _dangerColor,
                                          ),
                                        );
                                        return;
                                      }

                                      try {
                                        final response = await authPost(
                                          Uri.parse(
                                            '$apiBaseUrl/api/customers/$customerId/appointments',
                                          ),
                                          headers: {
                                            'Authorization': 'Bearer $token',
                                            'Accept': 'application/json',
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode({
                                            'date': date,
                                            'time': time,
                                            'note': noteController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : noteController.text.trim(),
                                            'is_first_appointment': isFirst,
                                            'no_sms': noSms,
                                            'no_reminder': noReminder,
                                          }),
                                        );

                                        if (!mounted) return;
                                        setState(() {
                                          _creating = false;
                                        });

                                        if (response.statusCode == 200 ||
                                            response.statusCode == 201) {
                                          navigator.pop(true);
                                        } else {
                                          navigator.pop(false);
                                        }
                                      } catch (_) {
                                        if (!mounted) return;
                                        setState(() {
                                          _creating = false;
                                        });
                                        navigator.pop(false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_creating) ...[
                                    const Icon(Icons.check, size: 20),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _creating
                                        ? loc.customersSaving
                                        : loc.customersSave,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

    if (created == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(loc.customersCreateAppointmentSuccess)),
            ],
          ),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      await _fetchAppointments();
    } else if (created == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(loc.customersCreateAppointmentFailed)),
            ],
          ),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.customer['name']?.toString() ?? '-';
    final Widget bodyContent;

    if (_loading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: _dangerColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _dangerColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchAppointments,
              icon: const Icon(Icons.refresh),
              label: Text(loc.customersRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_appointments.isEmpty) {
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.customersNoAppointments,
              style: const TextStyle(
                fontSize: 16,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      );
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appt = _appointments[index];
          final status = appt['appointment_status'] is Map
              ? (appt['appointment_status'] as Map)['name']?.toString() ??
                  (appt['appointment_status'] as Map)['alias']?.toString() ??
                  ''
              : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryLight,
                  _primaryLight.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _fmtTime(appt['time']?.toString()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtDate(appt['date']?.toString()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _textPrimary,
                        ),
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: _textSecondary,
                ),
              ],
            ),
          );
        },
      );
    }

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: const BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header (always visible)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.customersAppointments,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _creating ? null : _openCreateAppointmentDialog,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: loc.customersCreateAppointment,
                    ),
                  ],
                ),
              ),
              Expanded(child: bodyContent),
            ],
          ),
        ),
      ),
    );
  }
}
