// lib/utils/api_config.dart
class ApiConfig {
  // 🔧 MAIN API URL - CHANGE THIS TO YOUR ACTUAL API URL
  static const String BASE_URL = 'https://gethome.runasp.net';

  // Alternative URLs (uncomment the one that works for your backend)
  // static const String BASE_URL = 'https://getawayanapp.runasp.net';
  // static const String BASE_URL = 'http://localhost:5000'; // For local development
  // static const String BASE_URL = 'http://10.0.2.2:5000'; // For Android emulator
  // static const String BASE_URL = 'http://192.168.1.100:5000'; // For local network testing

  // Auth endpoints
  static String get loginUrl => '$BASE_URL/api/auth/login';
  static String get registerUrl => '$BASE_URL/api/auth/register';
  static String updateProfileUrl(int userId) => '$BASE_URL/api/auth/update-profile/$userId';
  static String changePasswordUrl(int userId) => '$BASE_URL/api/auth/change-password/$userId';
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

  // Alternative endpoints (try these if the above don't work)
  static String userPropertiesUrlAlt1(int userId) => '$BASE_URL/api/properties/by-user/$userId';
  static String userPropertiesUrlAlt2(int userId) => '$BASE_URL/api/properties?userId=$userId';
  static String userPropertiesUrlAlt3(int userId) => '$BASE_URL/api/users/$userId/properties';

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
    'User-Agent': 'GetHomeApp/1.0',
  };

  // Headers for multipart requests (file uploads)
  static Map<String, String> get multipartHeaders => {
    'Accept': 'application/json',
    'User-Agent': 'GetHomeApp/1.0',
    // Don't set Content-Type for multipart requests - let http package handle it
  };

  // Headers with auth token
  static Map<String, String> headersWithAuth(String? token) {
    final authHeaders = Map<String, String>.from(headers);
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    return authHeaders;
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

  // Get timeout durations
  static Duration get connectionTimeout => const Duration(seconds: 60);
  static Duration get receiveTimeout => const Duration(seconds: 60);
  static Duration get sendTimeout => const Duration(seconds: 60);

  // Error response codes
  static const int SUCCESS = 200;
  static const int CREATED = 201;
  static const int BAD_REQUEST = 400;
  static const int UNAUTHORIZED = 401;
  static const int FORBIDDEN = 403;
  static const int NOT_FOUND = 404;
  static const int CONFLICT = 409;
  static const int UNPROCESSABLE_ENTITY = 422;
  static const int INTERNAL_SERVER_ERROR = 500;

  // Helper method to get error message from status code
  static String getErrorMessage(int statusCode) {
    switch (statusCode) {
      case BAD_REQUEST:
        return 'Bad request. Please check your input.';
      case UNAUTHORIZED:
        return 'Unauthorized. Please login again.';
      case FORBIDDEN:
        return 'Access forbidden.';
      case NOT_FOUND:
        return 'Resource not found.';
      case CONFLICT:
        return 'Resource already exists.';
      case UNPROCESSABLE_ENTITY:
        return 'Invalid data format.';
      case INTERNAL_SERVER_ERROR:
        return 'Server error. Please try again later.';
      default:
        return 'Unknown error (Code: $statusCode)';
    }
  }

  // Check if status code indicates success
  static bool isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  // Check if status code indicates client error
  static bool isClientError(int statusCode) {
    return statusCode >= 400 && statusCode < 500;
  }

  // Check if status code indicates server error
  static bool isServerError(int statusCode) {
    return statusCode >= 500 && statusCode < 600;
  }

  // Network connectivity test URL
  static String get connectivityTestUrl => '$BASE_URL/api/health';

  // Environment configuration
  static bool get isDevelopment => BASE_URL.contains('localhost') || BASE_URL.contains('10.0.2.2');
  static bool get isProduction => !isDevelopment;

  // Debug helper
  static void printDebugInfo() {
    print('=== API Configuration Debug ===');
    print('Base URL: $BASE_URL');
    print('Add Property URL: $addPropertyUrl');
    print('Is Development: $isDevelopment');
    print('Connection Timeout: ${connectionTimeout.inSeconds}s');
    print('===============================');
  }
}