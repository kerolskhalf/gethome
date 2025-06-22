// lib/screens/property_details_screen_seller.dart - WITH COMPLETE IMAGE MANAGEMENT
import 'package:flutter/material.dart';
import 'package:gethome/screens/seller_dashboard_screen.dart';
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

    // Add cover image (no ID for cover image as it's handled separately)
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      _allImages.add({
        'id': null, // Cover image doesn't have deletable ID
        'url': coverImageUrl,
        'isCover': true,
      });
    }

    // Load additional images with IDs
    final images = _fullPropertyData['Images'] ?? _fullPropertyData['images'] ?? [];

    if (images != null && images is List) {
      print('📷 Found ${images.length} additional images');

      for (final image in images) {
        String? imageUrl;
        int? imageId;

        if (image is Map) {
          // Get image ID
          imageId = image['Id'] ?? image['id'];

          // Get image URL
          if (image['ImagePath'] != null) {
            imageUrl = image['ImagePath'].toString();
          } else if (image['imagePath'] != null) {
            final imagePath = image['imagePath'].toString();
            if (ApiConfig.isValidImagePath(imagePath)) {
              imageUrl = ApiConfig.getImageUrl(imagePath);
            }
          }
        }

        if (imageUrl != null && imageUrl.isNotEmpty && imageId != null) {
          _allImages.add({
            'id': imageId,
            'url': imageUrl,
            'isCover': false,
          });
          print('➕ Added image with ID $imageId: $imageUrl');
        }
      }
    }

    print('🎯 Final result: Loaded ${_allImages.length} images total');
    setState(() {});
  }

  // Add new image
  Future<void> _addImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isAddingImage = true);

      // Prepare multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/add-image'),
      );

      // Add headers
      request.headers.addAll(ApiConfig.headers);

      // Add property ID
      request.fields['propertyId'] = _fullPropertyData['id'].toString();

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );

      print('📤 Uploading image for property: ${_fullPropertyData['id']}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Add image response: ${response.statusCode}');
      print('📋 Add image body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Refresh property details to get updated images
          await _loadFullPropertyDetails();
          _showSuccessMessage('Image added successfully!');
        } else {
          _showErrorMessage('Failed to add image: ${responseData['message']}');
        }
      } else {
        _showErrorMessage('Failed to add image. Please try again.');
      }
    } catch (e) {
      print('❌ Error adding image: $e');
      _showErrorMessage('Error adding image: $e');
    } finally {
      setState(() => _isAddingImage = false);
    }
  }

  // Delete image by ID
  Future<void> _deleteImage(int imageId, int index) async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF234E70),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'Delete Image',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this image?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performImageDeletion(imageId, index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error showing delete dialog: $e');
    }
  }

  Future<void> _performImageDeletion(int imageId, int index) async {
    try {
      print('🗑️ Deleting image with ID: $imageId');

      final response = await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/remove-image/$imageId'),
        headers: ApiConfig.headers,
      );

      print('📡 Delete image response: ${response.statusCode}');
      print('📋 Delete image body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Remove image from local list
          setState(() {
            _allImages.removeAt(index);
            // Adjust current index if needed
            if (_currentImageIndex >= _allImages.length && _allImages.isNotEmpty) {
              _currentImageIndex = _allImages.length - 1;
              _pageController.animateToPage(
                _currentImageIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (_allImages.isEmpty) {
              _currentImageIndex = 0;
            }
          });
          _showSuccessMessage('Image deleted successfully!');
        } else {
          _showErrorMessage('Failed to delete image: ${responseData['message']}');
        }
      } else {
        _showErrorMessage('Failed to delete image. Please try again.');
      }
    } catch (e) {
      print('❌ Error deleting image: $e');
      _showErrorMessage('Error deleting image: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
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
          'Are you sure you want to delete this property?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performPropertyDeletion();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performPropertyDeletion() async {
    setState(() => _isDeleting = true);

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/delete/${widget.property['id']}'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        widget.onDelete();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete property: ${response.body}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting property: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF234E70), Color(0xFF1A3A52)],
          ),
        ),
        child: _isLoadingFullProperty
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageCarousel(),
                      const SizedBox(height: 24),
                      _buildPropertyFeatures(),
                      const SizedBox(height: 24),
                      _buildPropertyInfo(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewingRequestsScreen(
                  propertyId: widget.property['id'],
                ),
              ),
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today, color: Colors.white),
          ),
        ),
        IconButton(
          onPressed: _deleteProperty,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isDeleting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    if (_allImages.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'No images available',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Image carousel
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemCount: _allImages.length,
              itemBuilder: (context, index) {
                final imageData = _allImages[index];
                return Stack(
                  children: [
                    // Image
                    Container(
                      width: double.infinity,
                      child: Image.network(
                        imageData['url'],
                        fit: BoxFit.cover,
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
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, size: 48, color: Colors.white54),
                                  SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Cover image badge
                    if (imageData['isCover'] == true)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Delete button for non-cover images
                    if (imageData['isCover'] != true && imageData['id'] != null)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => _deleteImage(imageData['id'], index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Image indicators and add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Indicators
            if (_allImages.length > 1)
              Row(
                children: List.generate(
                  _allImages.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentImageIndex ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _currentImageIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(),
            // Add image button
            ElevatedButton.icon(
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
              Text(
                '\$${widget.property['price'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.property['city'] ?? 'Unknown'}, ${widget.property['region'] ?? 'Unknown'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeature(
                Icons.square_foot,
                'Area',
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
          _buildInfoRow('Floor', '${widget.property['floor'] ?? 'N/A'}'),
          _buildInfoRow('Furnished', (widget.property['isFurnished'] ?? false) ? 'Yes' : 'No'),
          _buildInfoRow('High Floor', (widget.property['isHighFloor'] ?? false) ? 'Yes' : 'No'),
          _buildInfoRow('Price per m²', '\$${widget.property['pricePerM2'] ?? 0}'),
          _buildInfoRow('Status', _getStatusText(widget.property['status'])),
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

  String _getStatusText(int? status) {
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
                  builder: (context) => AddPropertyScreen(  // FIXED: Use AddPropertyScreen instead
                    propertyToEdit: widget.property,
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewingRequestsScreen(
                    propertyId: widget.property['id'],
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
}