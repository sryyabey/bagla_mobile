import 'dart:io';

import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  // Production base URL.
  const prodBase = 'https://bagla.app';
  // const localBase = 'http://127.0.0.1:8000'; // Dev only

  // Use production everywhere; uncomment localBase above for local dev.
  if (kIsWeb) return prodBase;
  if (Platform.isAndroid) return prodBase;
  return prodBase;
}
