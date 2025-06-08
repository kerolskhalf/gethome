// lib/screens/seller_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'add_property_screen.dart';
import 'property_details_screen_seller.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'login_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  // User ID from authentication
  int get currentUserId => UserSession.getCurrentUserId();

  // Data and loading states
  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🏠 Seller Dashboard Initialized');
    print('👤 Current User ID: $currentUserId');
    print('👤 Current User Name: ${UserSession.getCurrentUserName()}');
    print('👤 Current User Role: ${UserSession.getCurrentUserRole()}');
    _loadUserProperties();
  }

  // Load user's properties from API with fallback endpoints
  Future<void> _loadUserProperties() async {
    print('🔄 Loading properties for user: $currentUserId');
    setState(() => _isLoading = true);

    // Try multiple possible endpoints
    final endpoints = [
      ApiConfig.userPropertiesUrl(currentUserId),
      ApiConfig.userPropertiesUrlAlt1(currentUserId),
      ApiConfig.userPropertiesUrlAlt2(currentUserId),
      ApiConfig.userPropertiesUrlAlt3(currentUserId),
    ];

    for (int i = 0; i < endpoints.length; i++) {
      try {
        final endpoint = endpoints[i];
        print('📡 Trying endpoint ${i + 1}: $endpoint');

        final response = await http.get(
          Uri.parse(endpoint),
          headers: ApiConfig.headers,
        );

        print('📡 Response Status: ${response.statusCode}');
        print('📡 Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ API Response successful from endpoint ${i + 1}');
          print('📊 Raw data: $data');

          // Handle different possible response formats
          List<dynamic> propertiesData = [];

          if (data is Map<String, dynamic>) {
            // Try different possible keys for the properties array
            if (data.containsKey('data')) {
              propertiesData = data['data'] ?? [];
            } else if (data.containsKey('properties')) {
              propertiesData = data['properties'] ?? [];
            } else if (data.containsKey('items')) {
              propertiesData = data['items'] ?? [];
            } else if (data.containsKey('result')) {
              propertiesData = data['result'] ?? [];
            } else if (data.containsKey('content')) {
              propertiesData = data['content'] ?? [];
            } else {
              // Maybe the response is directly the array in some field
              for (final value in data.values) {
                if (value is List) {
                  propertiesData = value;
                  break;
                }
              }

              // If still empty, maybe it's a single property object
              if (propertiesData.isEmpty && data.isNotEmpty) {
                // Check if this looks like a single property
                if (data.containsKey('id') || data.containsKey('houseType') || data.containsKey('price')) {
                  propertiesData = [data];
                }
              }
            }
          } else if (data is List) {
            // Response is directly an array
            propertiesData = data;
          }

          print('📝 Extracted properties data: $propertiesData');
          print('📊 Properties count: ${propertiesData.length}');

          setState(() {
            _properties = List<Map<String, dynamic>>.from(propertiesData);
            _errorMessage = null;
          });

          print('✅ Properties loaded: ${_properties.length} items');
          if (_properties.isNotEmpty) {
            print('📝 First property sample: ${_properties.first}');
          }

          setState(() => _isLoading = false);
          return; // Success, exit the loop

        } else if (response.statusCode == 404) {
          // User has no properties yet - this is normal
          print('ℹ️ No properties found for user (404) - trying next endpoint...');
          continue; // Try next endpoint
        } else if (response.statusCode == 401) {
          setState(() {
            _errorMessage = 'Authentication failed. Please login again.';
            _isLoading = false;
          });
          print('❌ Authentication error (401)');
          return;
        } else {
          print('❌ API Error from endpoint ${i + 1}: ${response.statusCode} - ${response.body}');
          continue; // Try next endpoint
        }
      } catch (e) {
        print('❌ Network Error from endpoint ${i + 1}: $e');
        continue; // Try next endpoint
      }
    }

    // If we get here, all endpoints failed
    setState(() {
      _properties = [];
      _errorMessage = 'Could not load properties. Please check your connection and try again.';
      _isLoading = false;
    });
    print('❌ All endpoints failed');
  }

  void _addNewProperty() async {
    print('➕ Adding new property');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnhancedAddPropertyScreen()),
    );

    if (result == true && mounted) {
      print('✅ Property added successfully, refreshing list');
      // Show loading immediately
      setState(() => _isLoading = true);

      // Add a small delay to ensure server has processed the new property
      await Future.delayed(const Duration(seconds: 1));

      // Force refresh after successful addition
      await _loadUserProperties();
    } else if (mounted) {
      print('ℹ️ Returned from add property screen without success');
      // Still refresh to be safe
      await _loadUserProperties();
    }
  }

  // Force refresh method
  Future<void> _forceRefresh() async {
    print('🔄 Force refresh triggered');
    setState(() => _isLoading = true);

    // Clear current properties to show loading state
    setState(() => _properties = []);

    // Add a small delay to ensure any server-side processing is complete
    await Future.delayed(const Duration(milliseconds: 500));

    await _loadUserProperties();
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

  void _editProperty(int index, Map<String, dynamic> updatedProperty) {
    setState(() {
      _properties[index] = updatedProperty;
    });
    _loadUserProperties();
  }

  Future<void> _deleteProperty(int propertyId, int index) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deletePropertyUrl(propertyId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          _properties.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete property: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting property: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteProperty(int propertyId, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Delete Property',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this property? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
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
              Navigator.pop(context);
              _deleteProperty(propertyId, index);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPropertyDetails(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyDetailsScreenSeller(
          property: _properties[index],
          onEdit: (updatedProperty) => _editProperty(index, updatedProperty),
          onDelete: () => _confirmDeleteProperty(
              _properties[index]['id'],
              index
          ),
        ),
      ),
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0:
        return 'Available';
      case 1:
        return 'Sold';
      case 2:
        return 'Rented';
      case 3:
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.red;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading your properties...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorState()
              else ...[
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildAddPropertyButton(),
                  ),
                  Expanded(
                    child: _properties.isEmpty
                        ? _buildEmptyState()
                        : _buildPropertiesList(),
                  ),
                ],
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _forceRefresh,
            backgroundColor: Colors.orange.withOpacity(0.8),
            heroTag: "refresh",
            tooltip: 'Force Refresh Properties',
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: _addNewProperty,
            backgroundColor: Colors.blue.withOpacity(0.8),
            heroTag: "add",
            label: const Text('Add Property', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              UserSession.getUserInitials(),
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
                  'Welcome, ${UserSession.getDisplayName()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your ${_properties.length} properties',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              _loadUserProperties();
            },
            tooltip: 'Refresh Properties',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildAddPropertyButton() {
    return GestureDetector(
      onTap: _addNewProperty,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_home_work,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Add New Property',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Expanded(
      child: Center(
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
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'User ID: $currentUserId',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                print('🔄 Retry button pressed');
                _forceRefresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No properties listed yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Property" to add your first property',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Debug information
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  'Debug Info',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'User ID: $currentUserId',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  'API: ${ApiConfig.userPropertiesUrl(currentUserId)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Manual refresh button
          ElevatedButton.icon(
            onPressed: () {
              print('🔄 Manual refresh triggered from empty state');
              _forceRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Force Refresh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        final property = _properties[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
            onTap: () => _navigateToPropertyDetails(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Property Image
                  Stack(
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: property['imagePath'] != null &&
                            property['imagePath'].isNotEmpty
                            ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.file(
                            File(property['imagePath']),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                            : const Center(
                          child: Icon(Icons.home,
                              size: 50, color: Colors.grey),
                        ),
                      ),
                      // Status badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(property['status'] ?? 0)
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(property['status'] ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Property Details
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
                                property['houseType'] ?? property['propertyType'] ?? 'Property',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
                        if (property['city'] != null || property['region'] != null)
                          Text(
                            '${property['city'] ?? ''}, ${property['region'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPropertyFeature(
                              Icons.straighten,
                              '${property['size'] ?? 0} m²',
                            ),
                            const SizedBox(width: 16),
                            _buildPropertyFeature(
                              Icons.king_bed,
                              '${property['bedrooms'] ?? 0} Beds',
                            ),
                            const SizedBox(width: 16),
                            _buildPropertyFeature(
                              Icons.bathtub,
                              '${property['bathrooms'] ?? 0} Baths',
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
                            Row(
                              children: [
                                _buildActionButton(
                                  Icons.edit,
                                  'Edit',
                                  onTap: () => _navigateToPropertyDetails(index),
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  Icons.delete,
                                  'Delete',
                                  onTap: () => _confirmDeleteProperty(
                                      property['id'],
                                      index
                                  ),
                                ),
                              ],
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
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}