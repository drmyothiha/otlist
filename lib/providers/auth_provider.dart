import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';  // For saving token
import '../../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _token;

  bool get isLoading => _isLoading;
  String? get token => _token;

  // Method to login user
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Pass the required named parameters: email and password
      final response = await _authService.login(
        email: email,
        password: password,
      );
      
      // Save the token if the login is successful
      if (response['token'] != null) {
        _token = response['token'];  // Store token in the provider
        // Optionally save the token to shared preferences for persistence
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('token', _token!);
      }
    } catch (e) {
      // Handle error (e.g., show error message)
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to register user

// In your AuthProvider
Future<bool> register(String email, String password, String name) async {
  try {
    final response = await _authService.register(
        email: email,
        password: password,
        name: name,
      );
    _token = response['token']; // Or whatever your success response contains
    return true;
  } catch (e) {
    return false;
  }
}


Future<void> loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  _token = prefs.getString('token'); // ✅ correct variable
  notifyListeners();
}


  // Logout function: Clears the token from memory and preferences
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('token');
    _token = null;
    notifyListeners();
  }
}
