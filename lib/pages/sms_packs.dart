import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_html/flutter_html.dart';

import '../config.dart';
import '../login_page.dart';
import '../auth.dart';
import '../dashboard_page.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

class SmsPacksPage extends StatefulWidget {
  const SmsPacksPage({super.key});

  @override
  State<SmsPacksPage> createState() => _SmsPacksPageState();
}

class _SmsPacksPageState extends State<SmsPacksPage> {
  AppLocalizations get loc => AppLocalizations.of(context);
  bool get _isAndroidPurchaseSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isPurchaseRestricted => !_isAndroidPurchaseSupported;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  int _currentStep = 0;

  List<String> _types = [];
  Map<String, List<Map<String, dynamic>>> _packsByType = {};
  String? _selectedType;
  Map<String, dynamic>? _selectedPack;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _districts = [];
  bool _loadingCountries = true;
  bool _loadingAddresses = true;
  bool _loadingCities = false;
  bool _loadingDistricts = false;
  String? _countriesError;
  String? _addressesError;
  String? _citiesError;
  String? _districtsError;
  int? _selectedAddressId;
  int? _selectedCountryId;
  int? _selectedCityId;
  int? _selectedDistrictId;
  String? _selectedPhoneCode;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _taxOfficeController = TextEditingController();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _addressTitleController = TextEditingController();
  String _selectedPayment = 'credit_card';
  bool _agreementChecked = false;
  Timer? _paymentTimer;
  String? _contractTitle;
  String? _contractDescriptionHtml;
  bool _pendingNotified = false;

