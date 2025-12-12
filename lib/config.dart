import 'dart:io';

import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  // Local development base URL.
  const localBase = 'http://127.0.0.1:8000';

  // Android emulators cannot hit host loopback directly; use 10.0.2.2 there.
  if (kIsWeb) return localBase;
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return localBase;
}
