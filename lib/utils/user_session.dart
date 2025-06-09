// lib/utils/user_session.dart
class UserSession {
  static Map<String, dynamic>? _currentUser;

  // Store user data globally
  static void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = userData;
    print('=== USER SESSION SET ===');
    print('Raw userData: $userData');
    print('Role from userData: ${userData['role']}');
    print('Role type: ${userData['role'].runtimeType}');
    print('========================');
  }

  // Get current user data
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  // Get current user ID
  static int getCurrentUserId() {
    if (_currentUser == null) {
      print('Warning: No user session found');
      return 0;
    }

    final userId = _currentUser!['userId'];
    if (userId is int) return userId;
    if (userId is String) return int.tryParse(userId) ?? 0;

    print('Warning: Invalid userId format: $userId');
    return 0;
  }

  // FIX: Enhanced role handling with debugging
  static String getCurrentUserRole() {
    if (_currentUser == null) {
      print('UserSession: No current user, defaulting to buyer');
      return 'buyer';
    }

    final rawRole = _currentUser!['role'];
    print('UserSession: Raw role from storage: $rawRole (type: ${rawRole.runtimeType})');

    if (rawRole == null) {
      print('UserSession: Role is null, defaulting to buyer');
      return 'buyer';
    }

    final role = rawRole.toString().toLowerCase().trim();
    print('UserSession: Processed role: "$role"');

    // Ensure we only return valid roles
    if (role == 'seller' || role == 'buyer') {
      print('UserSession: Returning valid role: $role');
      return role;
    } else {
      print('UserSession: Invalid role "$role", defaulting to buyer');
      return 'buyer';
    }
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
    print('User logged in: $isLoggedIn (UserId: ${getCurrentUserId()})'); // Debug print
    return isLoggedIn;
  }

  // Clear user session (logout)
  static void clearSession() {
    print('Clearing user session');
    _currentUser = null;
  }

  // Check if current user is seller
  static bool isSeller() {
    final role = getCurrentUserRole();
    final result = role.toLowerCase() == 'seller';
    print('UserSession: isSeller() = $result (role: $role)');
    return result;
  }

  // Check if current user is buyer
  static bool isBuyer() {
    final role = getCurrentUserRole();
    final result = role.toLowerCase() == 'buyer';
    print('UserSession: isBuyer() = $result (role: $role)');
    return result;
  }

  // Update user role (for role switching)
  static void updateUserRole(String newRole) {
    if (_currentUser != null) {
      final normalizedRole = newRole.toLowerCase().trim();
      _currentUser!['role'] = normalizedRole;
      print('User role updated to: $normalizedRole');
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
      print('User profile updated: $_currentUser');
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

  // Validate session
  static bool validateSession() {
    final isValid = _currentUser != null &&
        getCurrentUserId() > 0 &&
        getCurrentUserName().isNotEmpty &&
        getCurrentUserEmail().isNotEmpty;

    if (!isValid) {
      print('Session validation failed: $_currentUser');
    }

    return isValid;
  }

  // FIX: Enhanced debug method
  static void debugPrintSession() {
    print('=== USER SESSION DEBUG ===');
    print('Current User: $_currentUser');
    print('User ID: ${getCurrentUserId()}');
    print('User Role: ${getCurrentUserRole()}');
    print('User Name: ${getCurrentUserName()}');
    print('User Email: ${getCurrentUserEmail()}');
    print('Is Logged In: ${isLoggedIn()}');
    print('Is Buyer: ${isBuyer()}');
    print('Is Seller: ${isSeller()}');
    print('Session Valid: ${validateSession()}');
    print('========================');
  }
}