import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/question.dart';
import '../models/mood_analytics.dart';
import '../models/theme_palette.dart';
import '../utils/scoring.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _handleResponse(http.Response response) async {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? {};
    }

    final detail = body is Map ? body['detail'] : null;
    final message = detail is String
        ? detail
        : detail is List
            ? detail.map((e) => e['msg'] ?? e.toString()).join(', ')
            : 'Request failed (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<({String userId, String name, String email, String token})> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = await _handleResponse(response);
    _token = data['access_token'] as String;
    return (
      userId: data['user_id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      token: data['access_token'] as String,
    );
  }

  Future<({String userId, String name, String email, String token})> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(response);
    _token = data['access_token'] as String;
    return (
      userId: data['user_id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      token: data['access_token'] as String,
    );
  }

  Future<({ScoringResult result, List<ThemePalette> palettes})> submitCheckin(
    Map<int, AnswerOption> answers,
  ) async {
    final payload = {
      'answers': {
        for (final entry in answers.entries)
          entry.key.toString(): entry.value.value,
      },
    };

    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/checkin'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = await _handleResponse(response);

    final result = ScoringResult(
      depressionScore: data['depression_score'] as int,
      anxietyScore: data['anxiety_score'] as int,
      stressScore: data['stress_score'] as int,
      dominantCategory: _parseCategory(data['dominant_category'] as String),
    );

    final palettes = (data['recommended_palettes'] as List)
        .map((item) => _paletteFromJson(item as Map<String, dynamic>))
        .toList();

    return (result: result, palettes: palettes);
  }

  Future<MoodAnalytics> getMoodAnalytics({int days = 7}) async {
    if (![7, 30, 90].contains(days)) {
      throw ApiException('Mood analytics period must be 7, 30, or 90 days.');
    }

    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/mood/analytics?days=$days'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return MoodAnalytics.fromJson(data as Map<String, dynamic>);
  }

  Future<void> selectTheme(String paletteId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/themes/select'),
      headers: _headers,
      body: jsonEncode({'palette_id': paletteId}),
    );
    await _handleResponse(response);
  }

  Future<void> clearSelectedTheme() async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/themes/clear'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  Future<String> startGroundingSession(String userId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/startGroundingSession'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return data['session_id'] as String;
  }

  Future<void> addGroundingEntries({
    required String sessionId,
    required String category,
    required List<String> items,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/addGroundingEntries'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
        'category': category,
        'items': items,
      }),
    );
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getGroundingSession(String sessionId) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/getGroundingSession/$sessionId'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  Future<ThemePalette?> fetchSelectedTheme() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/themes/selected/me'),
      headers: _headers,
    );

    if (response.statusCode == 404) return null;
    final data = await _handleResponse(response);
    return _paletteFromJson(data);
  }

  MentalHealthCategory _parseCategory(String value) {
    switch (value) {
      case 'depression':
        return MentalHealthCategory.depression;
      case 'anxiety':
        return MentalHealthCategory.anxiety;
      case 'stress':
        return MentalHealthCategory.stress;
      default:
        return MentalHealthCategory.normal;
    }
  }

  ThemePalette _paletteFromJson(Map<String, dynamic> json) {
    return ThemePalette(
      id: json['id'] as String,
      name: json['name'] as String,
      category: _parseCategory(json['category'] as String),
      primary: _hexColor(json['primary'] as String),
      secondary: _hexColor(json['secondary'] as String),
      accent: _hexColor(json['accent'] as String),
      background: _hexColor(json['background'] as String),
      surface: _hexColor(json['surface'] as String),
      onPrimary: _hexColor(json['onPrimary'] as String),
      onBackground: _hexColor(json['onBackground'] as String),
      thumbnailGradient: (json['thumbnailGradient'] as List)
          .map((c) => _hexColor(c as String))
          .toList(),
    );
  }

  // ===== Sleep Tracking Endpoints =====

  Future<List<dynamic>> getSleepLogs({int days = 30}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/sleep/logs?days=$days'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> getSleepMetrics({int days = 7}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/sleep/metrics?days=$days'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getSleepMoodCorrelation({int days = 7}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/sleep/correlation?days=$days'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  Future<List<dynamic>> getWellbeingWarnings() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/sleep/warnings'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> saveSleepLog(Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/sleep/log'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<void> dismissWarning(String warningId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/sleep/warnings/$warningId/dismiss'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  Future<void> deleteSleepLog(String logId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/sleep/log/$logId'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  // ===== Breathing Exercise Endpoints =====

  Future<Map<String, dynamic>> saveBreathingSession(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/breathing/session'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getBreathingHistory({int limit = 30}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/breathing/history?limit=$limit'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> getBreathingMetrics() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/breathing/metrics'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<void> deleteBreathingSession(String sessionId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/breathing/session/$sessionId'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  static Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
