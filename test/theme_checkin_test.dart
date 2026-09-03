import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auramind/models/theme_palette.dart';
import 'package:auramind/providers/theme_provider.dart';
import 'package:auramind/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Theme and 24-Hour Check-in Logic', () {
    test('User with check-in within 24h keeps theme and skips MCQ', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/themes/selected/me') {
          return http.Response(
            jsonEncode({
              'id': 'ocean_calm',
              'name': 'Ocean Calm',
              'category': 'anxiety',
              'primary': '#4A90D9',
              'secondary': '#E8F4FD',
              'accent': '#87CEEB',
              'background': '#F5FAFF',
              'surface': '#FFFFFF',
              'onPrimary': '#FFFFFF',
              'onBackground': '#1A3A5C',
              'thumbnailGradient': ['#87CEEB', '#4A90D9', '#E8F4FD'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/checkin/status') {
          return http.Response(
            jsonEncode({
              'completed_within_24_hours': true,
              'last_checkin_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final api = ApiService(client: mockClient);
      final provider = AppThemeProvider();

      await provider.loadSavedTheme(api);

      expect(provider.palette.id, equals('ocean_calm'));
      expect(provider.hasCompletedCheckIn, isTrue);
    });

    test('After 24h, check-in is required but chosen theme stays preserved', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/themes/selected/me') {
          return http.Response(
            jsonEncode({
              'id': 'sage_forest',
              'name': 'Sage Forest',
              'category': 'anxiety',
              'primary': '#6B8F71',
              'secondary': '#F5F0E8',
              'accent': '#9CAF88',
              'background': '#F8FAF5',
              'surface': '#FFFFFF',
              'onPrimary': '#FFFFFF',
              'onBackground': '#2D4A32',
              'thumbnailGradient': ['#9CAF88', '#6B8F71', '#F5F0E8'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/checkin/status') {
          return http.Response(
            jsonEncode({
              'completed_within_24_hours': false,
              'last_checkin_at': DateTime.now()
                  .subtract(const Duration(hours: 25))
                  .toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final api = ApiService(client: mockClient);
      final provider = AppThemeProvider();

      await provider.loadSavedTheme(api);

      // Theme remains as user's picked theme
      expect(provider.palette.id, equals('sage_forest'));
      // Check-in is false so MCQ is shown after 24 hours
      expect(provider.hasCompletedCheckIn, isFalse);
    });

    test('Changing theme from profile updates and persists the palette', () async {
      String? savedPaletteId;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/themes/select') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          savedPaletteId = body['palette_id'] as String;
          return http.Response(jsonEncode({'response': 'Theme saved'}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final api = ApiService(client: mockClient);
      final provider = AppThemeProvider();
      final newTheme = allThemePalettes.firstWhere((p) => p.id == 'sunrise');

      await provider.changeTheme(newTheme, api);

      expect(provider.palette.id, equals('sunrise'));
      expect(savedPaletteId, equals('sunrise'));
    });
  });
}
