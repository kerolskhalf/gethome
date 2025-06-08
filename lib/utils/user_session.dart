// lib/utils/user_session.dart
class UserSession {
  static Map<String, dynamic>? _currentUser;

  // Store user data globally
  static void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = userData;
    print('💾 User session stored:');
    debugPrintUserData();
  }

  // Get current user data
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  // Get current user ID with better error handling
  static int getCurrentUserId() {
    if (_currentUser == null) {
      print('⚠️ Warning: No user session found, using fallback ID');
      return 1; // Use 1 instead of 123 as fallback
    }

    final userId = _currentUser!['userId'];
    if (userId == null) {
      print('⚠️ Warning: userId is null in session, using fallback ID');
      return 1;
    }

    if (userId is int) {
      return userId;
    }

    if (userId is String) {
      final parsed = int.tryParse(userId);
      if (parsed != null) {
        return parsed;
      }
    }

    print('⚠️ Warning: Invalid userId format ($userId), using fallback ID');
    return 1;
  }

  // Get current user role
  static String getCurrentUserRole() {
    if (_currentUser == null) {
      print('⚠️ Warning: No user session found, defaulting to buyer role');
      return 'buyer';
    }

    final role = _currentUser!['role']?.toString().toLowerCase();
    if (role == null || role.isEmpty) {
      print('⚠️ Warning: No role found in session, defaulting to buyer');
      return 'buyer';
    }

    return role;
  }

  // Get current user name
  static String getCurrentUserName() {
    if (_currentUser == null) return 'User';

    final name = _currentUser!['fullName']?.toString();
    if (name == null || name.isEmpty) {
      return 'User';
    }

    return name;
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

  // Get current user date of birth
  static String? getCurrentUserDateOfBirth() {
    if (_currentUser == null) return null;
    return _currentUser!['dateOfBirth']?.toString();
  }

  // Get current user token
  static String? getCurrentUserToken() {
    if (_currentUser == null) return null;
    return _currentUser!['token']?.toString();
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _currentUser != null && getCurrentUserId() > 0;
  }

  // Clear user session (logout)
  static void clearSession() {
    print('🔴 Clearing user session');
    _currentUser = null;
  }

  // Check if current user is seller
  static bool isSeller() {
    return getCurrentUserRole() == 'seller';
  }

  // Check if current user is buyer
  static bool isBuyer() {
    return getCurrentUserRole() == 'buyer';
  }

  // Update user role (for role switching)
  static void updateUserRole(String newRole) {
    if (_currentUser != null) {
      _currentUser!['role'] = newRole.toLowerCase();
      print('🔄 User role updated to: $newRole');
    }
  }

  // Update user profile information
  static void updateUserProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
  }) {
    if (_currentUser != null) {
      if (fullName != null) _currentUser!['fullName'] = fullName;
      if (email != null) _currentUser!['email'] = email;
      if (phoneNumber != null) _currentUser!['phoneNumber'] = phoneNumber;
      print('📝 User profile updated');
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

  // Check if user has complete profile
  static bool hasCompleteProfile() {
    if (_currentUser == null) {
      print('❌ No user session for profile check');
      return false;
    }

    final hasName = _currentUser!['fullName'] != null &&
        _currentUser!['fullName'].toString().isNotEmpty;
    final hasEmail = _currentUser!['email'] != null &&
        _currentUser!['email'].toString().isNotEmpty;
    final hasRole = _currentUser!['role'] != null &&
        _currentUser!['role'].toString().isNotEmpty;
    final hasUserId = getCurrentUserId() > 0;

    final isComplete = hasName && hasEmail && hasRole && hasUserId;

    if (!isComplete) {
      print('❌ Incomplete profile:');
      print('   - Name: $hasName');
      print('   - Email: $hasEmail');
      print('   - Role: $hasRole');
      print('   - UserId: $hasUserId');
    }

    return isComplete;
  }

  // Debug function to print current user data
  static void debugPrintUserData() {
    if (_currentUser != null) {
      print('=== Current User Session ===');
      print('User ID: ${getCurrentUserId()}');
      print('Name: ${getCurrentUserName()}');
      print('Email: ${getCurrentUserEmail()}');
      print('Role: ${getCurrentUserRole()}');
      print('Phone: ${getCurrentUserPhone() ?? 'Not provided'}');
      print('Token: ${getCurrentUserToken()?.isNotEmpty == true ? 'Present' : 'Missing'}');
      print('Logged in: ${isLoggedIn()}');
      print('Complete profile: ${hasCompleteProfile()}');
      print('Raw data: $_currentUser');
      print('===========================');
    } else {
      print('❌ No user session found');
    }
  }

  // Validate session (check if all required fields are present)
  static bool validateSession() {
    if (_currentUser == null) {
      print('❌ Session validation failed: No user data');
      return false;
    }

    // Check for required fields
    final requiredChecks = {
      'userId': getCurrentUserId() > 0,
      'fullName': getCurrentUserName().isNotEmpty && getCurrentUserName() != 'User',
      'email': getCurrentUserEmail().isNotEmpty,
      'role': getCurrentUserRole().isNotEmpty,
    };

    final failedChecks = requiredChecks.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();

    if (failedChecks.isNotEmpty) {
      print('❌ Session validation failed for: ${failedChecks.join(', ')}');
      return false;
    }

    print('✅ Session validation passed');
    return true;
  }

  // Get user display name (first name only)
  static String getDisplayName() {
    final fullName = getCurrentUserName();
    if (fullName.isEmpty || fullName == 'User') return 'User';

    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts[0] : 'User';
  }

  // Check if user token is expired (if implementing JWT)
  static bool isTokenExpired() {
    final token = getCurrentUserToken();
    if (token == null || token.isEmpty) return true;

    // TODO: Implement JWT token expiration check
    // For now, always return false
    return false;
  }

  // Refresh user token (if implementing JWT refresh)
  static void updateToken(String newToken) {
    if (_currentUser != null) {
      _currentUser!['token'] = newToken;
      print('🔑 Token updated');
    }
  }

  // Get session summary for debugging
  static String getSessionSummary() {
    if (_currentUser == null) return 'No session';

    return 'User: ${getCurrentUserName()} (ID: ${getCurrentUserId()}, Role: ${getCurrentUserRole()})';
  }

  // Force set user ID (for testing/debugging)
  static void debugSetUserId(int userId) {
    if (_currentUser != null) {
      _currentUser!['userId'] = userId;
      print('🐛 Debug: UserId forced to $userId');
    }
  }

  // Check session health
  static Map<String, dynamic> getSessionHealth() {
    return {
      'hasSession': _currentUser != null,
      'isLoggedIn': isLoggedIn(),
      'hasValidUserId': getCurrentUserId() > 0,
      'hasValidRole': getCurrentUserRole().isNotEmpty,
      'hasValidName': getCurrentUserName() != 'User',
      'hasValidEmail': getCurrentUserEmail().isNotEmpty,
      'isComplete': hasCompleteProfile(),
      'isValid': validateSession(),
    };
  }
}