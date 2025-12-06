import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class SmsPacksPage extends StatefulWidget {
  const SmsPacksPage({super.key});

  @override
  State<SmsPacksPage> createState() => _SmsPacksPageState();
}

class _SmsPacksPageState extends State<SmsPacksPage> {
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  int _currentStep = 0;

  List<String> _types = [];
  Map<String, List<Map<String, dynamic>>> _packsByType = {};
  String? _selectedType;
  Map<String, dynamic>? _selectedPack;
  int? _billingId;
  List<Map<String, dynamic>> _countries = [];
  bool _loadingCountries = true;
  String? _countriesError;
  int? _selectedCountryId;
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
  String _selectedPayment = 'credit_card';
  bool _agreementChecked = false;
  bool _savingBilling = false;

  final List<Map<String, String>> _paymentOptions = const [
    {'value': 'credit_card', 'label': 'Kredi Kartı'},
    {'value': 'eft', 'label': 'Havale / EFT'},
    {'value': 'cash', 'label': 'Nakit'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPacks();
      _loadCountries();
      _loadBillingAddress();
    });
  }

  @override
  void dispose() {
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
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer_token') ?? prefs.getString('authToken');
  }

  Future<void> _loadPacks() async {
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
        Uri.parse('$apiBaseUrl/api/packs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;

        final List<String> types = (data['types'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
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

        setState(() {
          _types = types.isNotEmpty ? types : parsed.keys.toList();
          _packsByType = parsed;
          _selectedType =
              _selectedType ?? (_types.isNotEmpty ? _types.first : null);
        });
      } else {
        setState(() {
          _error = 'Paketler alınamadı (HTTP ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Paketler alınırken hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCountries() async {
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
        final List<dynamic> list = data is List ? data : (data['data'] ?? []);
        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
        setState(() {
          _countries = parsed;
          if (parsed.isNotEmpty && _selectedCountryId == null) {
            _selectedCountryId = parsed.first['id'] as int?;
            _selectedPhoneCode =
                _cleanPhoneCode(parsed.first['phone_code']?.toString());
          }
        });
      } else {
        setState(() {
          _countriesError =
              'Ülkeler alınamadı (HTTP ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _countriesError = 'Ülkeler alınırken hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCountries = false;
        });
      }
    }
  }

  Future<void> _loadBillingAddress() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/billing-addresses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          _prefillBilling(data);
        }
      }
    } catch (_) {}
  }

  void _prefillBilling(Map<String, dynamic> data) {
    setState(() {
      _billingId = data['id'] is int ? data['id'] as int : null;
      _nameController.text = data['name']?.toString() ?? '';
      _lastNameController.text = data['last_name']?.toString() ?? '';
      _companyController.text = data['company_name']?.toString() ?? '';
      _emailController.text = data['email']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _identityController.text = data['identity_number']?.toString() ?? '';
      _taxNumberController.text = data['tax_number']?.toString() ?? '';
      _taxOfficeController.text = data['tax_office']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _noteController.text = data['note']?.toString() ?? '';
      final countryId = data['country_id'];
      if (countryId != null) {
        _selectedCountryId = countryId is int ? countryId : int.tryParse(countryId.toString());
      }
      if (data['phone_code'] != null) {
        _selectedPhoneCode = _cleanPhoneCode(data['phone_code']?.toString());
      }
    });
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

  String? _cleanPhoneCode(String? code) {
    if (code == null) return null;
    final trimmed = code.trim();
    return trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
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
                const Text(
                  'Özellikler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...details.map((d) {
                  final map = d is Map
                      ? Map<String, dynamic>.from(d as Map)
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

  Future<bool> _saveBillingAddress() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı.');
      return false;
    }
    setState(() {
      _savingBilling = true;
    });

    try {
      final payload = {
        'name': _nameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'company_name': _companyController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'country_id': _selectedCountryId?.toString() ?? '',
        'phone_code': _selectedPhoneCode ?? '',
        'identity_number': _identityController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
      };

      final uri = _billingId != null
          ? Uri.parse('$apiBaseUrl/api/billing-addresses/$_billingId')
          : Uri.parse('$apiBaseUrl/api/billing-addresses');
      final response = _billingId != null
          ? await http.put(uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
              body: payload)
          : await http.post(uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
              body: payload);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        try {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'] ?? decoded;
          if (data is Map<String, dynamic>) {
            _prefillBilling(data);
          }
        } catch (_) {}
        _showSnack('Fatura adresi kaydedildi.', success: true);
        return true;
      } else {
        String message = 'Fatura adresi kaydedilemedi (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
        return false;
      }
    } catch (e) {
      _showSnack('Fatura adresi kaydedilemedi: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingBilling = false;
        });
      }
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_selectedPack == null) {
        _showSnack('Lütfen bir paket seçin.');
        return false;
      }
    } else if (step == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showSnack('Ad alanı boş bırakılamaz.');
        return false;
      }
      if (_lastNameController.text.trim().isEmpty) {
        _showSnack('Soyad alanı boş bırakılamaz.');
        return false;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showSnack('Telefon alanı boş bırakılamaz.');
        return false;
      }
      if (_addressController.text.trim().isEmpty) {
        _showSnack('Adres alanı boş bırakılamaz.');
        return false;
      }
      if (!_agreementChecked) {
        _showSnack('Satın alma sözleşmesini onaylamalısınız.');
        return false;
      }
    }
    return true;
  }

  Future<void> _purchasePack() async {
    if (_selectedPack == null) {
      _showSnack('Lütfen bir paket seçin.');
      return;
    }
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _showSnack('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() {
      _purchasing = true;
    });

    try {
      final body = {
        'pack_id': _selectedPack!['id'].toString(),
        'type': _selectedPack!['type']?.toString() ?? _selectedType ?? '',
        'contact_name': _nameController.text.trim(),
        'contact_last_name': _lastNameController.text.trim(),
        'contact_email': _emailController.text.trim(),
        'contact_phone': _phoneController.text.trim(),
        'company_name': _companyController.text.trim(),
        'country_id': _selectedCountryId?.toString() ?? '',
        'phone_code': _selectedPhoneCode ?? '',
        'identity_number': _identityController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'payment_method': _selectedPayment,
        'agreement': _agreementChecked ? '1' : '0',
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/packs/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        String message = 'Satın alma isteği iletildi.';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message, success: true);
      } else {
        String message = 'Satın alma başarısız (HTTP ${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          message = decoded['message']?.toString() ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Satın alma sırasında hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
        });
      }
    }
  }

  Widget _buildTypeSelector() {
    if (_types.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _types
          .map(
            (t) => ChoiceChip(
              label: Text(t.toUpperCase()),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('Bu tipte paket bulunamadı.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = constraints.maxWidth > 820;
        final crossAxisCount = twoColumns ? 2 : 1;
        final aspectRatio = twoColumns ? 0.9 : 1.05;

        Widget buildCard(Map<String, dynamic> pack) {
          final dynamic packId = pack['id'];
          final bool selected = _selectedPack?['id'] == packId;
          final packColor =
              _parseColor(pack['color']?.toString()) ?? Colors.indigo.shade50;
          final String price = pack['price']?.toString() ?? '-';
          final String annualPrice = pack['annual_price']?.toString() ?? '';
          final String smsCount = pack['sms_count']?.toString() ?? '-';
          final List<dynamic> details =
              pack['details'] is List ? pack['details'] as List : const [];
          final String? imageUrl = pack['image_url']?.toString();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? packColor.withOpacity(0.16) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? packColor : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectPack(pack),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 72,
                              width: 72,
                              color: packColor.withOpacity(0.12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              color: packColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pack['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$smsCount SMS',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: packColor.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '₺$price',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (annualPrice.isNotEmpty)
                                    Text(
                                      'Yıllık: ₺$annualPrice',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected ? packColor : Colors.grey,
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showDetailsModal(details, packColor),
                          icon: Icon(Icons.list_alt, color: packColor),
                          label: Text(
                            'Özellikleri Gör',
                            style: TextStyle(color: packColor),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
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
                        child: Text(selected ? 'Seçildi' : 'Paketi Seç'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!twoColumns) {
          return Column(
            children: [
              for (final pack in packs) ...[
                buildCard(pack),
                const SizedBox(height: 12),
              ]
            ],
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
          ),
          itemBuilder: (context, index) => buildCard(packs[index]),
        );
      },
    );
  }

  Widget _buildBuyerForm() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Ad',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Soyad',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _companyController,
          decoration: const InputDecoration(
            labelText: 'Şirket Adı (opsiyonel)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-posta',
            border: OutlineInputBorder(),
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
                child: const Text('Yenile'),
              ),
            ],
          )
        else
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Ülke',
              border: OutlineInputBorder(),
            ),
            value: _selectedCountryId,
            onChanged: (val) {
            if (val == null) return;
            final selected = _countries
                .firstWhere((c) => c['id'] == val, orElse: () => {});
            setState(() {
              _selectedCountryId = val;
              _selectedPhoneCode =
                  _cleanPhoneCode(selected['phone_code']?.toString());
            });
          },
            items: _countries
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int?,
                    child: Text(
                        '${c['name'] ?? ''} (+${c['phone_code'] ?? '-'})'),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Telefon',
            border: const OutlineInputBorder(),
            prefixText:
                _selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty
                    ? '+${_selectedPhoneCode} '
                    : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _identityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Kimlik No (opsiyonel)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxNumberController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Vergi No (opsiyonel)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxOfficeController,
          decoration: const InputDecoration(
            labelText: 'Vergi Dairesi',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Adres',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Ödeme Yöntemi',
            border: OutlineInputBorder(),
          ),
          value: _selectedPayment,
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
                  child: Text(opt['label'] ?? ''),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Not',
            border: OutlineInputBorder(),
            hintText: 'Faturaya eklenecek not veya özel talepler',
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agreementChecked,
          onChanged: (val) {
            setState(() {
              _agreementChecked = val ?? false;
            });
          },
          title: const Text('Satın alma sözleşmesini okudum, onaylıyorum.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final pack = _selectedPack;
    if (pack == null) {
      return const Text('Özet için önce paket seçmelisiniz.');
    }

    final smsCount = pack['sms_count']?.toString() ?? '-';
    final price = pack['price']?.toString() ?? '-';
    final annualPrice = pack['annual_price']?.toString();
    final paymentLabel = (_paymentOptions.firstWhere(
          (e) => e['value'] == _selectedPayment,
          orElse: () => _paymentOptions.first,
        )['label'] ??
        '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            pack['name']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
              'Tip: ${pack['type']?.toString().toUpperCase() ?? (_selectedType?.toUpperCase() ?? '')}'),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₺$price', style: const TextStyle(fontWeight: FontWeight.w700)),
              if (annualPrice != null && annualPrice.isNotEmpty)
                Text('Yıllık: ₺$annualPrice',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('SMS: $smsCount'),
        if (_companyController.text.trim().isNotEmpty)
          Text('Şirket: ${_companyController.text.trim()}'),
        const SizedBox(height: 8),
        const SizedBox(height: 16),
        const Text(
          'Satın Alma Bilgileri',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text('Ad Soyad: ${_nameController.text} ${_lastNameController.text}'),
        Text('E-posta: ${_emailController.text}'),
        if (_selectedCountryId != null)
          Text(
            'Ülke: ${_countries.firstWhere((c) => c['id'] == _selectedCountryId, orElse: () => {})['name'] ?? ''}',
          ),
        if (_phoneController.text.isNotEmpty)
          Text(
            'Telefon: ${_selectedPhoneCode != null && _selectedPhoneCode!.isNotEmpty ? '+$_selectedPhoneCode ' : ''}${_phoneController.text}',
          ),
        Text('Ödeme: $paymentLabel'),
        if (_taxNumberController.text.isNotEmpty)
          Text('Vergi No: ${_taxNumberController.text}'),
        if (_taxOfficeController.text.isNotEmpty)
          Text('Vergi Dairesi: ${_taxOfficeController.text}'),
        if (_identityController.text.isNotEmpty)
          Text('Kimlik No: ${_identityController.text}'),
        if (_addressController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Adres: ${_addressController.text}'),
        ],
        if (_noteController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Not: ${_noteController.text.trim()}'),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _purchasing ? null : _purchasePack,
            icon: _purchasing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_purchasing ? 'Gönderiliyor...' : 'Satın Al'),
          ),
        ),
      ],
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Paket'),
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
        title: const Text('Bilgiler'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1
            ? StepState.complete
            : (_currentStep == 1 ? StepState.editing : StepState.indexed),
        content: _buildBuyerForm(),
      ),
      Step(
        title: const Text('Özet'),
        isActive: _currentStep >= 2,
        state: _currentStep == 2 ? StepState.editing : StepState.indexed,
        content: _buildSummary(),
      ),
    ];
  }

  void _onContinue() {
    if (_savingBilling || _purchasing) return;
    if (!_validateStep(_currentStep)) return;
    if (_currentStep >= _buildSteps().length - 1) {
      _purchasePack();
    } else if (_currentStep == 1) {
      _saveBillingAddress().then((ok) {
        if (ok && mounted) {
          setState(() {
            _currentStep += 1;
          });
        }
      });
    } else {
      setState(() {
        _currentStep += 1;
      });
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
        title: const Text('SMS Paketleri'),
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
                            label: const Text('Tekrar Dene'),
                          )
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        child: Stepper(
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
                                      onPressed: (_purchasing || _savingBilling)
                                          ? null
                                          : details.onStepContinue,
                                      child: Text(
                                        _purchasing
                                            ? '...'
                                            : _savingBilling
                                                ? 'Kaydediliyor...'
                                                : (isLast ? 'Satın Al' : 'Devam'),
                                      ),
                                    ),
                                  OutlinedButton(
                                    onPressed: details.onStepCancel,
                                    child: const Text('Geri'),
                                  ),
                                ],
                              ),
                            );
                          },
                          steps: _buildSteps(),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
