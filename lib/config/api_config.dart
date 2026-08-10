import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Override with: flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }
}
