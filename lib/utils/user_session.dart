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
    if (_currentUser == null) return 0;

    final userId = _currentUser!['userId'];
    if (userId is int) return userId;
    if (userId is String) return int.tryParse(userId) ?? 0;
    return 0;
  }

  // Get current user role
  static String getCurrentUserRole() {
    if (_currentUser == null) return 'Buyer';
    return _currentUser!['role']?.toString().toLowerCase() ?? 'buyer';
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
    return _currentUser != null && getCurrentUserId() > 0;
  }

  // Clear user session (logout)
  static void clearSession() {
    _currentUser = null;
  }

  // Check if current user is seller
  static bool isSeller() {
    return getCurrentUserRole().toLowerCase() == 'seller';
  }

  // Check if current user is buyer
  static bool isBuyer() {
    return getCurrentUserRole().toLowerCase() == 'buyer';
  }

  // Update user role (for role switching)
  static void updateUserRole(String newRole) {
    if (_currentUser != null) {
      _currentUser!['role'] = newRole;
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
    return _currentUser != null &&
        getCurrentUserId() > 0 &&
        getCurrentUserName().isNotEmpty &&
        getCurrentUserEmail().isNotEmpty;
  }
}