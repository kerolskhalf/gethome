// lib/screens/property_details_screen_seller.dart - WITH MULTIPLE IMAGES CAROUSEL
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'add_property_screen.dart';
import 'viewing_requests_screen.dart';
import '../utils/api_config.dart';

class PropertyDetailsScreenSeller extends StatefulWidget {
  final Map<String, dynamic> property;
  final Function(Map<String, dynamic>) onEdit;
  final Function() onDelete;

  const PropertyDetailsScreenSeller({
    Key? key,
    required this.property,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<PropertyDetailsScreenSeller> createState() => _PropertyDetailsScreenSellerState();
}

class _PropertyDetailsScreenSellerState extends State<PropertyDetailsScreenSeller> {
  bool _isDeleting = false;
  bool _isLoadingFullProperty = true;
  late PageController _pageController;
  int _currentImageIndex = 0;
  List<String> _allImageUrls = [];
  Map<String, dynamic> _fullPropertyData = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fullPropertyData = Map.from(widget.property); // Start with basic data
    _loadFullPropertyDetails(); // Load complete data with images
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // NEW: Load complete property details with images
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

        // Extract property data (it might be wrapped in 'data' field)
        Map<String, dynamic> propertyData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            propertyData = data['data'] as Map<String, dynamic>;
          } else {
            propertyData = data;
          }
        } else {
          propertyData = widget.property; // Fallback to original data
        }

        setState(() {
          _fullPropertyData = propertyData;
          _isLoadingFullProperty = false;
        });

