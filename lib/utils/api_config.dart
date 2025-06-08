// lib/utils/api_config.dart
class ApiConfig {
  // 🔧 CHANGE THIS TO YOUR ACTUAL API URL
  static const String BASE_URL = 'https://gethome.runasp.net';

  // Alternative URLs (uncomment the one that works for your backend)
  // static const String BASE_URL = 'https://getawayanapp.runasp.net';
  // static const String BASE_URL = 'http://localhost:5000'; // For local development
  // static const String BASE_URL = 'http://10.0.2.2:5000'; // For Android emulator

  // Auth endpoints
  static String get loginUrl => '$BASE_URL/api/auth/login';
  static String get registerUrl => '$BASE_URL/api/auth/register';
  static String get updateProfileUrl => '$BASE_URL/api/auth/update-profile';
  static String get changePasswordUrl => '$BASE_URL/api/auth/change-password';
  static String switchRoleUrl(int userId) => '$BASE_URL/api/auth/switch-role/$userId';

  // Property endpoints
  static String get allPropertiesUrl => '$BASE_URL/api/properties/all';
  static String get searchPropertiesUrl => '$BASE_URL/api/properties/search';
  static String get addPropertyUrl => '$BASE_URL/api/properties/add';
  static String propertyDetailsUrl(int propertyId) => '$BASE_URL/api/properties/$propertyId';
  static String updatePropertyUrl(int propertyId) => '$BASE_URL/api/properties/update/$propertyId';
  static String deletePropertyUrl(int propertyId) => '$BASE_URL/api/properties/delete/$propertyId';
  static String userPropertiesUrl(int userId) => '$BASE_URL/api/properties/user/$userId';
  static String propertyContactUrl(int propertyId) => '$BASE_URL/api/properties/$propertyId/contact';

  // Favorites endpoints
  static String get addFavoriteUrl => '$BASE_URL/api/favorites/add';
  static String get removeFavoriteUrl => '$BASE_URL/api/favorites/remove';
  static String get toggleFavoriteUrl => '$BASE_URL/api/favorites/toggle';
  static String userFavoritesUrl(int userId) => '$BASE_URL/api/favorites/user/$userId';

  // Viewing requests endpoints
  static String get createViewingRequestUrl => '$BASE_URL/api/viewing-requests/create';
  static String propertyViewingRequestsUrl(int propertyId) => '$BASE_URL/api/viewing-requests/property/$propertyId';
  static String updateViewingRequestUrl(int requestId) => '$BASE_URL/api/viewing-requests/update/$requestId';
  static String userViewingRequestsUrl(int userId) => '$BASE_URL/api/viewing-requests/user/$userId';

  // AI endpoints (if implemented)
  static String get predictPriceUrl => '$BASE_URL/api/ai/predict-price';

  // Common headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers with auth token
  static Map<String, String> headersWithAuth(String? token) {
    final authHeaders = Map<String, String>.from(headers);
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    return authHeaders;
  }

  // Debug function to test API connectivity
  static void debugPrintUrls() {
    print('=== API Configuration Debug ===');
    print('Base URL: $BASE_URL');
    print('Login URL: $loginUrl');
    print('Properties URL: $allPropertiesUrl');
    print('Search URL: $searchPropertiesUrl');
    print('===============================');
  }

  // Check if URL is reachable
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
}