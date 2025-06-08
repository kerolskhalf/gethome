// lib/utils/user_session.dart
class UserSession {
  static Map<String, dynamic>? _currentUser;

  // Store user data globally
  static void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = userData;
  }

  // Get current user data
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  // Get current user ID
  static int getCurrentUserId() {
    return _currentUser?['userId'] ?? 123; // fallback ID
  }

  // Get current user role
  static String getCurrentUserRole() {
    return _currentUser?['role']?.toString().toLowerCase() ?? 'buyer';
  }

  // Get current user name
  static String getCurrentUserName() {
    return _currentUser?['fullName'] ?? 'User';
  }

  // Get current user email
  static String getCurrentUserEmail() {
    return _currentUser?['email'] ?? '';
  }

  // Get current user phone
  static String? getCurrentUserPhone() {
    return _currentUser?['phoneNumber'];
  }

  // Get current user date of birth
  static String? getCurrentUserDateOfBirth() {
    return _currentUser?['dateOfBirth'];
  }

  // Get current user token
  static String? getCurrentUserToken() {
    return _currentUser?['token'];
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _currentUser != null && _currentUser!['userId'] != null;
  }

  // Clear user session (logout)
  static void clearSession() {
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
    }
  }

  // Get user initials for avatar
  static String getUserInitials() {
    final name = getCurrentUserName();
    if (name.isEmpty) return 'U';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  // Check if user has complete profile
  static bool hasCompleteProfile() {
    if (_currentUser == null) return false;

    return _currentUser!['fullName'] != null &&
        _currentUser!['email'] != null &&
        _currentUser!['role'] != null;
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
      print('Logged in: ${isLoggedIn()}');
      print('===========================');
    } else {
      print('No user session found');
    }
  }

  // Validate session (check if all required fields are present)
  static bool validateSession() {
    if (_currentUser == null) return false;

    // Check for required fields
    final requiredFields = ['userId', 'fullName', 'email', 'role'];
    for (final field in requiredFields) {
      if (_currentUser![field] == null || _currentUser![field].toString().isEmpty) {
        return false;
      }
    }

    return true;
  }

  // Get user display name (first name only)
  static String getDisplayName() {
    final fullName = getCurrentUserName();
    if (fullName.isEmpty) return 'User';

    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts[0] : 'User';
  }

  // Check if user token is expired (if implementing JWT)
  static bool isTokenExpired() {
    final token = getCurrentUserToken();
    if (token == null) return true;

    // TODO: Implement JWT token expiration check
    // For now, always return false
    return false;
  }

  // Refresh user token (if implementing JWT refresh)
  static void updateToken(String newToken) {
    if (_currentUser != null) {
      _currentUser!['token'] = newToken;
    }
  }
}