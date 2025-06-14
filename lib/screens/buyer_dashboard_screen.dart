// lib/screens/buyer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'property_details_screen.dart';
import 'property_comparison_screen.dart';
import 'favorites_screen.dart';
import 'map_screen.dart';
import 'user_profile_screen.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'login_screen.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  // Filter values
  RangeValues _priceRange = const RangeValues(0, 1000000);
  int _minBedrooms = 0;
  int _maxBedrooms = 10;
  String _city = '';
  String _region = '';
  bool _isFilterVisible = false;
  final Set<String> _selectedForComparison = {};
  bool _isSelectionMode = false;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Data and loading states
  List<Map<String, dynamic>> _allProperties = [];
  List<Map<String, dynamic>> _filteredProperties = [];
  bool _isLoadingProperties = false;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalCount = 0;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get responsive values based on screen size
  bool get isMobile => MediaQuery.of(context).size.width < mobileBreakpoint;
  bool get isTablet => MediaQuery.of(context).size.width >= mobileBreakpoint && MediaQuery.of(context).size.width < tabletBreakpoint;
  bool get isDesktop => MediaQuery.of(context).size.width >= tabletBreakpoint;

  double get horizontalPadding {
    if (isDesktop) return 40;
    if (isTablet) return 24;
    return 16;
  }

  double get verticalPadding {
    if (isDesktop) return 32;
    if (isTablet) return 20;
    return 16;
  }

  int get crossAxisCount {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return 3;
    if (width >= tabletBreakpoint) return 2;
    return 1;
  }

  double get cardAspectRatio {
    if (isDesktop) return 0.75;
    if (isTablet) return 0.8;
    return 0.85;
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoadingProperties = true);

    try {
      // Build query parameters for search endpoint
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      if (_city.isNotEmpty) {
        queryParams['city'] = _city;
      }
      if (_region.isNotEmpty) {
        queryParams['region'] = _region;
      }
      if (_priceRange.start > 0) {
        queryParams['minPrice'] = _priceRange.start.toString();
      }
      if (_priceRange.end < 1000000) {
        queryParams['maxPrice'] = _priceRange.end.toString();
      }
      if (_minBedrooms > 0) {
        queryParams['minBedrooms'] = _minBedrooms.toString();
      }
      if (_maxBedrooms < 10) {
        queryParams['maxBedrooms'] = _maxBedrooms.toString();
      }

      final uri = Uri.parse(ApiConfig.searchPropertiesUrl).replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allProperties = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _totalCount = data['totalCount'] ?? 0;
          _applyLocalSearch();
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

  void _applyLocalSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredProperties = _allProperties;
      });
    } else {
      setState(() {
        _filteredProperties = _allProperties.where((property) {
          final houseType = (property['houseType'] ?? '').toString().toLowerCase();
          final city = (property['city'] ?? '').toString().toLowerCase();
          final region = (property['region'] ?? '').toString().toLowerCase();
          final searchLower = _searchQuery.toLowerCase();

          return houseType.contains(searchLower) ||
              city.contains(searchLower) ||
              region.contains(searchLower);
        }).toList();
      });
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyLocalSearch();
    });
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
      _isFilterVisible = false;
    });
    _loadProperties();
  }

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 1000000);
      _minBedrooms = 0;
      _maxBedrooms = 10;
      _city = '';
      _region = '';
      _searchQuery = '';
      _currentPage = 1;
    });
    _searchController.clear();
    _loadProperties();
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

  void _clearSelection() {
    setState(() {
      _selectedForComparison.clear();
      _isSelectionMode = false;
    });
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
      floatingActionButton: _buildFloatingActionButtons(),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
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
                radius: isMobile ? 20 : 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  UserSession.getUserInitials(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${UserSession.getCurrentUserName()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Find your dream home (${_filteredProperties.length} properties)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ..._buildDesktopActions(),
              if (!isDesktop) ..._buildMobileActions(),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopActions() {
    return [
      IconButton(
        icon: Icon(
          _isFilterVisible ? Icons.close : Icons.filter_list,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () {
          setState(() {
            _isFilterVisible = !_isFilterVisible;
          });
        },
        tooltip: 'Filters',
      ),
      IconButton(
        icon: const Icon(Icons.favorite, color: Colors.white, size: 24),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FavoritesScreen()),
        ),
        tooltip: 'Favorites',
      ),
      IconButton(
        icon: const Icon(Icons.map, color: Colors.white, size: 24),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        ),
        tooltip: 'Map View',
      ),
      IconButton(
        icon: const Icon(Icons.person, color: Colors.white, size: 24),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
        ),
        tooltip: 'Profile',
      ),
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
        onPressed: _loadProperties,
        tooltip: 'Refresh',
      ),
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.white, size: 24),
        onPressed: _handleLogout,
        tooltip: 'Logout',
      ),
    ];
  }

  List<Widget> _buildMobileActions() {
    return [
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
        onPressed: _loadProperties,
        tooltip: 'Refresh',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        color: const Color(0xFF234E70),
        onSelected: (value) {
          switch (value) {
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
            value: 'profile',
            child: Text('Profile', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuItem(
            value: 'logout',
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ];
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 25 : 30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 14 : 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search by location, property type...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: isMobile ? 14 : 16,
          ),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.5),
            size: isMobile ? 20 : 24,
          ),
        ),
        onChanged: _performSearch,
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 18,
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
          SizedBox(height: isMobile ? 12 : 16),

          // Location filters
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: _buildLocationFilter('City', _city, (value) {
                    setState(() => _city = value);
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationFilter('Region', _region, (value) {
                    setState(() => _region = value);
                  }),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildLocationFilter('City', _city, (value) {
                  setState(() => _city = value);
                }),
                const SizedBox(height: 16),
                _buildLocationFilter('Region', _region, (value) {
                  setState(() => _region = value);
                }),
              ],
            ),
          SizedBox(height: isMobile ? 12 : 16),

          Text(
            'Price Range',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 16,
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
          SizedBox(height: isMobile ? 12 : 16),

          if (isDesktop)
            Row(
              children: [
                Expanded(child: _buildBedroomDropdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildMaxBedroomDropdown()),
              ],
            )
          else
            Column(
              children: [
                _buildBedroomDropdown(),
                const SizedBox(height: 16),
                _buildMaxBedroomDropdown(),
              ],
            ),

          SizedBox(height: isMobile ? 16 : 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
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
            fontSize: isMobile ? 12 : 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
          ),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: isMobile ? 14 : 16,
            ),
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

  Widget _buildBedroomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Min Bedrooms',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<int>(
          value: _minBedrooms,
          isExpanded: true,
          dropdownColor: const Color(0xFF234E70),
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
          ),
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
                _minBedrooms = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildMaxBedroomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Max Bedrooms',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<int>(
          value: _maxBedrooms,
          isExpanded: true,
          dropdownColor: const Color(0xFF234E70),
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
          ),
          items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
              .map((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(value == 10 ? 'Any' : value.toString()),
            );
          }).toList(),
          onChanged: (int? value) {
            if (value != null) {
              setState(() {
                _maxBedrooms = value;
              });
            }
          },
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
              onPressed: _loadProperties,
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
    if (isDesktop || isTablet) {
      return Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: cardAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredProperties.length,
          itemBuilder: (context, index) {
            final property = _filteredProperties[index];
            return _buildPropertyCard(property);
          },
        ),
      );
    } else {
      return ListView.builder(
        padding: EdgeInsets.all(horizontalPadding),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          final property = _filteredProperties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPropertyCard(property),
          );
        },
      );
    }
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
                  height: isDesktop ? 180 : (isTablet ? 160 : 200),
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            property['houseType'] ?? 'Property',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 14,
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
                            '${property['city'] ?? ''}, ${property['region'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${property['price'] ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (property['pricePerM2'] != null)
                              Text(
                                '\$${property['pricePerM2']} per m²',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: isMobile ? 10 : 12,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: isMobile ? 14 : 16,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: isMobile ? 11 : 14,
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

  Widget? _buildFloatingActionButtons() {
    if (_selectedForComparison.isEmpty) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMobile) ...[
          FloatingActionButton(
            onPressed: _clearSelection,
            backgroundColor: Colors.grey.withOpacity(0.8),
            heroTag: "clear",
            mini: true,
            child: const Icon(Icons.clear, color: Colors.white),
          ),
          const SizedBox(height: 8),
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
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _clearSelection,
                backgroundColor: Colors.grey.withOpacity(0.8),
                heroTag: "clear",
                child: const Icon(Icons.clear, color: Colors.white),
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
          ),
        ],
      ],
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (isDesktop) return null;

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