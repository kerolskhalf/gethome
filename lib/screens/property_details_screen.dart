// lib/screens/property_details_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool _isSaved = false;
  bool _isLoadingContact = false;
  bool _isCreatingViewingRequest = false;
  bool _isTogglingFavorite = false;
  Map<String, dynamic>? _contactInfo;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  // FIX: Enhanced favorite status checking
  Future<void> _checkIfFavorite() async {
    try {
      final userId = UserSession.getCurrentUserId();
      if (userId <= 0) return;

      print('🔍 Checking favorite status for property ${widget.property['id']}');

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/favorites/user/$userId?page=1&pageSize=100'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> favorites = [];

        if (data is List) {
          favorites = data;
        } else if (data is Map<String, dynamic> && data.containsKey('data')) {
          favorites = data['data'] ?? [];
        }

        setState(() {
          _isSaved = favorites.any((fav) {
            // Check both direct propertyId and nested property.id
            return fav['propertyId'] == widget.property['id'] ||
                (fav['property'] != null && fav['property']['id'] == widget.property['id']);
          });
        });

        print('✅ Favorite status: $_isSaved');
      }
    } catch (e) {
      print('❌ Error checking favorite status: $e');
    }
  }

  // FIX: Enhanced favorites toggle with proper error handling
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    setState(() => _isTogglingFavorite = true);

    try {
      final userId = UserSession.getCurrentUserId();
      final propertyId = widget.property['id'];

      // Use the toggle endpoint with query parameters
      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/favorites/toggle').replace(
        queryParameters: {
          'userId': userId.toString(),
          'propertyId': propertyId.toString(),
        },
      );

      print('💖 Toggling favorite: $uri');

      final response = await http.post(uri, headers: ApiConfig.headers);

      print('📡 Favorites toggle response: ${response.statusCode}');
      print('📋 Favorites toggle body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _isSaved = !_isSaved;
        });
        _showSuccessMessage(_isSaved ? 'Added to favorites' : 'Removed from favorites');
      } else {
        _showErrorMessage('Failed to update favorites');
      }
    } catch (e) {
      _showErrorMessage('Error updating favorites: $e');
    } finally {
      setState(() => _isTogglingFavorite = false);
    }
  }

  // FIX: Enhanced viewing request creation
  Future<void> _createViewingRequest() async {
    final selectedDateTime = await _showDateTimePicker();
    if (selectedDateTime == null) return;

    final propertyId = widget.property['id'];
    final userId = UserSession.getCurrentUserId();

    if (propertyId == null || userId <= 0) {
      _showErrorMessage('Unable to create viewing request');
      return;
    }

    setState(() => _isCreatingViewingRequest = true);

    try {
      final requestBody = {
        'propertyId': propertyId,
        'userId': userId,
        'requestedDateTime': selectedDateTime.toUtc().toIso8601String(),
        'message': 'Viewing request for ${widget.property['houseType']} in ${widget.property['city']}',
      };

      print('📅 Creating viewing request: $requestBody');

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/create'),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );

      print('📡 Viewing request response: ${response.statusCode}');
      print('📋 Viewing request body: ${response.body}');

      setState(() => _isCreatingViewingRequest = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showSuccessMessage(data['message'] ?? 'Viewing request created successfully for ${_formatDateTime(selectedDateTime)}');
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          _showErrorMessage(errorData['message'] ?? 'Failed to create viewing request');
        } catch (e) {
          _showErrorMessage('You may already have a pending request for this property');
        }
      } else {
        _showErrorMessage('Failed to create viewing request');
      }
    } catch (e) {
      setState(() => _isCreatingViewingRequest = false);
      if (mounted) {
        _showErrorMessage('Network error. Please try again.');
      }
    }
  }

  // Enhanced contact information retrieval
  Future<void> _getSellerContact() async {
    final propertyId = widget.property['id'];
    if (propertyId == null) {
      _showErrorMessage('Property ID is missing');
      return;
    }

    setState(() => _isLoadingContact = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/$propertyId/contact'),
        headers: ApiConfig.headers,
      );

      setState(() => _isLoadingContact = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final contactData = data['data'] ?? data;
          setState(() {
            _contactInfo = contactData;
          });
          _showContactDialog(contactData);
        } catch (e) {
          _showErrorMessage('Failed to parse contact information');
        }
      } else if (response.statusCode == 404) {
        _showErrorMessage('Contact information not available for this property');
      } else {
        _showErrorMessage('Failed to get contact information');
      }
    } catch (e) {
      setState(() => _isLoadingContact = false);
      if (mounted) {
        _showErrorMessage('Network error. Please check your connection.');
      }
    }
  }

  // Date/time picker for viewing requests
  Future<DateTime?> _showDateTimePicker() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Select viewing date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF234E70),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return null;

    if (!mounted) return null;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select viewing time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF234E70),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return null;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month $day at $hour:$minute';
  }

  void _showContactDialog(Map<String, dynamic> contactData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Seller Contact Information',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contactData['sellerPhoneNumber'] != null)
              _buildContactOption(
                Icons.phone,
                'Phone Number',
                contactData['sellerPhoneNumber'].toString(),
                onTap: () => _initiateCall(contactData['sellerPhoneNumber'].toString()),
              ),
            if (contactData['sellerPhoneNumber'] != null)
              const SizedBox(height: 16),
            if (contactData['sellerEmail'] != null)
              _buildContactOption(
                Icons.email,
                'Email',
                contactData['sellerEmail'].toString(),
                onTap: () => _initiateEmail(contactData['sellerEmail'].toString()),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? (() {
        _showSuccessMessage('$title copied to clipboard');
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _initiateCall(String phoneNumber) {
    Navigator.pop(context);
    _showSuccessMessage('Opening phone app to call $phoneNumber');
  }

  void _initiateEmail(String email) {
    Navigator.pop(context);
    _showSuccessMessage('Opening email app for $email');
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getStatusText(dynamic status) {
    if (status == 0 || status == 'Available') return 'Available';
    if (status == 1 || status == 'NotAvailable') return 'Not Available';
    return 'Unknown';
  }

  Color _getStatusColor(dynamic status) {
    if (status == 0 || status == 'Available') return Colors.green;
    if (status == 1 || status == 'NotAvailable') return Colors.red;
    return Colors.grey;
  }

  Widget _buildPropertyImage() {
    final imagePath = widget.property['imagePath'];

    if (!ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.home, size: 100, color: Colors.grey),
        ),
      );
    }

    final imageUrl = ApiConfig.getImageUrl(imagePath);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
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
            child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
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
          ),

          // Main content
          CustomScrollView(
            slivers: [
              // App Bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildPropertyImage(),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: _isTogglingFavorite
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(_isSaved ? Icons.favorite : Icons.favorite_border),
                    onPressed: _isTogglingFavorite ? null : _toggleFavorite,
                  ),
                ],
              ),

              // Property details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title, price and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.property['houseType'] ?? 'Property',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Property ID: ${widget.property['id']}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(widget.property['status'])
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(widget.property['status']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${widget.property['price'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.property['pricePerM2'] != null && widget.property['pricePerM2'] > 0)
                                Text(
                                  '\$${widget.property['pricePerM2']} per m²',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
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
                              '${widget.property['city'] ?? ''}, ${widget.property['region'] ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // High Floor indicator
                      if (widget.property['isHighFloor'] == true) ...[
                        const SizedBox(height: 8),
                        Row(
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
                                color: Colors.blue.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Property features
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildFeature(
                                  Icons.straighten,
                                  'Size',
                                  '${widget.property['size'] ?? 0} m²',
                                ),
                                _buildFeature(
                                  Icons.king_bed,
                                  'Bedrooms',
                                  '${widget.property['bedrooms'] ?? 0}',
                                ),
                                _buildFeature(
                                  Icons.bathtub,
                                  'Bathrooms',
                                  '${widget.property['bathrooms'] ?? 0}',
                                ),
                              ],
                            ),
                            if (widget.property['totalRooms'] != null && widget.property['totalRooms'] > 0) ...[
                              const SizedBox(height: 16),
                              _buildFeature(
                                Icons.room,
                                'Total Rooms',
                                '${widget.property['totalRooms']}',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Schedule Viewing',
                              Icons.calendar_today,
                              _isCreatingViewingRequest ? null : _createViewingRequest,
                              isLoading: _isCreatingViewingRequest,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'Contact Seller',
                              Icons.message,
                              _isLoadingContact ? null : _getSellerContact,
                              isLoading: _isLoadingContact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onTap, {bool isLoading = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}