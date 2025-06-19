// lib/screens/enhanced_add_property_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';
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
  final ImagePicker _picker = ImagePicker();

  // Image handling (max 10 images)
  List<File> _selectedImages = [];
  File? _coverImage;
  static const int maxImages = 10;

  // Form controllers
  late final TextEditingController _sizeController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _totalRoomsController;
  late final TextEditingController _regionController;
  late final TextEditingController _cityController;
  late final TextEditingController _priceController;
  late final TextEditingController _pricePerM2Controller;
  late final TextEditingController _floorController;

  // Form values
  String _propertyType = 'Apartment';
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _totalRooms = 0; // Changed to 0 to match DTO range (0-50)
  bool _isHighFloor = false;
  bool _isAvailable = true;
  bool _isFurnished = false;
  int _floor = 1;

  // Location
  LatLng? _selectedLocation;
  String _locationText = 'Select location on map';

  // AI Integration
  Map<String, dynamic>? _aiPrediction;
  bool _isPredicting = false;
  bool _showPredictionResults = false;

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Check if user is logged in
    if (!UserSession.isLoggedIn()) {
      print('Warning: User not logged in');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in first'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    _initializeControllers();
    _calculatePricePerM2();
  }

  void _initializeControllers() {
    _sizeController = TextEditingController(
        text: widget.propertyToEdit?['size']?.toString() ?? ''
    );
    _bedroomsController = TextEditingController(
        text: widget.propertyToEdit?['bedrooms']?.toString() ?? '1'
    );
    _bathroomsController = TextEditingController(
        text: widget.propertyToEdit?['bathrooms']?.toString() ?? '1'
    );
    _totalRoomsController = TextEditingController(
        text: widget.propertyToEdit?['totalRooms']?.toString() ?? '0'
    );
    _regionController = TextEditingController(
        text: widget.propertyToEdit?['region']?.toString() ?? ''
    );
    _cityController = TextEditingController(
        text: widget.propertyToEdit?['city']?.toString() ?? ''
    );
    _priceController = TextEditingController(
        text: widget.propertyToEdit?['price']?.toString() ?? ''
    );
    _pricePerM2Controller = TextEditingController(
        text: widget.propertyToEdit?['pricePerM2']?.toString() ?? ''
    );
    _floorController = TextEditingController(
        text: widget.propertyToEdit?['floor']?.toString() ?? '1'
    );

    // Initialize other values if editing
    if (widget.propertyToEdit != null) {
      _propertyType = widget.propertyToEdit!['houseType'] ?? 'Apartment';
      _bedrooms = widget.propertyToEdit!['bedrooms'] ?? 1;
      _bathrooms = widget.propertyToEdit!['bathrooms'] ?? 1;
      _totalRooms = widget.propertyToEdit!['totalRooms'] ?? 0;
      _isHighFloor = widget.propertyToEdit!['isHighFloor'] ?? false;
      _isAvailable = widget.propertyToEdit!['status'] == 0;
      _isFurnished = widget.propertyToEdit!['isFurnished'] ?? false;
      _floor = widget.propertyToEdit!['floor'] ?? 1;

      // Set location if available
      if (widget.propertyToEdit!['latitude'] != null && widget.propertyToEdit!['longitude'] != null) {
        _selectedLocation = LatLng(
          widget.propertyToEdit!['latitude'].toDouble(),
          widget.propertyToEdit!['longitude'].toDouble(),
        );
        _locationText = 'Location selected';
      }
    }

    // Add listeners for real-time calculation
    _priceController.addListener(_calculatePricePerM2);
    _sizeController.addListener(_calculatePricePerM2);
  }

  @override
  void dispose() {
    _priceController.removeListener(_calculatePricePerM2);
    _sizeController.removeListener(_calculatePricePerM2);
    _sizeController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _totalRoomsController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _pricePerM2Controller.dispose();
    _floorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Real-time price per m² calculation
  void _calculatePricePerM2() {
    final priceText = _priceController.text.trim();
    final sizeText = _sizeController.text.trim();

    if (priceText.isNotEmpty && sizeText.isNotEmpty) {
      final price = double.tryParse(priceText);
      final size = double.tryParse(sizeText);

      if (price != null && size != null && size > 0) {
        final pricePerM2 = price / size;
        _pricePerM2Controller.text = pricePerM2.toStringAsFixed(2);
      }
    }
  }

  // Image handling methods
  Future<void> _pickImagesFromGallery() async {
    if (_selectedImages.length >= maxImages) {
      _showMessage('Maximum $maxImages images allowed', isError: true);
      return;
    }

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      final remainingSlots = maxImages - _selectedImages.length;
      final filesToAdd = pickedFiles.take(remainingSlots);

      for (XFile file in filesToAdd) {
        final imageFile = File(file.path);
        if (await imageFile.exists()) {
          setState(() {
            _selectedImages.add(imageFile);
            // Set first image as cover if no cover is set
            if (_coverImage == null && _selectedImages.isNotEmpty) {
              _coverImage = _selectedImages.first;
            }
          });
        }
      }

      if (pickedFiles.length > remainingSlots) {
        _showMessage(
          'Only $remainingSlots images were added due to limit',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Failed to pick images: $e', isError: true);
    }
  }

  Future<void> _takePictureFromCamera() async {
    if (_selectedImages.length >= maxImages) {
      _showMessage('Maximum $maxImages images allowed', isError: true);
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        if (await imageFile.exists()) {
          setState(() {
            _selectedImages.add(imageFile);
            // Set as cover if no cover is set
            if (_coverImage == null) {
              _coverImage = imageFile;
            }
          });
        }
      }
    } catch (e) {
      _showMessage('Failed to take picture: $e', isError: true);
    }
  }

  void _removeImage(File image) {
    setState(() {
      _selectedImages.remove(image);
      if (_coverImage == image) {
        _coverImage = _selectedImages.isNotEmpty ? _selectedImages.first : null;
      }
    });
  }

  void _setCoverImage(File image) {
    setState(() {
      _coverImage = image;
    });
  }

  // Location selection
  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          isLocationPicker: true,
          onLocationSelected: (location) {
            setState(() {
              _selectedLocation = location;
              _locationText = 'Location selected (Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)})';
            });
          },
        ),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
        _locationText = 'Location selected (Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)})';
      });
    }
  }

  // AI Prediction Integration
  Future<void> _predictPrice() async {
    if (!_validateFormForPrediction()) return;

    setState(() => _isPredicting = true);

    try {
      final requestBody = {
        'property_type': _getPropertyTypeForAI(_propertyType),
        'area_m2': double.parse(_sizeController.text.trim()),
        'n_bedrooms': _bedrooms,
        'n_bathrooms': _bathrooms,
        'floor': _floor,
        'is_furnished': _isFurnished ? 1 : 0,
        'city': _getCityCodeForAI(_cityController.text.trim()),
        'region': _getRegionCodeForAI(_regionController.text.trim()),
        'price_per_m2': _pricePerM2Controller.text.isNotEmpty
            ? double.parse(_pricePerM2Controller.text)
            : 0,
        'total_rooms': _totalRooms,
        'is_high_floor': _isHighFloor ? 1 : 0,
      };

      final response = await http.post(
        Uri.parse('https://real-estate-api-production-49bc.up.railway.app/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _aiPrediction = data;
          _showPredictionResults = true;
          // Auto-fill with average price
          if (data['avg_price'] != null) {
            _priceController.text = data['avg_price'].toStringAsFixed(0);
          }
        });
        _showMessage('Price prediction completed successfully!');
      } else {
        _showMessage('Failed to predict price. Please try again.', isError: true);
      }
    } catch (e) {
      _showMessage('AI service unavailable. Please enter price manually.', isError: true);
    } finally {
      setState(() => _isPredicting = false);
    }
  }

  // Helper methods for AI integration
  int _getPropertyTypeForAI(String type) {
    const mapping = {
      'Apartment': 0,
      'House': 1,
      'Villa': 2,
      'Studio': 3,
      'Condo': 4,
      'Townhouse': 5,
    };
    return mapping[type] ?? 0;
  }

  int _getCityCodeForAI(String city) {
    const mapping = {
      'Cairo': 0,
      'Alexandria': 1,
      'Giza': 2,
      'Sharm El Sheikh': 3,
      'Hurghada': 4,
    };
    return mapping[city] ?? 0;
  }

  int _getRegionCodeForAI(String region) {
    const mapping = {
      'New Cairo': 0,
      'Maadi': 1,
      'Zamalek': 2,
      'Nasr City': 3,
      'Heliopolis': 4,
    };
    return mapping[region] ?? 0;
  }

  bool _validateFormForPrediction() {
    if (_sizeController.text.trim().isEmpty) {
      _showMessage('Please enter property size for prediction', isError: true);
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      _showMessage('Please enter city for prediction', isError: true);
      return false;
    }
    if (_regionController.text.trim().isEmpty) {
      _showMessage('Please enter region for prediction', isError: true);
      return false;
    }
    return true;
  }

  // Form submission - Fixed to match API exactly
  Future<void> _submitForm() async {
    if (_currentPage < 2) {
      _nextPage();
      return;
    }

    if (!_validateFormForSubmission()) return;

    setState(() => _isSubmitting = true);

    try {
      Uri uri;
      String httpMethod;

      if (widget.propertyToEdit != null) {
        final propertyId = widget.propertyToEdit!['id'];
        if (propertyId == null) {
          _showMessage('Error: Property ID is missing', isError: true);
          setState(() => _isSubmitting = false);
          return;
        }
        uri = Uri.parse('${ApiConfig.BASE_URL}/api/properties/update/$propertyId');
        httpMethod = 'PUT';
      } else {
        uri = Uri.parse('${ApiConfig.BASE_URL}/api/properties/add');
        httpMethod = 'POST';
      }

      final request = http.MultipartRequest(httpMethod, uri);

      // Add form fields - EXACTLY matching the API structure
      final formFields = _prepareFormFields();
      if (formFields.isEmpty) {
        _showMessage('Error preparing form data', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      request.fields.addAll(formFields);

      // Add cover image (required)
      if (_coverImage != null) {
        try {
          request.files.add(await http.MultipartFile.fromPath(
            'CoverImage',
            _coverImage!.path,
          ));
        } catch (e) {
          _showMessage('Error uploading cover image: $e', isError: true);
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Add additional images
      for (int i = 0; i < _selectedImages.length; i++) {
        if (_selectedImages[i] != _coverImage) {
          try {
            request.files.add(await http.MultipartFile.fromPath(
              'Images',
              _selectedImages[i].path,
            ));
          } catch (e) {
            print('Error adding image $i: $e');
            // Continue with other images
          }
        }
      }

      // Set headers
      request.headers['accept'] = '*/*';

      print('Sending request to: ${uri.toString()}');
      print('Form fields: ${request.fields}');
      print('Files: ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        _showMessage(responseData['message'] ??
            (widget.propertyToEdit != null
                ? 'Property updated successfully!'
                : 'Property added successfully!'));

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorMessage = 'Failed to save property';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server error. Status: ${response.statusCode}';
        }
        _showMessage(errorMessage, isError: true);
      }
    } catch (e) {
      _showMessage('Network error: $e', isError: true);
      print('Network error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Map<String, String> _prepareFormFields() {
    // Calculate price per m² if not set
    if (_pricePerM2Controller.text.trim().isEmpty) {
      _calculatePricePerM2();
    }

    // Get current user ID safely
    final userId = UserSession.getCurrentUserId();
    if (userId <= 0) {
      print('Warning: Invalid user ID: $userId');
      return {}; // Return empty map if user ID is invalid
    }

    final fields = <String, String>{
      'UserId': userId.toString(),
      'HouseType': _propertyType,
      'Size': _sizeController.text.trim(), // Backend expects float
      'Bedrooms': _bedrooms.toString(),
      'Bathrooms': _bathrooms.toString(),
      'TotalRooms': _totalRooms.toString(),
      'IsHighFloor': _isHighFloor.toString().toLowerCase(), // Ensure lowercase boolean
      'IsFurnished': _isFurnished.toString().toLowerCase(), // Ensure lowercase boolean
      'Floor': _floor.toString(),
      'Status': _isAvailable ? '0' : '1', // 0 = Available, 1 = NotAvailable (Status enum)
      'Region': _regionController.text.trim(),
      'City': _cityController.text.trim(),
      'Price': _priceController.text.trim(), // Backend expects decimal
      'PricePerM2': _pricePerM2Controller.text.trim().isEmpty
          ? '0'
          : _pricePerM2Controller.text.trim(), // Backend expects decimal
    };

    // Add location coordinates if available (both required as double in DTO)
    if (_selectedLocation != null) {
      fields['Latitude'] = _selectedLocation!.latitude.toString();
      fields['Longitude'] = _selectedLocation!.longitude.toString();
    } else {
      // Provide default coordinates if not selected
      fields['Latitude'] = '0';
      fields['Longitude'] = '0';
    }

    print('Prepared form fields: $fields');
    return fields;
  }

  bool _validateFormForSubmission() {
    if (_selectedImages.isEmpty) {
      _showMessage('Please add at least one property image', isError: true);
      return false;
    }

    if (_coverImage == null) {
      _showMessage('Please select a cover image', isError: true);
      return false;
    }

    // Safe form validation check
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      _showMessage('Please fill all required fields correctly', isError: true);
      return false;
    }

    if (_priceController.text.trim().isEmpty) {
      _showMessage('Please enter property price', isError: true);
      return false;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 1000 || price > 999999999) {
      _showMessage('Price must be between \$1,000 and \$999,999,999', isError: true);
      return false;
    }

    // Additional validation for required fields
    if (_sizeController.text.trim().isEmpty) {
      _showMessage('Please enter property size', isError: true);
      return false;
    }

    final size = double.tryParse(_sizeController.text.trim());
    if (size == null || size < 1 || size > 1000000) {
      _showMessage('Size must be between 1 and 1,000,000 m²', isError: true);
      return false;
    }

    if (_regionController.text.trim().isEmpty) {
      _showMessage('Please enter region', isError: true);
      return false;
    }

    if (_cityController.text.trim().isEmpty) {
      _showMessage('Please enter city', isError: true);
      return false;
    }

    return true;
  }

  void _nextPage() {
    if (_currentPage == 0 && _selectedImages.isEmpty) {
      _showMessage('Please add at least one image before continuing', isError: true);
      return;
    }

    if (_currentPage == 1 && !_validateBasicInfo()) {
      return;
    }

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateBasicInfo() {
    if (_sizeController.text.trim().isEmpty) {
      _showMessage('Please enter property size', isError: true);
      return false;
    }

    final size = double.tryParse(_sizeController.text.trim());
    if (size == null || size <= 0) {
      _showMessage('Please enter a valid property size', isError: true);
      return false;
    }

    // Check if required values are set
    if (_bedrooms < 1) {
      _showMessage('Please select number of bedrooms', isError: true);
      return false;
    }

    if (_bathrooms < 1) {
      _showMessage('Please select number of bathrooms', isError: true);
      return false;
    }

    return true;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
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
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _buildImageUploadPage(),
                    _buildPropertyDetailsPage(),
                    _buildLocationAndPricePage(),
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
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2))),
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
                  color: i <= _currentPage ? Colors.white : Colors.white.withOpacity(0.3),
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

  // Page 1: Image Upload
  Widget _buildImageUploadPage() {
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
            'Add up to $maxImages high-quality images of your property *',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Image preview grid
          if (_selectedImages.isNotEmpty) ...[
            SizedBox(
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  final image = _selectedImages[index];
                  final isCover = image == _coverImage;

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isCover ? Colors.blue : Colors.white.withOpacity(0.2),
                            width: isCover ? 3 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),

                      // Cover badge
                      if (isCover)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
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

                      // Action buttons
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          children: [
                            if (!isCover)
                              GestureDetector(
                                onTap: () => _setCoverImage(image),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _removeImage(image),
                              child: Container(
                                padding: const EdgeInsets.all(6),
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
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Add image buttons
          Row(
            children: [
              Expanded(
                child: _buildImageButton(
                  'Gallery',
                  Icons.photo_library,
                  _pickImagesFromGallery,
                  enabled: _selectedImages.length < maxImages,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildImageButton(
                  'Camera',
                  Icons.camera_alt,
                  _takePictureFromCamera,
                  enabled: _selectedImages.length < maxImages,
                ),
              ),
            ],
          ),

          if (_selectedImages.length >= maxImages)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Maximum $maxImages images reached',
                style: TextStyle(
                  color: Colors.orange.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageButton(String title, IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page 2: Property Details
  Widget _buildPropertyDetailsPage() {
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

            // Property Type Dropdown
            _buildDropdownField(
              'Property Type *',
              _propertyType,
              ['Apartment', 'House', 'Villa', 'Studio', 'Condo', 'Townhouse'],
                  (value) => setState(() => _propertyType = value!),
            ),
            const SizedBox(height: 20),

            // Size
            _buildTextField(
              controller: _sizeController,
              label: 'Size (m²) *',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Size is required';
                final size = double.tryParse(value!);
                if (size == null || size < 1 || size > 1000000) {
                  return 'Size must be between 1 and 1,000,000 m²';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Bedrooms and Bathrooms
            Row(
              children: [
                Expanded(
                  child: _buildNumberSelector(
                    'Bedrooms *',
                    _bedrooms,
                    1,
                    10,
                        (value) => setState(() {
                      _bedrooms = value;
                      _bedroomsController.text = value.toString();
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberSelector(
                    'Bathrooms *',
                    _bathrooms,
                    1,
                    10,
                        (value) => setState(() {
                      _bathrooms = value;
                      _bathroomsController.text = value.toString();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total Rooms and Floor
            Row(
              children: [
                Expanded(
                  child: _buildNumberSelector(
                    'Total Rooms *',
                    _totalRooms,
                    0, // DTO allows 0 to 50
                    50,
                        (value) => setState(() {
                      _totalRooms = value;
                      _totalRoomsController.text = value.toString();
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberSelector(
                    'Floor *',
                    _floor,
                    1,
                    50,
                        (value) => setState(() {
                      _floor = value;
                      _floorController.text = value.toString();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Boolean options
            _buildSwitchTile(
              'High Floor Property',
              _isHighFloor,
                  (value) => setState(() => _isHighFloor = value),
            ),
            _buildSwitchTile(
              'Furnished Property',
              _isFurnished,
                  (value) => setState(() => _isFurnished = value),
            ),
            _buildSwitchTile(
              'Available for Sale/Rent',
              _isAvailable,
                  (value) => setState(() => _isAvailable = value),
            ),
          ],
        ),
      ),
    );
  }

  // Page 3: Location and Price
  Widget _buildLocationAndPricePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location & Pricing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Location fields
          _buildTextField(
            controller: _regionController,
            label: 'Region *',
            validator: (value) => value?.isEmpty ?? true ? 'Region is required' : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _cityController,
            label: 'City *',
            validator: (value) => value?.isEmpty ?? true ? 'City is required' : null,
          ),
          const SizedBox(height: 20),

          // Map location selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Property Location (Optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _locationText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectLocationOnMap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: Text(
                      _selectedLocation != null ? 'Change Location' : 'Select on Map',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI Prediction Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Colors.blue.withOpacity(0.8),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Price Prediction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Get smart price suggestions based on similar properties',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPredicting ? null : _predictPrice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isPredicting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.auto_awesome, color: Colors.white),
                    label: Text(
                      _isPredicting ? 'Predicting...' : 'Get AI Price Prediction',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // AI Prediction Results
                if (_showPredictionResults && _aiPrediction != null) ...[
                  const SizedBox(height: 20),
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
                          'AI Prediction Results:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_aiPrediction!['predicted_price'] != null)
                          _buildPredictionRow('Predicted Price', '\$${_aiPrediction!['predicted_price'].toStringAsFixed(0)}'),
                        if (_aiPrediction!['min_price'] != null && _aiPrediction!['max_price'] != null)
                          _buildPredictionRow('Price Range', '\$${_aiPrediction!['min_price'].toStringAsFixed(0)} - \$${_aiPrediction!['max_price'].toStringAsFixed(0)}'),
                        if (_aiPrediction!['avg_price'] != null)
                          _buildPredictionRow('Average Price', '\$${_aiPrediction!['avg_price'].toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: You can adjust the price based on these predictions.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Price input
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
                    if (price == null || price < 1000 || price > 999999999) {
                      return 'Price must be between \$1,000 and \$999,999,999';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _pricePerM2Controller,
                  label: 'Price per m² (\$)',
                  readOnly: true,
                  validator: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? Colors.white.withOpacity(0.6) : Colors.white,
          ),
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
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
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberSelector(
      String label,
      int value,
      int min,
      int max,
      Function(int) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: Icon(
                  Icons.remove,
                  color: value > min ? Colors.white : Colors.white.withOpacity(0.3),
                ),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: Icon(
                  Icons.add,
                  color: value < max ? Colors.white : Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.blue.withOpacity(0.5),
            inactiveThumbColor: Colors.white.withOpacity(0.7),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _previousPage,
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
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  _getButtonText(),
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
      ),
    );
  }

  String _getButtonText() {
    if (_currentPage < 2) {
      return 'Next';
    } else if (widget.propertyToEdit != null) {
      return 'Update Property';
    } else {
      return 'Post Property';
    }
  }
}