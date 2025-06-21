// lib/screens/buyer_dashboard_screen.dart - ENHANCED WITH ADVANCED FILTERS
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
    'Any', 'Alexandria', 'Aswan', 'Asyut', 'Beheira', 'Beni Suef', 'Cairo',
    'Dakahlia', 'Damietta', 'Gharbia', 'Giza', 'Ismailia', 'Kafr Al-Sheikh',
    'Matruh', 'Minya', 'Monufia', 'Port Said', 'Qalyubia', 'Qena', 'Red Sea',
    'Sharqia', 'South Sinai', 'Suez',
  ];

  static const List<String> _availableRegions = [
    'Any', '10th of Ramadan', '6th of October', 'Abasiya', 'Abu Qir', 'Agami',
    'Agouza', 'Ain Shams', 'Al Manial', 'Alamein', 'Almazah', 'Amreya',
    'Ard El Lewa', 'Asafra', 'Basateen', 'Bolkly', 'Borg Al-Arab',
    'Camp Caesar', 'Cleopatra', 'Damanhour', 'Dar Al-Salaam', 'Dokki',
    'Downtown Cairo', 'El Fostat', 'Faisal', 'Fleming', 'Giza District',
    'Hadayek Al-Ahram', 'Haram', 'Heliopolis', 'Helwan', 'Hurghada',
    'Imbaba', 'Katameya', 'Maadi', 'Madinaty', 'Mandara', 'Mohandessin',
    'Mokattam', 'Montazah', 'Mostakbal City', 'Nasr City', 'New Cairo - El Tagamoa',
    'New Capital City', 'North Coast', 'Obour City', 'Rehab City', 'Sheraton',
    'Sheikh Zayed', 'Shorouk City', 'Shubra', 'Sidi Beshr', 'Sidi Gaber',
    'Smoha', 'Sporting', 'Stanley', 'Zamalek',
  ];

  static const List<String> _propertyTypes = [
    'Any', 'Apartment', 'House', 'Villa', 'Studio', 'Condo', 'Townhouse'
  ];

  static const List<String> _floorTypes = [
    'Any Floor', 'Ground Floor', 'First Floor', 'Second Floor', 'Third Floor',
    'Fourth Floor', 'Fifth Floor', 'High Floor (6+)', 'Top Floor', 'Basement'
  ];

  // Enhanced filter values
  RangeValues _priceRange = const RangeValues(0, 10000000);
  RangeValues _sizeRange = const RangeValues(0, 1000);
  int _minBedrooms = 0;
  int _maxBedrooms = 10;
  int _minBathrooms = 0;
  int _maxBathrooms = 10;
  int _minTotalRooms = 0;
  int _maxTotalRooms = 20;
  String _selectedCity = 'Any';
  String _selectedRegion = 'Any';
  String _selectedPropertyType = 'Any';
  String _selectedFloorType = 'Any Floor';
  bool _isFilterVisible = false;
  final Set<String> _selectedForComparison = {};
  bool _isSelectionMode = false;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Data and loading states
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _allLoadedProperties = [];
  bool _isLoadingProperties = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
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
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      if (_selectedCity != 'Any' && _selectedCity.isNotEmpty) {
        queryParams['city'] = _selectedCity.toLowerCase();
      }
      if (_selectedRegion != 'Any' && _selectedRegion.isNotEmpty) {
        queryParams['region'] = _selectedRegion.toLowerCase();
      }
      if (_priceRange.start > 0) {
        queryParams['minPrice'] = _priceRange.start.toString();
      }
      if (_priceRange.end < 10000000) {
        queryParams['maxPrice'] = _priceRange.end.toString();
      }
      if (_minBedrooms > 0) {
        queryParams['minBedrooms'] = _minBedrooms.toString();
      }
      if (_maxBedrooms < 10) {
        queryParams['maxBedrooms'] = _maxBedrooms.toString();
      }

      final hasFilters = queryParams.keys.any((key) => key != 'page' && key != 'pageSize');
      String endpoint;

      if (hasFilters) {
        endpoint = ApiConfig.searchPropertiesUrl;
      } else {
        endpoint = ApiConfig.allPropertiesUrl;
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: ApiConfig.headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> newProperties = [];

        if (hasFilters) {
          // Handle search/filter response
          if (data is Map<String, dynamic> && data.containsKey('data')) {
            final dataList = data['data'] as List? ?? [];
            newProperties = dataList
                .map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty)
                .toList();

            _totalCount = data['totalCount'] ?? 0;
            final pageSize = data['pageSize'] ?? _pageSize;
            _hasMoreData = newProperties.length == pageSize && (_currentPage * pageSize) < _totalCount;
          }
        } else {
          // Handle all properties response
          if (data is List) {
            // Direct array response
            final allPropertiesFromServer = data.map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty).toList();

            _totalCount = allPropertiesFromServer.length;

            // Calculate pagination manually for direct array response
            final startIndex = (_currentPage - 1) * _pageSize;
            final endIndex = startIndex + _pageSize;

            if (startIndex < allPropertiesFromServer.length) {
              newProperties = allPropertiesFromServer.sublist(
                  startIndex,
                  endIndex > allPropertiesFromServer.length ? allPropertiesFromServer.length : endIndex
              );
              _hasMoreData = endIndex < allPropertiesFromServer.length;
            } else {
              newProperties = [];
              _hasMoreData = false;
            }
          } else if (data is Map<String, dynamic> && data.containsKey('data')) {
            // Wrapped response
            final dataList = data['data'] as List;
            final allPropertiesFromServer = dataList.map((item) => _safeMapConversion(item))
                .where((item) => item.isNotEmpty).toList();

            _totalCount = data['totalCount'] ?? allPropertiesFromServer.length;

            // Calculate pagination manually
            final startIndex = (_currentPage - 1) * _pageSize;
            final endIndex = startIndex + _pageSize;

            if (startIndex < allPropertiesFromServer.length) {
              newProperties = allPropertiesFromServer.sublist(
                  startIndex,
                  endIndex > allPropertiesFromServer.length ? allPropertiesFromServer.length : endIndex
              );
              _hasMoreData = endIndex < allPropertiesFromServer.length;
            } else {
              newProperties = [];
              _hasMoreData = false;
            }
          }
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

        if (_searchQuery.isNotEmpty) {
          _applyLocalTextSearch();
        }

      } else {
        setState(() {
          _errorMessage = 'Failed to load properties. Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoadingProperties = false);
    }
  }

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
          'latitude': _safeNumericConversion(item['latitude'], 0),
          'longitude': _safeNumericConversion(item['longitude'], 0),
        };
      }
      return {};
    } catch (e) {
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

  Future<void> _loadMoreProperties() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      await _loadProperties();
    } catch (e) {
      _currentPage--;
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _applyLocalTextSearch() {
    if (_searchQuery.isEmpty) {
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
      _loadProperties(refresh: true);
    } else {
      _applyLocalTextSearch();
    }
  }

  void _applyFilters() {
    setState(() {
      _isFilterVisible = false;
      _currentPage = 1;
      _searchQuery = '';
    });
    _searchController.clear();
    _loadProperties(refresh: true);
  }

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
      _selectedPropertyType = 'Any';
      _selectedFloorType = 'Any Floor';
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
              _buildModernHeader(),
              if (_isFilterVisible)
                Expanded(
                  child: _buildAdvancedFilterPanel(),
                )
              else
                Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _selectedForComparison.isNotEmpty ? _buildComparisonFAB() : null,
    );
  }

  Widget _buildModernHeader() {
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
      child: Column(
        children: [
          // Top row with user info and actions
          Row(
            children: [
              // User avatar with initial
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    UserSession.getUserInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              // Welcome text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${UserSession.getDisplayName()}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Find your dream home (${_properties.length} of $_totalCount properties)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              _buildHeaderIconButton(
                icon: _isFilterVisible ? Icons.close : Icons.filter_list,
                onPressed: () => setState(() => _isFilterVisible = !_isFilterVisible),
                tooltip: 'Advanced Filters',
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                icon: Icons.refresh,
                onPressed: () => _loadProperties(refresh: true),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              _buildPopupMenu(),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar
          _buildModernSearchBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildPopupMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        color: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('My Requests', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('Profile', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search by type, location, area...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 24),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8)),
            onPressed: () {
              _searchController.clear();
              _performSearch('');
            },
          )
              : null,
        ),
        onChanged: _performSearch,
      ),
    );
  }

  Widget _buildAdvancedFilterPanel() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a237e),
            Color(0xFF234E70),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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
                  child: const Text(
                    'Reset All',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Section
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBlueDropdownFilter(
                          'City',
                          _selectedCity,
                          _availableCities,
                              (value) => setState(() => _selectedCity = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBlueDropdownFilter(
                          'Region',
                          _selectedRegion,
                          _availableRegions,
                              (value) => setState(() => _selectedRegion = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Property Type Section
                  const Text(
                    'Property Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBlueDropdownFilter(
                    'House Type',
                    _selectedPropertyType,
                    _propertyTypes,
                        (value) => setState(() => _selectedPropertyType = value!),
                  ),
                  const SizedBox(height: 20),

                  // Price Range Section
                  const Text(
                    'Price Range (LE)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000000,
                    divisions: 100,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                    labels: RangeLabels(
                      '${(_priceRange.start / 1000000).toStringAsFixed(1)}M LE',
                      '${(_priceRange.end / 1000000).toStringAsFixed(1)}M LE',
                    ),
                    onChanged: (values) => setState(() => _priceRange = values),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 LE',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      Text(
                        '10.0M LE',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Size Range Section
                  const Text(
                    'Size Range (m²)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RangeSlider(
                    values: _sizeRange,
                    min: 0,
                    max: 1000,
                    divisions: 100,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                    labels: RangeLabels(
                      '${_sizeRange.start.toStringAsFixed(0)} m²',
                      '${_sizeRange.end.toStringAsFixed(0)} m²',
                    ),
                    onChanged: (values) => setState(() => _sizeRange = values),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0 m²',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      Text(
                        '1000 m²',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Rooms Section
                  const Text(
                    'Rooms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Min Bedrooms',
                          _minBedrooms,
                              (value) => setState(() {
                            _minBedrooms = value;
                            if (_minBedrooms > _maxBedrooms) _maxBedrooms = _minBedrooms;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Max Bedrooms',
                          _maxBedrooms,
                              (value) => setState(() {
                            _maxBedrooms = value;
                            if (_maxBedrooms < _minBedrooms) _minBedrooms = _maxBedrooms;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Min Bathrooms',
                          _minBathrooms,
                              (value) => setState(() {
                            _minBathrooms = value;
                            if (_minBathrooms > _maxBathrooms) _maxBathrooms = _minBathrooms;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Max Bathrooms',
                          _maxBathrooms,
                              (value) => setState(() {
                            _maxBathrooms = value;
                            if (_maxBathrooms < _minBathrooms) _minBathrooms = _maxBathrooms;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Min Total Rooms',
                          _minTotalRooms,
                              (value) => setState(() {
                            _minTotalRooms = value;
                            if (_minTotalRooms > _maxTotalRooms) _maxTotalRooms = _minTotalRooms;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBlueNumberFilter(
                          'Max Total Rooms',
                          _maxTotalRooms,
                              (value) => setState(() {
                            _maxTotalRooms = value;
                            if (_maxTotalRooms < _minTotalRooms) _minTotalRooms = _maxTotalRooms;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Floor Type Section
                  const Text(
                    'Floor Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBlueDropdownFilter(
                    'Any Floor',
                    _selectedFloorType,
                    _floorTypes,
                        (value) => setState(() => _selectedFloorType = value!),
                  ),
                  const SizedBox(height: 20),

                  // Apply Filters button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildBlueDropdownFilter(
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
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              dropdownColor: const Color(0xFF234E70),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
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

  Widget _buildBlueNumberFilter(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              dropdownColor: const Color(0xFF234E70),
              items: List.generate(21, (index) => index).map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    value == 0 ? 'Any' : value.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
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

  Widget _buildBody() {
    if (_isLoadingProperties && _properties.isEmpty) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_properties.isEmpty) {
      return _buildEmptyState();
    }

    return _buildPropertyList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading properties...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProperties(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
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
    final hasActiveFilters = _selectedCity != 'Any' ||
        _selectedRegion != 'Any' ||
        _selectedPropertyType != 'Any' ||
        _selectedFloorType != 'Any Floor' ||
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
        _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(
                hasActiveFilters ? Icons.filter_list_off : Icons.home_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters ? 'No properties match your filters' : 'No properties available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Try adjusting your filters to see more results'
                  : 'Check back later for new listings',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasActiveFilters)
              ElevatedButton(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Clear All Filters', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList() {
    return RefreshIndicator(
      onRefresh: () => _loadProperties(refresh: true),
      color: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: _properties.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _properties.length) {
            final property = _properties[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildBluePropertyCard(property),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      'Loading more properties...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildBluePropertyCard(Map<String, dynamic> property) {
    final propertyId = property['id'];
    final isSelected = _selectedForComparison.contains(propertyId.toString());

    return GestureDetector(
      onTap: () => _handlePropertyTap(property),
      onLongPress: () => _handlePropertyLongPress(property),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Image section
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

                // Property type badge (top-left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      property['houseType'] ?? 'Property',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // High floor badge (top-right)
                if (property['isHighFloor'] == true)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'High Floor',
                        style: TextStyle(
                          color: Color(0xFF234E70),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Selection indicator
                if (isSelected)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_selectedForComparison.toList().indexOf(propertyId.toString()) + 1}',
                          style: const TextStyle(
                            color: Color(0xFF234E70),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price (prominent display)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${property['price'] ?? 0} LE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (property['pricePerM2'] != null && property['pricePerM2'] > 0)
                        Text(
                          '${property['pricePerM2']} LE/m²',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
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
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Property features
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBlueFeature(
                        Icons.straighten,
                        '${property['size'] ?? 0} m²',
                      ),
                      _buildBlueFeature(
                        Icons.king_bed,
                        '${property['bedrooms'] ?? 0} Beds',
                      ),
                      _buildBlueFeature(
                        Icons.bathtub,
                        '${property['bathrooms'] ?? 0} Baths',
                      ),
                      if (property['totalRooms'] != null && property['totalRooms'] > 0)
                        _buildBlueFeature(
                          Icons.room,
                          '${property['totalRooms']} Total',
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

  Widget _buildBlueFeature(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildPropertyImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty || !ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        color: Colors.white.withOpacity(0.1),
        child: Center(
          child: Icon(Icons.home, size: 50, color: Colors.white.withOpacity(0.5)),
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
          color: Colors.white.withOpacity(0.1),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.white.withOpacity(0.1),
          child: Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.white.withOpacity(0.5)),
          ),
        );
      },
    );
  }

  Widget _buildComparisonFAB() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          onPressed: _clearSelection,
          backgroundColor: Colors.white.withOpacity(0.2),
          heroTag: "clear",
          label: const Text('Clear', style: TextStyle(color: Colors.white)),
          icon: const Icon(Icons.clear, color: Colors.white),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.extended(
          onPressed: _startComparison,
          backgroundColor: Colors.white.withOpacity(0.3),
          heroTag: "compare",
          label: Text(
            'Compare (${_selectedForComparison.length})',
            style: const TextStyle(color: Colors.white),
          ),
          icon: const Icon(Icons.compare_arrows, color: Colors.white),
        ),
      ],
    );
  }

  Widget? _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a237e),
            Color(0xFF234E70),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        elevation: 0,
        currentIndex: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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