import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../widgets/common/neura_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedGender = "Male";
  bool _isLoading = false;
  String? _errorMessage;

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ── Other fields ──────────────────────────────────────────────────────────
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Signup ────────────────────────────────────────────────────────────────

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Phone: backend expects a number
    final int? phone = int.tryParse(_phoneController.text.trim());
    if (phone == null) {
      setState(() {
        _errorMessage = "Invalid phone number.";
        _isLoading = false;
      });
      return;
    }

    // Age: backend expects a number
    final int? age = int.tryParse(_ageController.text.trim());
    if (age == null) {
      setState(() {
        _errorMessage = "Invalid age.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.55.176:5000/api/patient/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'age': age,
          'gender': _selectedGender,
          'phone': phone,
          'password': _passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      // 200 or 201 are both valid success codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        final String? token = data['token'] as String?;
        final patient = data['patient'];
        final String? userId = patient?['id']?.toString();

        await _storage.write(key: 'token', value: token);
        if (userId != null) {
          await _storage.write(key: 'userId', value: userId);
        }

        if (mounted) context.go('/dashboard');
      } else {
        // Backend returns { message: "Patient already exists" } on 400, etc.
        setState(() {
          _errorMessage =
              data['message'] as String? ?? "Signup failed. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ── Header ────────────────────────────────────────────────
                const Text(
                  "Let's Set Up Your Profile",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This helps us personalize your assessments",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 30),

                // ── Avatar (decorative only) ──────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: const Icon(Icons.person,
                            size: 50, color: Colors.grey),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ── Full Name ─────────────────────────────────────────────
                _buildField(
                  label: "Full Name",
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Please enter your full name.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // ── Age ───────────────────────────────────────────────────
                _buildField(
                  label: "Age",
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Please enter your age.";
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 120) {
                      return "Enter a valid age.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Gender ────────────────────────────────────────────────
                const Text("Gender",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ["Male", "Female", "Other"]
                      .map(
                        (g) => Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedGender = g),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedGender == g
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                g,
                                style: TextStyle(
                                  color: _selectedGender == g
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // ── Phone Number ──────────────────────────────────────────
                _buildField(
                  label: "Phone Number",
                  hint: "+91 98765 43210",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Please enter your phone number.";
                    }
                    if (v.length != 10) {
                      return "Enter a valid 10-digit phone number.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // ── Password ──────────────────────────────────────────────
                _buildField(
                  label: "Password",
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Please enter a password.";
                    }
                    if (v.length < 6) {
                      return "Password must be at least 6 characters.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // ── Confirm Password ──────────────────────────────────────
                _buildField(
                  label: "Confirm Password",
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Please confirm your password.";
                    }
                    if (v != _passwordController.text) {
                      return "Passwords do not match.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Error Message ─────────────────────────────────────────
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // ── Submit ────────────────────────────────────────────────
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : NeuraButton(
                        text: "Save & Continue →",
                        onTap: _signup,
                      ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable field widget ─────────────────────────────────────────────────

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint ?? "Enter your $label",
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}