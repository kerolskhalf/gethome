// lib/screens/user_profile_screen.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'login_screen.dart';
import 'buyer_dashboard_screen.dart';
import 'seller_dashboard_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  bool _isEditingProfile = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final currentUser = UserSession.getCurrentUser();
    _fullNameController = TextEditingController(text: currentUser?['fullName'] ?? '');
    _emailController = TextEditingController(text: currentUser?['email'] ?? '');
    _phoneController = TextEditingController(text: currentUser?['phoneNumber'] ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  _buildActionsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Expanded(
          child: Text(
            'Profile Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48), // To balance the back button
      ],
    );
  }

  Widget _buildProfileCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Profile Avatar and Basic Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      UserSession.getUserInitials(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UserSession.getCurrentUserName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: UserSession.isSeller()
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: UserSession.isSeller()
                                      ? Colors.orange.withOpacity(0.5)
                                      : Colors.blue.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                UserSession.getCurrentUserRole().toUpperCase(),
                                style: TextStyle(
                                  color: UserSession.isSeller()
                                      ? Colors.orange
                                      : Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Profile Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name Field
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      enabled: _isEditingProfile,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      enabled: _isEditingProfile,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Phone Field
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      enabled: _isEditingProfile,
                    ),

                    // Password Change Section
                    if (_isChangingPassword) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _currentPasswordController,
                        label: 'Current Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _newPasswordController,
                        label: 'New Password',
                        icon: Icons.lock,
                        obscureText: true,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter a new password';
                          }
                          if (value!.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm New Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (_isEditingProfile || _isChangingPassword) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingProfile = false;
                                  _isChangingPassword = false;
                                });
                                _clearPasswordFields();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _isChangingPassword
                                  ? _changePassword
                                  : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  : Text(
                                _isChangingPassword ? 'Change Password' : 'Save Changes',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              if (!_isChangingPassword && !_isEditingProfile) ...[
                _buildActionButton(
                  'Edit Profile',
                  Icons.edit,
                      () => setState(() => _isEditingProfile = true),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  'Change Password',
                  Icons.security,
                      () => setState(() => _isChangingPassword = true),
                ),
                const SizedBox(height: 16),

                // FIXED: Role Switch Button
                _buildActionButton(
                  'Switch to ${UserSession.getCurrentUserRole().toLowerCase() == 'buyer' ? 'Seller' : 'Buyer'}',
                  UserSession.getCurrentUserRole().toLowerCase() == 'buyer'
                      ? Icons.store
                      : Icons.shopping_cart,
                  _isLoading ? null : _switchRole,
                  color: Colors.orange,
                ),

                const SizedBox(height: 24),

                _buildActionButton(
                  'Logout',
                  Icons.logout,
                  _logout,
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String title,
      IconData icon,
      VoidCallback? onTap, {
        Color color = Colors.white,
      }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isLoading && title.contains('Switch'))
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
                  Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.7), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FIXED: Role switching methods
  Future<void> _switchRole() async {
    final currentRole = UserSession.getCurrentUserRole().toLowerCase();
    final newRole = currentRole == 'buyer' ? 'Seller' : 'Buyer'; // Backend expects capitalized

    print('=== SWITCH ROLE TRIGGERED ===');
    print('Current role: $currentRole');
    print('New role: $newRole');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Switch Role',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to switch from ${currentRole.toUpperCase()} to ${newRole.toUpperCase()}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performRoleSwitch(newRole);
            },
            child: const Text(
              'Switch',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performRoleSwitch(String newRole) async {
    setState(() => _isLoading = true);

    try {
      print('=== ROLE SWITCH DEBUG ===');
      print('Current role: ${UserSession.getCurrentUserRole()}');
      print('New role to switch to: $newRole');
      print('User ID: ${UserSession.getCurrentUserId()}');
      print('API URL: ${ApiConfig.switchRoleUrl(UserSession.getCurrentUserId())}');

      final response = await http.put(
        Uri.parse(ApiConfig.switchRoleUrl(UserSession.getCurrentUserId())),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(newRole),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response data: $responseData');

        String actualNewRole = newRole.toLowerCase();
        if (responseData['newRole'] != null) {
          actualNewRole = responseData['newRole'].toString().toLowerCase();
        }

        await UserSession.updateUserRole(actualNewRole);
        print('Updated session role to: ${UserSession.getCurrentUserRole()}');

        _showSuccessMessage('Role switched to ${newRole.toUpperCase()} successfully');

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          final currentRole = UserSession.getCurrentUserRole().toLowerCase();
          print('Navigating based on role: $currentRole');

          if (currentRole == 'buyer') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyerDashboardScreen(),
              ),
                  (route) => false,
            );
          } else if (currentRole == 'seller') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const SellerDashboardFocused(),
              ),
                  (route) => false,
            );
          }
        }
      } else {
        String errorMessage = 'Failed to switch role';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server error. Status: ${response.statusCode}';
        }
        _showErrorMessage(errorMessage);
        print('Role switch failed: $errorMessage');
      }
    } catch (e) {
      print('Role switch error: $e');
      _showErrorMessage('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      };

      final response = await http.put(
        Uri.parse(ApiConfig.updateProfileUrl(UserSession.getCurrentUserId())),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        await UserSession.updateUserProfile(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

        _showSuccessMessage('Profile updated successfully');
        setState(() => _isEditingProfile = false);
      } else {
        _showErrorMessage('Failed to update profile');
      }
    } catch (e) {
      _showErrorMessage('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
        'confirmPassword': _confirmPasswordController.text,
      };

      final response = await http.put(
        Uri.parse(ApiConfig.changePasswordUrl(UserSession.getCurrentUserId())),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Password changed successfully');
        setState(() => _isChangingPassword = false);
        _clearPasswordFields();
      } else {
        _showErrorMessage('Failed to change password');
      }
    } catch (e) {
      _showErrorMessage('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await UserSession.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                      (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}