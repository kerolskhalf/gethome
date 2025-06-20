// lib/screens/debug_screen.dart - Add this temporarily for debugging
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/user_session.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _debugOutput = '';
  bool _isLoading = false;

  void _addToDebug(String message) {
    setState(() {
      _debugOutput += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _debugOutput = '';
    });

    _addToDebug('🔍 Starting API Debug Test...');
    _addToDebug('📱 User logged in: ${UserSession.isLoggedIn()}');
    _addToDebug('👤 User ID: ${UserSession.getCurrentUserId()}');
    _addToDebug('🎭 User role: ${UserSession.getCurrentUserRole()}');
    _addToDebug('');

    // Test 1: API Connectivity
    _addToDebug('🌐 Testing API connectivity...');
    _addToDebug('📡 URL: ${ApiConfig.allPropertiesUrl}');

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.allPropertiesUrl),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      _addToDebug('✅ Response received');
      _addToDebug('📊 Status Code: ${response.statusCode}');
      _addToDebug('📏 Body Length: ${response.body.length} characters');
      _addToDebug('');

      if (response.statusCode == 200) {
        _addToDebug('🎉 API is responding successfully!');

        // Test 2: Parse response
        _addToDebug('🔍 Parsing response...');

        try {
          final data = json.decode(response.body);
          _addToDebug('✅ JSON parsing successful');
          _addToDebug('📋 Data type: ${data.runtimeType}');

          if (data is List) {
            _addToDebug('📦 Direct array with ${data.length} items');
            if (data.isNotEmpty) {
              _addToDebug('🏠 First item keys: ${data[0].keys.toList()}');
              _addToDebug('🏠 First item: ${data[0]}');
            }
          } else if (data is Map) {
            _addToDebug('📦 Map response with keys: ${data.keys.toList()}');
            if (data.containsKey('data')) {
              final dataArray = data['data'];
              if (dataArray is List) {
                _addToDebug('📋 Data array found with ${dataArray.length} items');
                if (dataArray.isNotEmpty) {
                  _addToDebug('🏠 First property keys: ${dataArray[0].keys.toList()}');
                  _addToDebug('🏠 First property: ${dataArray[0]}');
                }
              }
            }
          }

          _addToDebug('');
          _addToDebug('📜 Full response preview:');
          final preview = response.body.length > 500
              ? '${response.body.substring(0, 500)}...'
              : response.body;
          _addToDebug(preview);

        } catch (e) {
          _addToDebug('❌ JSON parsing failed: $e');
          _addToDebug('📜 Raw response: ${response.body}');
        }

      } else {
        _addToDebug('❌ API returned error status: ${response.statusCode}');
        _addToDebug('📜 Error body: ${response.body}');
      }

    } catch (e) {
      _addToDebug('💥 Connection failed: $e');

      if (e.toString().contains('SocketException')) {
        _addToDebug('🌐 Network issue - check internet connection');
      } else if (e.toString().contains('TimeoutException')) {
        _addToDebug('⏰ Request timed out - server might be slow');
      } else {
        _addToDebug('🔧 Other error type - check server status');
      }
    }

    // Test 3: Alternative endpoints
    _addToDebug('');
    _addToDebug('🔄 Testing alternative endpoint...');

    try {
      final searchResponse = await http.get(
        Uri.parse('${ApiConfig.searchPropertiesUrl}?page=1&pageSize=10'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      _addToDebug('🔍 Search endpoint status: ${searchResponse.statusCode}');
      _addToDebug('📏 Search response length: ${searchResponse.body.length}');

    } catch (e) {
      _addToDebug('❌ Search endpoint failed: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug Tool'),
        backgroundColor: const Color(0xFF234E70),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a237e),
              Color(0xFF234E70),
              Color(0xFF305F80),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                color: Colors.white.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Debug Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This tool helps debug why properties are not loading.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _testApiConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Testing...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                              : const Text(
                            'Run API Debug Test',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  color: Colors.black.withOpacity(0.3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Debug Output:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_debugOutput.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _debugOutput = '';
                                  });
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _debugOutput.isEmpty
                                  ? 'Tap "Run API Debug Test" to start debugging...'
                                  : _debugOutput,
                              style: TextStyle(
                                color: _debugOutput.isEmpty
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}