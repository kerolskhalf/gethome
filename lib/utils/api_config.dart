// lib/utils/api_config.dart - ENHANCED VERSION with all endpoints
import 'package:http/http.dart' as http;
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

  // FIX: Enhanced viewing request endpoints with date/time support
  static String get createViewingRequestUrl => '$BASE_URL/api/viewing-requests/create';
  static String updateViewingRequestUrl(int requestId) => '$BASE_URL/api/viewing-requests/update/$requestId';
  static String rescheduleViewingRequestUrl(int requestId) => '$BASE_URL/api/viewing-requests/reschedule/$requestId';
  static String cancelViewingRequestUrl(int requestId) => '$BASE_URL/api/viewing-requests/cancel/$requestId';
  static String userViewingRequestsUrl(int userId) => '$BASE_URL/api/viewing-requests/user/$userId';
  static String propertyViewingRequestsUrl(int propertyId) => '$BASE_URL/api/viewing-requests/property/$propertyId';

  // FIX: Enhanced favorites endpoints with proper query parameter format
  static String get addFavoriteUrl => '$BASE_URL/api/favorites/add';
  static String get removeFavoriteUrl => '$BASE_URL/api/favorites/remove';
  static String get toggleFavoriteUrl => '$BASE_URL/api/favorites/toggle';
  static String userFavoritesUrl(int userId) => '$BASE_URL/api/favorites/user/$userId';

  // AI Prediction endpoint
  static const String AI_PREDICTION_URL = 'https://real-estate-api-production-49bc.up.railway.app/predict';

  // ENHANCED: Image handling with better debugging and error handling
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      debugLog('Empty imagePath provided');
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
      debugLog('Full URL already provided: $cleanPath');
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
    final fullUrl = '$BASE_URL/ProductsImages/$cleanPath';
    debugLog('Generated image URL: $fullUrl');
    return fullUrl;
  }

  // Helper method to check if image URL is valid
  static bool isValidImagePath(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }

    // Check if it's a valid image file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    final lowerPath = imagePath.toLowerCase();

    final isValid = validExtensions.any((ext) => lowerPath.endsWith(ext));
    if (!isValid) {
      debugLog('Invalid image path: $imagePath');
    }
    return isValid;
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

  // ENHANCED: Better error response parsing
  static String parseErrorResponse(String responseBody) {
    try {
      if (responseBody.isEmpty) {
        return 'Empty response from server';
      }

      debugLog('Parsing error response: $responseBody');

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
      debugLog('Error parsing response: $e');
      // If JSON parsing fails, return the original response
      return responseBody.isNotEmpty ? responseBody : 'Failed to parse error response';
    }
  }

  // ENHANCED: Test API connectivity
  static Future<bool> testApiConnectivity() async {
    try {
      debugLog('Testing API connectivity to: $BASE_URL');

      final response = await http.get(
        Uri.parse(allPropertiesUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugLog('API test response: ${response.statusCode}');
      debugLog('API test body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      return response.statusCode == 200;
    } catch (e) {
      debugLog('API connectivity test failed: $e');
      return false;
    }
  }

  // FIX: Enhanced favorites API helper methods
  static Future<http.Response> addToFavorites(int userId, int propertyId) async {
    final uri = Uri.parse(addFavoriteUrl).replace(
      queryParameters: {
        'userId': userId.toString(),
        'propertyId': propertyId.toString(),
      },
    );

    return await http.post(uri, headers: headers);
  }

  static Future<http.Response> removeFromFavorites(int userId, int propertyId) async {
    final uri = Uri.parse(removeFavoriteUrl).replace(
      queryParameters: {
        'userId': userId.toString(),
        'propertyId': propertyId.toString(),
      },
    );

    return await http.delete(uri, headers: headers);
  }

  static Future<http.Response> toggleFavorite(int userId, int propertyId) async {
    final uri = Uri.parse(toggleFavoriteUrl).replace(
      queryParameters: {
        'userId': userId.toString(),
        'propertyId': propertyId.toString(),
      },
    );

    return await http.post(uri, headers: headers);
  }

  // FIX: Enhanced viewing request helper methods
  static Future<http.Response> createViewingRequest({
    required int userId,
    required int propertyId,
    required DateTime requestedDateTime,
    String? message,
  }) async {
    final requestBody = {
      'userId': userId,
      'propertyId': propertyId,
      'requestedDateTime': requestedDateTime.toUtc().toIso8601String(),
      if (message != null) 'message': message,
    };

    return await http.post(
      Uri.parse(createViewingRequestUrl),
      headers: headers,
      body: json.encode(requestBody),
    );
  }

  static Future<http.Response> updateViewingRequestStatus(int requestId, String status) async {
    return await http.put(
      Uri.parse(updateViewingRequestUrl(requestId)),
      headers: headers,
      body: json.encode(status),
    );
  }

  static Future<http.Response> rescheduleViewingRequest(int requestId, DateTime newDateTime) async {
    final requestBody = {
      'newDateTime': newDateTime.toUtc().toIso8601String(),
    };

    return await http.put(
      Uri.parse(rescheduleViewingRequestUrl(requestId)),
      headers: headers,
      body: json.encode(requestBody),
    );
  }

  // AI Prediction helper method
  static Future<http.Response> predictPrice(Map<String, dynamic> propertyData) async {
    return await http.post(
      Uri.parse(AI_PREDICTION_URL),
      headers: headers,
      body: json.encode(propertyData),
    );
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

  // Search helper with filters
  static Future<http.Response> searchProperties({
    int page = 1,
    int pageSize = 10,
    String? city,
    String? region,
    double? minPrice,
    double? maxPrice,
    int? minBedrooms,
    int? maxBedrooms,
    String? propertyType,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (city != null && city.isNotEmpty && city != 'Any') {
      queryParams['city'] = city.toLowerCase();
    }
    if (region != null && region.isNotEmpty && region != 'Any') {
      queryParams['region'] = region.toLowerCase();
    }
    if (minPrice != null && minPrice > 0) {
      queryParams['minPrice'] = minPrice.toString();
    }
    if (maxPrice != null && maxPrice < 1000000) {
      queryParams['maxPrice'] = maxPrice.toString();
    }
    if (minBedrooms != null && minBedrooms > 0) {
      queryParams['minBedrooms'] = minBedrooms.toString();
    }
    if (maxBedrooms != null && maxBedrooms < 10) {
      queryParams['maxBedrooms'] = maxBedrooms.toString();
    }
    if (propertyType != null && propertyType.isNotEmpty && propertyType != 'All') {
      queryParams['propertyType'] = propertyType;
    }

    final uri = Uri.parse(searchPropertiesUrl).replace(queryParameters: queryParams);
    return await http.get(uri, headers: headers);
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

  // ENHANCED: Debug logging with better formatting
  static void debugLog(String message) {
    assert(() {
      final timestamp = DateTime.now().toIso8601String();
      print('🔧 [API_DEBUG $timestamp] $message');
      return true;
    }());
  }

  // Response validation helper
  static bool isValidResponse(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  // Generic API call wrapper with error handling
  static Future<Map<String, dynamic>?> makeApiCall(
      String method,
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
      }) async {
    try {
      Uri uri = Uri.parse(url);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: body != null ? json.encode(body) : null);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: body != null ? json.encode(body) : null);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      debugLog('API Call: $method $uri - Status: ${response.statusCode}');

      if (isValidResponse(response)) {
        return json.decode(response.body);
      } else {
        throw Exception('API Error ${response.statusCode}: ${parseErrorResponse(response.body)}');
      }
    } catch (e) {
      debugLog('API Call failed: $e');
      rethrow;
    }
  }
}