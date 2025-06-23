// lib/screens/property_details_screen.dart - COMPLETE FILE WITH COORDINATE FIX

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> with TickerProviderStateMixin {
  bool _isSaved = false;
  bool _isLoadingContact = false;
  bool _isCreatingViewingRequest = false;
  bool _isTogglingFavorite = false;
  bool _isCheckingFavorite = true;
  bool _isLoadingFullProperty = true;
  Map<String, dynamic>? _contactInfo;
  Map<String, dynamic> _fullPropertyData = {};

  // Image carousel variables
  late PageController _pageController;
  int _currentImageIndex = 0;
  List<Map<String, dynamic>> _allImages = []; // Store images with URLs

  late AnimationController _favoriteAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fullPropertyData = Map.from(widget.property);
    _initializeAnimations();
    _loadFullPropertyDetails();
    _checkIfFavorite();
  }

  @override
  void dispose() {
    _favoriteAnimationController.dispose();
    _fadeAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _favoriteScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _favoriteAnimationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController.forward();
  }

  // Load complete property details with images
  Future<void> _loadFullPropertyDetails() async {
    setState(() => _isLoadingFullProperty = true);

    try {
      final propertyId = widget.property['id'];
      print('🔄 Loading full property details for ID: $propertyId');

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/$propertyId'),
        headers: ApiConfig.headers,
      );

      print('📡 Property details response: ${response.statusCode}');
      print('📋 Property details body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        Map<String, dynamic> propertyData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            propertyData = data['data'] as Map<String, dynamic>;
          } else {
            propertyData = data;
          }
        } else {
          propertyData = widget.property;
        }

        setState(() {
          _fullPropertyData = propertyData;
          _isLoadingFullProperty = false;
        });

        _loadAllImages();
      } else {
        print('❌ Failed to load property details: ${response.statusCode}');
        setState(() => _isLoadingFullProperty = false);
        _loadAllImages();
      }
    } catch (e) {
      print('❌ Error loading property details: $e');
      setState(() => _isLoadingFullProperty = false);
      _loadAllImages();
    }
  }

  // Load all images method
  void _loadAllImages() {
    _allImages.clear();

    print('🖼️ Loading images for property: ${_fullPropertyData['id']}');

    // Load cover image first
    String? coverImageUrl;
    if (_fullPropertyData['Coverimage'] != null) {
      coverImageUrl = _fullPropertyData['Coverimage'].toString();
    } else if (_fullPropertyData['imagePath'] != null) {
      final coverImagePath = _fullPropertyData['imagePath'].toString();
      if (ApiConfig.isValidImagePath(coverImagePath)) {
        coverImageUrl = ApiConfig.getImageUrl(coverImagePath);
      }
    }

    // Add cover image
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      _allImages.add({
        'id': null,
        'url': coverImageUrl,
        'isCover': true,
      });
    }

    // Load additional images
    final images = _fullPropertyData['Images'] ?? _fullPropertyData['images'] ?? [];
    if (images is List) {
      for (var image in images) {
        String? imageUrl;

        if (image is Map) {
          // Handle image object format
          final imagePath = image['imagePath'] ?? image['ImagePath'];
          if (imagePath != null && ApiConfig.isValidImagePath(imagePath.toString())) {
            imageUrl = ApiConfig.getImageUrl(imagePath.toString());
          }
        } else if (image is String) {
          // Handle direct string format
          if (ApiConfig.isValidImagePath(image)) {
            imageUrl = ApiConfig.getImageUrl(image);
          }
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          _allImages.add({
            'id': image is Map ? image['id'] : null,
            'url': imageUrl,
            'isCover': false,
          });
        }
      }
    }

    // If no images found, add a placeholder
    if (_allImages.isEmpty) {
      _allImages.add({
        'id': null,
        'url': 'placeholder',
        'isCover': true,
      });
    }

    print('📸 Total images loaded: ${_allImages.length}');
    setState(() {});
  }

  // Check if property is in favorites
  Future<void> _checkIfFavorite() async {
    setState(() => _isCheckingFavorite = true);

    try {
      final userId = UserSession.getCurrentUserId();
      if (userId <= 0) {
        setState(() {
          _isCheckingFavorite = false;
          _isSaved = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/favorites/user/$userId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List favorites = data is List ? data : (data['data'] ?? []);

        setState(() {
          _isSaved = favorites.any((fav) =>
          (fav['propertyId'] ?? fav['id']) == widget.property['id']
          );
          _isCheckingFavorite = false;
        });
      } else {
        setState(() {
          _isCheckingFavorite = false;
          _isSaved = false;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
      setState(() {
        _isCheckingFavorite = false;
        _isSaved = false;
      });
    }
  }

  // Toggle favorite status
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    final userId = UserSession.getCurrentUserId();
    if (userId <= 0) {
      _showErrorMessage('Please log in to save favorites');
      return;
    }

    setState(() => _isTogglingFavorite = true);

    try {
      if (_isSaved) {
        // Remove from favorites
        final response = await http.delete(
          Uri.parse('${ApiConfig.BASE_URL}/api/favorites'),
          headers: ApiConfig.headers,
          body: json.encode({
            'userId': userId,
            'propertyId': widget.property['id'],
          }),
        );

        if (response.statusCode == 200) {
          setState(() => _isSaved = false);
          _favoriteAnimationController.reverse();
          _showSuccessMessage('Removed from favorites');
        }
      } else {
        // Add to favorites
        final response = await http.post(
          Uri.parse('${ApiConfig.BASE_URL}/api/favorites'),
          headers: ApiConfig.headers,
          body: json.encode({
            'userId': userId,
            'propertyId': widget.property['id'],
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() => _isSaved = true);
          _favoriteAnimationController.forward();
          _showSuccessMessage('Added to favorites');
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      _showErrorMessage('Failed to update favorites');
    } finally {
      setState(() => _isTogglingFavorite = false);
    }
  }

  // FIXED: Open location on map using coordinates first, then region fallback
  void _openLocationOnMap() async {
    try {
      // Check if we have latitude and longitude coordinates first
      final latitude = widget.property['latitude'];
      final longitude = widget.property['longitude'];

      String googleMapsUrl;

      if (latitude != null && longitude != null &&
          latitude != 0 && longitude != 0) {
        // Use precise coordinates if available
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        print('Opening map with coordinates: $latitude, $longitude');
      } else {
        // Fallback to region-based search only if coordinates are not available
        final city = widget.property['city'] ?? '';
        final region = widget.property['region'] ?? '';
        final address = widget.property['address'] ?? '';

        // Create search query for the location
        String locationQuery = '';
        if (address.isNotEmpty) {
          locationQuery = address;
        } else if (city.isNotEmpty && region.isNotEmpty) {
          locationQuery = '$city, $region';
        } else if (city.isNotEmpty) {
          locationQuery = city;
        } else {
          _showErrorMessage('Location information not available');
          return;
        }

        // Encode the query for URL
        final encodedQuery = Uri.encodeComponent(locationQuery);
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
        print('Opening map with location search: $locationQuery');
      }

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Enhanced fallback with coordinates if available
        String fallbackUrl;
        if (latitude != null && longitude != null &&
            latitude != 0 && longitude != 0) {
          fallbackUrl = 'https://maps.google.com/?q=$latitude,$longitude';
        } else {
          final city = widget.property['city'] ?? '';
          final region = widget.property['region'] ?? '';
          final locationQuery = city.isNotEmpty && region.isNotEmpty
              ? '$city, $region'
              : city.isNotEmpty ? city : region;
          final encodedQuery = Uri.encodeComponent(locationQuery);
          fallbackUrl = 'https://maps.google.com/?q=$encodedQuery';
        }

        if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
          await launchUrl(
            Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          _showErrorMessage('Unable to open maps application');
        }
      }
    } catch (e) {
      print('Error opening map: $e');
      _showErrorMessage('Error opening map: ${e.toString()}');
    }
  }

  // Create viewing request
  Future<void> _createViewingRequest(DateTime dateTime) async {
    setState(() => _isCreatingViewingRequest = true);

    try {
      final userId = UserSession.getCurrentUserId();
      if (userId <= 0) {
        _showErrorMessage('Please log in to request a viewing');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests'),
        headers: ApiConfig.headers,
        body: json.encode({
          'PropertyId': widget.property['id'],
          'BuyerId': userId,
          'RequestedDateTime': dateTime.toIso8601String(),
          'Status': 0, // Pending
        }),
      );

      setState(() => _isCreatingViewingRequest = false);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        _showSuccessMessage(
          'Viewing request sent!',
          'Your viewing request has been sent for ${_formatDateTime(dateTime)}. The seller will contact you soon.',
        );
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

  // Get seller contact information
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

  // Show date/time picker for viewing request
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

  // Format date time for display
  String _formatDateTime(DateTime dateTime) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final dayName = days[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$dayName, $month ${dateTime.day} at $hour:$minute';
  }

  // Show contact dialog
  void _showContactDialog(Map<String, dynamic> contactData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Seller Contact Information',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactItem(Icons.person, 'Name', contactData['name'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildContactItem(Icons.email, 'Email', contactData['email'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildContactItem(Icons.phone, 'Phone', contactData['phone'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show success message
  void _showSuccessMessage(String title, [String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (message != null) Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoadingFullProperty
                      ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageCarousel(),
                        const SizedBox(height: 24),
                        _buildPropertyHeader(),
                        const SizedBox(height: 24),
                        _buildPropertyFeatures(),
                        const SizedBox(height: 24),
                        _buildPropertyInfo(),
                        const SizedBox(height: 24),
                        _buildLocationInfo(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Spacer(),
          ScaleTransition(
            scale: _favoriteScaleAnimation,
            child: IconButton(
              onPressed: _isTogglingFavorite ? null : _toggleFavorite,
              icon: _isCheckingFavorite
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                _isSaved ? Icons.favorite : Icons.favorite_border,
                color: _isSaved ? Colors.red : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemCount: _allImages.length,
              itemBuilder: (context, index) {
                final image = _allImages[index];
                return _buildImageWidget(image['url']);
              },
            ),
            if (_allImages.length > 1) ...[
              // Image indicators
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_allImages.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentImageIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }),
                ),
              ),
              // Navigation arrows
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      if (_currentImageIndex > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      if (_currentImageIndex < _allImages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl == 'placeholder') {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.home, size: 80, color: Colors.grey),
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $imageUrl - $error');
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.error, size: 50, color: Colors.grey),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildPropertyHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.property['houseType'] ?? 'Property',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.attach_money,
              color: Colors.white.withOpacity(0.9),
              size: 24,
            ),
            Text(
              '\$${widget.property['price'] ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '\$${widget.property['pricePerM2'] ?? 0}/m²',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Property Features',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  Icons.straighten,
                  '${widget.property['size'] ?? 0} m²',
                  const Color(0xFF32CD32), // Green
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  Icons.king_bed,
                  '${widget.property['bedrooms'] ?? 0}',
                  const Color(0xFF1E90FF), // Blue
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  Icons.room_outlined,
                  widget.property['totalRooms'] != null && widget.property['totalRooms'] > 0
                      ? '${widget.property['totalRooms']}'
                      : '${widget.property['floor'] ?? 0}',
                  const Color(0xFF9932CC), // Purple
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String value, Color color) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.list_alt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Additional Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Property Type', widget.property['houseType'] ?? 'N/A'),
          _buildInfoRow('Floor', '${widget.property['floor'] ?? 0}'),
          _buildInfoRow('Furnished', widget.property['isFurnished'] == true ? 'Yes' : 'No'),
          _buildInfoRow('High Floor', widget.property['isHighFloor'] == true ? 'Yes' : 'No'),
          _buildInfoRow('Bathrooms', '${widget.property['bathrooms'] ?? 0}'),
          _buildInfoRow('Total Rooms', '${widget.property['totalRooms'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.location_city,
                color: Colors.white.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'City',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                widget.property['city'] ?? 'N/A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.map,
                color: Colors.white.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Region',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                widget.property['region'] ?? 'N/A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (widget.property['address'] != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.home,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Address',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.property['address'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Location Button
          InkWell(
            onTap: _openLocationOnMap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'View Location on Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoadingContact ? null : _getSellerContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoadingContact
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.phone, color: Colors.white),
              label: Text(
                _isLoadingContact ? 'Loading...' : 'Contact Seller',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isCreatingViewingRequest
                  ? null
                  : () async {
                final dateTime = await _showDateTimePicker();
                if (dateTime != null) {
                  _createViewingRequest(dateTime);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF234E70),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isCreatingViewingRequest
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.calendar_today, color: Colors.white),
              label: Text(
                _isCreatingViewingRequest ? 'Requesting...' : 'Schedule Viewing',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}