  final List<Map<String, String>> _paymentOptions = const [
    {'value': 'credit_card', 'label': 'credit_card'},
  ];
  String? _authToken;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _companyController.dispose();
    _taxNumberController.dispose();
    _taxOfficeController.dispose();
    _identityController.dispose();
    _addressController.dispose();
    _addressTitleController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingCountries = false;
          _loadingAddresses = false;
          _error = loc.smsPacksSessionMissing;
          _countriesError = loc.smsPacksSessionMissing;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _authToken = token;
      });
    }

    // Ardışık yerine paralel başlat; token hazır
    await Future.wait([
      _loadPacks(skipToken: true),
      _loadCountries(skipToken: true),
      _loadAddresses(skipToken: true),
    ]);
  }

  Future<String?> _getToken() async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token') ?? prefs.getString('authToken');
  }

  Future<http.Response?> _withAuth(
    Future<http.Response> Function(String token) fn,
  ) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      await _handleUnauthorized();
      return null;
    }

    var res = await fn(token);
    if (res.statusCode != 401) {
      _authToken = token;
      return res;
    }

    if (_loggingOut) return null;

    final refreshed = await refreshAccessToken();
    if (refreshed != null) {
      _authToken = refreshed;
      res = await fn(refreshed);
      if (res.statusCode != 401) return res;
    }

    await _handleUnauthorized();
    return null;
  }

  Future<void> _handleUnauthorized() async {
    if (_loggingOut) return;
    _loggingOut = true;
    _paymentTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bearer_token');
    await prefs.remove('authToken');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.smsPacksSessionExpired),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(onLocaleChange: (_) {})),
      (route) => false,
    );
  }

  Future<void> _loadPacks({bool skipToken = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _withAuth((token) {
        return http.get(
          Uri.parse('$apiBaseUrl/api/packs'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      });

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        final List<String> types =
            (data['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final Map<String, dynamic> packMap =
            data['packs_by_type'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(data['packs_by_type'])
                : {};

        final Map<String, List<Map<String, dynamic>>> parsed = {};
        packMap.forEach((key, value) {
          if (value is List) {
            parsed[key] =
                value.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        });

        final contract = data['contract'];
        String? contractTitle;
        String? contractDesc;
        if (contract is Map<String, dynamic>) {
          final title = contract['title'];
          if (title is Map) {
            contractTitle = title['tr']?.toString();
            contractTitle ??= title.values
                .firstWhere(
                  (e) => e != null && e.toString().isNotEmpty,
                  orElse: () => null,
                )
                ?.toString();
          } else if (title != null) {
            contractTitle = title.toString();
          }

          final desc = contract['description'];
          if (desc is Map) {
            contractDesc = desc['tr']?.toString();
            contractDesc ??= desc.values
                .firstWhere(
                  (e) => e != null && e.toString().isNotEmpty,
                  orElse: () => null,
                )
                ?.toString();
          } else if (desc != null) {
            contractDesc = desc.toString();
          }
        } else if (contract is String) {
          contractDesc = contract;
        }
        contractDesc ??= data['contract_description']?.toString();
        contractTitle ??= data['contract_title']?.toString();

        setState(() {
          _types = types.isNotEmpty ? types : parsed.keys.toList();
          _packsByType = parsed;
          _selectedType =
              _selectedType ?? (_types.isNotEmpty ? _types.first : null);
          _contractTitle = contractTitle;
          _contractDescriptionHtml = contractDesc;
        });
      } else {
        setState(() {
          _error = loc.smsPacksLoadFailedStatus(response.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _error = loc.smsPacksLoadFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCountries({bool skipToken = false}) async {
    setState(() {
      _loadingCountries = true;
      _countriesError = null;
    });

    try {
      final response = await _withAuth((token) {
        return http.get(
          Uri.parse('$apiBaseUrl/api/settings/countries'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      });

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final List<dynamic> list = data is List ? data : (data['data'] ?? []);
        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
        setState(() {
          _countries = parsed;
          if (parsed.isNotEmpty && _selectedCountryId == null) {
            _selectedCountryId = parsed.first['id'] as int?;
            _selectedPhoneCode = _cleanPhoneCode(
              parsed.first['phone_code']?.toString(),
            );
          }
        });
        final targetCountryId = _selectedCountryId ??
            (_countries.isNotEmpty ? _countries.first['id'] as int? : null);
        if (targetCountryId != null) {
          _loadCities(countryId: targetCountryId);
        } else {
          setState(() {
            _cities = [];
            _districts = [];
            _selectedCityId = null;
            _selectedDistrictId = null;
          });
        }
      } else {
        setState(() {
          _countriesError =
              loc.smsPacksCountriesFailedStatus(response.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _countriesError = loc.smsPacksCountriesFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCountries = false;
        });
      }
    }
  }

  Future<void> _loadCities({
    int? countryId,
    int? preselectCityId,
    int? preselectDistrictId,
  }) async {
    final targetCountryId = countryId ?? _selectedCountryId;
    setState(() {
      _loadingCities = true;
      _citiesError = null;
      _cities = [];
      _selectedCityId = null;
      _districts = [];
      _selectedDistrictId = null;
      _loadingDistricts = false;
      _districtsError = null;
    });

    if (targetCountryId == null) {
      setState(() {
        _loadingCities = false;
      });
      return;
    }

    try {
      final response = await _withAuth((token) {
        return http.get(
          Uri.parse(
            '$apiBaseUrl/api/settings/cities?country_id=$targetCountryId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      });

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final List<dynamic> list = data is List ? data : (data['data'] ?? []);
        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);

        int? cityToSelect;
        if (preselectCityId != null &&
            parsed.any((c) => c['id'] == preselectCityId)) {
          cityToSelect = preselectCityId;
        } else if (parsed.isNotEmpty) {
          cityToSelect = parsed.first['id'] as int?;
        }

        if (!mounted) return;
        setState(() {
          _cities = parsed;
          _selectedCityId = cityToSelect;
        });

        if (cityToSelect != null) {
          await _loadDistricts(
            cityId: cityToSelect,
            preselectDistrictId: preselectDistrictId,
          );
        } else {
          if (!mounted) return;
          setState(() {
            _districts = [];
            _selectedDistrictId = null;
          });
        }
      } else {
        setState(() {
          _citiesError = loc.smsPacksCitiesFailedStatus(response.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _citiesError = loc.smsPacksCitiesFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCities = false;
        });
      }
    }
  }

  Future<void> _loadDistricts({
    int? cityId,
    int? preselectDistrictId,
  }) async {
    final targetCityId = cityId ?? _selectedCityId;
    setState(() {
      _loadingDistricts = true;
      _districtsError = null;
      _districts = [];
      _selectedDistrictId = null;
    });

    if (targetCityId == null) {
      setState(() {
        _loadingDistricts = false;
      });
      return;
    }

    try {
      final response = await _withAuth((token) {
        return http.get(
          Uri.parse(
            '$apiBaseUrl/api/settings/districts?city_id=$targetCityId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      });

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final List<dynamic> list = data is List ? data : (data['data'] ?? []);
        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);

        int? districtToSelect;
        if (preselectDistrictId != null &&
            parsed.any((d) => d['id'] == preselectDistrictId)) {
          districtToSelect = preselectDistrictId;
        } else if (parsed.isNotEmpty) {
          districtToSelect = parsed.first['id'] as int?;
        }

        if (!mounted) return;
        setState(() {
          _districts = parsed;
          _selectedDistrictId = districtToSelect;
        });
      } else {
        setState(() {
          _districtsError =
              loc.smsPacksDistrictsFailedStatus(response.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _districtsError = loc.smsPacksDistrictsFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
      }
    }
  }

  Future<void> _loadAddresses({bool skipToken = false}) async {
    setState(() {
      _loadingAddresses = true;
      _addressesError = null;
    });

    try {
      final response = await _withAuth((token) {
        return http.get(
          Uri.parse('$apiBaseUrl/api/packs/user-addresses'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      });

      if (response == null) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final List<dynamic> list = data is Map<String, dynamic>
            ? (data['addresses'] as List? ?? [])
            : <dynamic>[];
        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
        if (!mounted) return;
        setState(() {
          _addresses = parsed;
        });
      } else {
        setState(() {
          _addressesError =
              loc.smsPacksAddressesFailedStatus(response.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _addressesError = loc.smsPacksAddressesFailed(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAddresses = false;
        });
      }
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    final buffer = StringBuffer();
    if (cleaned.length == 6) buffer.write('FF');
    buffer.write(cleaned);
    return Color(int.parse(buffer.toString(), radix: 16));
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

  void _showContract() {
    final htmlText = _contractDescriptionHtml ?? loc.smsPacksContentMissing;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _contractTitle ?? 'Sözleşme',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: SingleChildScrollView(child: Html(data: htmlText)),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _cleanPhoneCode(String? code) {
    if (code == null) return null;
    final trimmed = code.trim();
    return trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
  }

  void _onCountryChanged(int val) {
    final selected = _countries.firstWhere(
      (c) => c['id'] == val,
      orElse: () => {},
    );
    setState(() {
      _selectedCountryId = val;
      _selectedPhoneCode = _cleanPhoneCode(
        selected['phone_code']?.toString(),
      );
    });
    _loadCities(countryId: val);
  }

  void _onCityChanged(int? val) {
    if (val == null) return;
    setState(() {
      _selectedCityId = val;
    });
    _loadDistricts(cityId: val);
  }

  void _showDetailsModal(List<dynamic> details, Color accent) {
    if (details.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.smsPacksFeatures,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...details.map((d) {
                  final map = d is Map
                      ? Map<String, dynamic>.from(d)
                      : <String, dynamic>{};
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle, color: accent),
                    title: Text(map['name']?.toString() ?? ''),
                    subtitle: map['description'] != null
                        ? Text(map['description'].toString())
                        : null,
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectType(String type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      _selectedPack = null;
    });
  }

  void _selectPack(Map<String, dynamic> pack) {
    setState(() {
      _selectedPack = pack;
    });
  }

  String _localizePlanLabel(String? raw) {
    final value = raw?.toLowerCase().trim();
    if (value == 'monthly') return loc.smsPacksPlanMonthly;
    if (value == 'annual' || value == 'yearly') return loc.smsPacksPlanAnnual;
    return raw?.toUpperCase() ?? '';
  }

  String _getNameById(List<Map<String, dynamic>> list, int? id) {
    if (id == null) return '';
    final match = list.firstWhere((item) => item['id'] == id, orElse: () => {});
    return match['name']?.toString() ?? '';
  }

  void _clearAddressFields() {
    _selectedAddressId = null;
    final int? currentCountryId = _selectedCountryId ??
        (_countries.isNotEmpty ? _countries.first['id'] as int? : null);
    _addressTitleController.clear();
    _nameController.clear();
    _lastNameController.clear();
    _companyController.clear();
    _emailController.clear();
    _phoneController.clear();
    _selectedCountryId = currentCountryId;
    _selectedCityId = null;
    _selectedDistrictId = null;
    _cities = [];
    _districts = [];
    _loadingCities = false;
    _loadingDistricts = false;
    _citiesError = null;
    _districtsError = null;
    final selectedCountry = _countries.firstWhere(
      (c) => c['id'] == _selectedCountryId,
      orElse: () => {},
    );
    _selectedPhoneCode = _cleanPhoneCode(
      selectedCountry['phone_code']?.toString(),
    );
    _identityController.clear();
    _taxNumberController.clear();
    _taxOfficeController.clear();
    _addressController.clear();
    _noteController.clear();
    if (_selectedCountryId != null) {
      _loadCities(countryId: _selectedCountryId);
    }
  }

  void _applyAddress(Map<String, dynamic> address) {
    final int? countryId = address['country_id'] is int
        ? address['country_id'] as int
        : int.tryParse(address['country_id']?.toString() ?? '');
    final int? cityId = address['city_id'] is int
        ? address['city_id'] as int
        : int.tryParse(address['city_id']?.toString() ?? '');
    final int? districtId = address['district_id'] is int
        ? address['district_id'] as int
        : int.tryParse(address['district_id']?.toString() ?? '');
    final selectedCountry = _countries.firstWhere(
      (c) => c['id'] == countryId,
      orElse: () => {},
    );
    final fallbackPhoneCode =
        _cleanPhoneCode(selectedCountry['phone_code']?.toString());

    setState(() {
      _selectedAddressId = address['id'] is int
          ? address['id'] as int
          : int.tryParse(address['id']?.toString() ?? '');
      _selectedCountryId = countryId ?? _selectedCountryId;
      _selectedCityId = cityId;
      _selectedDistrictId = districtId;
      _nameController.text = address['name']?.toString() ?? '';
      _lastNameController.text = address['last_name']?.toString() ?? '';
      _companyController.text = address['company_name']?.toString() ?? '';
      _emailController.text = address['email']?.toString() ?? '';

      final phone = address['phone']?.toString() ?? '';
      _selectedPhoneCode = fallbackPhoneCode;
      if (phone.startsWith('+')) {
        final cleaned = phone.replaceFirst('+', '');
        final digits = cleaned.replaceAll(RegExp(r'\D'), '');
        // heuristic: first 2-3 digits as code if available
        if (digits.length > 9) {
          _selectedPhoneCode = digits.substring(0, digits.length - 9);
          _phoneController.text = digits.substring(digits.length - 9);
        } else {
          _selectedPhoneCode = fallbackPhoneCode;
          _phoneController.text = cleaned;
        }
      } else {
        _selectedPhoneCode = fallbackPhoneCode;
        _phoneController.text = phone;
      }

      _addressTitleController.text = address['title']?.toString() ?? '';
      _identityController.text = address['identity_number']?.toString() ?? '';
      _taxNumberController.text = address['tax_number']?.toString() ?? '';
      _taxOfficeController.text = address['tax_office']?.toString() ?? '';
      _addressController.text = address['address']?.toString() ?? '';
      _noteController.text = address['note']?.toString() ?? '';
    });

    if (_selectedCountryId != null) {
      _loadCities(
        countryId: _selectedCountryId,
        preselectCityId: _selectedCityId,
        preselectDistrictId: _selectedDistrictId,
      );
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_selectedPack == null) {
        _showSnack(loc.smsPacksSelectPack);
        return false;
      }
    } else if (step == 1) {
      if (_selectedCountryId == null) {
        _showSnack(loc.smsPacksSelectCountry);
        return false;
      }
      if (_selectedCityId == null) {
        _showSnack(loc.smsPacksSelectCity);
        return false;
      }
      if (_selectedDistrictId == null) {
        _showSnack(loc.smsPacksSelectDistrict);
        return false;
      }
      if (_nameController.text.trim().isEmpty) {
        _showSnack(loc.smsPacksNameRequired);
        return false;
      }
      if (_lastNameController.text.trim().isEmpty) {
        _showSnack(loc.smsPacksLastNameRequired);
        return false;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showSnack(loc.smsPacksPhoneRequired);
        return false;
      }
      if (_addressController.text.trim().isEmpty) {
        _showSnack(loc.smsPacksAddressRequired);
        return false;
      }
      if (!_agreementChecked) {
        _showSnack(loc.smsPacksAgreementRequired);
        return false;
      }
    }
    return true;
  }

  Future<void> _purchasePack() async {
    if (_isPurchaseRestricted) {
      _showSnack(loc.smsPacksAndroidOnlyMessage);
      return;
    }
    if (_selectedPack == null) {
      _showSnack(loc.smsPacksSelectPack);
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack(loc.smsPacksSessionMissing);
      return;
    }

    setState(() {
      _purchasing = true;
    });

    try {
      final planType =
          _selectedPack?['type']?.toString() ?? _selectedType ?? 'sms';
          final countryNumber =
              _selectedPhoneCode == null || _selectedPhoneCode!.isEmpty
                  ? ''
                  : '+$_selectedPhoneCode';
      final body = {
        'pack_id': _selectedPack!['id'],
        'plan_type': planType,
        'title': _addressTitleController.text.trim(),
        if (_selectedAddressId != null) 'address_id': _selectedAddressId,
        'country_id': _selectedCountryId,
        'city_id': _selectedCityId,
        'district_id': _selectedDistrictId,
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'company_name': _companyController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country_number': countryNumber,
        'identity_number': _identityController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'payment_method': _selectedPayment,
        'terms_agreement': true,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/packs/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      } else if (response.statusCode == 200 || response.statusCode == 201) {
        String message = loc.smsPacksPurchaseSuccess;
        String? transactionId;
        try {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'] ?? decoded;
          if (data is Map<String, dynamic>) {
            message = data['message']?.toString() ??
                decoded['message']?.toString() ??
                message;
            final order = data['order'];
            if (order is Map<String, dynamic>) {
              transactionId = order['transaction_id']?.toString();
            } else if (data['transaction_id'] != null) {
              transactionId = data['transaction_id']?.toString();
            }
          } else {
            message = decoded['message']?.toString() ?? message;
          }
        } catch (_) {}
        _showSnack(message, success: true);
        if (transactionId != null && transactionId.isNotEmpty) {
          await _startPaytrPayment(token, transactionId);
        }
      } else {
        String message = loc.smsPacksPurchaseFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack(loc.smsPacksPurchaseError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
        });
      }
    }
  }

  Future<void> _startPaytrPayment(String token, String transactionId) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/payment/paytr/token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'transaction_id': transactionId}),
      );
      if (res.statusCode == 401) {
        await _handleUnauthorized();
        return;
      } else if (res.statusCode == 200 || res.statusCode == 201) {
        String? iframeUrl;
        try {
          final decoded = jsonDecode(res.body);
          final data = decoded['data'] ?? decoded;
          final tokenVal = data['token']?.toString();
          iframeUrl = data['iframe_url']?.toString();
          if ((iframeUrl == null || iframeUrl.isEmpty) &&
              tokenVal != null &&
              tokenVal.isNotEmpty) {
            iframeUrl = 'https://www.paytr.com/odeme/guvenli/$tokenVal';
          }
        } catch (_) {}
        if (iframeUrl != null && iframeUrl.isNotEmpty && mounted) {
          _startPaymentPolling(transactionId);
          await _openPaymentWebView(iframeUrl);
        } else {
          _showSnack(loc.smsPacksPaymentStartInvalid);
        }
      } else {
        _showSnack(loc.smsPacksPaymentStartFailedStatus(res.statusCode));
      }
    } catch (e) {
      _showSnack(loc.smsPacksPaymentStartError(e.toString()));
    }
  }

  Future<void> _openPaymentWebView(String url) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PaymentPage(
          controller: controller,
          onExit: () => _paymentTimer?.cancel(),
        ),
      ),
    );
  }

  void _startPaymentPolling(String transactionId) {
    _paymentTimer?.cancel();
    _pendingNotified = false;
    _paymentTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkOrderStatus(transactionId);
    });
  }

  Future<void> _checkOrderStatus(String transactionId) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$apiBaseUrl/payment/success/paytr?transaction_id=$transactionId',
        ),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        String status = 'pending';
        Map<String, dynamic> order = {};
        try {
          final decoded = jsonDecode(res.body);
          status = decoded['status']?.toString() ?? status;
          final data = decoded['data'] ?? decoded;
          final orderMap = data is Map<String, dynamic> ? data['order'] : null;
          if (orderMap is Map<String, dynamic>) {
            order = orderMap;
          }
          // Payment status varsa onu kullan
          final paymentStatus = order['payment_status']?.toString();
          if (paymentStatus != null && paymentStatus.isNotEmpty) {
            status = paymentStatus;
          }
        } catch (_) {}

        final normalized = status.toLowerCase();
        if (normalized == 'paid' || normalized == 'success') {
          _paymentTimer?.cancel();
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          _showPaymentResultDialog(status, order);
        } else if (normalized == 'pending') {
          if (!_pendingNotified) {
            _pendingNotified = true;
            _showSnack(loc.smsPacksPaymentPending, success: true);
          }
        } else if (normalized == 'failed' || normalized == 'canceled') {
          _paymentTimer?.cancel();
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          _showPaymentResultDialog(status, order);
        }
      } else if (res.statusCode == 403) {
        _paymentTimer?.cancel();
        _showSnack(loc.smsPacksPaymentVerify403);
      } else if (res.statusCode == 404) {
        _paymentTimer?.cancel();
        _showSnack(loc.smsPacksPaymentVerify404);
      } else {
        _showSnack(loc.smsPacksPaymentVerifyFailedStatus(res.statusCode));
      }
    } catch (_) {}
  }

  Future<void> _showPaymentResultDialog(
    String status,
    Map<String, dynamic> order,
  ) async {
    final normalized = status.toLowerCase();
    final isSuccess = normalized == 'paid';
    final isPending = normalized == 'pending';

    final packName = order['pack_name']?.toString() ?? loc.smsPacksPackLabel;
    final packType = order['pack_type']?.toString() ?? '';
    final total =
        order['total_price']?.toString() ?? order['price']?.toString() ?? '-';
    final invoice = order['invoice_number']?.toString() ?? '';
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isSuccess
                ? loc.smsPacksPaymentSuccessTitle
                : isPending
                    ? loc.smsPacksPaymentPendingTitle
                    : loc.smsPacksPaymentFailedTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${loc.smsPacksPackLabel}: $packName'),
              if (packType.isNotEmpty)
                Text('${loc.smsPacksTypeLabel}: $packType'),
              Text('${loc.smsPacksAmountLabel}: ₺$total'),
              if (invoice.isNotEmpty)
                Text('${loc.smsPacksInvoiceLabel}: $invoice'),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(loc.smsPacksPaymentVerifying),
                ),
            ],
          ),
          actions: [
            if (isSuccess)
              TextButton(
                onPressed: () {
                  _paymentTimer?.cancel();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DashboardPage()),
                  );
                },
                child: Text(loc.smsPacksGoHome),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(loc.smsPacksClose),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTypeSelector() {
    if (_types.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _types
          .map(
            (t) => ChoiceChip(
              label: Text(_localizePlanLabel(t)),
              selected: _selectedType == t,
              onSelected: (_) => _selectType(t),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPackCards() {
    final packs = _selectedType != null
        ? _packsByType[_selectedType] ?? []
        : <Map<String, dynamic>>[];

    if (packs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(loc.smsPacksNoPacksForType),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool canUseTwoColumns = constraints.maxWidth >= 340;
        final crossAxisCount = canUseTwoColumns ? 2 : 1;
        final aspectRatio = canUseTwoColumns ? 0.68 : 1.05;

        Widget buildCard(Map<String, dynamic> pack) {
          final dynamic packId = pack['id'];
          final bool selected = _selectedPack?['id'] == packId;
          final packColor =
              _parseColor(pack['color']?.toString()) ?? Colors.indigo.shade50;
          final String price = pack['price']?.toString() ?? '-';
          final String priceWithTax = pack['price_with_tax']?.toString() ?? '';
          final String smsCount = pack['sms_count']?.toString() ?? '-';
          final List<dynamic> details =
              pack['details'] is List ? pack['details'] as List : const [];
          final String? imageUrl = pack['image_url']?.toString();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? packColor.withValues(alpha: 0.16) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? packColor : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectPack(pack),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        color: packColor.withValues(alpha: 0.12),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey.shade500,
                                  size: 28,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 34),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.smsPacksSmsCount(smsCount),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₺$price',
                      style: TextStyle(
                        color: packColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceWithTax.isNotEmpty
                          ? loc.smsPacksPriceWithTax(priceWithTax)
                          : '',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showDetailsModal(details, packColor),
                        icon: Icon(Icons.list_alt, color: packColor),
                        label: Text(
                          loc.smsPacksDetails,
                          style: TextStyle(color: packColor),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _selectPack(pack),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              selected ? Colors.white : Colors.black87,
                          backgroundColor:
                              selected ? packColor : Colors.transparent,
                          side: BorderSide(
                            color: selected ? packColor : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(selected
                            ? loc.smsPacksSelected
                            : loc.smsPacksSelectButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspectRatio,
            mainAxisExtent: canUseTwoColumns ? 370 : null,
          ),
          itemBuilder: (context, index) => buildCard(packs[index]),
        );
      },
    );
  }

  Widget _buildBuyerForm() {
    return Column(
      children: [
        if (_loadingAddresses)
          const LinearProgressIndicator(minHeight: 2)
        else if (_addressesError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _addressesError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: _loadAddresses,
                child: Text(loc.smsPacksRefresh),
              ),
            ],
          )
        else if (_addresses.isNotEmpty)
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: loc.smsPacksSavedAddressesLabel,
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedAddressId,
            isExpanded: true,
            onChanged: (val) {
              if (val == null) return;
              if (val == -1) {
                setState(() {
                  _clearAddressFields();
                });
                return;
              }
              final addr = _addresses.firstWhere(
                (a) => a['id'] == val,
                orElse: () => {},
              );
              if (addr.isNotEmpty) {
                _applyAddress(addr);
              }
            },
            items: _addresses
                .map(
                  (a) => DropdownMenuItem<int>(
                    value: a['id'] as int?,
                    child: Text(
                      a['title']?.toString().isNotEmpty == true
                          ? a['title'].toString()
                          : (a['name']?.toString() ?? loc.smsPacksAddress),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList()
              ..insert(
                0,
                DropdownMenuItem<int>(
                  value: -1,
                  child: Text(loc.smsPacksNewAddress),
                ),
              ),
          ),
        if (_addresses.isNotEmpty) const SizedBox(height: 12),
        TextField(
          controller: _addressTitleController,
          decoration: InputDecoration(
            labelText: loc.smsPacksAddressTitle,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: loc.smsPacksFirstName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: loc.smsPacksLastName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _companyController,
          decoration: InputDecoration(
            labelText: loc.smsPacksCompany,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: loc.smsPacksEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingCountries)
          const LinearProgressIndicator(minHeight: 2)
        else if (_countriesError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _countriesError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: _loadCountries,
                child: Text(loc.smsPacksRefresh),
              ),
            ],
          )
        else
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: loc.smsPacksCountry,
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedCountryId,
            onChanged: (val) {
              if (val == null) return;
              _onCountryChanged(val);
            },
            items: _countries
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int?,
                    child: Text(
                      '${c['name'] ?? ''} (+${_cleanPhoneCode(c['phone_code']?.toString()) ?? '-'})',
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        if (_loadingCities)
          const LinearProgressIndicator(minHeight: 2)
        else if (_citiesError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _citiesError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => _loadCities(
                  countryId: _selectedCountryId,
                  preselectCityId: _selectedCityId,
                  preselectDistrictId: _selectedDistrictId,
                ),
                child: Text(loc.smsPacksRefresh),
              ),
            ],
          )
        else
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: loc.smsPacksCity,
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedCityId,
            onChanged: _cities.isEmpty ? null : _onCityChanged,
            items: _cities
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int?,
                    child: Text(c['name']?.toString() ?? ''),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        if (_loadingDistricts)
          const LinearProgressIndicator(minHeight: 2)
        else if (_districtsError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _districtsError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => _loadDistricts(cityId: _selectedCityId),
                child: Text(loc.smsPacksRefresh),
              ),
            ],
          )
        else
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: loc.smsPacksDistrict,
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedDistrictId,
            onChanged: _districts.isEmpty
                ? null
                : (val) {
                    setState(() {
                      _selectedDistrictId = val;
                    });
                  },
            items: _districts
                .map(
                  (d) => DropdownMenuItem<int>(
                    value: d['id'] as int?,
                    child: Text(d['name']?.toString() ?? ''),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: loc.smsPacksPhone,
            border: const OutlineInputBorder(),
            prefixText:
                _selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty
                    ? '+$_selectedPhoneCode '
                    : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _identityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: loc.smsPacksIdentity,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: loc.smsPacksTaxNumber,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxOfficeController,
          decoration: InputDecoration(
            labelText: loc.smsPacksTaxOffice,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: loc.smsPacksAddress,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (!_isPurchaseRestricted) ...[
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: loc.smsPacksPaymentMethod,
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedPayment,
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedPayment = val;
              });
            },
            items: _paymentOptions
                .map(
                  (opt) => DropdownMenuItem(
                    value: opt['value'],
                    child: Text(
                      opt['value'] == 'credit_card'
                          ? loc.smsPacksPaymentMethod
                          : (opt['label'] ?? ''),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: loc.smsPacksNote,
            border: const OutlineInputBorder(),
            hintText: loc.smsPacksNoteHint,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agreementChecked,
          onChanged: (val) {
            setState(() {
              _agreementChecked = val ?? false;
            });
          },
          title: Text(loc.smsPacksAgreementTitle),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showContract,
            icon: const Icon(Icons.description_outlined),
            label: Text(
              _contractTitle?.isNotEmpty == true
                  ? _contractTitle!
                  : loc.smsPacksContract,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final pack = _selectedPack;
    if (pack == null) {
      return Text(loc.smsPacksSelectPackForSummary);
    }

    final smsCount = pack['sms_count']?.toString() ?? '-';
    final price = pack['price']?.toString() ?? '-';
    final priceWithTax = pack['price_with_tax']?.toString() ?? '';
    final paymentLabel = _isPurchaseRestricted
        ? '-'
        : (_paymentOptions.firstWhere(
              (e) => e['value'] == _selectedPayment,
              orElse: () => _paymentOptions.first,
            )['value'] ==
                'credit_card'
            ? loc.smsPacksPaymentMethod
            : (_paymentOptions.firstWhere(
                  (e) => e['value'] == _selectedPayment,
                  orElse: () => _paymentOptions.first,
                )['label'] ??
                ''));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack['name']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loc.smsPacksPlanLabel}: ${_localizePlanLabel(pack['type']?.toString() ?? _selectedType)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₺$price',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (priceWithTax.isNotEmpty)
                      Text(
                        '${loc.smsPacksVatIncluded} ₺$priceWithTax',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('${loc.smsPacksSmsLabel}: $smsCount'),
        if (_companyController.text.trim().isNotEmpty)
          Text(
              '${loc.smsPacksCompanyLabel}: ${_companyController.text.trim()}'),
        const SizedBox(height: 8),
        const SizedBox(height: 16),
        Text(
          loc.smsPacksSummaryPurchaseInfo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
            '${loc.smsPacksBuyerLabel}: ${_nameController.text} ${_lastNameController.text}'),
        Text('${loc.smsPacksEmailLabel}: ${_emailController.text}'),
        if (_selectedCountryId != null)
          Text(
              '${loc.smsPacksCountryLabel}: ${_getNameById(_countries, _selectedCountryId)}'),
        if (_selectedCityId != null)
          Text(
              '${loc.smsPacksCityLabel}: ${_getNameById(_cities, _selectedCityId)}'),
        if (_selectedDistrictId != null)
          Text(
              '${loc.smsPacksDistrictLabel}: ${_getNameById(_districts, _selectedDistrictId)}'),
        if (_phoneController.text.isNotEmpty)
          Text(
            '${loc.smsPacksPhoneLabel}: ${_selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty ? '+$_selectedPhoneCode ' : ''}${_phoneController.text}',
          ),
        Text('${loc.smsPacksPaymentLabel}: $paymentLabel'),
        if (_isPurchaseRestricted) ...[
          const SizedBox(height: 8),
          Text(
            loc.smsPacksAndroidOnlyMessage,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_taxNumberController.text.isNotEmpty)
          Text('${loc.smsPacksTaxNumberLabel}: ${_taxNumberController.text}'),
        if (_taxOfficeController.text.isNotEmpty)
          Text('${loc.smsPacksTaxOfficeLabel}: ${_taxOfficeController.text}'),
        if (_identityController.text.isNotEmpty)
          Text('${loc.smsPacksIdentityLabel}: ${_identityController.text}'),
        if (_addressController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${loc.smsPacksAddressLabel}: ${_addressController.text}'),
        ],
        if (_noteController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${loc.smsPacksNoteLabel}: ${_noteController.text.trim()}'),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPurchaseRestricted
                ? null
                : (_purchasing ? null : _purchasePack),
            icon: _purchasing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle),
            label: Text(
                _purchasing ? loc.smsPacksSubmitting : loc.smsPacksSubmitLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildRestrictedBody() {
    return RefreshIndicator(
      onRefresh: _loadPacks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.smsPacksAndroidOnlyTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.smsPacksAndroidOnlyMessage,
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.smsPacksStepPack,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 12),
          _buildPackCards(),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    final labels = [
      loc.smsPacksStepPack,
      loc.smsPacksStepInfo,
      loc.smsPacksStepSummary,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap = constraints.maxWidth < 370;
        final children = List.generate(labels.length, (index) {
          final isActive = _currentStep == index;
          final isDone = _currentStep > index;
          final bg = isActive
              ? Colors.indigo.shade50
              : (isDone ? Colors.green.shade50 : Colors.grey.shade100);
          final border = isActive
              ? Colors.indigo.shade300
              : (isDone ? Colors.green.shade300 : Colors.grey.shade300);
          final textColor = isActive
              ? Colors.indigo.shade700
              : (isDone ? Colors.green.shade700 : Colors.black87);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Text(
              '${index + 1}. ${labels[index]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          );
        });

        if (useWrap) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const SizedBox.shrink(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0
            ? StepState.complete
            : (_selectedPack != null ? StepState.editing : StepState.indexed),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 12),
            _buildPackCards(),
          ],
        ),
      ),
      Step(
        title: const SizedBox.shrink(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1
            ? StepState.complete
            : (_currentStep == 1 ? StepState.editing : StepState.indexed),
        content: _buildBuyerForm(),
      ),
      Step(
        title: const SizedBox.shrink(),
        isActive: _currentStep >= 2,
        state: _currentStep == 2 ? StepState.editing : StepState.indexed,
        content: _buildSummary(),
      ),
    ];
  }

  void _onContinue() {
    if (_purchasing) return;
    if (!_validateStep(_currentStep)) return;
    if (_currentStep == 0) {
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      setState(() {
        _currentStep = 2;
      });
      if (!_isPurchaseRestricted) {
        _purchasePack();
      }
    } else {
      if (_isPurchaseRestricted) {
        _showSnack(loc.smsPacksAndroidOnlyMessage);
        return;
      }
      _purchasePack();
    }
  }

  void _onCancel() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.smsPacksTitle),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
              (route) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadPacks,
                            icon: const Icon(Icons.refresh),
                            label: Text(loc.smsPacksRetry),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isPurchaseRestricted
                    ? _buildRestrictedBody()
                    : LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: _buildStepHeader(),
                          ),
                          Expanded(
                            child: Stepper(
                              type: StepperType.horizontal,
                              currentStep: _currentStep,
                              onStepContinue: _onContinue,
                              onStepCancel: _onCancel,
                              onStepTapped: (index) {
                                if (index < _currentStep) {
                                  setState(() {
                                    _currentStep = index;
                                  });
                                }
                              },
                              controlsBuilder: (context, details) {
                                final isLast =
                                    _currentStep == _buildSteps().length - 1;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _purchasing
                                            ? null
                                            : details.onStepContinue,
                                        child: Text(
                                          _purchasing
                                              ? loc.smsPacksSubmitting
                                              : (isLast
                                                  ? loc.smsPacksBuy
                                                  : loc.smsPacksNext),
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: details.onStepCancel,
                                        child: Text(loc.smsPacksBack),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              steps: _buildSteps(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

class _PaymentPage extends StatelessWidget {
  final WebViewController controller;
  final VoidCallback onExit;

  const _PaymentPage({required this.controller, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) onExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).smsPacksPaymentLabel),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                onExit();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: SafeArea(child: WebViewWidget(controller: controller)),
      ),
    );
  }
}
