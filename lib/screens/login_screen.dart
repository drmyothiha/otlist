import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:modern_auth_app/providers/auth_provider.dart';
import 'package:modern_auth_app/screens/operations_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final Function()? onRegisterClicked;

  const LoginScreen({super.key, this.onRegisterClicked});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Text("Welcome Back",
                  style: GoogleFonts.poppins(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              Text("Login to continue", style: GoogleFonts.poppins(color: Colors.grey)),
              const SizedBox(height: 50),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Username",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login"),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : widget.onRegisterClicked,
                child: Text("Don't have an account? Register", style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter username and password')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (authProvider.token != null) {
      // ✅ Save token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', authProvider.token!);

      // ✅ Navigate to OperationsScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OperationsScreen(token: authProvider.token!),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login failed: ${e.toString()}')),
    );
  } finally {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }
}

}
