// lib/utils/api_config.dart
import 'dart:convert';

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
  static String userViewingRequestsUrl(int userId) => '$BASE_URL/api/viewing-requests/user/$userId';
  static String propertyViewingRequestsUrl(int propertyId) => '$BASE_URL/api/viewing-requests/property/$propertyId';

  // Favorites endpoints
  static String get addFavoriteUrl => '$BASE_URL/api/favorites/add';
  static String get removeFavoriteUrl => '$BASE_URL/api/favorites/remove';
  static String get toggleFavoriteUrl => '$BASE_URL/api/favorites/toggle';
  static String userFavoritesUrl(int userId) => '$BASE_URL/api/favorites/user/$userId';

  // FIXED: Image handling with correct ProductsImages path
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // Handle different image path formats
    String cleanPath = imagePath;

    // Remove leading slash if present
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // Remove base URL if already present (avoid double URL)
    if (cleanPath.startsWith('http')) {
      return cleanPath;
    }

    // Remove any existing path prefixes
    if (cleanPath.startsWith('images/')) {
      cleanPath = cleanPath.substring(7);
    }
    if (cleanPath.startsWith('ProductsImages/')) {
      cleanPath = cleanPath.substring(15);
    }

    // Return the correct URL with ProductsImages path (matching backend)
    return '$BASE_URL/ProductsImages/$cleanPath';
  }

  // Helper method to check if image URL is valid
  static bool isValidImagePath(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }

    // Check if it's a valid image file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    final lowerPath = imagePath.toLowerCase();

    return validExtensions.any((ext) => lowerPath.endsWith(ext));
  }

  // Common headers for JSON requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers for multipart requests (file uploads)
  static Map<String, String> get multipartHeaders => {
    'Accept': 'application/json',
    // Don't set Content-Type for multipart requests - let http package handle it
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

  // Helper method to check if response is successful
  static bool isSuccessful(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  // Helper method to parse error response
  static String parseErrorResponse(String responseBody) {
    try {
      if (responseBody.isEmpty) {
        return 'Empty response from server';
      }

      // Try to parse as JSON
      if (responseBody.trim().startsWith('{')) {
        final Map<String, dynamic> errorData = json.decode(responseBody);

        if (errorData.containsKey('message')) {
          return errorData['message'].toString();
        } else if (errorData.containsKey('errors')) {
          final errors = errorData['errors'];
          final errorMessages = <String>[];

          if (errors is Map<String, dynamic>) {
            errors.forEach((key, value) {
              if (value is List) {
                errorMessages.addAll(value.cast<String>());
              } else {
                errorMessages.add(value.toString());
              }
            });
            return errorMessages.join('\n');
          } else if (errors is List) {
            return errors.join('\n');
          } else {
            return errors.toString();
          }
        } else {
          return 'An error occurred';
        }
      } else {
        // If not JSON, return as is (might be plain text error)
        return responseBody;
      }
    } catch (e) {
      // If JSON parsing fails, return the original response
      return responseBody.isNotEmpty ? responseBody : 'Failed to parse error response';
    }
  }

  // Pagination helper
  static Map<String, String> buildPaginationParams({
    int page = 1,
    int pageSize = 10,
    Map<String, String>? additionalParams,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return params;
  }

  // Image cache helper
  static String getCachedImageKey(String imagePath) {
    return 'cached_image_${imagePath.hashCode}';
  }

  // Network error handling
  static String handleNetworkError(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Connection timeout. Please try again.';
    } else if (error.toString().contains('FormatException')) {
      return 'Invalid server response format.';
    } else {
      return 'Network error: ${error.toString()}';
    }
  }

  // Debug logging (only in debug mode)
  static void debugLog(String message) {
    assert(() {
      print('[API_DEBUG] $message');
      return true;
    }());
  }
}