import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> getNotifications() async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['notifications'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Get notifications error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    final token = await _getToken();
    if (token == null) return 0;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['count'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAllRead() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/read'),
        headers: _headers(token),
      );
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }
}
