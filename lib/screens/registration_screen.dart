// lib/screens/registration_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import './buyer_dashboard_screen.dart';
import './seller_dashboard_screen.dart';
import '../utils/user_session.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  String _selectedRole = 'Buyer';
  DateTime? _selectedDateOfBirth;

  // Replace with your actual API base URL
  static const String API_BASE_URL = 'https://gethome.runasp.net';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // Enhanced validation functions matching the API schema
  String? _validateFullName(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Full name is required';
    }
    if (value!.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    // Check if it contains at least first and last name
    if (!value.trim().contains(' ')) {
      return 'Please enter your full name (first and last name)';
    }
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Email is required';
    }
    if (value!.trim().length < 1) {
      return 'Email must be at least 1 character';
    }

    // Email format validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    // Check for common email providers for better UX
    final email = value.trim().toLowerCase();
    if (email.length > 100) {
      return 'Email address is too long';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Password is required';
    }
    if (value!.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value.length > 100) {
      return 'Password is too long';
    }

    // Enhanced password strength checks
    if (!value.contains(RegExp(r'[A-Za-z]'))) {
      return 'Password must contain at least one letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for common weak passwords
    final weakPasswords = ['123456', 'password', 'qwerty', '123123'];
    if (weakPasswords.contains(value.toLowerCase())) {
      return 'Password is too weak. Please choose a stronger password';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please confirm your password';
    }
    if (value!.length < 1) {
      return 'Confirm password must be at least 1 character';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    // Phone number is nullable in the schema, so it's optional
    if (value?.isEmpty ?? true) {
      return null; // It's optional
    }

    // Remove all non-digit characters for validation
    final digitsOnly = value!.replaceAll(RegExp(r'[^\d]'), '');

    // If provided, validate format and length
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (digitsOnly.length > 15) {
      return 'Phone number is too long';
    }

    // Basic phone format validation
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  String? _validateDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      return 'Date of birth is required';
    }

    // Check if user is at least 13 years old
    final now = DateTime.now();
    final minAge = DateTime(now.year - 13, now.month, now.day);

    if (dateOfBirth.isAfter(minAge)) {
      return 'You must be at least 13 years old';
    }

    // Check if date is not in the future
    if (dateOfBirth.isAfter(now)) {
      return 'Date of birth cannot be in the future';
    }

    // Check if date is reasonable (not before 1900)
    final minDate = DateTime(1900);
    if (dateOfBirth.isBefore(minDate)) {
      return 'Please enter a valid date of birth';
    }

    return null;
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)), // Default to 25 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
      cancelText: 'Cancel',
      confirmText: 'Select',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF234E70),
              onPrimary: Colors.white,
              surface: Color(0xFF1a237e),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateOfBirth = pickedDate;
      });
    }
  }

  Future<void> _handleRegistration() async {
    // Validate date of birth separately since it's not in a TextFormField
    final dateOfBirthError = _validateDateOfBirth(_selectedDateOfBirth);
    if (dateOfBirthError != null) {
      _showErrorMessage(dateOfBirthError);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Format dateOfBirth to ISO 8601 string as required by the API
      final dateOfBirthString = _selectedDateOfBirth!.toUtc().toIso8601String();

      final requestBody = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
        'phoneNumber': _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
        'dateOfBirth': dateOfBirthString,
        'role': _selectedRole.toLowerCase(), // Add role to registration
      };

      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successful registration
        final responseData = json.decode(response.body);

        // Store user data for immediate use
        UserSession.setCurrentUser({
          'userId': responseData['userId'] ?? 0,
          'fullName': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole.toLowerCase(),
          'phoneNumber': _phoneNumberController.text.trim().isEmpty
              ? null
              : _phoneNumberController.text.trim(),
          'dateOfBirth': dateOfBirthString,
          'token': responseData['token'], // If your API returns a JWT token
        });

        _showSuccessMessage('Registration successful! Welcome to our app.');

        // Navigate to appropriate dashboard based on role
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => _selectedRole.toLowerCase() == 'buyer'
                  ? const BuyerDashboardScreen()
                  : const SellerDashboardScreen(),
            ),
          );
        }
      } else if (response.statusCode == 400) {
        // Handle validation errors
        try {
          final errorData = json.decode(response.body);
          _handle400ValidationError(errorData);
        } catch (e) {
          _showErrorMessage('Registration failed. Please check your information and try again.');
        }
      } else if (response.statusCode == 409) {
        _showErrorMessage('An account with this email already exists. Please use a different email or try logging in.');
      } else if (response.statusCode == 422) {
        _showErrorMessage('Invalid data format. Please check your information and try again.');
      } else {
        _showErrorMessage('Server error (${response.statusCode}). Please try again later.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorMessage('Network error. Please check your internet connection and try again.');
      }
    }
  }

  void _handle400ValidationError(Map<String, dynamic> errorData) {
    // Handle different types of 400 error responses
    if (errorData.containsKey('errors')) {
      // Handle validation errors object
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
      // Handle single error message
      _showErrorMessage(errorData['message']);
    } else if (errorData.containsKey('title')) {
      // Handle error with title
      String message = errorData['title'];
      if (errorData.containsKey('detail')) {
        message += ': ${errorData['detail']}';
      }
      _showErrorMessage(message);
    } else {
      // Generic validation error
      _showErrorMessage('Please check your information. Make sure all required fields are filled correctly.');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 20),

                    // Registration form
                    _buildRegistrationForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 28,
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
                          Text(
                            'Join our real estate community',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Role Selection Dropdown
                _buildRoleDropdown(),
                const SizedBox(height: 20),

                // Full Name (Required)
                _buildTextField(
                  controller: _fullNameController,
                  label: 'Full Name *',
                  hintText: 'Enter your full name',
                  validator: _validateFullName,
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 20),

                // Email (Required)
                _buildTextField(
                  controller: _emailController,
                  label: 'Email *',
                  hintText: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  prefixIcon: Icons.email,
                ),
                const SizedBox(height: 20),

                // Phone Number (Optional)
                _buildTextField(
                  controller: _phoneNumberController,
                  label: 'Phone Number',
                  hintText: 'Enter your phone number (optional)',
                  keyboardType: TextInputType.phone,
                  validator: _validatePhoneNumber,
                  prefixIcon: Icons.phone,
                ),
                const SizedBox(height: 20),

                // Date of Birth (Required)
                _buildDateOfBirthField(),
                const SizedBox(height: 20),

                // Password (Required)
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password *',
                  hintText: 'Enter your password (min. 6 characters)',
                  isPassword: true,
                  isPasswordVisible: _isPasswordVisible,
                  onTogglePasswordVisibility: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  validator: _validatePassword,
                  prefixIcon: Icons.lock,
                ),
                const SizedBox(height: 20),

                // Confirm Password (Required)
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password *',
                  hintText: 'Confirm your password',
                  isPassword: true,
                  isPasswordVisible: _isConfirmPasswordVisible,
                  onTogglePasswordVisibility: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                  validator: _validateConfirmPassword,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 20),

                // Register Button
                _buildRegisterButton(),
                const SizedBox(height: 20),

                // Login Link
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    final hasError = _validateDateOfBirth(_selectedDateOfBirth) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth *',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDateOfBirth,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? Colors.red : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: TextStyle(
                      color: _selectedDateOfBirth != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            _validateDateOfBirth(_selectedDateOfBirth)!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Register as',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF234E70),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'Buyer',
                        child: Text('Buyer - Looking for properties'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Seller',
                        child: Text('Seller - Listing properties'),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onTogglePasswordVisibility,
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
          obscureText: isPassword && !(isPasswordVisible ?? false),
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
            suffixIcon: isPassword && onTogglePasswordVisibility != null
                ? IconButton(
              icon: Icon(
                isPasswordVisible ?? false
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: onTogglePasswordVisibility,
            )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegistration,
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
          'Create Account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
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