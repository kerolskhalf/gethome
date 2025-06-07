// lib/screens/buyer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'property_details_screen.dart';
import 'property_comparison_screen.dart';
import '../utils/user_session.dart';
import 'login_screen.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  // API Configuration
  static const String API_BASE_URL = 'https://gethome.runasp.net';

  // User ID from authentication
  int get currentUserId => UserSession.getCurrentUserId();

  // Filter values
  RangeValues _priceRange = const RangeValues(0, 1000000);
  double _minSize = 0;
  int _bedrooms = 0;
  String _propertyType = 'All';
  bool _isFilterVisible = false;
  final Set<String> _selectedForComparison = {};
  bool _isSelectionMode = false;

  // API-related state
  List<int> _favoritePropertyIds = [];
  String _searchQuery = '';
  String _selectedCity = '';
  String _selectedRegion = '';

  // Data and loading states
  List<Map<String, dynamic>> _allProperties = [];
  List<Map<String, dynamic>> _filteredProperties = [];
  bool _isLoadingProperties = false;
  bool _isLoadingFavorites = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserFavorites(),
      _loadProperties(),
    ]);
  }

  // Load user's favorite properties from API
  Future<void> _loadUserFavorites() async {
    setState(() => _isLoadingFavorites = true);

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/api/favorites/user/$currentUserId?page=1&pageSize=100'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _favoritePropertyIds = List<int>.from(
              data['data']?.map((item) => item['propertyId'] ?? 0) ?? []
          );
        });
      } else {
        print('Failed to load favorites: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading favorites: $e');
    } finally {
      setState(() => _isLoadingFavorites = false);
    }
  }

  // Load properties from API with search filters
  Future<void> _loadProperties() async {
    setState(() => _isLoadingProperties = true);

    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': '1',
        'pageSize': '50',
      };

      if (_selectedCity.isNotEmpty) {
        queryParams['city'] = _selectedCity;
      }
      if (_selectedRegion.isNotEmpty) {
        queryParams['region'] = _selectedRegion;
      }
      if (_priceRange.start > 0) {
        queryParams['minPrice'] = _priceRange.start.toString();
      }
      if (_priceRange.end < 1000000) {
        queryParams['maxPrice'] = _priceRange.end.toString();
      }
      if (_bedrooms > 0) {
        queryParams['minBedrooms'] = _bedrooms.toString();
      }

      final uri = Uri.parse('$API_BASE_URL/api/properties/search').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allProperties = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _applyLocalFiltersAndSearch();
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load properties';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() => _isLoadingProperties = false);
    }
  }

  // Toggle favorite status via API
  Future<void> _toggleFavorite(int propertyId) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/favorites/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'userId': currentUserId,
          'propertyId': propertyId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          if (_favoritePropertyIds.contains(propertyId)) {
            _favoritePropertyIds.remove(propertyId);
          } else {
            _favoritePropertyIds.add(propertyId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _favoritePropertyIds.contains(propertyId)
                    ? 'Added to favorites'
                    : 'Removed from favorites'
            ),
            backgroundColor: _favoritePropertyIds.contains(propertyId)
                ? Colors.green
                : Colors.grey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyLocalFiltersAndSearch();
    });
  }

  void _applyLocalFiltersAndSearch() {
    setState(() {
      _filteredProperties = _allProperties.where((property) {
        final price = (property['price'] ?? 0).toDouble();
        final size = (property['size'] ?? 0).toDouble();
        final beds = property['bedrooms'] ?? 0;
        final type = property['propertyType'] ?? '';
        final title = (property['title'] ?? '').toString().toLowerCase();
        final address = (property['address'] ?? '').toString().toLowerCase();
        final description = (property['description'] ?? '').toString().toLowerCase();

        // Apply search query
        bool matchesSearch = _searchQuery.isEmpty ||
            title.contains(_searchQuery) ||
            address.contains(_searchQuery) ||
            description.contains(_searchQuery) ||
            type.toLowerCase().contains(_searchQuery);

        // Apply local filters (additional to API filters)
        bool matchesSize = size >= _minSize;
        bool matchesType = _propertyType == 'All' || type == _propertyType;

        return matchesSearch && matchesSize && matchesType;
      }).toList();

      _isFilterVisible = false;
    });
  }

  void _applyFiltersAndSearch() async {
    // This will trigger a new API call with updated filters
    await _loadProperties();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to logout, ${UserSession.getCurrentUserName()}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              // Clear user session
              UserSession.clearSession();

              // Navigate to login screen and remove all previous routes
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePropertySelection(String propertyId) {
    setState(() {
      if (_selectedForComparison.contains(propertyId)) {
        _selectedForComparison.remove(propertyId);
        if (_selectedForComparison.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        if (_selectedForComparison.length < 3) {
          _selectedForComparison.add(propertyId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can compare up to 3 properties at a time'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  void _startComparison() {
    if (_selectedForComparison.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least 2 properties to compare'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedProperties = _filteredProperties
        .where((p) => _selectedForComparison.contains(p['id'].toString()))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyComparisonScreen(
          selectedProperties: selectedProperties,
        ),
      ),
    );
  }

  void _handlePropertyTap(Map<String, dynamic> property) {
    if (_selectedForComparison.isNotEmpty) {
      _togglePropertySelection(property['id'].toString());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PropertyDetailsScreen(property: property),
        ),
      );
    }
  }

  void _handlePropertyLongPress(Map<String, dynamic> property) {
    setState(() {
      _isSelectionMode = true;
      _togglePropertySelection(property['id'].toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            stops: [0.2, 0.6, 0.9],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              if (_isFilterVisible) _buildFilterPanel(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedForComparison.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _startComparison,
        backgroundColor: Colors.blue,
        label: Text(
          'Compare (${_selectedForComparison.length})',
          style: const TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.compare_arrows, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  UserSession.getCurrentUserName().isNotEmpty
                      ? UserSession.getCurrentUserName()[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${UserSession.getCurrentUserName()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Find your dream home',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFilterVisible ? Icons.close : Icons.filter_list,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isFilterVisible = !_isFilterVisible;
                  });
                },
                tooltip: 'Filters',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadInitialData,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _handleLogout,
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by location, property type...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
        ),
        onChanged: _performSearch,
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location filters
          Row(
            children: [
              Expanded(
                child: _buildLocationFilter('City', _selectedCity, (value) {
                  setState(() => _selectedCity = value);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLocationFilter('Region', _selectedRegion, (value) {
                  setState(() => _selectedRegion = value);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Price Range',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 100,
            labels: RangeLabels(
              '\$${_priceRange.start.toStringAsFixed(0)}',
              '\$${_priceRange.end.toStringAsFixed(0)}',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          const SizedBox(height: 16),

          const Text(
            'Minimum Size (m²)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Slider(
            value: _minSize,
            min: 0,
            max: 500,
            divisions: 50,
            label: '${_minSize.toStringAsFixed(0)} m²',
            onChanged: (double value) {
              setState(() {
                _minSize = value;
              });
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minimum Bedrooms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<int>(
                      value: _bedrooms,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF234E70),
                      style: const TextStyle(color: Colors.white),
                      items: [0, 1, 2, 3, 4, 5]
                          .map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value == 0 ? 'Any' : value.toString()),
                        );
                      }).toList(),
                      onChanged: (int? value) {
                        if (value != null) {
                          setState(() {
                            _bedrooms = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Property Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _propertyType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF234E70),
                      style: const TextStyle(color: Colors.white),
                      items: ['All', 'Apartment', 'House', 'Villa', 'Studio']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _propertyType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFiltersAndSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoadingProperties) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredProperties.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPropertyList();
  }

  Widget _buildPropertyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        final property = _filteredProperties[index];
        final propertyId = property['id'];
        final isSelected = _selectedForComparison.contains(propertyId.toString());
        final isFavorite = _favoritePropertyIds.contains(propertyId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
            onTap: () => _handlePropertyTap(property),
            onLongPress: () => _handlePropertyLongPress(property),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.white.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: property['imagePath'] != null && property['imagePath'].isNotEmpty
                            ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.file(
                            File(property['imagePath']),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                            : const Center(
                          child: Icon(Icons.home, size: 50, color: Colors.grey),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_selectedForComparison.toList().indexOf(propertyId.toString()) + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
                                property['title'] ?? property['houseType'] ?? 'Property',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.white,
                              ),
                              onPressed: () => _toggleFavorite(propertyId),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${property['city'] ?? ''}, ${property['region'] ?? ''}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${property['price'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (property['pricePerM2'] != null)
                                  Text(
                                    '\$${property['pricePerM2']} per m²',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                property['houseType'] ?? 'Property',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPropertyFeature(
                              Icons.straighten,
                              '${property['size'] ?? 0} m²',
                            ),
                            _buildPropertyFeature(
                              Icons.king_bed,
                              '${property['bedrooms'] ?? 0} Beds',
                            ),
                            _buildPropertyFeature(
                              Icons.bathtub,
                              '${property['bathrooms'] ?? 0} Baths',
                            ),
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
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No properties found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}