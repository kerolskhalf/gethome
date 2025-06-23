// lib/screens/property_details_screen_seller.dart - COMPLETE FILE WITH SELLER FIXES
import 'package:flutter/material.dart';
import 'package:gethome/screens/seller_dashboard_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  bool _isAddingImage = false;
  late PageController _pageController;
  int _currentImageIndex = 0;
  List<Map<String, dynamic>> _allImages = []; // Store images with IDs
  Map<String, dynamic> _fullPropertyData = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fullPropertyData = Map.from(widget.property);
    _loadFullPropertyDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        int? imageId;

        if (image is Map<String, dynamic>) {
          imageId = image['id'];
          final imagePath = image['imagePath'] ?? image['path'];
          if (imagePath != null && ApiConfig.isValidImagePath(imagePath)) {
            imageUrl = ApiConfig.getImageUrl(imagePath);
          }
        } else if (image is String && ApiConfig.isValidImagePath(image)) {
          imageUrl = ApiConfig.getImageUrl(image);
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          _allImages.add({
            'id': imageId,
            'url': imageUrl,
            'isCover': false,
          });
        }
      }
    }

    print('📸 Loaded ${_allImages.length} images total');
    setState(() {});
  }

  Future<void> _addImage() async {
    setState(() => _isAddingImage = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() => _isAddingImage = false);
        return;
      }

      final propertyId = widget.property['id'];
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/$propertyId/images'),
      );

      request.headers.addAll(ApiConfig.multipartHeaders);
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showSuccessMessage('Image added successfully!');
        await _loadFullPropertyDetails(); // Reload to get new images
      } else {
        _showErrorMessage('Failed to add image');
      }
    } catch (e) {
      _showErrorMessage('Error adding image: $e');
    } finally {
      setState(() => _isAddingImage = false);
    }
  }

  Future<void> _deleteImage(int imageId) async {
    try {
      final propertyId = widget.property['id'];
      final response = await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/$propertyId/images/$imageId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Image deleted successfully!');
        await _loadFullPropertyDetails(); // Reload images
      } else {
        _showErrorMessage('Failed to delete image');
      }
    } catch (e) {
      _showErrorMessage('Error deleting image: $e');
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
          child: _isLoadingFullProperty ? _buildLoadingState() : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading property details...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        _buildImageSlider(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPropertyHeader(),
                const SizedBox(height: 24),
                _buildPropertyFeatures(),
                const SizedBox(height: 24),
                _buildPropertyInfo(),
                const SizedBox(height: 24),
                _buildImageManagement(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSlider() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _allImages.isNotEmpty
            ? PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemCount: _allImages.length,
          itemBuilder: (context, index) {
            final image = _allImages[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  image['url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
                if (image['isCover'] == true)
                   Positioned(
                    top: 60,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Cover',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            );
          },
        )
            : _buildDefaultImage(),
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 80, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No Images Available',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fullPropertyData['houseType'] ?? 'Property',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '\$${_fullPropertyData['price'] ?? 0}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(_fullPropertyData['status']),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(_fullPropertyData['status']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_fullPropertyData['city'] ?? 'Unknown'}, ${_fullPropertyData['region'] ?? 'Unknown'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
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
                child: const Icon(Icons.home, color: Colors.white, size: 20),
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
                Icons.square_foot,
                'Area',
                '${_fullPropertyData['size'] ?? 0} m²',
              ),
              _buildFeature(
                Icons.king_bed,
                'Bedrooms',
                '${_fullPropertyData['bedrooms'] ?? 0}',
              ),
              _buildFeature(
                Icons.bathtub,
                'Bathrooms',
                '${_fullPropertyData['bathrooms'] ?? 0}',
              ),
            ],
          ),
          if (_fullPropertyData['totalRooms'] != null && _fullPropertyData['totalRooms'] > 0) ...[
            const SizedBox(height: 24),
            Center(
              child: _buildFeature(
                Icons.room,
                'Total Rooms',
                '${_fullPropertyData['totalRooms']}',
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
          _buildInfoRow('Property Type', _fullPropertyData['houseType'] ?? 'N/A'),
          _buildInfoRow('Floor', '${_fullPropertyData['floor'] ?? 0}'),
          _buildInfoRow('Furnished', _fullPropertyData['isFurnished'] == true ? 'Yes' : 'No'),
          _buildInfoRow('High Floor', _fullPropertyData['isHighFloor'] == true ? 'Yes' : 'No'),
          _buildInfoRow('Status', _getStatusText(_fullPropertyData['status'])),
          if (_fullPropertyData['description'] != null && _fullPropertyData['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fullPropertyData['description'].toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
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

  Widget _buildImageManagement() {
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
                child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Image Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Images: ${_allImages.length}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAddingImage ? null : _addImage,
                  icon: _isAddingImage
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(_isAddingImage ? 'Adding...' : 'Add Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Color _getStatusColor(dynamic status) {
    switch (status) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(dynamic status) {
    switch (status) {
      case 0:
        return 'For Sale';
      case 1:
        return 'For Rent';
      case 2:
        return 'Sold';
      case 3:
        return 'Rented';
      default:
        return 'Unknown';
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPropertyScreen(
                    propertyToEdit: _fullPropertyData,
                  ),
                ),
              );

              if (result != null) {
                widget.onEdit(result);
                await _loadFullPropertyDetails(); // Refresh data
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Property'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // FIXED: Pass both isSellerView and propertyId for seller viewing requests
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewingRequestsScreen(
                    isSellerView: true,                    // Important: Set to true for seller
                    propertyId: widget.property['id'],     // Pass specific property ID
                  ),
                ),
              );
            },
            icon: const Icon(Icons.schedule),
            label: const Text('View Requests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withOpacity(0.8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
}