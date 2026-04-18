import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import 'offline_sync_service.dart';
import 'cache_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;
  String? _token;
  Map<String, dynamic>? _userData;

  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      _userData = jsonDecode(userJson);
    }
    debugPrint('[API] init: token=${_token != null ? "${_token!.substring(0, 20)}..." : "null"}');
  }

  Map<String, dynamic>? get userData => _userData;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'platform': 'android',
      }),
    );

    final data = await _handleResponse(response);
    final token = data['data']?['access_token'];
    debugPrint('[API] LOGIN token=${token != null ? "${token.toString().substring(0, 30)}..." : "NULL"}');
    if (token != null) {
      _token = token;
      _userData = data['data']?['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      if (_userData != null) {
        await prefs.setString('user_data', jsonEncode(_userData));
      }
    }
    return data;
  }

  Future<void> logout() async {
    _token = null;
    _userData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Future<dynamic> get(String endpoint) async {
    if (!isOnline) {
      debugPrint('[API] OFFLINE GET $endpoint - trying cache');
      final cached = await CacheService.instance.getCachedData(
        endpoint,
        maxAge: const Duration(hours: 24),
      );
      if (cached != null) return cached;
      throw Exception('You are offline');
    }

    final uri = Uri.parse('$baseUrl/$endpoint');
    debugPrint('[API] GET $uri');
    final response = await http.get(uri, headers: _headers);
    debugPrint('[API] RESPONSE [$endpoint] status=${response.statusCode}');
    final result = await _handleResponse(response);

    // Cache successful GET responses
    await CacheService.instance.cacheData(endpoint, result);

    return result;
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    if (!isOnline) {
      debugPrint('[API] OFFLINE POST $endpoint - queuing');
      await OfflineSyncService.instance.enqueueAction(endpoint, 'POST', data);
      return {'status': true, 'queued': true, 'message': 'Action queued for sync'};
    }

    debugPrint('[API] POST $baseUrl/$endpoint');
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    debugPrint('[API] RESPONSE [$endpoint] status=${response.statusCode}');
    final result = await _handleResponse(response);
    return result;
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    if (!isOnline) {
      debugPrint('[API] OFFLINE PUT $endpoint - queuing');
      await OfflineSyncService.instance.enqueueAction(endpoint, 'PUT', data);
      return {'status': true, 'queued': true, 'message': 'Action queued for sync'};
    }

    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return await _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    if (!isOnline) {
      debugPrint('[API] OFFLINE DELETE $endpoint - queuing');
      await OfflineSyncService.instance.enqueueAction(endpoint, 'DELETE', null);
      return {'status': true, 'queued': true, 'message': 'Action queued for sync'};
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    return await _handleResponse(response);
  }

  /// Upload a file via multipart POST.
  Future<dynamic> uploadFile(String endpoint, String filePath, {Map<String, String>? fields}) async {
    if (!isOnline) {
      throw Exception('You are offline. Cannot upload files.');
    }

    final uri = Uri.parse('$baseUrl/$endpoint');
    debugPrint('[API] UPLOAD $uri');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('[API] UPLOAD RESPONSE status=${response.statusCode}');
    return await _handleResponse(response);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _handleResponse(http.Response response) async {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      // Server returned non-JSON (HTML error page, empty body, etc.)
      if (response.statusCode == 404) {
        throw Exception('This feature is not available yet');
      }
      if (response.statusCode == 401) {
        await logout();
        final ctx1 = navigatorKey.currentContext;
        if (ctx1 != null) {
          // ignore: use_build_context_synchronously
          Navigator.of(ctx1).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Server error (${response.statusCode}). Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 401) {
      // Token expired — auto-logout and redirect to login
      await logout();
      final ctx2 = navigatorKey.currentContext;
      if (ctx2 != null) {
        // ignore: use_build_context_synchronously
        Navigator.of(ctx2).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
      throw Exception('Session expired. Please login again.');
    } else {
      final message = body['error']?['message'] ??
          body['message'] ??
          'Error: ${response.statusCode}';
      throw Exception(message);
    }
  }

  bool get isAuthenticated => _token != null;

  bool get isOnline => OfflineSyncService.instance.isOnline.value;
}
