import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';



class AuthUser {

  const AuthUser({

    required this.id,

    required this.name,

    required this.email,

  });



  final String id;

  final String name;

  final String email;

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
        _user = AuthUser(id: userId, name: name, email: email);
        _api.setToken(_token);
        notifyListeners();
      }
    }();
  }




  final ApiService _api;



  AuthUser? _user;

  String? _token;

  bool _isLoading = false;



  AuthUser? get user => _user;

  String? get token => _token;

  bool get isLoggedIn => _user != null;

  bool get isLoading => _isLoading;

  ApiService get api => _api;



  Future<String?> signUp({

    required String name,

    required String email,

    required String password,

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

      );

      _user = AuthUser(

        id: result.userId,

        name: result.name,

        email: result.email,

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



  Future<void> logout() async {
    // Try to clear selected theme on server so future logins start default
    try {
      await _api.clearSelectedTheme();
    } catch (_) {
      // ignore errors; still proceed with local logout
    }

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



  bool _isValidEmail(String email) {

    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);

  }

}


