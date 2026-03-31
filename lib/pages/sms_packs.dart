import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_html/flutter_html.dart';

import '../config.dart';
import '../login_page.dart';
import '../auth.dart';
import '../dashboard_page.dart';
import '../services/apple_subscription_catalog.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';

class SmsPacksPage extends StatefulWidget {
  const SmsPacksPage({super.key});

  @override
  State<SmsPacksPage> createState() => _SmsPacksPageState();
}

class _SmsPacksPageState extends State<SmsPacksPage> {
  AppLocalizations get loc => AppLocalizations.of(context);
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static const Set<String> _supportedPlanTypes = {'monthly', 'annual', 'yearly'};
  bool get _isAndroidPurchaseSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
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
  final String _selectedPayment = 'credit_card';
  bool _agreementChecked = false;
  bool _showInvoiceFields = false;
  Timer? _paymentTimer;
  String? _contractTitle;
  String? _contractDescriptionHtml;
  bool _loadingIosProducts = false;
  final Map<String, ProductDetails> _iosProductsById = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _restoringPurchases = false;
  Map<String, dynamic>? _pendingApplePack;

  final List<Map<String, String>> _paymentOptions = const [
    {'value': 'credit_card', 'label': 'credit_card'},
  ];
  bool _loggingOut = false;
  static const int _phoneDigitsMax = 10;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {
        _showSnack('Apple satin alma akisi izlenemedi.');
      },
    );
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
    _purchaseSubscription?.cancel();
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
      setState(() {});
    }

    // Ardışık yerine paralel başlat; token hazır
    await Future.wait([
      _loadPacks(),
      _loadCountries(),
      _loadAddresses(),
      _loadIosProducts(),
    ]);
  }

  Future<String?> _getToken() async {
    return getAccessToken();
  }

  Future<void> _handleUnauthorized() async {
    if (_loggingOut) return;
    _loggingOut = true;
    _paymentTimer?.cancel();
    await clearTokens();
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

  Future<void> _loadPacks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/packs'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        final List<String> types =
            (data['types'] as List?)
                ?.map((e) => e.toString())
                .where(_isSupportedPlanType)
                .toList() ??
            [];
        final Map<String, dynamic> packMap =
            data['packs_by_type'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(data['packs_by_type'])
                : {};

        final Map<String, List<Map<String, dynamic>>> parsed = {};
        packMap.forEach((key, value) {
          if (value is List) {
            final supportedPacks = value
                .map((e) => Map<String, dynamic>.from(e))
                .where((pack) => _isSupportedPlanType(pack['type']?.toString()))
                .toList();
            if (supportedPacks.isNotEmpty && _isSupportedPlanType(key)) {
              parsed[key] = supportedPacks;
            }
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
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          return;
        }
        setState(() {
          _error = loc.smsPacksLoadFailedStatus(response.statusCode);
        });
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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

  static bool _isSupportedPlanType(String? raw) {
    if (raw == null) return false;
    return _supportedPlanTypes.contains(raw.trim().toLowerCase());
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countriesError = null;
    });

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/settings/countries'),
        headers: {
          'Accept': 'application/json',
        },
      );

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
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          return;
        }
        setState(() {
          _countriesError =
              loc.smsPacksCountriesFailedStatus(response.statusCode);
        });
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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
      final response = await authGet(
        Uri.parse(
          '$apiBaseUrl/api/settings/cities?country_id=$targetCountryId',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

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
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          return;
        }
        setState(() {
          _citiesError = loc.smsPacksCitiesFailedStatus(response.statusCode);
        });
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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
      final response = await authGet(
        Uri.parse(
          '$apiBaseUrl/api/settings/districts?city_id=$targetCityId',
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

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
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          return;
        }
        setState(() {
          _districtsError =
              loc.smsPacksDistrictsFailedStatus(response.statusCode);
        });
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressesError = null;
    });

    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/packs/user-addresses'),
        headers: {
          'Accept': 'application/json',
        },
      );

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
        if (response.statusCode == 401) {
          await _handleUnauthorized();
          return;
        }
        setState(() {
          _addressesError =
              loc.smsPacksAddressesFailedStatus(response.statusCode);
        });
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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

  Future<void> _loadIosProducts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _loadingIosProducts = false;
        _iosProductsById.clear();
      });
      return;
    }

    setState(() {
      _loadingIosProducts = true;
    });

    try {
      final response = await InAppPurchase.instance.queryProductDetails(
        AppleSubscriptionCatalog.productIds,
      );
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '[sms_packs] notFound product IDs: ${response.notFoundIDs.join(', ')}',
        );
      }
      if (!mounted) return;
      setState(() {
        _iosProductsById
          ..clear()
          ..addEntries(
              response.productDetails.map((item) => MapEntry(item.id, item)));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iosProductsById.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingIosProducts = false;
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
                  _contractTitle ?? loc.smsPacksContract,
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
                    child: Text(loc.smsPacksClose),
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

  String _extractPhoneDigits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= _phoneDigitsMax) return digits;
    return digits.substring(0, _phoneDigitsMax);
  }

  String _formatPhone(String value) {
    final digits = _extractPhoneDigits(value);
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return '($digits';
    if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    }
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)} ${digits.substring(6)}';
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

  ProductDetails? _appleProductForPack(Map<String, dynamic> pack) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    final productId = AppleSubscriptionCatalog.productIdForPackData(
      pack,
      fallbackPlanType: _selectedType,
    );
    if (productId == null) return null;
    return _iosProductsById[productId];
  }

  Map<String, dynamic>? _packForAppleProductId(String productId) {
    for (final packs in _packsByType.values) {
      for (final pack in packs) {
        final mappedId = AppleSubscriptionCatalog.productIdForPackData(
          pack,
        );
        if (mappedId == productId) {
          return pack;
        }
      }
    }
    return null;
  }

  String _displayPriceForPack(Map<String, dynamic> pack) {
    final appleProduct = _appleProductForPack(pack);
    if (appleProduct != null) {
      return appleProduct.price;
    }
    final price = pack['price']?.toString();
    return (price == null || price.isEmpty) ? '-' : '₺$price';
  }

  String? _displayTaxLabelForPack(Map<String, dynamic> pack) {
    final priceWithTax = pack['price_with_tax']?.toString() ?? '';
    if (priceWithTax.isEmpty) return null;
    return loc.smsPacksPriceWithTax(priceWithTax);
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
    _showInvoiceFields = false;
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
        if (digits.length > _phoneDigitsMax) {
          _selectedPhoneCode =
              digits.substring(0, digits.length - _phoneDigitsMax);
          _phoneController.text =
              _formatPhone(digits.substring(digits.length - _phoneDigitsMax));
        } else {
          _selectedPhoneCode = fallbackPhoneCode;
          _phoneController.text = _formatPhone(cleaned);
        }
      } else {
        _selectedPhoneCode = fallbackPhoneCode;
        _phoneController.text = _formatPhone(phone);
      }

      _addressTitleController.text = address['title']?.toString() ?? '';
      _identityController.text = address['identity_number']?.toString() ?? '';
      _taxNumberController.text = address['tax_number']?.toString() ?? '';
      _taxOfficeController.text = address['tax_office']?.toString() ?? '';
      _addressController.text = address['address']?.toString() ?? '';
      _noteController.text = address['note']?.toString() ?? '';
      _showInvoiceFields = _companyController.text.trim().isNotEmpty ||
          _identityController.text.trim().isNotEmpty ||
          _taxNumberController.text.trim().isNotEmpty ||
          _taxOfficeController.text.trim().isNotEmpty;
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
    setState(() {
      _purchasing = true;
    });

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _purchaseIosSubscription();
      return;
    }

      try {
      final planType =
          _selectedPack?['type']?.toString() ?? _selectedType ?? 'monthly';
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
        'phone': _extractPhoneDigits(_phoneController.text.trim()),
        'country_number': countryNumber,
        'identity_number': _identityController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'payment_method': _selectedPayment,
        'terms_agreement': true,
      };

      final response = await authPost(
        Uri.parse('$apiBaseUrl/api/packs/orders'),
        headers: {
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
          await _startPaytrPayment(transactionId);
        }
      } else {
        String message = loc.smsPacksPurchaseFailedStatus(response.statusCode);
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } on AuthRequiredException {
      await _handleUnauthorized();
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

  Future<void> _purchaseIosSubscription() async {
    final pack = _selectedPack;
    if (pack == null) {
      _showSnack(loc.smsPacksSelectPack);
      setState(() {
        _purchasing = false;
      });
      return;
    }

    final product = _appleProductForPack(pack);
    if (product == null) {
      _showSnack(
        _loadingIosProducts
            ? 'App Store fiyatlari yukleniyor. Biraz sonra tekrar deneyin.'
            : 'Bu paket App Store urunu ile eslesmedi.',
      );
      setState(() {
        _purchasing = false;
      });
      return;
    }

    try {
      final purchaseParam = PurchaseParam(
        productDetails: product,
      );
      _pendingApplePack = Map<String, dynamic>.from(pack);
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        _showSnack('App Store satin alma istegi baslatilamadi.');
        if (mounted) {
          setState(() {
            _purchasing = false;
          });
        }
      }
    } catch (e) {
      _showSnack('App Store satin alma hatasi: $e');
      if (mounted) {
        setState(() {
          _purchasing = false;
        });
      }
    }
  }

  Future<void> _restoreApplePurchases() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    setState(() {
      _restoringPurchases = true;
    });
    try {
      await _inAppPurchase.restorePurchases();
      _showSnack('Apple satin alimlari geri yukleniyor...', success: true);
    } catch (e) {
      _showSnack('Geri yukleme baslatilamadi: $e');
      if (mounted) {
        setState(() {
          _restoringPurchases = false;
        });
      }
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) {
            setState(() {
              _purchasing = true;
            });
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleCompletedApplePurchase(purchase);
          break;
        case PurchaseStatus.error:
          _showSnack(
            purchase.error?.message.isNotEmpty == true
                ? purchase.error!.message
                : 'App Store satin alma islemi basarisiz oldu.',
          );
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoringPurchases = false;
            });
          }
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          _showSnack('Satin alma islemi iptal edildi.');
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoringPurchases = false;
            });
          }
          break;
      }
    }
  }

  Future<void> _handleCompletedApplePurchase(PurchaseDetails purchase) async {
    final pack =
        _packForAppleProductId(purchase.productID) ?? _pendingApplePack;
    if (pack == null) {
      _showSnack('App Store urunu icin paket eslesmesi bulunamadi.');
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
      if (mounted) {
        setState(() {
          _purchasing = false;
          _restoringPurchases = false;
        });
      }
      return;
    }

    await _submitIosPurchaseToBackend(
      purchase: purchase,
      pack: pack,
      restored: purchase.status == PurchaseStatus.restored,
    );

    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }

    if (mounted) {
      setState(() {
        _purchasing = false;
        _restoringPurchases = false;
      });
    }
    _pendingApplePack = null;
  }

  Future<void> _submitIosPurchaseToBackend({
    required PurchaseDetails purchase,
    required Map<String, dynamic> pack,
    required bool restored,
  }) async {
    final planType = pack['type']?.toString() ?? _selectedType ?? 'monthly';
    final countryNumber =
        _selectedPhoneCode == null || _selectedPhoneCode!.isEmpty
            ? ''
            : '+$_selectedPhoneCode';

    final body = {
      'pack_id': pack['id'],
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
      'phone': _extractPhoneDigits(_phoneController.text.trim()),
      'country_number': countryNumber,
      'identity_number': _identityController.text.trim(),
      'tax_number': _taxNumberController.text.trim(),
      'tax_office': _taxOfficeController.text.trim(),
      'address': _addressController.text.trim(),
      'note': _noteController.text.trim(),
      'payment_method': 'apple_iap',
      'terms_agreement': true,
      'apple_product_id': purchase.productID,
      'apple_purchase_id': purchase.purchaseID,
      'apple_transaction_date': purchase.transactionDate,
      'apple_source': purchase.verificationData.source,
      'apple_receipt_data': purchase.verificationData.serverVerificationData,
      'apple_local_receipt_data':
          purchase.verificationData.localVerificationData,
      'apple_is_restore': restored,
    };

    final response = await authPost(
      Uri.parse('$apiBaseUrl/api/packs/orders'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      await _handleUnauthorized();
      return;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      String message = restored
          ? 'Apple aboneligi geri yuklendi.'
          : 'Apple aboneligi basariyla aktif edildi.';
      try {
        final decoded = jsonDecode(response.body);
        message = decoded['message']?.toString() ??
            decoded['data']?['message']?.toString() ??
            message;
      } catch (_) {}
      _showSnack(message, success: true);
      return;
    }

    String message =
        'Apple satin alma dogrulamasi backend tarafinda tamamlanamadi.';
    try {
      final decoded = jsonDecode(response.body);
      message = decoded['message']?.toString() ?? message;
    } catch (_) {}
    _showSnack(message);
  }

  Future<void> _startPaytrPayment(String transactionId) async {
    try {
      final res = await authPost(
        Uri.parse('$apiBaseUrl/api/payment/paytr/token'),
        headers: {
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
    } on AuthRequiredException {
      await _handleUnauthorized();
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
    _paymentTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkOrderStatus(transactionId);
    });
  }

  Future<void> _checkOrderStatus(String transactionId) async {
    try {
      final res = await authGet(
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
          // Pending durumda kullanıcıyı ekstra snackbar ile rahatsız etmiyoruz.
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
          final String price = _displayPriceForPack(pack);
          final String? priceWithTax = _displayTaxLabelForPack(pack);
          final String smsCount = pack['sms_count']?.toString() ?? '-';
          final List<dynamic> details =
              pack['details'] is List ? pack['details'] as List : const [];
          final String? imageUrl = pack['image_url']?.toString();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color:
                  selected ? packColor.withValues(alpha: 0.16) : Colors.white,
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
                      price,
                      style: TextStyle(
                        color: packColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceWithTax ?? '',
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
    Widget section({
      required String title,
      required IconData icon,
      required List<Widget> children,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.indigo.shade500),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
    }

    final pack = _selectedPack;
    final packSms = pack?['sms_count']?.toString() ?? '-';
    final packPrice = pack == null ? '-' : _displayPriceForPack(pack);
    final packPriceWithTax =
        pack == null ? null : _displayTaxLabelForPack(pack);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pack != null)
          section(
            title: loc.smsPacksPackLabel,
            icon: Icons.inventory_2_outlined,
            children: [
              Text(
                '${pack['name']?.toString() ?? '-'} - $packSms ${loc.smsPacksSmsLabel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(packPrice, style: const TextStyle(fontSize: 18)),
              if (packPriceWithTax != null)
                Text(
                  packPriceWithTax,
                  style: const TextStyle(color: Colors.black54),
                ),
            ],
          ),
        section(
          title: loc.smsPacksAddressLabel,
          icon: Icons.bookmark_outline,
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
                    setState(_clearAddressFields);
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
              )
            else
              Text(
                loc.smsPacksNewAddress,
                style: const TextStyle(color: Colors.black54),
              ),
          ],
        ),
        section(
          title: loc.smsPacksBuyerLabel,
          icon: Icons.person_outline,
          children: [
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: loc.smsPacksEmail,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: const [_LocalPhoneMaskFormatter()],
              decoration: InputDecoration(
                labelText: loc.smsPacksPhone,
                border: const OutlineInputBorder(),
                prefixText:
                    _selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty
                        ? '+$_selectedPhoneCode '
                        : null,
              ),
            ),
          ],
        ),
        section(
          title: loc.smsPacksAddressLabel,
          icon: Icons.location_on_outlined,
          children: [
            TextField(
              controller: _addressTitleController,
              decoration: InputDecoration(
                labelText: loc.smsPacksAddressTitle,
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
              controller: _addressController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: loc.smsPacksAddress,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        section(
          title: loc.smsPacksInvoiceLabel,
          icon: Icons.receipt_long_outlined,
          children: [
            SwitchListTile(
              value: _showInvoiceFields,
              contentPadding: EdgeInsets.zero,
              title: Text(loc.smsPacksInvoiceLabel),
              onChanged: (val) {
                setState(() {
                  _showInvoiceFields = val;
                });
              },
            ),
            if (_showInvoiceFields) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: loc.smsPacksCompany,
                  border: const OutlineInputBorder(),
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
            ],
          ],
        ),
        section(
          title: loc.smsPacksStepSummary,
          icon: Icons.tune_outlined,
          children: [
            if (!_isPurchaseRestricted) ...[
              InputDecorator(
                decoration: InputDecoration(
                  labelText: loc.smsPacksPaymentMethod,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                ),
                child: Text(
                  loc.smsPacksPaymentMethod,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
            const SizedBox(height: 8),
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

    Widget infoRow(String label, String value, {IconData? icon}) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.blueGrey.shade500),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, height: 1.35),
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade600, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.smsPacksPaymentMethod} • SSL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: Colors.white),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.smsPacksPaymentSecurityNote,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.smsPacksSummaryPurchaseInfo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              infoRow(loc.smsPacksPackLabel, pack['name']?.toString() ?? '-',
                  icon: Icons.inventory_2_outlined),
              infoRow(
                loc.smsPacksPlanLabel,
                _localizePlanLabel(pack['type']?.toString() ?? _selectedType),
                icon: Icons.layers_outlined,
              ),
              infoRow(loc.smsPacksSmsLabel, smsCount, icon: Icons.sms_outlined),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.smsPacksAmountLabel),
                  Text(
                    '₺$price',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (priceWithTax.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.smsPacksVatIncluded),
                    Text(
                      '₺$priceWithTax',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.smsPacksBuyerLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              infoRow(
                loc.smsPacksBuyerLabel,
                '${_nameController.text} ${_lastNameController.text}'.trim(),
                icon: Icons.person_outline,
              ),
              infoRow(loc.smsPacksEmailLabel, _emailController.text,
                  icon: Icons.mail_outline),
              infoRow(
                loc.smsPacksPhoneLabel,
                '${_selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty ? '+$_selectedPhoneCode ' : ''}${_phoneController.text}',
                icon: Icons.phone_outlined,
              ),
              infoRow(
                loc.smsPacksAddressLabel,
                _addressController.text,
                icon: Icons.location_on_outlined,
              ),
              if (_selectedCityId != null || _selectedDistrictId != null)
                infoRow(
                  loc.smsPacksCityLabel,
                  '${_getNameById(_cities, _selectedCityId)} ${_getNameById(_districts, _selectedDistrictId)}'
                      .trim(),
                  icon: Icons.map_outlined,
                ),
              infoRow(loc.smsPacksPaymentLabel, paymentLabel,
                  icon: Icons.credit_card_outlined),
              if (_companyController.text.trim().isNotEmpty)
                infoRow(
                  loc.smsPacksCompanyLabel,
                  _companyController.text.trim(),
                  icon: Icons.business_outlined,
                ),
              if (_noteController.text.trim().isNotEmpty)
                infoRow(loc.smsPacksNoteLabel, _noteController.text.trim(),
                    icon: Icons.notes_outlined),
            ],
          ),
        ),
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
        actions: [
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            TextButton(
              onPressed: _restoringPurchases || _purchasing
                  ? null
                  : _restoreApplePurchases,
              child: Text(
                _restoringPurchases ? 'Restoring...' : 'Restore',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
                                    final isLast = _currentStep ==
                                        _buildSteps().length - 1;
                                    final continueButton = ElevatedButton(
                                      onPressed: _purchasing
                                          ? null
                                          : details.onStepContinue,
                                      child: Text(
                                        _purchasing
                                            ? loc.smsPacksSubmitting
                                            : loc.smsPacksNext,
                                      ),
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: isLast
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: _purchasing
                                                      ? null
                                                      : details.onStepContinue,
                                                  icon: _purchasing
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2),
                                                        )
                                                      : const Icon(
                                                          Icons.lock_outline),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.indigo.shade600,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 14),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  label: Text(
                                                    _purchasing
                                                        ? loc.smsPacksSubmitting
                                                        : loc.smsPacksBuy,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                OutlinedButton(
                                                  onPressed:
                                                      details.onStepCancel,
                                                  child: Text(loc.smsPacksBack),
                                                ),
                                              ],
                                            )
                                          : Wrap(
                                              spacing: 12,
                                              runSpacing: 8,
                                              children: [
                                                continueButton,
                                                OutlinedButton(
                                                  onPressed:
                                                      details.onStepCancel,
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

class _LocalPhoneMaskFormatter extends TextInputFormatter {
  const _LocalPhoneMaskFormatter();

  static const int _maxDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited =
        digits.length <= _maxDigits ? digits : digits.substring(0, _maxDigits);
    final formatted = _format(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _format(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return '($digits';
    if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    }
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
}
