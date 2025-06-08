// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './registration_screen.dart';
import './buyer_dashboard_screen.dart';
import './seller_dashboard_screen.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      print('🔄 Attempting login...');
      print('📡 Login URL: ${ApiConfig.loginUrl}');
      print('📧 Email: ${_emailController.text.trim()}');

      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      print('📡 Login Response Status: ${response.statusCode}');
      print('📡 Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Login successful!');
        print('📊 Response data keys: ${data.keys.toList()}');

        // Extract user ID - try multiple possible field names
        int? userId;
        if (data['userId'] != null) {
          userId = int.tryParse(data['userId'].toString());
        } else if (data['id'] != null) {
          userId = int.tryParse(data['id'].toString());
        } else if (data['user'] != null && data['user']['id'] != null) {
          userId = int.tryParse(data['user']['id'].toString());
        } else if (data['user'] != null && data['user']['userId'] != null) {
          userId = int.tryParse(data['user']['userId'].toString());
        }

        if (userId == null) {
          print('⚠️ Warning: No valid userId found in response, using fallback');
          userId = 1; // Use 1 instead of 123 as fallback
        }

        print('👤 Extracted User ID: $userId');

        // Extract user role - try multiple possible field names
        String userRole = 'buyer'; // default role
        if (data['role'] != null) {
          userRole = data['role'].toString().toLowerCase();
        } else if (data['userType'] != null) {
          userRole = data['userType'].toString().toLowerCase();
        } else if (data['accountType'] != null) {
          userRole = data['accountType'].toString().toLowerCase();
        } else if (data['userRole'] != null) {
          userRole = data['userRole'].toString().toLowerCase();
        } else if (data['type'] != null) {
          userRole = data['type'].toString().toLowerCase();
        } else if (data['user'] != null && data['user']['role'] != null) {
          userRole = data['user']['role'].toString().toLowerCase();
        }

        print('🎭 Extracted role: $userRole');

        // Normalize role values
        if (userRole.contains('buy')) {
          userRole = 'buyer';
        } else if (userRole.contains('sell')) {
          userRole = 'seller';
        } else if (userRole == '0' || userRole == 'false') {
          userRole = 'buyer';
        } else if (userRole == '1' || userRole == 'true') {
          userRole = 'seller';
        }

        print('🎭 Normalized role: $userRole');

        // Extract user name
        String fullName = 'User';
        if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
          fullName = data['fullName'].toString();
        } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
          fullName = data['name'].toString();
        } else if (data['user'] != null && data['user']['fullName'] != null) {
          fullName = data['user']['fullName'].toString();
        } else if (data['user'] != null && data['user']['name'] != null) {
          fullName = data['user']['name'].toString();
        }

        print('📝 Extracted name: $fullName');

        // Store user data globally using UserSession
        final userData = {
          'userId': userId,
          'fullName': fullName,
          'email': data['email'] ?? data['user']?['email'] ?? _emailController.text.trim(),
          'role': userRole,
          'phoneNumber': data['phoneNumber'] ?? data['phone'] ?? data['user']?['phoneNumber'],
          'dateOfBirth': data['dateOfBirth'] ?? data['user']?['dateOfBirth'],
          'token': data['token'] ?? data['accessToken'] ?? data['jwt'],
        };

        UserSession.setCurrentUser(userData);

        print('👤 User stored successfully:');
        print('   - ID: ${UserSession.getCurrentUserId()}');
        print('   - Name: ${UserSession.getCurrentUserName()}');
        print('   - Email: ${UserSession.getCurrentUserEmail()}');
        print('   - Role: ${UserSession.getCurrentUserRole()}');

        // Validate session
        if (!UserSession.validateSession()) {
          print('⚠️ Warning: Session validation failed');
          _showErrorMessage('Login data incomplete. Please try again.');
          return;
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${UserSession.getDisplayName()}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate based on role
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          if (userRole == 'buyer') {
            print('🛒 Navigating to Buyer Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyerDashboardScreen(),
              ),
            );
          } else if (userRole == 'seller') {
            print('🏠 Navigating to Seller Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SellerDashboardScreen(),
              ),
            );
          } else {
            print('❓ Unknown role, defaulting to Buyer Dashboard');
            // Update role to buyer for unknown roles
            UserSession.updateUserRole('buyer');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyerDashboardScreen(),
              ),
            );
          }
        }

      } else if (response.statusCode == 400) {
        _handle400ValidationError(response.body);
      } else if (response.statusCode == 401) {
        try {
          final errorData = json.decode(response.body);
          _showErrorMessage(errorData['message'] ?? 'Invalid email or password');
        } catch (e) {
          _showErrorMessage('Invalid email or password');
        }
      } else if (response.statusCode == 404) {
        _showErrorMessage('User not found. Please check your email or register a new account.');
      } else if (response.statusCode == 422) {
        _showErrorMessage('Invalid data format. Please check your inputs.');
      } else {
        try {
          final errorData = json.decode(response.body);
          _showErrorMessage(errorData['message'] ?? 'Server error (${response.statusCode}). Please try again later.');
        } catch (e) {
          _showErrorMessage('Server error (${response.statusCode}). Please try again later.');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        print('❌ Login network error: $e');
        _showErrorMessage('Network error. Please check your connection and try again.');
      }
    }
  }

  void _handle400ValidationError(String responseBody) {
    try {
      final errorData = json.decode(responseBody);

      if (errorData.containsKey('errors')) {
        final errors = errorData['errors'] as Map<String, dynamic>;
        final List<String> errorMessages = [];

        errors.forEach((field, messages) {
          if (messages is List) {
            for (final message in messages) {
              errorMessages.add('$field: $message');
            }
          } else {
            errorMessages.add('$field: $messages');
          }
        });

        _showErrorMessage('Validation errors:\n${errorMessages.join('\n')}');
      } else if (errorData.containsKey('message')) {
        _showErrorMessage(errorData['message']);
      } else if (errorData.containsKey('title')) {
        String message = errorData['title'];
        if (errorData.containsKey('detail')) {
          message += ': ${errorData['detail']}';
        }
        _showErrorMessage(message);
      } else {
        _showErrorMessage('Please check your email and password format.');
      }
    } catch (e) {
      _showErrorMessage('Invalid email or password format.');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Demo login for testing
  void _demoLogin(String role) {
    final userData = {
      'userId': role == 'seller' ? 1 : 2,
      'fullName': 'Demo ${role.toUpperCase()}',
      'email': 'demo${role}@example.com',
      'role': role,
      'phoneNumber': '+1234567890',
      'dateOfBirth': DateTime.now().subtract(const Duration(days: 365 * 25)).toIso8601String(),
      'token': 'demo_token_${role}_${DateTime.now().millisecondsSinceEpoch}',
    };

    UserSession.setCurrentUser(userData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demo login as $role successful!'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    if (role == 'buyer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BuyerDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SellerDashboardScreen()),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }

    final trimmedValue = value!.trim();
    if (trimmedValue.isEmpty) {
      return 'Email cannot be empty';
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmedValue)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your password';
    }

    if (value!.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Forgot password feature will be available soon. Please contact support for assistance.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a237e),
                  Color(0xFF234E70),
                  Color(0xFF305F80),
                ],
                stops: [0.2, 0.6, 0.9],
              ),
            ),
          ),

          // Overlay gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    _buildWelcomeSection(),
                    const SizedBox(height: 40),
                    _buildLoginForm(),
                    const SizedBox(height: 20),
                    _buildDemoButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.home_work,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in to find your perfect home',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  prefixIcon: Icons.email,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  isPassword: true,
                  validator: _validatePassword,
                  prefixIcon: Icons.lock,
                ),
                const SizedBox(height: 15),

                // Remember me and forgot password row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          fillColor: WidgetStateProperty.all(
                            Colors.white.withOpacity(0.2),
                          ),
                          checkColor: Colors.white,
                        ),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _handleForgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                _buildLoginButton(),
                const SizedBox(height: 20),
                _buildRegisterLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Demo Login (For Testing)',
            style: TextStyle(
              color: Colors.orange.shade300,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _demoLogin('buyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text('Demo Buyer', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _demoLogin('seller'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.sell, color: Colors.white),
                  label: const Text('Demo Seller', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isPassword = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          validator: validator,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: !isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
              prefixIcon,
              color: Colors.white.withOpacity(0.7),
            )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            errorStyle: const TextStyle(color: Colors.red),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text(
          'Sign In',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationScreen(),
              ),
            );
          },
          child: const Text(
            'Register now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}