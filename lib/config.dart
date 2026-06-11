import 'dart:io';

import 'package:flutter/foundation.dart';

const _prodBase = 'https://bagla.app';
const _localHostBase = 'http://127.0.0.1:8000';
const _androidEmulatorBase = 'http://10.0.2.2:8000';
// App Store ID (in_app_review için)
const appleAppStoreId = '6744039002';

const standardAppleEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const privacyPolicyUrl = 'https://bagla.app/contract/22';

// Google Sign-In (Android)
const googleAndroidPackageName = 'com.bagla.app';
const googleAndroidSha1 =
    'EF:BC:55:36:81:B0:19:43:A5:F9:36:52:23:8D:EB:E3:9E:4F:AF:92';
const googleAndroidClientId =
    '99910465030-vj8m6u9nccv4lt0528bk2c3f3i0vouf5.apps.googleusercontent.com';

// Backend ID token doğrulaması için Web OAuth client.
const googleWebServerClientId =
    '99910465030-ng2ik9e1hpmbv9dg5530u7jr2e2emrmu.apps.googleusercontent.com';

String get apiBaseUrl {
  // APP_ENV=prod -> prod, APP_ENV=dev/local -> local; varsayılan prod. prod olursa bagla.app dev olursa localhost
  const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  const useLocal = env == 'dev' || env == 'local';

  if (useLocal) {
    if (kIsWeb) return _localHostBase;
    if (Platform.isAndroid) return _androidEmulatorBase;
    return _localHostBase;
  }
  return _prodBase;
}
