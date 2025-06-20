// lib/screens/buyer_dashboard_screen.dart - FIXED VERSION with API Search
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
  // Predefined cities and regions from the mapping
  static const List<String> _availableCities = [
    'Any', // Default option
    'Alexandria',
    'Aswan',
    'Asyut',
    'Beheira',
    'Beni Suef',
    'Cairo',
    'Dakahlia',
    'Damietta',
    'Gharbia',
    'Giza',
    'Ismailia',
    'Kafr Al-Sheikh',
    'Matruh',
    'Minya',
    'Monufia',
    'Port Said',
    'Qalyubia',
    'Qena',
    'Red Sea',
    'Sharqia',
    'South Sinai',
    'Suez',
  ];

  static const List<String> _availableRegions = [
    'Any', // Default option
    '10th of Ramadan',
    '6th of October',
    'Abasiya',
    'Abu Qir',
    'Abu Talat',
    'Agami',
    'Agouza',
    'Ain Shams',
    'Ain Sukhna',
    'Al Hadrah',
    'Al Ibrahimiyyah',
    'Al Manial',
    'Alamein',
    'Almazah',
    'Amreya',
    'Arbaeen',
    'Ard El Lewa',
    'Asafra',
    'Aswan City',
    'Asyut City',
    'Awayed',
    'Azarita',
    'Bacchus',
    'Badr City',
    'Bahray - Anfoshy',
    'Bahtim',
    'Banha',
    'Basateen',
    'Belqas',
    'Beni Suef City',
    'Bilbeis',
    'Bolkly',
    'Borg Al-Arab',
    'Camp Caesar',
    'Cleopatra',
    'Damanhour',
    'Damietta City',
    'Dar Al-Salaam',
    'Dawahy District',
    'Dhahria',
    'Dokki',
    'Downtown Cairo',
    'El Fostat',
    'El Max',
    'Faisal',
    'Fleming',
    'Gamasa',
    'Gesr Al Suez',
    'Gianaclis',
    'Giza District',
    'Glim',
    'Gomrok',
    'Gouna',
    'Hadayek 6th of October',
    'Hadayek Al-Ahram',
    'Hadayek Al-Kobba',
    'Hadayek Helwan',
    'Haram',
    'Heliopolis',
    'Helmeyat El Zaytoun',
    'Helwan',
    'Hurghada',
    'Imbaba',
    'Ismailia City',
    'Kafr Abdo',
    'Kafr Al-Dawwar',
    'Kafr Al-Sheikh City',
    'Katameya',
    'Koum Al-Dikka',
    'Labban',
    'Laurent',
    'Maadi',
    'Maamoura',
    'Madinaty',
    'Mahalla Al-Kobra',
    'Mandara',
    'Manshiyya',
    'Mansura',
    'Mansuriyya',
    'Marg',
    'Markaz Badr',
    'Marsa Matrouh',
    'Maryotaya',
    'Masr Al-Kadema',
    'Matareya',
    'Miami',
    'Minya City',
    'Mit Ghamr',
    'Mohandessin',
    'Moharam Bik',
    'Mokattam',
    'Moneeb',
    'Montazah',
    'Mostakbal City',
    'Nabaruh',
    'Nagela',
    'Nakheel',
    'Nasr City',
    'New Beni Suef',
    'New Cairo - El Tagamoa',
    'New Capital City',
    'New Damietta',
    'New Heliopolis',
    'New Mansoura',
    'New Nozha',
    'North Coast',
    'Obour City',
    'Qalyub',
    'Qasr Al-Nil',
    'Qena City',
    'Raml Station',
    'Ramses + Ramses Extension',
    'Ras Al-Bar',
    'Ras El Tin',
    'Ras Sedr',
    'Rehab City',
    'Rod Al-Farag',
    'Roushdy',
    'Saba Pasha',
    'Saft El Laban',
    'Salam City',
    'San Stefano',
    'Schutz',
    'Seyouf',
    'Sharm Al-Sheikh',
    'Sharq District',
    'Shatby',
    'Shebin Al-Koum',
    'Sheikh Zayed',
    'Sheraton',
    'Shorouk City',
    'Shubra',
    'Shubra Al-Khaimah',
    'Sidi Beshr',
    'Sidi Gaber',
    'Smoha',
    'Sporting',
    'Stanley',
    'Suez District',
    'Taba',
    'Tanta',
    'Tersa',
    'Victoria',
    'Wardian',
    'Warraq',
    'West Somid',
    'Zagazig',
    'Zahraa Al Maadi',
    'Zamalek',
    'Zezenia',
    'Zohour District',
  ];

  // Filter values
  RangeValues _priceRange = const RangeValues(0, 1000000);
  int _minBedrooms = 0;
  int _maxBedrooms = 10;
  String _selectedCity = 'Any';
  String _selectedRegion = 'Any';
  bool _isFilterVisible = false;
  final Set<String> _selectedForComparison = {};
  bool _isSelectionMode = false;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Data and loading states
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _allLoadedProperties = []; // Store unfiltered results
  bool _isLoadingProperties = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalCount = 0;
  bool _hasMoreData = true;

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreProperties();
      }
    }
  }

  // FIX: Updated to use search API with filters or fallback to all properties
  Future<void> _loadProperties({bool refresh = false}) async {
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
      print('🔄 Loading properties with filters...');

      // Build query parameters for search API
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // Only add parameters that have actual values (not 'Any')
      if (_selectedCity != 'Any' && _selectedCity.isNotEmpty) {
        queryParams['city'] = _selectedCity.toLowerCase();
      }
      if (_selectedRegion != 'Any' && _selectedRegion.isNotEmpty) {
        queryParams['region'] = _selectedRegion.toLowerCase();
      }

      // Add price range if not at extremes
      if (_priceRange.start > 0) {
        queryParams['minPrice'] = _priceRange.start.toString();
      }
      if (_priceRange.end < 1000000) {
        queryParams['maxPrice'] = _priceRange.end.toString();
      }

      // Add bedroom filters if not at defaults
      if (_minBedrooms > 0) {
        queryParams['minBedrooms'] = _minBedrooms.toString();
      }
      if (_maxBedrooms < 10) {
        queryParams['maxBedrooms'] = _maxBedrooms.toString();
      }

      // Check if any filters are applied (excluding pagination)
      final hasFilters = queryParams.keys.any((key) =>
      key != 'page' && key != 'pageSize');

      String endpoint;
      if (hasFilters) {
        endpoint = ApiConfig.searchPropertiesUrl;
        print('🔍 Using SEARCH endpoint with filters');
      } else {
        endpoint = ApiConfig.allPropertiesUrl;
        // Clear query params for all properties endpoint
        queryParams.clear();
        print('🏠 Using ALL PROPERTIES endpoint (no filters)');
      }

      print('📡 Query parameters: $queryParams');

      final uri = queryParams.isEmpty
          ? Uri.parse(endpoint)
          : Uri.parse(endpoint).replace(queryParameters: queryParams);

      print('🌐 Request URL: $uri');

      final response = await http.get(
        uri,
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> newProperties = [];

        if (hasFilters) {
          // Handle search API response format
          if (data is Map<String, dynamic> && data.containsKey('data')) {
            final dataList = data['data'] as List? ?? [];
            newProperties = dataList
                .map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty)
                .toList();

            // Update pagination info from search API
            _totalCount = data['totalCount'] ?? 0;
            final pageSize = data['pageSize'] ?? _pageSize;

            _hasMoreData = newProperties.length == pageSize &&
                (_currentPage * pageSize) < _totalCount;

            print('📊 Search API returned: ${_totalCount} total, ${newProperties.length} on this page');
          } else {
            print('⚠️ Unexpected search API response format');
            newProperties = [];
          }
        } else {
          // Handle all properties response format
          if (data is List) {
            newProperties = data.map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty).toList();
          } else if (data is Map<String, dynamic> && data.containsKey('data')) {
            final dataList = data['data'] as List;
            newProperties = dataList.map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty).toList();
          }

          // For all properties, implement simple pagination
          _totalCount = newProperties.length;
          final startIndex = (_currentPage - 1) * _pageSize;
          final endIndex = startIndex + _pageSize;

          if (_currentPage == 1) {
            // First page: take first pageSize items
            if (newProperties.length > _pageSize) {
              newProperties = newProperties.sublist(0, _pageSize);
              _hasMoreData = true;
            } else {
              _hasMoreData = false;
            }
          } else {
            // Subsequent pages: this shouldn't happen with all properties endpoint
            // but handle it anyway
            _hasMoreData = false;
            newProperties = [];
          }
        }

        print('🏠 Successfully loaded ${newProperties.length} properties');
        print('📊 Total count: $_totalCount, Has more: $_hasMoreData');

        // Debug: Print first property structure
        if (newProperties.isNotEmpty) {
          print('📋 Sample property: ${newProperties.first}');
        }

        setState(() {
          if (refresh || _currentPage == 1) {
            _allLoadedProperties = newProperties;
            _properties = newProperties;
          } else {
            _allLoadedProperties.addAll(newProperties);
            _properties = List.from(_allLoadedProperties);
          }
          _errorMessage = null;
        });

        // Apply text search if needed (after loading results)
        if (_searchQuery.isNotEmpty) {
          _applyLocalTextSearch();
        }

      } else {
        print('❌ Failed to load properties: ${response.statusCode}');
        print('📄 Error response: ${response.body}');

        setState(() {
          _errorMessage = 'Failed to load properties. Server returned ${response.statusCode}';
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

  // Helper method to safely convert API response items to Map
  Map<String, dynamic> _safeMapConversion(dynamic item) {
    try {
      if (item is Map<String, dynamic>) {
        // Ensure all required fields exist with safe defaults
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

  // Helper method to safely convert numeric values
  dynamic _safeNumericConversion(dynamic value, dynamic defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> _loadMoreProperties() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      await _loadProperties();
    } catch (e) {
      print('Error loading more properties: $e');
      _currentPage--; // Revert page increment on error
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // FIX: Improved text search that works with API results
  void _applyLocalTextSearch() {
    if (_searchQuery.isEmpty) {
      // If no search query, show all loaded properties
      setState(() {
        _properties = List.from(_allLoadedProperties);
      });
      return;
    }

    setState(() {
      _properties = _allLoadedProperties.where((property) {
        final houseType = (property['houseType'] ?? '').toString().toLowerCase();
        final city = (property['city'] ?? '').toString().toLowerCase();
        final region = (property['region'] ?? '').toString().toLowerCase();
        final searchLower = _searchQuery.toLowerCase().trim();

        // Search in multiple fields
        return houseType.contains(searchLower) ||
            city.contains(searchLower) ||
            region.contains(searchLower);
      }).toList();
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_searchQuery.isEmpty) {
      // If search is cleared, reload all properties with current filters
      _loadProperties(refresh: true);
    } else {
      // Apply text search to current results
      _applyLocalTextSearch();
    }
  }

  // FIX: Apply filters using API search
  void _applyFilters() {
    setState(() {
      _isFilterVisible = false;
      _currentPage = 1;
      _searchQuery = ''; // Clear text search when applying filters
    });
    _searchController.clear(); // Clear search text field
    _loadProperties(refresh: true);
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 1000000);
      _minBedrooms = 0;
      _maxBedrooms = 10;
      _selectedCity = 'Any';
      _selectedRegion = 'Any';
      _searchQuery = '';
      _currentPage = 1;
      _isFilterVisible = false;
      _allLoadedProperties.clear();
    });
    _searchController.clear();
    _loadProperties(refresh: true);
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
              UserSession.clearSession();
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
                        _buildFilterPanel(),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildBody(),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: _buildBody(),
                ),
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
            label: const Text(
              'Clear',
              style: TextStyle(color: Colors.white),
            ),
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
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
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
                      'Find your dream home (${_properties.length} properties)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isFilterVisible ? Icons.close : Icons.filter_list,
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
                onPressed: () => _loadProperties(refresh: true),
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
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search by location, property type...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.5),
            size: 20,
          ),
        ),
        onChanged: _performSearch,
      ),
    );
  }

  // FIX: Enhanced filter panel with city/region dropdowns
  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _resetFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // City and Region dropdowns
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

          // Price Range
          const Text(
            'Price Range',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
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

          // Bedrooms
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min Bedrooms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
                          value: _minBedrooms,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF234E70),
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(11, (index) => index).map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value == 0 ? 'Any' : value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _minBedrooms = newValue;
                                if (_minBedrooms > _maxBedrooms) {
                                  _maxBedrooms = _minBedrooms;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Max Bedrooms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
                          value: _maxBedrooms,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF234E70),
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(11, (index) => index).map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value == 0 ? 'Any' : value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _maxBedrooms = newValue;
                                if (_maxBedrooms < _minBedrooms) {
                                  _minBedrooms = _maxBedrooms;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Apply Filters Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
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

  Widget _buildBody() {
    if (_isLoadingProperties && _properties.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Searching properties...',
              style: TextStyle(color: Colors.white),
            ),
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
                onPressed: () => _loadProperties(refresh: true),
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
      onRefresh: () => _loadProperties(refresh: true),
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (property['isHighFloor'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'High Floor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
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
                  const SizedBox(height: 8),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (property['pricePerM2'] != null && property['pricePerM2'] > 0)
                            Text(
                              '\$${property['pricePerM2']} per m²',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPropertyFeature(
                        Icons.straighten,
                        '${property['size'] ?? 0} m²',
                      ),
                      _buildPropertyFeature(
                        Icons.king_bed,
                        '${property['bedrooms'] ?? 0}',
                      ),
                      _buildPropertyFeature(
                        Icons.bathtub,
                        '${property['bathrooms'] ?? 0}',
                      ),
                    ],
                  ),
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
          size: 14,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    // Check if any filters are applied
    final hasActiveFilters = _selectedCity != 'Any' ||
        _selectedRegion != 'Any' ||
        _priceRange.start > 0 ||
        _priceRange.end < 1000000 ||
        _minBedrooms > 0 ||
        _maxBedrooms < 10 ||
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
              onPressed: () => _loadProperties(refresh: true),
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
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        elevation: 0,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
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
    );
  }
}