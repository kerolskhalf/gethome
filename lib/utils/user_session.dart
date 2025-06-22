// lib/utils/user_session.dart - FIXED VERSION
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserSession {
  static Map<String, dynamic>? _currentUser;

  // Initialize user session with data
  static void setCurrentUser(Map<String, dynamic> userData) {
    print('=== SETTING USER SESSION ===');
    print('Input userData: $userData');

    // Ensure role is properly formatted
    String role = '';
    if (userData['role'] != null) {
      if (userData['role'] is int) {
        // Convert backend enum to string
        role = userData['role'] == 0 ? 'seller' : 'buyer';
      } else {
        role = userData['role'].toString().toLowerCase().trim();
      }
    }

    _currentUser = {
      'userId': userData['userId'] ?? userData['id'] ?? 0,
      'fullName': userData['fullName'] ?? userData['name'] ?? 'User',
      'email': userData['email'] ?? '',
      'role': role, // Ensure lowercase role
      'phoneNumber': userData['phoneNumber'],
    };

    print('Stored user data: $_currentUser');
    print('Final role: "${_currentUser!['role']}"');
    print('========================');

    // Persist to SharedPreferences
    _persistUserSession();
  }

  // Persist user session to SharedPreferences
  static Future<void> _persistUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString('user_session', json.encode(_currentUser));
        print('✅ User session persisted to SharedPreferences');
      }
    } catch (e) {
      print('❌ Failed to persist user session: $e');
    }
  }

  // Load user session from SharedPreferences
  static Future<bool> loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('user_session');

      if (sessionData != null) {
        _currentUser = json.decode(sessionData);
        print('✅ User session loaded from SharedPreferences: $_currentUser');
        return true;
      }
    } catch (e) {
      print('❌ Failed to load user session: $e');
    }
    return false;
  }

  // Clear user session from memory and SharedPreferences
  static Future<void> clearSession() async {
    print('🗑️ Clearing user session');
    _currentUser = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      print('✅ User session cleared from SharedPreferences');
    } catch (e) {
      print('❌ Failed to clear SharedPreferences: $e');
    }
  }

  // Get current user ID
  static int getCurrentUserId() {
    if (_currentUser == null) {
      print('⚠️ getCurrentUserId: No current user');
      return 0;
    }
    final userId = _currentUser!['userId'] ?? 0;
    return userId is int ? userId : int.tryParse(userId.toString()) ?? 0;
  }

  // Get current user role with enhanced debugging
  static String getCurrentUserRole() {
    if (_currentUser == null) {
      print('⚠️ getCurrentUserRole: No current user, returning "buyer"');
      return 'buyer';
    }
    final role = _currentUser!['role']?.toString().toLowerCase().trim() ?? 'buyer';
    print('📋 Current user role: "$role"');
    return role;
  }

  // Get current user name
  static String getCurrentUserName() {
    if (_currentUser == null) return 'User';
    return _currentUser!['fullName']?.toString() ?? 'User';
  }

  // Get current user email
  static String getCurrentUserEmail() {
    if (_currentUser == null) return '';
    return _currentUser!['email']?.toString() ?? '';
  }

  // Get current user phone
  static String? getCurrentUserPhone() {
    if (_currentUser == null) return null;
    final phone = _currentUser!['phoneNumber']?.toString();
    return phone?.isEmpty ?? true ? null : phone;
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    final isLoggedIn = _currentUser != null && getCurrentUserId() > 0;
    print('🔐 User logged in: $isLoggedIn (UserId: ${getCurrentUserId()})');
    return isLoggedIn;
  }

  // Check if current user is seller
  static bool isSeller() {
    final role = getCurrentUserRole();
    final result = role == 'seller';
    print('🏪 UserSession: isSeller() = $result (role: "$role")');
    return result;
  }

  // Check if current user is buyer
  static bool isBuyer() {
    final role = getCurrentUserRole();
    final result = role == 'buyer';
    print('🛒 UserSession: isBuyer() = $result (role: "$role")');
    return result;
  }

  // FIXED: Update user role with proper persistence
  static Future<void> updateUserRole(String newRole) async {
    if (_currentUser != null) {
      final normalizedRole = newRole.toLowerCase().trim();
      _currentUser!['role'] = normalizedRole;

      print('🔄 User role updated to: "$normalizedRole"');

      // Persist the updated session
      await _persistUserSession();

      // Verify the update
      print('✅ Role verification: getCurrentUserRole() = "${getCurrentUserRole()}"');
    } else {
      print('❌ Cannot update role: No current user session');
    }
  }

  // Update user profile information with persistence
  static Future<void> updateUserProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
  }) async {
    if (_currentUser != null) {
      if (fullName != null) _currentUser!['fullName'] = fullName;
      if (email != null) _currentUser!['email'] = email;
      if (phoneNumber != null) _currentUser!['phoneNumber'] = phoneNumber;

      print('📝 User profile updated: $_currentUser');

      // Persist the updated session
      await _persistUserSession();
    } else {
      print('❌ Cannot update profile: No current user session');
    }
  }

  // Get user initials for avatar
  static String getUserInitials() {
    final name = getCurrentUserName();
    if (name.isEmpty || name == 'User') return 'U';

    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    } else {
      return 'U';
    }
  }

  // Get user display name (first name only)
  static String getDisplayName() {
    final fullName = getCurrentUserName();
    if (fullName.isEmpty || fullName == 'User') return 'User';

    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts[0] : 'User';
  }

  // Debug method to print current session state
  static void debugPrintSession() {
    print('=== USER SESSION DEBUG ===');
    print('Current user: $_currentUser');
    print('User ID: ${getCurrentUserId()}');
    print('Role: "${getCurrentUserRole()}"');
    print('Is logged in: ${isLoggedIn()}');
    print('Is seller: ${isSeller()}');
    print('Is buyer: ${isBuyer()}');
    print('========================');
  }

  // Get current user data (for external use)
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser != null ? Map<String, dynamic>.from(_currentUser!) : null;
  }
}