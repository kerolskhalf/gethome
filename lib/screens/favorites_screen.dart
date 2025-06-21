// lib/screens/favorites_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'property_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _favoriteProperties = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavoriteProperties();
  }

  // FIX: Enhanced favorites loading with better error handling
  Future<void> _loadFavoriteProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = UserSession.getCurrentUserId();
      if (userId <= 0) {
        setState(() {
          _errorMessage = 'Please log in to view favorites';
          _isLoading = false;
        });
        return;
      }

      print('🔍 Loading favorites for user: $userId');

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/favorites/user/$userId?page=1&pageSize=100'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      print('📡 Favorites response status: ${response.statusCode}');
      print('📋 Favorites response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> properties = [];

        // Handle different response formats
        if (data is List) {
          // Direct array of favorites
          for (var favorite in data) {
            if (favorite['property'] != null) {
              properties.add(_safeMapConversion(favorite['property']));
            }
          }
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            // Wrapped response with data array
            final favorites = data['data'] as List;
            for (var favorite in favorites) {
              if (favorite['property'] != null) {
                properties.add(_safeMapConversion(favorite['property']));
              }
            }
          }
        }

        print('✅ Processed ${properties.length} favorite properties');

        setState(() {
          _favoriteProperties = properties;
          _errorMessage = null;
        });
      } else if (response.statusCode == 404) {
        // No favorites found - this is normal
        setState(() {
          _favoriteProperties = [];
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load favorites (${response.statusCode})';
        });
      }
    } catch (e) {
      print('❌ Error loading favorites: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method to safely convert property data
  Map<String, dynamic> _safeMapConversion(dynamic item) {
    try {
      if (item is Map<String, dynamic>) {
        return {
          'id': item['id'] ?? 0,
          'houseType': item['houseType']?.toString() ?? 'Property',
          'city': item['city']?.toString() ?? '',
          'region': item['region']?.toString() ?? '',
          'price': _safeNumericConversion(item['price'], 0),
          'size': _safeNumericConversion(item['size'], 0),
          'bedrooms': _safeNumericConversion(item['bedrooms'], 0),
          'bathrooms': _safeNumericConversion(item['bathrooms'], 0),
          'imagePath': item['imagePath']?.toString() ?? '',
          'isHighFloor': item['isHighFloor'] == true,
          'pricePerM2': _safeNumericConversion(item['pricePerM2'], 0),
          'status': item['status'] ?? 0,
          'totalRooms': _safeNumericConversion(item['totalRooms'], 0),
          'userId': _safeNumericConversion(item['userId'], 0),
          'isFurnished': item['isFurnished'] == true,
          'floor': _safeNumericConversion(item['floor'], 0),
        };
      }
      return {};
    } catch (e) {
      print('❌ Error converting property: $e');
      return {};
    }
  }

  dynamic _safeNumericConversion(dynamic value, dynamic defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  // FIX: Enhanced remove from favorites with proper API call
  Future<void> _removeFromFavorites(int propertyId) async {
    try {
      final userId = UserSession.getCurrentUserId();

      // Use query parameters as per API documentation
      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/favorites/remove').replace(
        queryParameters: {
          'userId': userId.toString(),
          'propertyId': propertyId.toString(),
        },
      );

      print('🗑️ Removing from favorites: $uri');

      final response = await http.delete(uri, headers: ApiConfig.headers);

      print('📡 Remove favorite response: ${response.statusCode}');
      print('📋 Remove favorite body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _favoriteProperties.removeWhere((property) => property['id'] == propertyId);
        });
        _showSuccessMessage('Removed from favorites');
      } else {
        _showErrorMessage('Failed to remove from favorites');
      }
    } catch (e) {
      _showErrorMessage('Error removing from favorites: $e');
    }
  }

  void _showRemoveConfirmation(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Remove from Favorites',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${property['houseType'] ?? 'this property'}" from your favorites?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromFavorites(property['id']);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPropertyImage(String? imagePath) {
    if (!ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.home, size: 50, color: Colors.grey[400]),
        ),
      );
    }

    final imageUrl = ApiConfig.getImageUrl(imagePath);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a237e),
            Color(0xFF234E70),
            Color(0xFF4A90E2),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Favorites',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_favoriteProperties.length} ${_favoriteProperties.length == 1 ? 'property' : 'properties'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadFavoriteProperties,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4A90E2)),
            SizedBox(height: 16),
            Text('Loading your favorites...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_favoriteProperties.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPropertiesList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load favorites',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavoriteProperties,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Properties you mark as favorites will appear here',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Browse Properties', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesList() {
    return RefreshIndicator(
      onRefresh: _loadFavoriteProperties,
      color: const Color(0xFF4A90E2),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _favoriteProperties.length,
        itemBuilder: (context, index) {
          final property = _favoriteProperties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyDetailsScreen(property: property),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: _buildPropertyImage(property['imagePath']),
                          ),
                        ),
                        // Remove from favorites button
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                              onPressed: () => _showRemoveConfirmation(property),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  property['houseType'] ?? 'Property',
                                  style: const TextStyle(
                                    color: Color(0xFF234E70),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${property['price'] ?? 0} LE',
                                  style: const TextStyle(
                                    color: Color(0xFF4A90E2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${property['city'] ?? ''}, ${property['region'] ?? ''}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPropertyFeature(Icons.straighten, '${property['size'] ?? 0} m²'),
                              _buildPropertyFeature(Icons.king_bed, '${property['bedrooms'] ?? 0} Beds'),
                              _buildPropertyFeature(Icons.bathtub, '${property['bathrooms'] ?? 0} Baths'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A90E2), size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}