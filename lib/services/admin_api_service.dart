import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminApiService {
  AdminApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> login(
      String email, String password, String studentId) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'password': password, 'student_id': studentId}),
    );
    final data = _decode(response);
    _token = data['access_token'] as String;
    return data;
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/admin/dashboard'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<void> deleteReportedComment(String commentId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/admin/community/comments/$commentId'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<void> deleteReportedPost(String postId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/admin/community/posts/$postId'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<void> createPractitioner(Map<String, dynamic> practitioner) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/practitioners'),
      headers: _headers,
      body: jsonEncode(practitioner),
    );
    _decode(response);
  }

  Future<void> moderationAction(String id, String status) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/admin/moderation/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _decode(response);
  }

  Future<void> practitionerAction(String id, String status) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/admin/practitioners/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _decode(response);
  }

  Future<void> updatePolicy(
      String category, bool enabled, double threshold) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/moderation-policies/$category'),
      headers: _headers,
      body: jsonEncode({'enabled': enabled, 'threshold': threshold}),
    );
    _decode(response);
  }

  Future<void> updateSetting(String key, String value) async {
    final response = await _client.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/settings/$key'),
      headers: _headers,
      body: jsonEncode({'value': value}),
    );
    _decode(response);
  }

  Future<void> logout() async {
    if (_token == null) return;
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/logout'),
        headers: _headers,
      );
      _decode(response);
    } finally {
      _token = null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(body as Map);
    }
    final detail = body is Map ? body['detail'] : null;
    throw Exception(detail is String
        ? detail
        : 'Admin request failed (${response.statusCode})');
  }
}
