import 'dart:async';
import 'dart:convert';

import 'package:bagla_mobile/auth.dart';
import 'package:bagla_mobile/config.dart';
import 'package:bagla_mobile/dashboard_page.dart';
import 'package:bagla_mobile/l10n/app_localizations.dart';
import 'package:bagla_mobile/login_page.dart';
import 'package:bagla_mobile/services/apple_subscription_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IosPacksPage extends StatefulWidget {
  const IosPacksPage({super.key});

  @override
  State<IosPacksPage> createState() => _IosPacksPageState();
}

class _IosPacksPageState extends State<IosPacksPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static const Set<String> _supportedPlanTypes = {'monthly', 'annual', 'yearly'};

  AppLocalizations get loc => AppLocalizations.of(context);

  bool _loading = true;
  bool _loadingProducts = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _loggingOut = false;
  String? _error;
  String? _storeErrorDetails;
  bool _storeKitAvailable = true;

  List<String> _types = [];
  Map<String, List<Map<String, dynamic>>> _packsByType = {};
  String? _selectedType;
  Map<String, dynamic>? _selectedPack;
  final Map<String, ProductDetails> _productsById = {};
  final Set<String> _notFoundProductIds = <String>{};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Map<String, dynamic>? _pendingPack;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error, StackTrace stackTrace) {
        _logStore('purchase stream error: $error');
        _logStore(stackTrace.toString());
        if (!mounted) return;
        setState(() {
          _storeErrorDetails = 'purchaseStream error: $error';
        });
        _showSnack('Apple satin alma akisi izlenemedi: $error');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingProducts = false;
        _error = loc.smsPacksSessionMissing;
      });
      return;
    }

    await Future.wait([
      _loadPacks(),
      _loadIosProducts(),
    ]);
  }

  Future<void> _handleUnauthorized() async {
    if (_loggingOut) return;
    _loggingOut = true;
    await clearTokens();
    if (!mounted) return;
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
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _error = loc.smsPacksLoadFailedStatus(response.statusCode);
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      debugPrint('[PACKS_RAW] $decoded');
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

      final parsed = <String, List<Map<String, dynamic>>>{};
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

      if (!mounted) return;
      setState(() {
        _types = types.isNotEmpty ? types : parsed.keys.toList();
        _packsByType = parsed;
        _selectedType =
            _selectedType ?? (_types.isNotEmpty ? _types.first : null);
        _loading = false;
      });
      debugPrint('[PACKS_PARSED] types=$_types keys=${parsed.keys}');
      parsed.forEach((k, v) {
        for (final p in v) {
          debugPrint('[PACK] key=$k name=${p['name']} type=${p['type']}');
        }
      });
      _logStore(
        'packs loaded: types=$_types totalPacks=${parsed.values.fold<int>(0, (sum, items) => sum + items.length)}',
      );
    } on AuthRequiredException {
      await _handleUnauthorized();
    } catch (e) {
      _logStore('load packs error: $e');
      if (!mounted) return;
      setState(() {
        _error = loc.smsPacksLoadFailed(e.toString());
        _loading = false;
      });
    }
  }

  static bool _isSupportedPlanType(String? raw) {
    if (raw == null) return false;
    return _supportedPlanTypes.contains(raw.trim().toLowerCase());
  }

  Future<void> _loadIosProducts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _logStore('skip iOS product load: platform is not iOS');
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
      });
      return;
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    debugPrint('[IAP] isAvailable=$isAvailable');
    debugPrint('[IAP] platform=${defaultTargetPlatform.name}');
    _logStore('store availability: $isAvailable');
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _productsById.clear();
        _notFoundProductIds.clear();
        _storeKitAvailable = false;
        _storeErrorDetails = 'InAppPurchase.isAvailable returned false';
        _loadingProducts = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingProducts = true;
        _storeKitAvailable = true;
        _storeErrorDetails = null;
      });
    }

    try {
      debugPrint('[IAP] querying: ${AppleSubscriptionCatalog.productIds}');
      _logStore(
        'querying products: ${AppleSubscriptionCatalog.productIds.join(', ')}',
      );
      final response = await _inAppPurchase.queryProductDetails(
        AppleSubscriptionCatalog.productIds,
      );
      _logStore(
        'product query completed: found=${response.productDetails.length} notFound=${response.notFoundIDs.length} error=${response.error}',
      );
      if (response.notFoundIDs.isNotEmpty) {
        _logStore('notFound product IDs: ${response.notFoundIDs.join(', ')}');
      }
      if (!mounted) return;
      setState(() {
        _productsById
          ..clear()
          ..addEntries(
            response.productDetails.map((item) => MapEntry(item.id, item)),
          );
        _notFoundProductIds
          ..clear()
          ..addAll(response.notFoundIDs);
        _storeErrorDetails =
            response.error != null ? 'queryProductDetails error: ${response.error}' : null;
        _loadingProducts = false;
      });
    } catch (e) {
      _logStore('query products exception: $e');
      if (!mounted) return;
      setState(() {
        _productsById.clear();
        _notFoundProductIds.clear();
        _storeErrorDetails = 'queryProductDetails exception: $e';
        _loadingProducts = false;
      });
    }
  }

  ProductDetails? _appleProductForPack(Map<String, dynamic> pack) {
    final productId = AppleSubscriptionCatalog.productIdForPackData(
      pack,
      fallbackPlanType: _selectedType,
    );
    if (productId == null) return null;
    return _productsById[productId];
  }

  Map<String, dynamic>? _packForProductId(String productId) {
    for (final packs in _packsByType.values) {
      for (final pack in packs) {
        final mappedId = AppleSubscriptionCatalog.productIdForPack(
          packName: pack['name']?.toString(),
          planType: pack['type']?.toString(),
        );
        if (mappedId == productId) return pack;
      }
    }
    return null;
  }

  String _displayPrice(Map<String, dynamic> pack) {
    final product = _appleProductForPack(pack);
    if (product != null) return product.price;
    return _loadingProducts ? 'Loading...' : 'App Store pricing unavailable';
  }

  String _displayTitle(Map<String, dynamic> pack) {
    final product = _appleProductForPack(pack);
    final title = product?.title.trim();
    if (title != null && title.isNotEmpty) return title;
    return pack['name']?.toString() ?? '-';
  }

  String? _productIdForPack(Map<String, dynamic> pack) {
    return AppleSubscriptionCatalog.productIdForPackData(
      pack,
      fallbackPlanType: _selectedType,
    );
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

  void _logStore(String message) {
    debugPrint('[ios_packs] $message');
  }

  String? _diagnosticForPack(Map<String, dynamic> pack) {
    final productId = _productIdForPack(pack);
    if (_storeErrorDetails != null) return _storeErrorDetails;
    if (!_storeKitAvailable) {
      return 'StoreKit unavailable. Device/App Store account may not be ready.';
    }
    if (productId == null) {
      return 'Catalog mapping failed for backend pack="${pack['name']}" type="${pack['type']}".';
    }
    if (_notFoundProductIds.contains(productId)) {
      return 'App Store returned notFound for "$productId".';
    }
    if (!_loadingProducts && !_productsById.containsKey(productId)) {
      return 'Product "$productId" was not loaded from App Store.';
    }
    return null;
  }

  List<String> _mappingIssues() {
    final issues = <String>[];
    for (final entry in _packsByType.entries) {
      for (final pack in entry.value) {
        final productId = _productIdForPack(pack);
        if (productId == null) {
          issues.add(
            'Mapping failed for pack="${pack['name']}" type="${pack['type']}"',
          );
          continue;
        }
        if (_notFoundProductIds.contains(productId)) {
          issues.add(
            'App Store notFound for pack="${pack['name']}" -> $productId',
          );
        }
      }
    }
    return issues;
  }

  String _overallDiagnosis() {
    if (_loading || _loadingProducts) {
      return 'Diagnosis pending. Packages or App Store products are still loading.';
    }
    if (!_storeKitAvailable) {
      return 'StoreKit is unavailable on this device/session. Check App Store account state and sandbox readiness.';
    }
    if (_storeErrorDetails?.contains('storekit_no_response') == true) {
      return 'StoreKit returned no product response. Most likely App Store Connect review-state, sandbox account, or Apple-side product availability issue.';
    }
    if (_notFoundProductIds.isNotEmpty) {
      return 'App Store explicitly did not recognize one or more queried product IDs.';
    }
    if (_productsById.isEmpty) {
      return 'No App Store products were loaded. Most likely App Store Connect configuration or sandbox availability issue.';
    }
    final mappingIssues = _mappingIssues();
    if (mappingIssues.isNotEmpty) {
      return 'App Store returned products, but one or more backend packs could not be matched cleanly.';
    }
    return 'App Store products loaded and backend pack mapping looks healthy.';
  }

  Widget _buildDiagnosticCard() {
    final queriedIds = AppleSubscriptionCatalog.productIds.toList()..sort();
    final loadedIds = _productsById.keys.toList()..sort();
    final notFoundIds = _notFoundProductIds.toList()..sort();
    final mappingIssues = _mappingIssues();

    Widget line(String label, String value, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '$label$value',
          style: TextStyle(
            fontSize: 12,
            color: color ?? Colors.black87,
            fontWeight: label == 'Likely issue: ' ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IAP Diagnosis',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          line('Likely issue: ', _overallDiagnosis()),
          line('StoreKit available: ', _storeKitAvailable ? 'yes' : 'no'),
          line('Backend types: ', _types.isEmpty ? '-' : _types.join(', ')),
          line('Queried IDs: ', queriedIds.join(', ')),
          line('Loaded IDs: ', loadedIds.isEmpty ? '-' : loadedIds.join(', ')),
          line(
            'Not found IDs: ',
            notFoundIds.isEmpty ? '-' : notFoundIds.join(', '),
            color: notFoundIds.isEmpty ? null : Colors.red.shade700,
          ),
          line(
            'Query error: ',
            _storeErrorDetails ?? '-',
            color: _storeErrorDetails == null ? null : Colors.red.shade700,
          ),
          if (mappingIssues.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Mapping issues',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final issue in mappingIssues)
              Text(
                issue,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
          ],
        ],
      ),
    );
  }

  String _describePurchase(PurchaseDetails purchase) {
    return 'status=${purchase.status.name} product=${purchase.productID} purchaseId=${purchase.purchaseID ?? '-'} pendingComplete=${purchase.pendingCompletePurchase} error=${purchase.error}';
  }

  void _selectType(String type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      _selectedPack = null;
    });
  }

  String _localizePlanLabel(String? raw) {
    final value = raw?.toLowerCase().trim();
    if (value == 'monthly') return loc.smsPacksPlanMonthly;
    if (value == 'annual' || value == 'yearly') return loc.smsPacksPlanAnnual;
    return raw?.toUpperCase() ?? '';
  }

  Future<void> _buySelectedPack() async {
    final pack = _selectedPack;
    if (pack == null) {
      _showSnack(loc.smsPacksSelectPack);
      return;
    }

    final product = _appleProductForPack(pack);
    if (product == null) {
      final diagnostic = _diagnosticForPack(pack);
      _logStore(
        'purchase blocked: missing product for pack="${pack['name']}" type="${pack['type']}" mappedProduct="${_productIdForPack(pack)}" diagnostic="$diagnostic"',
      );
      _showSnack(
        diagnostic == null
            ? 'Bu paket icin App Store urunu bulunamadi.'
            : 'Bu paket icin App Store urunu bulunamadi. $diagnostic',
      );
      return;
    }

    setState(() {
      _purchasing = true;
      _pendingPack = Map<String, dynamic>.from(pack);
    });

    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      _logStore('buyNonConsumable started=$started product=${product.id}');
      if (!started && mounted) {
        setState(() {
          _purchasing = false;
        });
        _showSnack('App Store satin alma istegi baslatilamadi.');
      }
    } catch (e) {
      _logStore('buyNonConsumable exception: $e');
      if (!mounted) return;
      setState(() {
        _purchasing = false;
      });
      _showSnack('App Store satin alma hatasi: $e');
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _restoring = true;
    });
    try {
      await _inAppPurchase.restorePurchases();
      _logStore('restorePurchases requested');
      _showSnack('Apple satin alimlari geri yukleniyor...', success: true);
    } catch (e) {
      _logStore('restorePurchases exception: $e');
      if (mounted) {
        setState(() {
          _restoring = false;
        });
      }
      _showSnack('Geri yukleme baslatilamadi: $e');
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _logStore('purchase update: ${_describePurchase(purchase)}');
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
          await _submitPurchaseToBackend(
            purchase: purchase,
            pack: _packForProductId(purchase.productID) ?? _pendingPack,
            restored: purchase.status == PurchaseStatus.restored,
          );
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoring = false;
              _pendingPack = null;
            });
          }
          break;
        case PurchaseStatus.error:
          _logStore('purchase error details: ${purchase.error}');
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
              _restoring = false;
            });
          }
          break;
        case PurchaseStatus.canceled:
          _logStore('purchase canceled for product=${purchase.productID}');
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoring = false;
            });
          }
          _showSnack('Satin alma islemi iptal edildi.');
          break;
      }
    }
  }

  Future<void> _submitPurchaseToBackend({
    required PurchaseDetails purchase,
    required Map<String, dynamic>? pack,
    required bool restored,
  }) async {
    if (pack == null) {
      _logStore(
        'backend submit skipped: no pack match for product=${purchase.productID}',
      );
      _showSnack('App Store urunu icin paket eslesmesi bulunamadi.');
      return;
    }

    try {
      _logStore(
        'submitting purchase to backend: packId=${pack['id']} type=${pack['type']} product=${purchase.productID} restored=$restored',
      );
      final response = await authPost(
        Uri.parse('$apiBaseUrl/api/packs/orders'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pack_id': pack['id'],
          'plan_type': pack['type']?.toString() ?? _selectedType ?? 'monthly',
          'payment_method': 'apple_iap',
          'terms_agreement': true,
          'apple_product_id': purchase.productID,
          'apple_purchase_id': purchase.purchaseID,
          'apple_transaction_date': purchase.transactionDate,
          'apple_source': purchase.verificationData.source,
          'apple_receipt_data':
              purchase.verificationData.serverVerificationData,
          'apple_local_receipt_data':
              purchase.verificationData.localVerificationData,
          'apple_is_restore': restored,
        }),
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logStore('backend submit success: status=${response.statusCode}');
        _showSnack(
          restored
              ? 'Apple aboneligi geri yuklendi.'
              : 'Apple aboneligi basariyla aktif edildi.',
          success: true,
        );
        return;
      }

      String message = 'Apple satin alma backend tarafinda dogrulanamadi.';
      try {
        final decoded = jsonDecode(response.body);
        message = decoded['message']?.toString() ?? message;
      } catch (_) {}
      _logStore(
        'backend submit failed: status=${response.statusCode} body=${response.body}',
      );
      _showSnack(message);
    } on AuthRequiredException {
      await _handleUnauthorized();
    } catch (e) {
      _logStore('backend submit exception: $e');
      _showSnack('Apple satin alma backend hatasi: $e');
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
              label: Text(_localizePlanLabel(t)),
              selected: _selectedType == t,
              onSelected: (_) => _selectType(t),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPackGrid() {
    final packs =
        _selectedType != null ? _packsByType[_selectedType] ?? [] : [];
    if (packs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(loc.smsPacksNoPacksForType),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;
        final mainExtent = constraints.maxWidth >= 720 ? 320.0 : 270.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: mainExtent,
          ),
          itemBuilder: (context, index) {
            final pack = packs[index];
            final selected = _selectedPack?['id'] == pack['id'];
            final price = _displayPrice(pack);
            final smsCount = pack['sms_count']?.toString() ?? '-';
            final color = Colors.indigo.shade600;
            final hasAppleProduct = _appleProductForPack(pack) != null;
            final productId = _productIdForPack(pack);
            final diagnostic = _diagnosticForPack(pack);
            final backendName = pack['name']?.toString() ?? '-';
            final backendType = pack['type']?.toString() ?? '-';

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedPack = pack;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      selected ? color.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade200,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayTitle(pack),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localizePlanLabel(pack['type']?.toString()),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.smsPacksSmsCount(smsCount),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      price,
                      style: TextStyle(
                        color: hasAppleProduct ? color : Colors.orange.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasAppleProduct
                          ? 'App Store subscription'
                          : 'Product not available in App Store yet',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    if (productId != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        productId,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Debug',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'backend name: $backendName',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'backend type: $backendType',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'mapped product: ${productId ?? 'null'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'apple loaded: ${hasAppleProduct ? 'yes' : 'no'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasAppleProduct
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (diagnostic != null)
                              Text(
                                'issue: $diagnostic',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPack = pack;
                          });
                        },
                        child: Text(
                          selected
                              ? loc.smsPacksSelected
                              : loc.smsPacksSelectButton,
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

  @override
  Widget build(BuildContext context) {
    final shouldShowPackList = _loadingProducts || _productsById.isNotEmpty;
    final selectedPrice =
        _selectedPack == null ? null : _displayPrice(_selectedPack!);
    final selectedProductId =
        _selectedPack == null ? null : _productIdForPack(_selectedPack!);
    final selectedHasAppleProduct =
        _selectedPack != null && _appleProductForPack(_selectedPack!) != null;
    final selectedDiagnostic =
        _selectedPack == null ? null : _diagnosticForPack(_selectedPack!);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.dashboardSmsPacks),
        actions: [
          TextButton(
            onPressed: _restoring || _purchasing ? null : _restorePurchases,
            child: Text(
              _restoring ? 'Restoring...' : 'Restore',
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
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _bootstrap,
                            icon: const Icon(Icons.refresh),
                            label: Text(loc.smsPacksRetry),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _bootstrap,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.indigo.shade100),
                          ),
                          child: const Text(
                            'iOS subscriptions are purchased directly with Apple. This screen only shows App Store products and does not request customer contact fields.',
                          ),
                        ),
                        _buildDiagnosticCard(),
                        if (!_loadingProducts && _productsById.isEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Text(
                              'App Store products could not be loaded yet. Check App Store Connect status, sandbox account, and product IDs.',
                            ),
                          ),
                          if (kDebugMode && _storeErrorDetails != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _storeErrorDetails!,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                        if (shouldShowPackList) ...[
                          const SizedBox(height: 16),
                          _buildTypeSelector(),
                          const SizedBox(height: 16),
                          _buildPackGrid(),
                        ],
                        if (shouldShowPackList && _selectedPack != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayTitle(_selectedPack!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(selectedPrice ?? '-'),
                                const SizedBox(height: 6),
                                Text(
                                  _localizePlanLabel(
                                    _selectedPack?['type']?.toString(),
                                  ),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                if (selectedProductId != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedProductId,
                                    style: const TextStyle(
                                      color: Colors.black38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (kDebugMode && selectedDiagnostic != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedDiagnostic,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _purchasing || !selectedHasAppleProduct
                                            ? null
                                            : _buySelectedPack,
                                    icon: _purchasing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.lock_outline),
                                    label: Text(
                                      _purchasing
                                          ? loc.smsPacksSubmitting
                                          : loc.smsPacksBuy,
                                    ),
                                  ),
                                ),
                                if (!selectedHasAppleProduct) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'This package cannot be purchased until the App Store product becomes available.',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
