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
}