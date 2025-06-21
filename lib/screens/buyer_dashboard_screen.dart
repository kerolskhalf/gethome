// lib/screens/buyer_dashboard_screen.dart - ENHANCED VERSION
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'property_details_screen.dart';
import 'property_comparison_screen.dart';
import 'favorites_screen.dart';
import 'map_screen.dart';
import 'user_profile_screen.dart';
import 'viewing_requests_screen.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'login_screen.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  // Enhanced filter options
  static const List<String> _availableCities = [
    'Any', 'Alexandria', 'Aswan', 'Asyut', 'Beheira', 'Beni Suef', 'Cairo',
    'Dakahlia', 'Damietta', 'Gharbia', 'Giza', 'Ismailia', 'Kafr Al-Sheikh',
    'Matruh', 'Minya', 'Monufia', 'Port Said', 'Qalyubia', 'Qena',
    'Red Sea', 'Sharqia', 'South Sinai', 'Suez',
  ];

  static const List<String> _availableRegions = [
    'Any', '10th of Ramadan', '6th of October', 'Abasiya', 'Abu Qir',
    'Agami', 'Agouza', 'Ain Shams', 'Alamein', 'Maadi', 'Zamalek',
    'Heliopolis', 'New Cairo - El Tagamoa', 'Nasr City', 'Dokki',
    'Mohandessin', 'Sheikh Zayed', 'Katameya', 'Rehab City',
  ];

  static const List<String> _availableHouseTypes = [
    'Any', 'Apartment', 'House', 'Villa', 'Studio', 'Condo', 'Townhouse', 'Duplex', 'Penthouse'
  ];

  // Enhanced filter values
  RangeValues _priceRange = const RangeValues(0, 10000000); // Increased max to 10M LE
  RangeValues _sizeRange = const RangeValues(0, 1000); // Size in m²
  int _minBedrooms = 0;
  int _maxBedrooms = 10;
  int _minBathrooms = 0;
  int _maxBathrooms = 10;
  int _minTotalRooms = 0;
  int _maxTotalRooms = 20;
  String _selectedCity = 'Any';
  String _selectedRegion = 'Any';
  String _selectedHouseType = 'Any';
  bool? _isHighFloor; // null = Any, true = High Floor only, false = Not High Floor
  bool _isFilterVisible = false;

  // Comparison functionality
  final Set<String> _selectedForComparison = {};
  bool _isSelectionMode = false;

  // Enhanced search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Data and states
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _allLoadedProperties = [];
  bool _isLoadingProperties = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Enhanced pagination
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalCount = 0;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllProperties();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Enhanced scroll listener for infinite loading
  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && _allLoadedProperties.isNotEmpty) {
        _loadMoreProperties();
      }
    }
  }

  // Load all properties with pagination support
  Future<void> _loadAllProperties({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _properties.clear();
        _allLoadedProperties.clear();
        _hasMoreData = true;
        _errorMessage = null;
      });
    }

    setState(() => _isLoadingProperties = true);

    try {
      print('🔄 Loading all properties - Page: $_currentPage');

      // Use the all properties endpoint for initial load
      final response = await http.get(
        Uri.parse(ApiConfig.allPropertiesUrl),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 15));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> allProperties = [];

        // Handle different response formats
        if (data is List) {
          allProperties = data.map((item) => _safeMapConversion(item))
              .where((item) => item.isNotEmpty).toList();
        } else if (data is Map<String, dynamic> && data.containsKey('data')) {
          final dataList = data['data'] as List;
          allProperties = dataList.map((item) => _safeMapConversion(item))
              .where((item) => item.isNotEmpty).toList();
        }

        print('🏠 Total properties loaded: ${allProperties.length}');

        // Store all properties and implement client-side pagination
        setState(() {
          _allLoadedProperties = allProperties;
          _totalCount = allProperties.length;

          // Show first page
          final endIndex = _pageSize > allProperties.length
              ? allProperties.length
              : _pageSize;
          _properties = allProperties.sublist(0, endIndex);
          _hasMoreData = _pageSize < allProperties.length;
          _errorMessage = null;
        });

        // Apply filters and search if active
        _applyFiltersAndSearch();

      } else {
        setState(() {
          _errorMessage = 'Failed to load properties. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('💥 Error loading properties: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoadingProperties = false);
    }
  }

  // Load more properties (client-side pagination)
  Future<void> _loadMoreProperties() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading

    try {
      final startIndex = _properties.length;
      final endIndex = startIndex + _pageSize > _allLoadedProperties.length
          ? _allLoadedProperties.length
          : startIndex + _pageSize;

      if (startIndex < _allLoadedProperties.length) {
        final newProperties = _allLoadedProperties.sublist(startIndex, endIndex);

        setState(() {
          _properties.addAll(newProperties);
          _hasMoreData = endIndex < _allLoadedProperties.length;
        });

        print('📄 Loaded ${newProperties.length} more properties. Total: ${_properties.length}');
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // Enhanced safe map conversion
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
          'totalRooms': _safeNumericConversion(item['totalRooms'], 0),
          'imagePath': item['imagePath']?.toString() ?? '',
          'isHighFloor': item['isHighFloor'] == true,
          'pricePerM2': _safeNumericConversion(item['pricePerM2'], 0),
          'status': item['status'] ?? 0,
          'userId': _safeNumericConversion(item['userId'], 0),
          'isFurnished': item['isFurnished'] == true,
          'floor': _safeNumericConversion(item['floor'], 0),
          'latitude': _safeNumericConversion(item['latitude'], 0),
          'longitude': _safeNumericConversion(item['longitude'], 0),
        };
      }
      return {};
    } catch (e) {
      print('⚠️ Error converting property item: $e');
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

  // Enhanced search functionality
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    _applyFiltersAndSearch();
  }

  // Apply all filters and search
  void _applyFiltersAndSearch() {
    List<Map<String, dynamic>> filteredProperties = List.from(_allLoadedProperties);

    // Apply filters
    filteredProperties = filteredProperties.where((property) {
      // City filter
      if (_selectedCity != 'Any') {
        final propertyCity = property['city']?.toString().toLowerCase() ?? '';
        if (!propertyCity.contains(_selectedCity.toLowerCase())) {
          return false;
        }
      }

      // Region filter
      if (_selectedRegion != 'Any') {
        final propertyRegion = property['region']?.toString().toLowerCase() ?? '';
        if (!propertyRegion.contains(_selectedRegion.toLowerCase())) {
          return false;
        }
      }

      // House type filter
      if (_selectedHouseType != 'Any') {
        final propertyType = property['houseType']?.toString().toLowerCase() ?? '';
        if (!propertyType.contains(_selectedHouseType.toLowerCase())) {
          return false;
        }
      }

      // Price range filter
      final price = _safeNumericConversion(property['price'], 0);
      if (price < _priceRange.start || price > _priceRange.end) {
        return false;
      }

      // Size range filter
      final size = _safeNumericConversion(property['size'], 0);
      if (size < _sizeRange.start || size > _sizeRange.end) {
        return false;
      }

      // Bedrooms filter
      final bedrooms = _safeNumericConversion(property['bedrooms'], 0);
      if ((_minBedrooms > 0 && bedrooms < _minBedrooms) ||
          (_maxBedrooms < 10 && bedrooms > _maxBedrooms)) {
        return false;
      }

      // Bathrooms filter
      final bathrooms = _safeNumericConversion(property['bathrooms'], 0);
      if ((_minBathrooms > 0 && bathrooms < _minBathrooms) ||
          (_maxBathrooms < 10 && bathrooms > _maxBathrooms)) {
        return false;
      }

      // Total rooms filter
      final totalRooms = _safeNumericConversion(property['totalRooms'], 0);
      if ((_minTotalRooms > 0 && totalRooms < _minTotalRooms) ||
          (_maxTotalRooms < 20 && totalRooms > _maxTotalRooms)) {
        return false;
      }

      // High floor filter
      if (_isHighFloor != null) {
        final isHighFloor = property['isHighFloor'] == true;
        if (_isHighFloor! != isHighFloor) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply text search
    if (_searchQuery.isNotEmpty) {
      filteredProperties = filteredProperties.where((property) {
        final houseType = property['houseType']?.toString().toLowerCase() ?? '';
        final city = property['city']?.toString().toLowerCase() ?? '';
        final region = property['region']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();

        return houseType.contains(searchLower) ||
            city.contains(searchLower) ||
            region.contains(searchLower);
      }).toList();
    }

    setState(() {
      _properties = filteredProperties.take(_pageSize).toList();
      _hasMoreData = filteredProperties.length > _pageSize;
      _allLoadedProperties = filteredProperties; // Update base for pagination
    });

    print('🔍 Filtered results: ${filteredProperties.length} properties');
  }

  // Apply filters
  void _applyFilters() {
    setState(() {
      _isFilterVisible = false;
      _currentPage = 1;
    });
    _applyFiltersAndSearch();
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 10000000);
      _sizeRange = const RangeValues(0, 1000);
      _minBedrooms = 0;
      _maxBedrooms = 10;
      _minBathrooms = 0;
      _maxBathrooms = 10;
      _minTotalRooms = 0;
      _maxTotalRooms = 20;
      _selectedCity = 'Any';
      _selectedRegion = 'Any';
      _selectedHouseType = 'Any';
      _isHighFloor = null;
      _searchQuery = '';
      _isFilterVisible = false;
    });
    _searchController.clear();
    _loadAllProperties(refresh: true);
  }

  // Logout handler
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to logout, ${UserSession.getCurrentUserName()}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              UserSession.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Property interaction handlers
  void _handlePropertyTap(Map<String, dynamic> property) {
    if (_isSelectionMode) {
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

  void _handlePropertyLongPress(Map<String, dynamic> property) {
    setState(() {
      _isSelectionMode = true;
      _togglePropertySelection(property['id'].toString());
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

    final selectedProperties = _properties
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

  void _clearSelection() {
    setState(() {
      _selectedForComparison.clear();
      _isSelectionMode = false;
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
              if (_isFilterVisible) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildEnhancedFilterPanel(),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: _buildBody(),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _selectedForComparison.isNotEmpty
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _clearSelection,
            backgroundColor: Colors.grey.withOpacity(0.8),
            heroTag: "clear",
            label: const Text('Clear', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.clear, color: Colors.white),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
            onPressed: _startComparison,
            backgroundColor: Colors.blue,
            heroTag: "compare",
            label: Text(
              'Compare (${_selectedForComparison.length})',
              style: const TextStyle(color: Colors.white),
            ),
            icon: const Icon(Icons.compare_arrows, color: Colors.white),
          ),
        ],
      )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  UserSession.getUserInitials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${UserSession.getDisplayName()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Find your dream home (${_properties.length} of ${_totalCount} properties)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFilterVisible ? Icons.close : Icons.tune,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isFilterVisible = !_isFilterVisible;
                  });
                },
                tooltip: 'Filters',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: () => _loadAllProperties(refresh: true),
                tooltip: 'Refresh',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                color: const Color(0xFF234E70),
                onSelected: (value) {
                  switch (value) {
                    case 'requests':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ViewingRequestsScreen()),
                      );
                      break;
                    case 'profile':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                      );
                      break;
                    case 'logout':
                      _handleLogout();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'requests',
                    child: Text('My Requests', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('Profile', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Logout', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEnhancedSearchBar(),
        ],
      ),
    );
  }

  Widget _buildEnhancedSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF234E70),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Color(0xFF234E70),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search by type, location, area...',
                hintStyle: TextStyle(
                  color: const Color(0xFF234E70).withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _performSearch,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF234E70),
                  size: 18,
                ),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced filter panel with all requested options
  Widget _buildEnhancedFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Advanced Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset All', style: TextStyle(color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Location Filters
            _buildFilterSectionTitle('Location'),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownFilter(
                    'City',
                    _selectedCity,
                    _availableCities,
                        (value) => setState(() => _selectedCity = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownFilter(
                    'Region',
                    _selectedRegion,
                    _availableRegions,
                        (value) => setState(() => _selectedRegion = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Property Type
            _buildFilterSectionTitle('Property Type'),
            _buildDropdownFilter(
              'House Type',
              _selectedHouseType,
              _availableHouseTypes,
                  (value) => setState(() => _selectedHouseType = value!),
            ),
            const SizedBox(height: 20),

            // Price Range (LE)
            _buildFilterSectionTitle('Price Range (LE)'),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 10000000,
              divisions: 100,
              labels: RangeLabels(
                '${_formatPrice(_priceRange.start)} LE',
                '${_formatPrice(_priceRange.end)} LE',
              ),
              onChanged: (RangeValues values) {
                setState(() => _priceRange = values);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatPrice(_priceRange.start)} LE',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_formatPrice(_priceRange.end)} LE',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Size Range
            _buildFilterSectionTitle('Size Range (m²)'),
            RangeSlider(
              values: _sizeRange,
              min: 0,
              max: 1000,
              divisions: 50,
              labels: RangeLabels(
                '${_sizeRange.start.toInt()} m²',
                '${_sizeRange.end.toInt()} m²',
              ),
              onChanged: (RangeValues values) {
                setState(() => _sizeRange = values);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_sizeRange.start.toInt()} m²',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_sizeRange.end.toInt()} m²',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rooms Section
            _buildFilterSectionTitle('Rooms'),
            // Bedrooms
            Row(
              children: [
                Expanded(
                  child: _buildNumberFilter('Min Bedrooms', _minBedrooms, 0, 10,
                          (value) => setState(() => _minBedrooms = value)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberFilter('Max Bedrooms', _maxBedrooms, 0, 10,
                          (value) => setState(() => _maxBedrooms = value)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bathrooms
            Row(
              children: [
                Expanded(
                  child: _buildNumberFilter('Min Bathrooms', _minBathrooms, 0, 10,
                          (value) => setState(() => _minBathrooms = value)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberFilter('Max Bathrooms', _maxBathrooms, 0, 10,
                          (value) => setState(() => _maxBathrooms = value)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Rooms
            Row(
              children: [
                Expanded(
                  child: _buildNumberFilter('Min Total Rooms', _minTotalRooms, 0, 20,
                          (value) => setState(() => _minTotalRooms = value)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberFilter('Max Total Rooms', _maxTotalRooms, 0, 20,
                          (value) => setState(() => _maxTotalRooms = value)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // High Floor Filter
            _buildFilterSectionTitle('Floor Type'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool?>(
                  value: _isHighFloor,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF234E70),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('Any Floor'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('High Floor Only'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text('Not High Floor'),
                    ),
                  ],
                  onChanged: (bool? value) {
                    setState(() => _isHighFloor = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Apply Filters Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
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
      ),
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(
      String label,
      String value,
      List<String> items,
      Function(String?) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberFilter(
      String label,
      int value,
      int min,
      int max,
      Function(int) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: List.generate(max - min + 1, (index) => min + index)
                  .map((int val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text(val == 0 ? 'Any' : val.toString()),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) onChanged(newValue);
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    } else {
      return price.toStringAsFixed(0);
    }
  }

  Widget _buildBody() {
    if (_isLoadingProperties && _properties.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading properties...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                onPressed: () => _loadAllProperties(refresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_properties.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPropertyList();
  }

  Widget _buildPropertyList() {
    return RefreshIndicator(
      onRefresh: () => _loadAllProperties(refresh: true),
      color: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _properties.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _properties.length) {
            final property = _properties[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPropertyCard(property),
            );
          } else {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final propertyId = property['id'];
    final isSelected = _selectedForComparison.contains(propertyId.toString());

    return GestureDetector(
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
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: _buildPropertyImage(property['imagePath']),
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
                // Property type badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      property['houseType'] ?? 'Property',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              property['houseType'] ?? 'Property',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_capitalizeFirst(property['city'] ?? '')}, ${_capitalizeFirst(property['region'] ?? '')}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatPrice(property['price'].toDouble())} LE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (property['pricePerM2'] != null && property['pricePerM2'] > 0)
                            Text(
                              '${_formatPrice(property['pricePerM2'].toDouble())} LE/m²',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Property features
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
                      if (property['totalRooms'] != null && property['totalRooms'] > 0)
                        _buildPropertyFeature(
                          Icons.room,
                          '${property['totalRooms']} Total',
                        ),
                    ],
                  ),

                  // High floor indicator
                  if (property['isHighFloor'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.height,
                            color: Colors.blue.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'High Floor Property',
                            style: TextStyle(
                              color: Colors.blue.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildPropertyImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty || !ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.home, size: 50, color: Colors.grey),
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
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasActiveFilters = _selectedCity != 'Any' ||
        _selectedRegion != 'Any' ||
        _selectedHouseType != 'Any' ||
        _priceRange.start > 0 ||
        _priceRange.end < 10000000 ||
        _sizeRange.start > 0 ||
        _sizeRange.end < 1000 ||
        _minBedrooms > 0 ||
        _maxBedrooms < 10 ||
        _minBathrooms > 0 ||
        _maxBathrooms < 10 ||
        _minTotalRooms > 0 ||
        _maxTotalRooms < 20 ||
        _isHighFloor != null ||
        _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters ? Icons.filter_list_off : Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'No properties match your filters'
                  : 'No properties found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try adjusting your filters to see more results'
                  : 'Try adjusting your search terms',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasActiveFilters) ...[
              ElevatedButton.icon(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                icon: const Icon(Icons.clear_all, color: Colors.white),
                label: const Text(
                  'Clear All Filters',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: () => _loadAllProperties(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Refresh Properties',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF234E70).withOpacity(0.95),
            const Color(0xFF1a237e).withOpacity(0.98),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          currentIndex: 0,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_rounded, size: 22),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, size: 22),
              ),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_rounded, size: 22),
              ),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded, size: 22),
              ),
              label: 'Profile',
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
              // Already on home
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritesScreen()),
                );
                break;
              case 2:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
                break;
              case 3:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}