        // Now load all images with the complete data
        _loadAllImages();
      } else {
        print('❌ Failed to load property details: ${response.statusCode}');
        setState(() => _isLoadingFullProperty = false);
        // Use original data and try to load images anyway
        _loadAllImages();
      }
    } catch (e) {
      print('❌ Error loading property details: $e');
      setState(() => _isLoadingFullProperty = false);
      // Use original data and try to load images anyway
      _loadAllImages();
    }
  }

  void _loadAllImages() {
    _allImageUrls.clear();

    print('🖼️ Loading images for property: ${widget.property['id']}');
    print('📋 Property data: ${widget.property}');

    // Method 1: Try to get cover image from different possible fields
    String? coverImageUrl;

    // Check for full URL in 'Coverimage' field (backend sometimes returns this)
    if (widget.property['Coverimage'] != null) {
      coverImageUrl = widget.property['Coverimage'].toString();
      print('📸 Found Coverimage: $coverImageUrl');
    }
    // Check for path in 'imagePath' field
    else if (widget.property['imagePath'] != null) {
      final coverImagePath = widget.property['imagePath'].toString();
      if (ApiConfig.isValidImagePath(coverImagePath)) {
        coverImageUrl = ApiConfig.getImageUrl(coverImagePath);
        print('📸 Found imagePath: $coverImagePath -> $coverImageUrl');
      }
    }

    // Add cover image to list if found
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      _allImageUrls.add(coverImageUrl);
    }

    // Method 2: Load all additional images from the Images array
    final images = widget.property['images'] ?? widget.property['Images'] ?? widget.property['propertyImages'];

    if (images != null && images is List) {
      print('📷 Found ${images.length} additional images');

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        String? imageUrl;

        print('🔍 Processing image $i: $image (type: ${image.runtimeType})');

        if (image is Map) {
          // Case 1: Image is a map with ImagePath field containing full URL
          if (image['ImagePath'] != null) {
            imageUrl = image['ImagePath'].toString();
            print('✅ Found ImagePath (full URL): $imageUrl');
          }
          // Case 2: Image is a map with imagePath field containing path only
          else if (image['imagePath'] != null) {
            final imagePath = image['imagePath'].toString();
            if (ApiConfig.isValidImagePath(imagePath)) {
              imageUrl = ApiConfig.getImageUrl(imagePath);
              print('✅ Found imagePath (converted): $imagePath -> $imageUrl');
            }
          }
          // Case 3: Image is a map with path field
          else if (image['path'] != null) {
            final imagePath = image['path'].toString();
            if (ApiConfig.isValidImagePath(imagePath)) {
              imageUrl = ApiConfig.getImageUrl(imagePath);
              print('✅ Found path (converted): $imagePath -> $imageUrl');
            }
          }
        }
        // Case 4: Image is a direct string (could be URL or path)
        else if (image is String) {
          if (image.startsWith('http')) {
            // It's already a full URL
            imageUrl = image;
            print('✅ Found direct URL: $imageUrl');
          } else if (ApiConfig.isValidImagePath(image)) {
            // It's a path, convert to URL
            imageUrl = ApiConfig.getImageUrl(image);
            print('✅ Found direct path (converted): $image -> $imageUrl');
          }
        }

        // Add to list if valid and not duplicate
        if (imageUrl != null && imageUrl.isNotEmpty && !_allImageUrls.contains(imageUrl)) {
          _allImageUrls.add(imageUrl);
          print('➕ Added image: $imageUrl');
        } else if (imageUrl != null && _allImageUrls.contains(imageUrl)) {
          print('⚠️ Duplicate image skipped: $imageUrl');
        } else {
          print('❌ Invalid image skipped: $image');
        }
      }
    } else {
      print('📷 No additional images found in property data');
    }

    print('🎯 Final result: Loaded ${_allImageUrls.length} images total');
    for (int i = 0; i < _allImageUrls.length; i++) {
      print('   $i: ${_allImageUrls[i]}');
    }
  }

  void _deleteProperty() {
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
            onPressed: _isDeleting ? null : () async {
              Navigator.pop(context); // Close dialog
              await _performDelete();
            },
            child: _isDeleting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    setState(() => _isDeleting = true);

    try {
      final propertyId = widget.property['id'];
      final response = await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/delete/$propertyId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        widget.onDelete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Property deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete property'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _editProperty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedAddPropertyScreen(
          propertyToEdit: _fullPropertyData.isNotEmpty ? _fullPropertyData : widget.property,
        ),
      ),
    );

    if (result == true) {
      // Property was successfully updated - reload the full data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload full property details to get updated images
        _loadFullPropertyDetails();
      }
    }
  }

  void _viewPropertyRequests() {
    final propertyId = _fullPropertyData['id'] ?? widget.property['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewingRequestsScreen(
          isSellerView: true,
          propertyId: propertyId,
        ),
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
    if (_allImageUrls.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[300]!,
              Colors.grey[400]!,
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.home, size: 120, color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image carousel
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: _allImageUrls.length,
          itemBuilder: (context, index) {
            return Image.network(
              _allImageUrls[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey[300]!,
                        Colors.grey[400]!,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey[300]!,
                        Colors.grey[400]!,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 120, color: Colors.white),
                  ),
                );
              },
            );
          },
        ),

        // Gradient overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),

        // Navigation arrows for multiple images
        if (_allImageUrls.length > 1) ...[
          // Left arrow
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                  onPressed: () {
                    if (_currentImageIndex > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          // Right arrow
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                  onPressed: () {
                    if (_currentImageIndex < _allImageUrls.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],

        // Image counter and indicators
        if (_allImageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Image counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${_allImageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_allImageUrls.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentImageIndex == index ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
      ],
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

          // Show loading state while fetching full property details
          if (_isLoadingFullProperty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading property details...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
          // Main content
            CustomScrollView(
              slivers: [
                // Enhanced App Bar with image carousel
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildPropertyImage(),
                  ),
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  actions: [
                    // Edit Button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 22),
                        onPressed: _editProperty,
                        tooltip: 'Edit Property',
                      ),
                    ),
                    // View Requests Button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.remove_red_eye, color: Colors.white, size: 22),
                        onPressed: _viewPropertyRequests,
                        tooltip: 'View Requests',
                      ),
                    ),
                    // Delete Button
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: _isDeleting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.delete, color: Colors.white, size: 22),
                        onPressed: _isDeleting ? null : _deleteProperty,
                        tooltip: 'Delete Property',
                      ),
                    ),
                  ],
                ),

                // Property details
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1a237e),
                          Color(0xFF234E70),
                          Color(0xFF305F80),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPropertyHeader(),
                          const SizedBox(height: 24),
                          _buildLocationSection(),
                          const SizedBox(height: 24),
                          _buildPropertyFeatures(),
                          const SizedBox(height: 24),
                          _buildPropertyInfo(),
                          const SizedBox(height: 32),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      widget.property['houseType'] ?? 'Property',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.property['status']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(widget.property['status']).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  _getStatusText(widget.property['status']),
                  style: TextStyle(
                    color: _getStatusColor(widget.property['status']),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${widget.property['price'] ?? 0} LE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.property['pricePerM2'] != null && widget.property['pricePerM2'] > 0)
                    Text(
                      '${widget.property['pricePerM2']} LE/m²',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_city,
                color: Colors.white.withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.property['city'] ?? ''}, ${widget.property['region'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (widget.property['isHighFloor'] == true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.height,
                  color: Colors.blue.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _buildPropertyFeatures() {
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
                child: const Icon(Icons.home_work, color: Colors.white, size: 20),
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
          const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            Center(
              child: _buildFeature(
                Icons.room,
                'Total Rooms',
                '${widget.property['totalRooms']}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
          _buildInfoRow('Status', _getStatusText(widget.property['status'])),
          if (widget.property['pricePerM2'] != null)
            _buildInfoRow('Price per m²', '${widget.property['pricePerM2']} LE'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _viewPropertyRequests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.7),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                label: const Text(
                  'View Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _editProperty,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.7),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                label: const Text(
                  'Edit Property',
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
        const SizedBox(height: 16),
        // Delete Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isDeleting ? null : _deleteProperty,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.7),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: _isDeleting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.delete, color: Colors.white, size: 20),
            label: Text(
              _isDeleting ? 'Deleting...' : 'Delete Property',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}