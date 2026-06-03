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
import 'package:flutter_html/flutter_html.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class IosPacksPage extends StatefulWidget {
  const IosPacksPage({super.key});

  @override
  State<IosPacksPage> createState() => _IosPacksPageState();
}

class _IosPacksPageState extends State<IosPacksPage>
    with SingleTickerProviderStateMixin {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  static const Set<String> _supportedPlanTypes = {
    'monthly',
    'annual',
    'yearly',
  };

  AppLocalizations get loc => AppLocalizations.of(context);

  bool _loading = true;
  bool _loadingProducts = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _agreementChecked = false;
  String? _error;
  String? _storeErrorDetails;
  bool _storeKitAvailable = true;
  String? _contractTitle;
  String? _contractDescriptionHtml;

  List<String> _types = [];
  String? _selectedType;
  ProductDetails? _selectedProduct;
  final Map<String, ProductDetails> _productsById = {};
  final Set<String> _notFoundProductIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _packDetailsByProductId = {};
  final Set<String> _loadingPackDetailsIds = <String>{};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _loggingOut = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const _bg = Color(0xFFF7F5F2);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceElevated = Color(0xFFF0EDE8);
  static const _border = Color(0xFFE4DDD4);
  static const _accent = Color(0xFF6F6255);
  static const _accentSoft = Color(0xFF8F8172);
  static const _textPrimary = Color(0xFF1A1714);
  static const _textSecondary = Color(0xFF7A736B);
  static const _textTertiary = Color(0xFFB0A89E);
  static const _highlight = Color(0xFFE8DED0);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error, StackTrace stackTrace) {
        _logStore('purchase stream error: $error');
        _logStore(stackTrace.toString());
        if (!mounted) return;
        setState(() {
          _storeErrorDetails = 'purchaseStream error: $error';
        });
        _showSnack(loc.iosPacksPurchaseStreamError(error.toString()));
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([
      _loadIosProducts(),
      _loadContract(),
    ]);
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
    _logStore('store availability: $isAvailable');
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _productsById.clear();
        _notFoundProductIds.clear();
        _storeKitAvailable = false;
        _storeErrorDetails = 'InAppPurchase.isAvailable returned false';
        _loadingProducts = false;
        _loading = false;
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
      _logStore(
        'querying products: ${AppleSubscriptionCatalog.productIds.join(', ')}',
      );
      final response = await _inAppPurchase.queryProductDetails(
        AppleSubscriptionCatalog.productIds,
      );
      _logStore(
        'product query completed: found=${response.productDetails.length} notFound=${response.notFoundIDs.length}',
      );
      if (!mounted) return;
      final productsById = {
        for (final item in response.productDetails) item.id: item,
      };
      final types = response.productDetails
          .map((item) => _planTypeForProductId(item.id))
          .whereType<String>()
          .where(_isSupportedPlanType)
          .toSet()
          .toList()
        ..sort(_comparePlanTypes);
      setState(() {
        _productsById
          ..clear()
          ..addAll(productsById);
        _notFoundProductIds
          ..clear()
          ..addAll(response.notFoundIDs);
        _types = types;
        _selectedType = types.contains(_selectedType)
            ? _selectedType
            : (types.isNotEmpty ? types.first : null);
        final selectedId = _selectedProduct?.id;
        _selectedProduct = selectedId != null
            ? _productsById[selectedId]
            : _selectDefaultProduct(types);
        _storeErrorDetails = response.error != null
            ? 'queryProductDetails error: ${response.error}'
            : null;
        _loadingProducts = false;
        _loading = false;
      });
      _fadeController
        ..reset()
        ..forward();
    } catch (e) {
      _logStore('query products exception: $e');
      if (!mounted) return;
      setState(() {
        _productsById.clear();
        _notFoundProductIds.clear();
        _types = const [];
        _selectedType = null;
        _selectedProduct = null;
        _storeErrorDetails = 'queryProductDetails exception: $e';
        _loadingProducts = false;
        _loading = false;
      });
    }
  }

  int _comparePlanTypes(String a, String b) {
    const order = {'monthly': 0, 'yearly': 1, 'annual': 1};
    return (order[a] ?? 99).compareTo(order[b] ?? 99);
  }

  String? _planTypeForProductId(String? productId) {
    if (productId == null) return null;
    final value = productId.toLowerCase();
    if (value.contains('monthly')) return 'monthly';
    if (value.contains('annual')) return 'annual';
    if (value.contains('yearly')) return 'yearly';
    if (value.contains('year')) return 'yearly';
    if (value.contains('month')) return 'monthly';
    return null;
  }

  String _productDebugName(String productId) {
    final key = AppleSubscriptionCatalog.packKeyForProductId(productId);
    if (key == null || key.isEmpty) return productId;
    return '${key[0].toUpperCase()}${key.substring(1)}';
  }

  String? _assetPathForProduct(String productId) {
    final normalized = productId.trim();
    if (normalized.isEmpty) return null;
    return 'assets/ios_packs/$normalized.webp';
  }

  int _compareProducts(ProductDetails a, ProductDetails b) {
    const packOrder = {'spark': 0, 'boost': 1, 'power': 2, 'prime': 3};
    final aPack = AppleSubscriptionCatalog.packKeyForProductId(a.id);
    final bPack = AppleSubscriptionCatalog.packKeyForProductId(b.id);
    final packCompare =
        (packOrder[aPack] ?? 99).compareTo(packOrder[bPack] ?? 99);
    if (packCompare != 0) return packCompare;
    final typeCompare = _comparePlanTypes(
      _planTypeForProductId(a.id) ?? '',
      _planTypeForProductId(b.id) ?? '',
    );
    if (typeCompare != 0) return typeCompare;
    return a.id.compareTo(b.id);
  }

  List<ProductDetails> _productsForSelectedType() {
    final selectedType = _selectedType;
    final products = _productsById.values.where((product) {
      if (selectedType == null) return true;
      return _planTypeForProductId(product.id) == selectedType;
    }).toList()
      ..sort(_compareProducts);
    return products;
  }

  ProductDetails? _selectDefaultProduct(List<String> types) {
    final selectedType = types.isNotEmpty ? types.first : null;
    if (selectedType == null) {
      final products = _productsById.values.toList()..sort(_compareProducts);
      return products.isEmpty ? null : products.first;
    }
    final productsForType = _productsById.values
        .where((item) => _planTypeForProductId(item.id) == selectedType)
        .toList()
      ..sort(_compareProducts);
    return productsForType.isEmpty ? null : productsForType.first;
  }

  String _displayPrice(ProductDetails product) => product.price;

  String _displayTitle(ProductDetails product) {
    final title = product.title.trim();
    return title.isNotEmpty ? title : _productDebugName(product.id);
  }

  Map<String, String?> _parseContractPayload(dynamic rawData) {
    final data = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{});

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

    return {
      'title': contractTitle,
      'description': contractDesc,
    };
  }

  Future<void> _handleUnauthorized() async {
    if (_loggingOut) return;
    _loggingOut = true;
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

  Future<void> _loadContract() async {
    try {
      final response = await authGet(
        Uri.parse('$apiBaseUrl/api/packs'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'] ?? decoded;
      final contract = _parseContractPayload(data);
      if (!mounted) return;
      setState(() {
        _contractTitle = contract['title'];
        _contractDescriptionHtml = contract['description'];
      });
    } on AuthRequiredException {
      await _handleUnauthorized();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchPackDetails(
      String iosProductId) async {
    try {
      final response = await authGet(
        Uri.parse(
          '$apiBaseUrl/api/packs/ios-pack-details',
        ).replace(queryParameters: {'ios_product_id': iosProductId}),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return const [];
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      final iosPackDetails =
          data is Map<String, dynamic> ? data['ios_pack_details'] : null;
      final details = iosPackDetails is Map<String, dynamic>
          ? iosPackDetails['details']
          : null;

      if (details is! List) return const [];

      return details
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on AuthRequiredException {
      await _handleUnauthorized();
      return const [];
    }
  }

  Future<void> _showPackDetails(ProductDetails product) async {
    final iosProductId = product.id.trim();
    if (iosProductId.isEmpty) {
      _showSnack(loc.iosPacksPackIdMissing);
      return;
    }

    if (!_packDetailsByProductId.containsKey(iosProductId)) {
      setState(() {
        _loadingPackDetailsIds.add(iosProductId);
      });

      try {
        final details = await _fetchPackDetails(iosProductId);
        if (!mounted) return;
        setState(() {
          _packDetailsByProductId[iosProductId] = details;
        });
      } catch (e) {
        if (!mounted) return;
        _showSnack(loc.iosPacksPackDetailsLoadFailed(e.toString()));
        return;
      } finally {
        if (mounted) {
          setState(() {
            _loadingPackDetailsIds.remove(iosProductId);
          });
        }
      }
    }

    if (!mounted) return;
    final details = _packDetailsByProductId[iosProductId] ?? const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.iosPacksPackDetailsTitle(_displayTitle(product)),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  iosProductId,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: details.isEmpty
                      ? Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Text(
                            loc.iosPacksNoPackDetails,
                            style: TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                              height: 1.45,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: details.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final item = details[index];
                            final name = item['name']?.toString().trim() ?? '';
                            final description =
                                item['description']?.toString().trim() ?? '';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFCF8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? '-' : name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      loc.smsPacksClose,
                      style: TextStyle(color: _accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      _showSnack(loc.iosPacksInvalidLink(value));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showSnack(loc.iosPacksLinkOpenFailed(value));
  }

  void _showAgreementSheet() {
    final htmlText = _contractDescriptionHtml ?? loc.smsPacksContentMissing;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _contractTitle ?? loc.smsPacksContract,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    child: Html(
                      data: htmlText,
                      style: {
                        'body': Style(
                          color: _textSecondary,
                          fontSize: FontSize(13),
                        ),
                        'p': Style(color: _textSecondary),
                        'li': Style(color: _textSecondary),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      loc.smsPacksClose,
                      style: TextStyle(color: _accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF5F9B77) : const Color(0xFFB86C6C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _logStore(String message) => debugPrint('[ios_packs] $message');

  String? _diagnosticForProductId(String productId) {
    if (_storeErrorDetails != null) return _storeErrorDetails;
    if (!_storeKitAvailable) {
      return loc.iosPacksStoreKitUnavailable;
    }
    if (_notFoundProductIds.contains(productId)) {
      return loc.iosPacksStoreProductNotFound(productId);
    }
    if (!_loadingProducts && !_productsById.containsKey(productId)) {
      return loc.iosPacksStoreProductMissing(productId);
    }
    return null;
  }

  String _describePurchase(PurchaseDetails purchase) =>
      'status=${purchase.status.name} product=${purchase.productID} purchaseId=${purchase.purchaseID ?? '-'}';

  void _selectType(String type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      final products = _productsForSelectedType();
      _selectedProduct = products.isEmpty ? null : products.first;
    });
  }

  String _localizePlanLabel(String? raw) {
    final value = raw?.toLowerCase().trim();
    if (value == 'monthly') return loc.smsPacksPlanMonthly;
    if (value == 'annual' || value == 'yearly') return loc.smsPacksPlanAnnual;
    return raw?.toUpperCase() ?? '';
  }

  String _headlineForSelectedProduct(ProductDetails? product) {
    final key = product == null
        ? null
        : AppleSubscriptionCatalog.packKeyForProductId(product.id);
    switch (key) {
      case 'spark':
        return loc.iosPacksPlanSparkHeadline;
      case 'boost':
        return loc.iosPacksPlanBoostHeadline;
      case 'power':
        return loc.iosPacksPlanPowerHeadline;
      case 'prime':
        return loc.iosPacksPlanPrimeHeadline;
      default:
        return loc.iosPacksPlanDefaultHeadline;
    }
  }

  List<String> _benefitsForSelectedProduct(ProductDetails? product) {
    final duration = product == null
        ? loc.iosPacksSubscriptionGeneric
        : _localizePlanLabel(_planTypeForProductId(product.id)).toLowerCase();
    return [
      loc.iosPacksBenefitAppointmentAccess(duration),
      loc.iosPacksBenefitSecureCheckout,
      loc.iosPacksBenefitManageSubscription,
    ];
  }

  Widget _buildTrustHero() {
    final benefits = _benefitsForSelectedProduct(_selectedProduct);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              loc.iosPacksAppleSubscription,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _headlineForSelectedProduct(_selectedProduct),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.iosPacksHeroDescription,
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          for (final benefit in benefits) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EEE6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: _accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _buySelectedPack() async {
    final product = _selectedProduct;
    if (product == null) {
      _showSnack(loc.smsPacksSelectPack);
      return;
    }
    if (!_agreementChecked) {
      _showSnack(loc.smsPacksAgreementRequired);
      return;
    }
    final diagnostic = _diagnosticForProductId(product.id);
    if (diagnostic != null) {
      _logStore(
          'purchase blocked: product=${product.id} diagnostic="$diagnostic"');
      _showSnack(loc.iosPacksStoreProductUnavailable(diagnostic));
      return;
    }
    setState(() => _purchasing = true);
    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      _logStore('buyNonConsumable started=$started product=${product.id}');
      if (!started && mounted) {
        setState(() => _purchasing = false);
        _showSnack(loc.iosPacksPurchaseStartFailed);
      }
    } catch (e) {
      _logStore('buyNonConsumable exception: $e');
      if (!mounted) return;
      setState(() => _purchasing = false);
      _showSnack(loc.iosPacksPurchaseFailed(e.toString()));
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoring = true);
    try {
      await _inAppPurchase.restorePurchases();
      _logStore('restorePurchases requested');
      _showSnack(loc.iosPacksRestoreStarted, success: true);
    } catch (e) {
      _logStore('restorePurchases exception: $e');
      if (mounted) setState(() => _restoring = false);
      _showSnack(loc.iosPacksRestoreFailed(e.toString()));
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _logStore('purchase update: ${_describePurchase(purchase)}');
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _purchasing = true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoring = false;
            });
          }
          _showSnack(
            purchase.status == PurchaseStatus.restored
                ? loc.iosPacksRestoreSuccess
                : loc.iosPacksPurchaseSuccess,
            success: true,
          );
          break;
        case PurchaseStatus.error:
          _logStore('purchase error: ${purchase.error}');
          _showSnack(
            purchase.error?.message.isNotEmpty == true
                ? purchase.error!.message
                : loc.iosPacksPurchaseUnknownError,
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
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (mounted) {
            setState(() {
              _purchasing = false;
              _restoring = false;
            });
          }
          _showSnack(loc.iosPacksPurchaseCancelled);
          break;
      }
    }
  }

  Widget _buildTypeToggle() {
    if (_types.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: _types.map((t) {
          final selected = _selectedType == t;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectType(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _highlight : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _localizePlanLabel(t),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? _accent : _textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPackCard(ProductDetails product) {
    final selected = _selectedProduct?.id == product.id;
    final imageAsset = _assetPathForProduct(product.id);
    final hasProduct = _diagnosticForProductId(product.id) == null;
    final isLoadingDetails = _loadingPackDetailsIds.contains(product.id);

    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBF8F3) : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _accentSoft : _border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _surfaceElevated,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: _textTertiary,
                            ),
                          ),
                        ),
                      )
                    : Container(color: _surfaceElevated),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _displayTitle(product),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected ? _accent : _surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selected ? Icons.check : Icons.add,
                          size: 14,
                          color: selected ? Colors.white : _textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (product.description.trim().isNotEmpty)
                    Text(
                      product.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _displayPrice(product),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: selected ? _accent : _textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '/ ${_localizePlanLabel(_planTypeForProductId(product.id))}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!hasProduct) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          loc.iosPacksUnavailableInStore,
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isLoadingDetails
                          ? null
                          : () => _showPackDetails(product),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoadingDetails
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent,
                              ),
                            )
                          : Text(
                              loc.iosPacksDetailsButton,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
  }

  Widget _buildPlanStrip() {
    final products = _productsForSelectedType();
    if (products.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            loc.iosPacksNoProductsForType,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return SizedBox(
      height: 456,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return SizedBox(
            width: 240,
            child: _buildPackCard(products[i]),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutPanel() {
    final product = _selectedProduct;
    if (product == null) return const SizedBox.shrink();
    final hasProduct = _diagnosticForProductId(product.id) == null;
    final diagnostic = _diagnosticForProductId(product.id);
    final imageAsset = _assetPathForProduct(product.id);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.iosPacksSelectedPlan,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageAsset != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    imageAsset,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayTitle(product),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _localizePlanLabel(_planTypeForProductId(product.id)),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.iosPacksActivationInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _displayPrice(product),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ],
          ),
          if (diagnostic != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8C97A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      diagnostic,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _agreementChecked = !_agreementChecked);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _agreementChecked ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _agreementChecked ? _accent : _border,
                      width: 1.5,
                    ),
                  ),
                  child: _agreementChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _agreementChecked = !_agreementChecked);
                  },
                  child: Text(
                    loc.smsPacksAgreementTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showAgreementSheet,
                icon: const Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: _accent,
                ),
                label: Text(
                  loc.iosPacksAgreementDetails,
                  style: TextStyle(
                    fontSize: 12,
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _border),
                  backgroundColor: const Color(0xFFFFFCF8),
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            loc.iosPacksAppointmentPackageInfo,
            style: TextStyle(
              fontSize: 11,
              color: _textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.iosPacksLegalConsent,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OutlinedSoftButton(
                      icon: Icons.description_outlined,
                      label: loc.iosPacksTermsOfUse,
                      onTap: () => _openExternalUrl(standardAppleEulaUrl),
                    ),
                    _OutlinedSoftButton(
                      icon: Icons.privacy_tip_outlined,
                      label: loc.iosPacksPrivacyPolicy,
                      onTap: () => _openExternalUrl(privacyPolicyUrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_purchasing || !hasProduct) ? null : _buySelectedPack,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _surfaceElevated,
                foregroundColor: Colors.white,
                disabledForegroundColor: _textTertiary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _purchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          loc.smsPacksBuy,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableCard() {
    final message = _storeErrorDetails ?? loc.iosPacksStoreUnavailableNow;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowPackList = _loadingProducts || _productsById.isNotEmpty;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: _textPrimary),
          titleTextStyle: TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.dashboardSmsPacks),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DashboardPage()),
                (route) => false,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: _restoring || _purchasing ? null : _restorePurchases,
              child: Text(
                _restoring
                    ? loc.iosPacksRestoreInProgress
                    : loc.iosPacksRestore,
                style: const TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2,
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _bootstrap,
                              icon: const Icon(Icons.refresh),
                              label: Text(loc.smsPacksRetry),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: RefreshIndicator(
                        color: _accent,
                        backgroundColor: _surface,
                        onRefresh: _bootstrap,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          children: [
                            _buildTrustHero(),
                            const SizedBox(height: 20),
                            if (!_loadingProducts && _productsById.isEmpty) ...[
                              _buildUnavailableCard(),
                              const SizedBox(height: 16),
                            ],
                            if (shouldShowPackList) ...[
                              _buildTypeToggle(),
                              const SizedBox(height: 16),
                              if (_loadingProducts)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(
                                      color: _accent,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                _buildPlanStrip(),
                              const SizedBox(height: 20),
                              _buildCheckoutPanel(),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _OutlinedSoftButton extends StatelessWidget {
  const _OutlinedSoftButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4DDD4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8F8172)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F6255),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
