class AppleSubscriptionCatalog {
  static const Map<String, String> _productIds = {
    'spark.monthly': 'app.bagla.spark.monthly',
    'boost.monthly': 'app.bagla.boost.monthly',
    'power.monthly': 'app.bagla.power.monthly',
    'prime.monthly': 'app.bagla.prime.monthly',
    'spark.yearly': 'app.bagla.spark.yearly',
    'boost.yearly': 'app.bagla.boost.yearly',
    'power.yearly': 'app.bagla.power.yearly',
    'prime.yearly': 'app.bagla.prime.yearly',
  };

  static final Map<String, String> _reverseMap = {
    for (var e in _productIds.entries) e.value: e.key
  };

  static Set<String> get productIds => _productIds.values.toSet();

  static String? productIdForPack({
    required String? packName,
    required String? planType,
  }) {
    final packKey = _normalizePackKey(packName);
    final durationKey = _normalizeDurationKey(planType);

    if (packKey == null || durationKey == null) {
      return null;
    }

    final key = '$packKey.$durationKey';
    return _productIds[key];
  }

  static String? productIdForPackData(
    Map<String, dynamic> pack, {
    String? fallbackPlanType,
  }) {
    const directKeys = [
      'apple_product_id',
      'ios_product_id',
      'app_store_product_id',
      'product_id',
    ];

    for (final key in directKeys) {
      final value = pack[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return productIdForPack(
      packName: pack['name']?.toString(),
      planType: pack['type']?.toString() ?? fallbackPlanType,
    );
  }

  static String? packKeyForProductId(String productId) {
    final key = _reverseMap[productId];
    return key?.split('.').first;
  }

  static String? _normalizePackKey(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();

    if (value.contains('spark')) return 'spark';
    if (value.contains('boost')) return 'boost';
    if (value.contains('power')) return 'power';
    if (value.contains('prime')) return 'prime';

    return null;
  }

  static String? _normalizeDurationKey(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase().replaceAll('_', ' ');

    if (value.contains('month')) return 'monthly';
    if (value.contains('annual')) return 'yearly';
    if (value.contains('year')) return 'yearly';

    return null;
  }
}
