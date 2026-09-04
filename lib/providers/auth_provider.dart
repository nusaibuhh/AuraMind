import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.emergencyContact,
  });

  final String id;

  final String name;

  final String email;
  final String? emergencyContact;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService() {
    _init();
  }

  // initialize persisted session
  void _init() {
    () async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final name = prefs.getString('user_name');
      final email = prefs.getString('user_email');
      if (token != null && userId != null && name != null && email != null) {
        _token = token;
        _user = AuthUser(
            id: userId,
            name: name,
            email: email,
            emergencyContact: prefs.getString('emergency_contact'));
        _api.setToken(_token);
        try {
          final profile = await _api.getProfile();
          _user = AuthUser(
              id: userId,
              name: profile.name,
              email: profile.email,
              emergencyContact: profile.emergencyContact);
          await prefs.setString('user_name', profile.name);
          await prefs.setString('user_email', profile.email);
          if (profile.emergencyContact != null)
            await prefs.setString(
                'emergency_contact', profile.emergencyContact!);
        } catch (_) {}
      }
      _isReady = true;
      notifyListeners();
    }();
  }

  final ApiService _api;

  AuthUser? _user;

  String? _token;

  bool _isLoading = false;
  bool _isReady = false;

  AuthUser? get user => _user;

  String? get token => _token;

  bool get isLoggedIn => _user != null;

  /// True after persisted authentication has been restored (or confirmed absent).
  bool get isReady => _isReady;

  bool get isLoading => _isLoading;

  ApiService get api => _api;

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required String emergencyContact,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (name.trim().isEmpty) {
      return 'Please enter your name';
    }

    if (!_isValidEmail(normalizedEmail)) {
      return 'Please enter a valid email';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    _isLoading = true;

    notifyListeners();

    try {
      final result = await _api.signUp(
        name: name,
        email: normalizedEmail,
        password: password,
        emergencyContact: emergencyContact.trim(),
      );

      _user = AuthUser(
        id: result.userId,
        name: result.name,
        email: result.email,
        emergencyContact: emergencyContact.trim(),
      );

      _token = result.token;
      _api.setToken(_token);
      // persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_id', _user!.id);
      await prefs.setString('user_name', _user!.name);
      await prefs.setString('user_email', _user!.email);

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not connect to server. Is the backend running?';
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!_isValidEmail(normalizedEmail)) {
      return 'Please enter a valid email';
    }

    if (password.isEmpty) {
      return 'Please enter your password';
    }

    _isLoading = true;

    notifyListeners();

    try {
      final result = await _api.login(
        email: normalizedEmail,
        password: password,
      );

      _user = AuthUser(
        id: result.userId,
        name: result.name,
        email: result.email,
        emergencyContact: result.emergencyContact,
      );

      _token = result.token;
      _api.setToken(_token);
      // persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_id', _user!.id);
      await prefs.setString('user_name', _user!.name);
      await prefs.setString('user_email', _user!.email);
      if (_user!.emergencyContact != null && _user!.emergencyContact!.isNotEmpty) {
        await prefs.setString('emergency_contact', _user!.emergencyContact!);
      }

      // Also sync profile in background to ensure latest emergency contact is captured
      try {
        final profile = await _api.getProfile();
        _user = AuthUser(
          id: _user!.id,
          name: profile.name,
          email: profile.email,
          emergencyContact: profile.emergencyContact ?? _user!.emergencyContact,
        );
        if (_user!.emergencyContact != null && _user!.emergencyContact!.isNotEmpty) {
          await prefs.setString('emergency_contact', _user!.emergencyContact!);
        }
      } catch (_) {}

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not connect to server. Is the backend running?';
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;

    _token = null;

    _api.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');

    notifyListeners();
  }

  Future<String?> updateProfile(
      {required String name,
      required String email,
      required String emergencyContact}) async {
    try {
      final result = await _api.updateProfile(
          name: name.trim(),
          email: email.trim(),
          emergencyContact: emergencyContact.trim());
      _user = AuthUser(
          id: _user!.id,
          name: result.name,
          email: result.email,
          emergencyContact: result.emergencyContact);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', result.name);
      await prefs.setString('user_email', result.email);
      if (result.emergencyContact == null || result.emergencyContact!.isEmpty) {
        await prefs.remove('emergency_contact');
      } else {
        await prefs.setString('emergency_contact', result.emergencyContact!);
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save profile changes.';
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not change your password.';
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
}
