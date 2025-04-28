import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';  // Added for TimeoutException
import 'package:internet_connection_checker/internet_connection_checker.dart';

class AuthService {
  static const String baseUrl = "http://192.168.100.8/otlist";
  static const Duration timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        body: jsonEncode({
          'username': email,
          'password': password,
        }),
        headers: _headers(),
      ).timeout(timeout);

      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        body: jsonEncode({
          'username': email,
          'password': password,
          'name': name,
        }),
        headers: _headers(),
      ).timeout(timeout);

      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> fetchOperations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/operations'),
        headers: _headers(token: token),
      ).timeout(timeout);

      return _parseListResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

Future<bool> addOperation(String token, String title, String details) async {
  // Immediately return false if no connection
  if (!await InternetConnectionChecker().hasConnection) {
    return false;
  }

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/operations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title, 'details': details}),
    ).timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
 
 // In AuthService
Future<bool> deleteOperation(String token, String operationId) async {
    // First check internet connectivity
    if (!await InternetConnectionChecker().hasConnection) {
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/operations/$operationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      //debugPrint("Error deleting operation: $e");
      return false;
    }
  }


  // Helper methods
  Map<String, String> _headers({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _parseResponse(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Request failed with status ${response.statusCode}');
    }
  }

  List<dynamic> _parseListResponse(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is List ? body : [body];
    } else {
      throw Exception(body['message'] ?? 'Request failed with status ${response.statusCode}');
    }
  }

  String _handleError(dynamic error) {
    if (error is http.ClientException) {
      return 'Connection error: ${error.message}';
    } else if (error is TimeoutException) {
      return 'Request timed out';
    } else if (error is FormatException) {
      return 'Invalid server response';
    }
    return error.toString();
  }
}