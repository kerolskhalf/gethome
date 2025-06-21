// lib/utils/api_debug_helper.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_session.dart';
import 'api_config.dart';

class ApiDebugHelper {
  static Future<void> testViewingRequestsEndpoints() async {
    print('🔍 === TESTING VIEWING REQUESTS ENDPOINTS ===');

    final userId = UserSession.getCurrentUserId();
    print('📱 Current User ID: $userId');

    // Test 1: Try to get all viewing requests
    try {
      print('\n1️⃣ Testing: Get all viewing requests');
      final response1 = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/all'),
        headers: ApiConfig.headers,
      );
      print('Status: ${response1.statusCode}');
      print('Body: ${response1.body.substring(0, response1.body.length > 200 ? 200 : response1.body.length)}...');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 2: Try to get user-specific viewing requests
    try {
      print('\n2️⃣ Testing: Get user viewing requests');
      final response2 = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/user/$userId'),
        headers: ApiConfig.headers,
      );
      print('Status: ${response2.statusCode}');
      print('Body: ${response2.body}');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 3: Create a test viewing request
    try {
      print('\n3️⃣ Testing: Create viewing request');
      final requestBody = {
        'propertyId': 1, // Test with property ID 1
        'userId': userId,
        'requestedDateTime': DateTime.now().add(Duration(days: 1)).toUtc().toIso8601String(),
        'message': 'Test viewing request from debug helper',
      };

      final response3 = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/create'),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );
      print('Request Body: $requestBody');
      print('Status: ${response3.statusCode}');
      print('Body: ${response3.body}');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> testFavoritesEndpoints() async {
    print('💖 === TESTING FAVORITES ENDPOINTS ===');

    final userId = UserSession.getCurrentUserId();
    print('📱 Current User ID: $userId');

    // Test 1: Get user favorites
    try {
      print('\n1️⃣ Testing: Get user favorites');
      final response1 = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/favorites/user/$userId'),
        headers: ApiConfig.headers,
      );
      print('Status: ${response1.statusCode}');
      print('Body: ${response1.body}');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 2: Add to favorites
    try {
      print('\n2️⃣ Testing: Add to favorites');
      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/favorites/add').replace(
        queryParameters: {
          'userId': userId.toString(),
          'propertyId': '1', // Test with property ID 1
        },
      );

      final response2 = await http.post(uri, headers: ApiConfig.headers);
      print('URL: $uri');
      print('Status: ${response2.statusCode}');
      print('Body: ${response2.body}');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 3: Toggle favorite
    try {
      print('\n3️⃣ Testing: Toggle favorite');
      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/favorites/toggle').replace(
        queryParameters: {
          'userId': userId.toString(),
          'propertyId': '1', // Test with property ID 1
        },
      );

      final response3 = await http.post(uri, headers: ApiConfig.headers);
      print('URL: $uri');
      print('Status: ${response3.statusCode}');
      print('Body: ${response3.body}');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> testPropertiesEndpoints() async {
    print('🏠 === TESTING PROPERTIES ENDPOINTS ===');

    // Test 1: Get all properties
    try {
      print('\n1️⃣ Testing: Get all properties');
      final response1 = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/all'),
        headers: ApiConfig.headers,
      );
      print('Status: ${response1.statusCode}');
      print('Properties count: ${json.decode(response1.body).length}');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 2: Get property by ID
    try {
      print('\n2️⃣ Testing: Get property by ID');
      final response2 = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/1'),
        headers: ApiConfig.headers,
      );
      print('Status: ${response2.statusCode}');
      print('Body: ${response2.body}');
    } catch (e) {
      print('❌ Error: $e');
    }

    // Test 3: Search properties
    try {
      print('\n3️⃣ Testing: Search properties');
      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/properties/search').replace(
        queryParameters: {
          'page': '1',
          'pageSize': '10',
        },
      );

      final response3 = await http.get(uri, headers: ApiConfig.headers);
      print('URL: $uri');
      print('Status: ${response3.statusCode}');
      print('Body: ${response3.body.substring(0, response3.body.length > 300 ? 300 : response3.body.length)}...');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> runFullDebugTest() async {
    print('🧪 === STARTING FULL API DEBUG TEST ===');
    print('⏰ Timestamp: ${DateTime.now()}');
    print('👤 User: ${UserSession.getCurrentUserName()} (ID: ${UserSession.getCurrentUserId()})');
    print('🎭 Role: ${UserSession.getCurrentUserRole()}');
    print('🌐 Base URL: ${ApiConfig.BASE_URL}');

    await testPropertiesEndpoints();
    await testFavoritesEndpoints();
    await testViewingRequestsEndpoints();

    print('\n✅ === DEBUG TEST COMPLETED ===');
  }

  // Quick test method you can call from any screen
  static Future<void> quickTest() async {
    try {
      print('🚀 Quick API Test Started');

      // Test basic connectivity
      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/all'),
        headers: ApiConfig.headers,
      ).timeout(Duration(seconds: 5));

      print('✅ API is reachable');
      print('📊 Status: ${response.statusCode}');
      print('📏 Response length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Data type: ${data.runtimeType}');
        if (data is List) {
          print('🏠 Properties found: ${data.length}');
        }
      }

    } catch (e) {
      print('❌ Quick test failed: $e');
    }
  }
}