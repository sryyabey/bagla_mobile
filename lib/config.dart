import 'dart:io';

import 'package:flutter/foundation.dart';

const _prodBase = 'https://bagla.app';
const _localHostBase = 'http://127.0.0.1:8000';
const _androidEmulatorBase = 'http://10.0.2.2:8000';

String get apiBaseUrl {
  // APP_ENV=prod ile prod'a geç; aksi halde debug ve APP_ENV=dev/local'da local kullan.
  const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  final useLocal = !kReleaseMode || env == 'dev' || env == 'local';

  if (useLocal) {
    if (kIsWeb) return _localHostBase;
    if (Platform.isAndroid) return _androidEmulatorBase;
    return _localHostBase;
  }

  return _prodBase;
}
