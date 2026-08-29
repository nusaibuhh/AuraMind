import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/question.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../models/mood_analytics.dart';
import '../models/best_self_vision.dart';
import '../models/consultation.dart';
import '../models/journal_entry.dart';
import '../models/savoring_log.dart';
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
        // Free ngrok tunnels otherwise serve an HTML warning page to browser
        // requests, which Flutter Web reports as a generic "Failed to fetch".
        // Non-ngrok API servers safely ignore this header.
        'ngrok-skip-browser-warning': 'true',
        'X-Timezone-Offset-Minutes':
            DateTime.now().timeZoneOffset.inMinutes.toString(),
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<http.Response> _withTimeout(Future<http.Response> request) async {
    try {
      return await request.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw ApiException(
        'The planner took too long to respond. Please try again when you are ready.',
      );
    }
  }

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

  Future<ThemePalette?> fetchSelectedTheme() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/themes/selected/me'),
      headers: _headers,
    );

    if (response.statusCode == 404) return null;
    final data = await _handleResponse(response);
    return _paletteFromJson(data);
  }

  Future<List<BestSelfVision>> getBestSelfVisions() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/best-self/visions'),
      headers: _headers,
    );
    final data = await _handleResponse(response) as List<dynamic>;
    return data
        .map((item) => BestSelfVision.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBestSelfVision(BestSelfVision vision) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/best-self/visions'),
      headers: _headers,
      body: jsonEncode({
        'id': vision.id,
        'timeline': vision.timeline,
        'vision': vision.vision,
        'created_at': vision.createdAt.toIso8601String(),
      }),
    );
    await _handleResponse(response);
  }

  Future<void> deleteBestSelfVision(String visionId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/best-self/visions/$visionId'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  Future<({String name, String email, String? emergencyContact})>
      updateProfile({
    required String name,
    required String email,
    required String emergencyContact,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/profile/me'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'emergency_contact': emergencyContact,
      }),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return (
      name: data['name'] as String,
      email: data['email'] as String,
      emergencyContact: data['emergency_contact'] as String?,
    );
  }

  Future<({String name, String email, String? emergencyContact})>
      getProfile() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/me'),
      headers: _headers,
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return (
      name: data['name'] as String,
      email: data['email'] as String,
      emergencyContact: data['emergency_contact'] as String?,
    );
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

  // ===== Module 1: Anonymous Community Forum =====

  Future<List<CommunityPost>> getCommunityPosts({int limit = 50}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/community/posts?limit=$limit'),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    if (result is! List) return [];
    return result
        .map((item) => CommunityPost.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<CommunityPost> createCommunityPost(String content) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/community/posts'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    final result = await _handleResponse(response);
    return CommunityPost.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<void> reportCommunityPost({
    required String postId,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/community/posts/$postId/report'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    await _handleResponse(response);
  }

  Future<List<CommunityComment>> getCommunityComments({
    required String postId,
    int limit = 100,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/community/posts/$postId/comments?limit=$limit',
      ),
      headers: _headers,
    );
    final result = await _handleResponse(response);
    if (result is! List) return [];
    return result
        .map(
          (item) => CommunityComment.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<CommunityComment> createCommunityComment({
    required String postId,
    required String content,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/community/posts/$postId/comments'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    final result = await _handleResponse(response);
    return CommunityComment.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<void> reportCommunityComment({
    required String commentId,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/community/comments/$commentId/report'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    await _handleResponse(response);
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

  Future<Map<String, dynamic>> saveSleepLog(
      Map<String, dynamic> payload) async {
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

  // ===== Journal & Notes Endpoints =====

  Future<List<JournalEntry>> getJournalEntries({int limit = 100}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/journal/entries?limit=$limit'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    if (data is! List) return [];
    return data
        .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntry> createJournalEntry({
    String? title,
    required String content,
    String? moodTag,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/journal/entries'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'content': content,
        'mood_tag': moodTag,
      }),
    );
    final data = await _handleResponse(response);
    return JournalEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<JournalEntry> updateJournalEntry({
    required String id,
    String? title,
    required String content,
    String? moodTag,
  }) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/journal/entries/$id'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'content': content,
        'mood_tag': moodTag,
      }),
    );
    final data = await _handleResponse(response);
    return JournalEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteJournalEntry(String entryId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/journal/entries/$entryId'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  // ===== Behavioral Activation Endpoints =====

  Future<Map<String, dynamic>> getTodayBehavioralTask() async {
    final response = await _withTimeout(
      _client.get(
        Uri.parse('${ApiConfig.baseUrl}/behavioral-activation/today'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> completeBehavioralTask(String taskId) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/behavioral-activation/tasks/$taskId/complete'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> skipBehavioralTask(String taskId) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/behavioral-activation/tasks/$taskId/skip'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> submitBehavioralMood(
    String taskId, {
    int? moodBefore,
    int? moodAfter,
  }) async {
    final payload = <String, dynamic>{};
    if (moodBefore != null) payload['mood_before'] = moodBefore;
    if (moodAfter != null) payload['mood_after'] = moodAfter;

    final response = await _withTimeout(
      _client.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/behavioral-activation/tasks/$taskId/mood'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> changeBehavioralTask(String taskId) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/behavioral-activation/tasks/$taskId/change'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getBehavioralHistory(
      {int? days, int limit = 30}) async {
    final query = days != null ? '?days=$days&limit=$limit' : '?limit=$limit';
    final response = await _withTimeout(
      _client.get(
        Uri.parse('${ApiConfig.baseUrl}/behavioral-activation/history$query'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> getBehavioralStats({int days = 7}) async {
    final response = await _withTimeout(
      _client.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/behavioral-activation/stats?days=$days'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  // ===== Savoring Log Endpoints =====

  Future<Map<String, dynamic>> getTodaySavoringLog() async {
    final response = await _withTimeout(
      _client.get(
        Uri.parse('${ApiConfig.baseUrl}/savoring/today'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> saveSavoringLog(
    String logId,
    List<SavoringEntry> entries,
  ) async {
    final response = await _withTimeout(
      _client.put(
        Uri.parse('${ApiConfig.baseUrl}/savoring/logs/$logId'),
        headers: _headers,
        body: jsonEncode({
          'entries': entries.map((entry) => entry.toJson()).toList(),
        }),
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> completeSavoringLog(
    String logId,
    List<SavoringEntry> entries,
  ) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse('${ApiConfig.baseUrl}/savoring/logs/$logId/complete'),
        headers: _headers,
        body: jsonEncode({
          'entries': entries.map((entry) => entry.toJson()).toList(),
        }),
      ),
    );
    final result = await _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getSavoringHistory({
    int? days,
    int limit = 30,
  }) async {
    final query = days == null ? '?limit=$limit' : '?days=$days&limit=$limit';
    final response = await _withTimeout(
      _client.get(
        Uri.parse('${ApiConfig.baseUrl}/savoring/history$query'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return result is List ? result : [];
  }

  // ===== Consultation Booking and Payment Endpoints =====

  Future<List<Psychiatrist>> getConsultationPractitioners({
    int days = 14,
  }) async {
    final response = await _withTimeout(
      _client.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/consultations/practitioners?days=$days'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return (result as List)
        .map((item) => Psychiatrist.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<ConsultationBooking> createConsultationBooking({
    required String practitionerId,
    required String slotId,
    required String paymentTiming,
  }) async {
    final response = await _withTimeout(
      _client.post(
        Uri.parse('${ApiConfig.baseUrl}/consultations/bookings'),
        headers: _headers,
        body: jsonEncode({
          'practitioner_id': practitionerId,
          'slot_id': slotId,
          'payment_timing': paymentTiming,
        }),
      ),
    );
    final result = await _handleResponse(response);
    return ConsultationBooking.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<ConsultationBooking>> getMyConsultationBookings() async {
    final response = await _withTimeout(
      _client.get(
        Uri.parse('${ApiConfig.baseUrl}/consultations/bookings/me'),
        headers: _headers,
      ),
    );
    final result = await _handleResponse(response);
    return (result as List)
        .map((item) => ConsultationBooking.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<ConsultationCheckout> startConsultationPayment({
    required String bookingId,
    required String method,
    required String customerPhone,
  }) async {
    final response = await _client
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}/consultations/bookings/$bookingId/payments',
          ),
          headers: _headers,
          body: jsonEncode({
            'method': method,
            'customer_phone': customerPhone,
          }),
        )
        .timeout(const Duration(seconds: 25));
    final result = await _handleResponse(response);
    return ConsultationCheckout.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<ConsultationBooking> refreshConsultationPayment(
    String bookingId,
  ) async {
    final response = await _client
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}/consultations/bookings/$bookingId/payments/refresh',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 25));
    final result = await _handleResponse(response);
    return ConsultationBooking.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  static Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
