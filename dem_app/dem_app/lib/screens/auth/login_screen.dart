import 'dart:convert'; // Fix: was missing, needed for jsonEncode / jsonDecode
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── State variables ───────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscureText = true;
  bool isLogin = true; // Fix: was used throughout build() but never declared

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ── Other fields ──────────────────────────────────────────────────────────
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final storage = FlutterSecureStorage(); // Fix: removed duplicate declared inside initState

  String? _errorMessage;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkToken(); // Fix: initState cannot be async; extracted to a helper
  }

  // Fix: await requires an async context; pulled out of initState
  Future<void> _checkToken() async {
    final token = await storage.read(key: 'token'); // Fix: now uses class-level storage, not a duplicate local
    if (token != null && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      int? phone = int.tryParse(_phoneController.text.trim());

      if (phone == null) {
        setState(() {
          _errorMessage = "Invalid Phone Number";
          _isLoading = false;
        });
        return;
      }

      try {
        print("Attempting login with phone: $phone");
        final response = await http.post(
          Uri.parse('http://192.168.55.176:5000/api/patient/signin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,
            'password': _passwordController.text.trim(),
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          final token = data['token'];
          // Fix: moved storage write inside the success branch only
          await storage.write(key: 'token', value: token);

          final dynamic userIdValue = data['userId'] ?? data['id'];
          final String? userId = userIdValue?.toString();
          if (userId != null) {
            await storage.write(key: 'userId', value: userId);
          }

          if (mounted) context.go('/dashboard');
        } else {
          setState(() {
            _errorMessage = "Invalid Phone Number or password";
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = "Something went wrong. Please try again.";
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form( // Fix: Form widget was missing; _formKey was attached to nothing
        key: _formKey,
        child: Column(
          children: [
            // HEADER
            Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0E8F8F)],
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // FORM
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone, // Fix: TextInputType.Number does not exist
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter Phone Number";
                          }
                          if (value.length != 10) {
                            return "Write valid Phone Number";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter password";
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: "Password",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Error Message
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),

                      const SizedBox(height: 20),

                      // Submit button
                      GestureDetector(
                        onTap: () {
                          if (isLogin) {
                            login();
                          } else {
                            context.go('/profile-setup');
                          }
                        },
                        child: Container(
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isLogin ? "Login" : "Create Account",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}