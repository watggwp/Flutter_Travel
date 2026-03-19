import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PostService {
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

  // Create a new post
  Future<bool> createPost({
    required String imageBase64,
    required String caption,
    required String locationName,
    double? lat,
    double? lng,
    List<String> tags = const [],
  }) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: _headers(token),
        body: jsonEncode({
          'imageBase64': imageBase64,
          'caption': caption,
          'locationName': locationName,
          'lat': lat,
          'lng': lng,
          'tags': tags,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Create post error: $e');
      return false;
    }
  }

  // Get feed
  Future<List<dynamic>> getFeed({int limit = 20, int offset = 0}) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/feed?limit=$limit&offset=$offset'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['posts'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Get feed error: $e');
      return [];
    }
  }

  // Get single post
  Future<Map<String, dynamic>?> getPost(int postId) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['post'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get post error: $e');
      return null;
    }
  }

  // Get posts by user
  Future<List<dynamic>> getUserPosts(int userId) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/posts'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['posts'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Toggle like — returns true if now liked
  Future<bool> toggleLike(int postId) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['liked'] as bool;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get comments
  Future<List<dynamic>> getComments(int postId) async {
    final token = await _getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['comments'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Add comment
  Future<Map<String, dynamic>?> addComment(int postId, String text) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: _headers(token),
        body: jsonEncode({'text': text}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['comment'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Toggle follow
  Future<bool> toggleFollow(int userId) async {
    final token = await _getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/follows/$userId'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['following'] as bool;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user public profile
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    final token = await _getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['user'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
