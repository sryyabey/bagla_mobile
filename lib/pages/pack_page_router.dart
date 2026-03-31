import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ios_packs.dart';
import 'sms_packs.dart';

Widget buildPackPageForPlatform() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return const IosPacksPage();
  }
  return const SmsPacksPage();
}
