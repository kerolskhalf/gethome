// lib/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/user_session.dart';
import 'map_screen.dart';

class EnhancedAddPropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? propertyToEdit;

  const EnhancedAddPropertyScreen({Key? key, this.propertyToEdit}) : super(key: key);

  @override
  State<EnhancedAddPropertyScreen> createState() => _EnhancedAddPropertyScreenState();
}

class _EnhancedAddPropertyScreenState extends State<EnhancedAddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Multiple images support
  List<String> _selectedImagePaths = [];

  // AI Price Prediction
  Map<String, dynamic>? _pricePrediction;
  bool _isPredictingPrice = false;
  double? _selectedPrice;

  // Replace with your actual API base URL
  static const String API_BASE_URL = 'https://gethome.runasp.net';

  // Form controllers
  late final TextEditingController _sizeController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _totalRoomsController;
  late final TextEditingController _regionController;
  late final TextEditingController _cityController;
  late final TextEditingController _priceController;
  late final TextEditingController _pricePerM2Controller;
  late final TextEditingController _descriptionController;

  late String _houseType;
  late int _status;
  late bool _isHighFloor;
  late int _userId;

  // Location data
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _userId = UserSession.getCurrentUserId();
  }

  void _initializeControllers() {
    _sizeController = TextEditingController(text: widget.propertyToEdit?['size']?.toString() ?? '');
    _bedroomsController = TextEditingController(text: widget.propertyToEdit?['bedrooms']?.toString() ?? '');
    _bathroomsController = TextEditingController(text: widget.propertyToEdit?['bathrooms']?.toString() ?? '');
    _totalRoomsController = TextEditingController(text: widget.propertyToEdit?['totalRooms']?.toString() ?? '');
    _regionController = TextEditingController(text: widget.propertyToEdit?['region'] ?? '');
    _cityController = TextEditingController(text: widget.propertyToEdit?['city'] ?? '');
    _priceController = TextEditingController(text: widget.propertyToEdit?['price']?.toString() ?? '');
    _pricePerM2Controller = TextEditingController(text: widget.propertyToEdit?['pricePerM2']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.propertyToEdit?['description'] ?? '');

    _houseType = widget.propertyToEdit?['houseType'] ?? 'Apartment';
    _status = widget.propertyToEdit?['status'] ?? 0;
    _isHighFloor = widget.propertyToEdit?['isHighFloor'] ?? false;

    // Initialize with existing images if editing
    if (widget.propertyToEdit?['imagePaths'] != null) {
      _selectedImagePaths = List<String>.from(widget.propertyToEdit!['imagePaths']);
    } else if (widget.propertyToEdit?['imagePath'] != null) {
      _selectedImagePaths = [widget.propertyToEdit!['imagePath']];
    }

    // Initialize location if available
    if (widget.propertyToEdit?['latitude'] != null && widget.propertyToEdit?['longitude'] != null) {
      _selectedLocation = LatLng(
        widget.propertyToEdit!['latitude'].toDouble(),
        widget.propertyToEdit!['longitude'].toDouble(),
      );
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _totalRoomsController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _pricePerM2Controller.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Multiple image picker
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          // Add new images to existing list (max 10 images)
          for (final image in images) {
            if (_selectedImagePaths.length < 10) {
              _selectedImagePaths.add(image.path);
            }
          }
        });
      }
    } catch (e) {
      _showErrorMessage('Failed to pick images: $e');
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && _selectedImagePaths.length < 10) {
        setState(() {
          _selectedImagePaths.add(image.path);
        });
      }
    } catch (e) {
      _showErrorMessage('Failed to take photo: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImagePaths.removeAt(index);
    });
  }

  // AI Price Prediction
  Future<void> _predictPrice() async {
    if (!_canPredictPrice()) return;

    setState(() => _isPredictingPrice = true);

    try {
      final requestBody = {
        'houseType': _houseType,
        'size': int.tryParse(_sizeController.text) ?? 0,
        'bedrooms': int.tryParse(_bedroomsController.text) ?? 0,
        'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
        'region': _regionController.text.trim(),
        'city': _cityController.text.trim(),
        'isHighFloor': _isHighFloor,
      };

      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/ai/predict-price'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pricePrediction = data;
          // Set average price as default
          if (data['averagePrice'] != null) {
            _selectedPrice = data['averagePrice'].toDouble();
            _priceController.text = _selectedPrice!.toStringAsFixed(0);
            _calculatePricePerM2();
          }
        });
        _showSuccessMessage('Price prediction completed!');
      } else {
        _showErrorMessage('Failed to predict price. Please try again.');
      }
    } catch (e) {
      _showErrorMessage('Network error during price prediction: $e');
    } finally {
      setState(() => _isPredictingPrice = false);
    }
  }

  bool _canPredictPrice() {
    return _sizeController.text.isNotEmpty &&
        _bedroomsController.text.isNotEmpty &&
        _bathroomsController.text.isNotEmpty &&
        _regionController.text.isNotEmpty &&
        _cityController.text.isNotEmpty;
  }

  void _calculatePricePerM2() {
    final price = double.tryParse(_priceController.text);
    final size = int.tryParse(_sizeController.text);

    if (price != null && size != null && size > 0) {
      final pricePerM2 = price / size;
      _pricePerM2Controller.text = pricePerM2.toStringAsFixed(2);
    }
  }

  // Location selection
  Future<void> _selectLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          isLocationPicker: true,
          onLocationSelected: (location) {
            setState(() {
              _selectedLocation = location;
            });
          },
        ),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
      });
      // TODO: Reverse geocoding to get address
      _selectedAddress = 'Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}';
    }
  }

  // Form submission
  Future<void> _submitForm() async {
    if (_currentPage < 2) {
      _nextPage();
      return;
    }

    // Validate final form
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImagePaths.isEmpty) {
      _showErrorMessage('Please add at least one property image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = widget.propertyToEdit != null
          ? Uri.parse('$API_BASE_URL/api/properties/update/${widget.propertyToEdit!['id']}')
          : Uri.parse('$API_BASE_URL/api/properties/add');

      final request = http.MultipartRequest(
        widget.propertyToEdit != null ? 'PUT' : 'POST',
        uri,
      );

      // Add headers
      request.headers.addAll({
        'Accept': '*/*',
      });

      // Calculate price per m² if not provided
      if (_pricePerM2Controller.text.isEmpty) {
        _calculatePricePerM2();
      }

      // Add form fields
      Map<String, String> fields = {
        'HouseType': _houseType,
        'Size': _sizeController.text.trim(),
        'Bedrooms': _bedroomsController.text.trim(),
        'Bathrooms': _bathroomsController.text.trim(),
        'Status': _status.toString(),
        'Region': _regionController.text.trim(),
        'City': _cityController.text.trim(),
        'Price': _priceController.text.trim(),
        'IsHighFloor': _isHighFloor.toString(),
        'Description': _descriptionController.text.trim(),
      };

      // Add UserId only for new properties
      if (widget.propertyToEdit == null) {
        fields['UserId'] = _userId.toString();
      }

      // Add optional fields
      if (_totalRoomsController.text.isNotEmpty) {
        fields['TotalRooms'] = _totalRoomsController.text.trim();
      }
      if (_pricePerM2Controller.text.isNotEmpty) {
        fields['PricePerM2'] = _pricePerM2Controller.text.trim();
      }

      // Add location data
      if (_selectedLocation != null) {
        fields['Latitude'] = _selectedLocation!.latitude.toString();
        fields['Longitude'] = _selectedLocation!.longitude.toString();
      }

      request.fields.addAll(fields);

      // Add multiple image files
      for (int i = 0; i < _selectedImagePaths.length; i++) {
        final imageFile = await http.MultipartFile.fromPath(
          'Images', // Use 'Images' for multiple files
          _selectedImagePaths[i],
        );
        request.files.add(imageFile);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final successMessage = widget.propertyToEdit != null
            ? 'Property updated successfully!'
            : 'Property added successfully!';
        _showSuccessMessage(successMessage);

        Navigator.pop(context, true);
      } else {
        _handleApiError(response);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorMessage('Network error. Please check your connection and try again.');
      }
    }
  }

  void _handleApiError(http.Response response) {
    if (response.statusCode == 400) {
      try {
        final errorData = json.decode(response.body);
        if (errorData.containsKey('errors')) {
          final errors = errorData['errors'] as Map<String, dynamic>;
          final errorMessages = <String>[];
          errors.forEach((field, messages) {
            if (messages is List) {
              for (final message in messages) {
                errorMessages.add('$field: $message');
              }
            }
          });
          _showErrorMessage('Validation errors:\n${errorMessages.join('\n')}');
        } else {
          _showErrorMessage(errorData['message'] ?? 'Validation failed');
        }
      } catch (e) {
        _showErrorMessage('Please check all required fields and try again.');
      }
    } else {
      _showErrorMessage('Server error (${response.statusCode}). Please try again later.');
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
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
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildImagesPage(),
                    _buildBasicInfoPage(),
                    _buildPriceAndLocationPage(),
                  ],
                ),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.propertyToEdit != null ? 'Edit Property' : 'Add New Property',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentPage
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildImagesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Property Images',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 10 high-quality images of your property',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Image grid
          if (_selectedImagePaths.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _selectedImagePaths.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          File(_selectedImagePaths[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Add image buttons
          if (_selectedImagePaths.length < 10) ...[
            Row(
              children: [
                Expanded(
                  child: _buildImageButton(
                    'Gallery',
                    Icons.photo_library,
                    _pickImages,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImageButton(
                    'Camera',
                    Icons.camera_alt,
                    _pickSingleImage,
                  ),
                ),
              ],
            ),
          ],

          if (_selectedImagePaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${_selectedImagePaths.length}/10 images added',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageButton(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // House Type
            _buildDropdown(),
            const SizedBox(height: 16),

            // Size
            _buildTextField(
              controller: _sizeController,
              label: 'Size (m²) *',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Size is required';
                final size = int.tryParse(value!);
                if (size == null || size <= 0) return 'Please enter a valid size';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bedrooms and Bathrooms
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _bedroomsController,
                    label: 'Bedrooms *',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final bedrooms = int.tryParse(value!);
                      if (bedrooms == null || bedrooms < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _bathroomsController,
                    label: 'Bathrooms *',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final bathrooms = int.tryParse(value!);
                      if (bathrooms == null || bathrooms < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Rooms
            _buildTextField(
              controller: _totalRoomsController,
              label: 'Total Rooms',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // High Floor Toggle
            _buildHighFloorToggle(),
            const SizedBox(height: 16),

            // Status Dropdown
            _buildStatusDropdown(),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Description is required';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price & Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Location section
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _regionController,
                  label: 'Region *',
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Region is required';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City *',
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'City is required';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location picker
          GestureDetector(
            onTap: _selectLocation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLocation != null
                          ? _selectedAddress ?? 'Location selected'
                          : 'Select location on map',
                      style: TextStyle(
                        color: _selectedLocation != null
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // AI Price Prediction
          if (_canPredictPrice()) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Price Prediction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get an AI-powered price estimate based on your property details',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPredictingPrice ? null : _predictPrice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isPredictingPrice
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.psychology, color: Colors.white),
                      label: Text(
                        _isPredictingPrice ? 'Predicting...' : 'Predict Price',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Price prediction results
          if (_pricePrediction != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price Prediction Results',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceOption(
                        'Lowest',
                        _pricePrediction!['lowestPrice']?.toDouble() ?? 0.0,
                        Colors.red.shade300,
                      ),
                      _buildPriceOption(
                        'Average',
                        _pricePrediction!['averagePrice']?.toDouble() ?? 0.0,
                        Colors.blue.shade300,
                      ),
                      _buildPriceOption(
                        'Highest',
                        _pricePrediction!['highestPrice']?.toDouble() ?? 0.0,
                        Colors.green.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Manual price input
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _priceController,
                  label: 'Price (\$) *',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Price is required';
                    final price = double.tryParse(value!);
                    if (price == null || price <= 0) return 'Invalid price';
                    return null;
                  },
                  onChanged: (value) => _calculatePricePerM2(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _pricePerM2Controller,
                  label: 'Price per m² (\$)',
                  keyboardType: TextInputType.number,
                  readOnly: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOption(String label, double price, Color color) {
    final isSelected = _selectedPrice == price;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPrice = price;
          _priceController.text = price.toStringAsFixed(0);
          _calculatePricePerM2();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${price.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? Colors.white.withOpacity(0.6) : Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        filled: true,
        fillColor: readOnly
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.1),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'House Type *',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _houseType,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white),
              items: ['Apartment', 'House', 'Villa', 'Studio', 'Condo', 'Townhouse']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _houseType = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighFloorToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'High Floor',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        Switch(
          value: _isHighFloor,
          onChanged: (value) {
            setState(() {
              _isHighFloor = value;
            });
          },
          activeColor: Colors.white,
          activeTrackColor: Colors.blue.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _status,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem<int>(value: 0, child: Text('Available')),
                DropdownMenuItem<int>(value: 1, child: Text('Sold')),
                DropdownMenuItem<int>(value: 2, child: Text('Rented')),
                DropdownMenuItem<int>(value: 3, child: Text('Pending')),
              ],
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _status = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                _currentPage < 2 ? 'Next' :
                (widget.propertyToEdit != null ? 'Save Changes' : 'Post Property'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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