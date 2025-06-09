// lib/utils/api_config.dart
class ApiConfig {
  // Main API URL - Update this to your actual backend URL
  static const String BASE_URL = 'https://gethome.runasp.net';

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
  static String propertyContactUrl(int propertyId) => '$BASE_URL/api/properties/$propertyId/contact';

  // Viewing request endpoints
  static String get createViewingRequestUrl => '$BASE_URL/api/viewing-requests/create';
  static String updateViewingRequestUrl(int requestId) => '$BASE_URL/api/viewing-requests/update/$requestId';

  // Favorites endpoints (if implemented in backend)
  static String get addFavoriteUrl => '$BASE_URL/api/favorites/add';
  static String get removeFavoriteUrl => '$BASE_URL/api/favorites/remove';
  static String get toggleFavoriteUrl => '$BASE_URL/api/favorites/toggle';
  static String userFavoritesUrl(int userId) => '$BASE_URL/api/favorites/user/$userId';

  // Common headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers for multipart requests (file uploads)
  static Map<String, String> get multipartHeaders => {
    'Accept': 'application/json',
  };

  // Response status codes
  static const int SUCCESS = 200;
  static const int CREATED = 201;
  static const int BAD_REQUEST = 400;
  static const int UNAUTHORIZED = 401;
  static const int NOT_FOUND = 404;
  static const int INTERNAL_SERVER_ERROR = 500;

  // Helper method to get error message from status code
  static String getErrorMessage(int statusCode) {
    switch (statusCode) {
      case BAD_REQUEST:
        return 'Bad request. Please check your input.';
      case UNAUTHORIZED:
        return 'Unauthorized. Please login again.';
      case NOT_FOUND:
        return 'Resource not found.';
      case INTERNAL_SERVER_ERROR:
        return 'Server error. Please try again later.';
      default:
        return 'Unknown error (Code: $statusCode)';
    }
  }
}