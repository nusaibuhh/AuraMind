import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auramind/providers/auth_provider.dart';
import 'package:auramind/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Emergency Contact Persistence across Sessions', () {
    test('Login restores emergency contact and persists after logout & relogin',
        () async {
      String currentEmergencyContact = 'guardian@example.com';

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'user_id': 'user_123',
              'name': 'Test User',
              'email': 'test@example.com',
              'emergency_contact': currentEmergencyContact,
              'access_token': 'token_abc',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/profile/me') {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'name': 'Test User',
                'email': 'test@example.com',
                'emergency_contact': currentEmergencyContact,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            currentEmergencyContact = body['emergency_contact'] as String;
            return http.Response(
              jsonEncode({
                'name': body['name'],
                'email': body['email'],
                'emergency_contact': currentEmergencyContact,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not found', 404);
      });

      final api = ApiService(client: mockClient);
      final auth = AuthProvider(api: api);

      // 1. Initial Login
      await auth.login(email: 'test@example.com', password: 'password123');
      expect(auth.user?.emergencyContact, 'guardian@example.com');

      // 2. User updates emergency contact in settings
      await auth.updateProfile(
        name: 'Test User',
        email: 'test@example.com',
        emergencyContact: 'new_trusted@example.com',
      );
      expect(auth.user?.emergencyContact, 'new_trusted@example.com');

      // 3. User logs out
      await auth.logout();
      expect(auth.user, isNull);

      // 4. User logs back in
      await auth.login(email: 'test@example.com', password: 'password123');
      expect(auth.user?.emergencyContact, 'new_trusted@example.com');
    });
  });
}
