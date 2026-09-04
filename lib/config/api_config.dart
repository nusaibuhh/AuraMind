import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Override with: flutter run --dart-define=API_BASE_URL=https://auramind-production-51c5.up.railway.app
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'https://auramind-production-51c5.up.railway.app';
    if (Platform.isAndroid) return 'https://auramind-production-51c5.up.railway.app';
    return 'https://auramind-production-51c5.up.railway.app';
  }
}
