// lib/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Single image support (matching API)
  String? _selectedImagePath;

  // AI Price Prediction
  Map<String, dynamic>? _pricePrediction;
  bool _isPredictingPrice = false;
  double? _selectedPrice;

  // Form controllers
  late final TextEditingController _sizeController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _totalRoomsController;
  late final TextEditingController _regionController;
  late final TextEditingController _cityController;
  late final TextEditingController _priceController;
  late final TextEditingController _pricePerM2Controller;

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

    // Ensure we have a valid user session
    UserSession.ensureValidSession();
    _userId = UserSession.getCurrentUserId();

    // Print debug info
    ApiConfig.printDebugInfo();
    print('🔧 Current User ID: $_userId');
    print('🔧 User Session Valid: ${UserSession.validateSession()}');
    print('🔧 User Session Summary: ${UserSession.getSessionSummary()}');

    // Validate user session
    if (_userId <= 0) {
      print('⚠️ Invalid user ID detected, attempting to fix...');
      UserSession.ensureValidSession();
      _userId = UserSession.getCurrentUserId();

      if (_userId <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorMessage('Invalid user session. Please login again.');
          Navigator.pop(context);
        });
      }
    }
  }

  void _initializeControllers() {
    // Initialize controllers with safe null checks
    _sizeController = TextEditingController(
        text: widget.propertyToEdit?['size']?.toString() ?? ''
    );
    _bedroomsController = TextEditingController(
        text: widget.propertyToEdit?['bedrooms']?.toString() ?? ''
    );
    _bathroomsController = TextEditingController(
        text: widget.propertyToEdit?['bathrooms']?.toString() ?? ''
    );
    _totalRoomsController = TextEditingController(
        text: widget.propertyToEdit?['totalRooms']?.toString() ?? ''
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

    // Initialize dropdowns with safe defaults
    _houseType = widget.propertyToEdit?['houseType']?.toString() ?? 'Apartment';
    _status = widget.propertyToEdit?['status'] as int? ?? 0;
    _isHighFloor = widget.propertyToEdit?['isHighFloor'] as bool? ?? false;

    // Initialize with existing image if editing
    final imagePath = widget.propertyToEdit?['imagePath']?.toString();
    if (imagePath != null && imagePath.isNotEmpty) {
      _selectedImagePath = imagePath;
    }

    // Initialize location if available
    final latitude = widget.propertyToEdit?['latitude'];
    final longitude = widget.propertyToEdit?['longitude'];
    if (latitude != null && longitude != null) {
      try {
        _selectedLocation = LatLng(
          double.parse(latitude.toString()),
          double.parse(longitude.toString()),
        );
      } catch (e) {
        print('⚠️ Error parsing location coordinates: $e');
        _selectedLocation = null;
      }
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
    _pageController.dispose();
    super.dispose();
  }

  // Enhanced image picker with better error handling
  Future<void> _pickImageFromGallery() async {
    try {
      print('📷 Picking image from gallery...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && image.path.isNotEmpty) {
        // Verify file exists and is readable
        final file = File(image.path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('📷 Image selected: ${image.path} (${fileSize} bytes)');

          setState(() {
            _selectedImagePath = image.path;
          });
          _showSuccessMessage('Image selected successfully!');
        } else {
          _showErrorMessage('Selected image file is not accessible.');
        }
      } else {
        print('📷 No image selected from gallery');
      }
    } catch (e) {
      print('❌ Error picking image from gallery: $e');
      _showErrorMessage('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      print('📷 Taking photo with camera...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && image.path.isNotEmpty) {
        // Verify file exists and is readable
        final file = File(image.path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('📷 Photo taken: ${image.path} (${fileSize} bytes)');

          setState(() {
            _selectedImagePath = image.path;
          });
          _showSuccessMessage('Photo taken successfully!');
        } else {
          _showErrorMessage('Captured photo is not accessible.');
        }
      } else {
        print('📷 No photo taken');
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      _showErrorMessage('Failed to take photo: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
    _showSuccessMessage('Image removed');
  }

  // AI Price Prediction with better error handling
  Future<void> _predictPrice() async {
    if (!_canPredictPrice()) {
      _showErrorMessage('Please fill in all required fields for price prediction');
      return;
    }

    setState(() => _isPredictingPrice = true);

    try {
      print('🤖 Predicting price with AI...');
      final requestBody = {
        'houseType': _houseType,
        'size': int.tryParse(_sizeController.text) ?? 0,
        'bedrooms': int.tryParse(_bedroomsController.text) ?? 0,
        'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
        'region': _regionController.text.trim(),
        'city': _cityController.text.trim(),
        'isHighFloor': _isHighFloor,
      };

      print('🤖 Price prediction request: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConfig.predictPriceUrl),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      ).timeout(ApiConfig.connectionTimeout);

      print('🤖 Price prediction response: ${response.statusCode}');
      print('🤖 Price prediction body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pricePrediction = data;
          if (data['averagePrice'] != null) {
            _selectedPrice = data['averagePrice'].toDouble();
            _priceController.text = _selectedPrice!.toStringAsFixed(0);
            _calculatePricePerM2();
          }
        });
        _showSuccessMessage('Price prediction completed!');
      } else {
        print('❌ Price prediction failed: ${response.statusCode}');
        _showErrorMessage('Price prediction not available');
      }
    } catch (e) {
      print('❌ Price prediction error: $e');
      _showErrorMessage('Price prediction service unavailable');
    } finally {
      setState(() => _isPredictingPrice = false);
    }
  }

  bool _canPredictPrice() {
    try {
      return _sizeController.text.trim().isNotEmpty &&
          _bedroomsController.text.trim().isNotEmpty &&
          _bathroomsController.text.trim().isNotEmpty &&
          _regionController.text.trim().isNotEmpty &&
          _cityController.text.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _calculatePricePerM2() {
    try {
      final priceText = _priceController.text.trim();
      final sizeText = _sizeController.text.trim();

      if (priceText.isEmpty || sizeText.isEmpty) return;

      final price = double.tryParse(priceText);
      final size = int.tryParse(sizeText);

      if (price != null && size != null && size > 0) {
        final pricePerM2 = price / size;
        _pricePerM2Controller.text = pricePerM2.toStringAsFixed(2);
      }
    } catch (e) {
      print('⚠️ Error calculating price per m²: $e');
    }
  }

  // Location selection
  Future<void> _selectLocation() async {
    try {
      print('📍 Opening location picker...');
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
        _selectedAddress = 'Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)}';
        _showSuccessMessage('Location selected successfully!');
      }
    } catch (e) {
      print('❌ Error selecting location: $e');
      _showErrorMessage('Error opening map: $e');
    }
  }

  // Enhanced form submission with detailed logging
  Future<void> _submitForm() async {
    try {
      print('📝 Form submission started...');

      if (_currentPage < 2) {
        _nextPage();
        return;
      }

      // Pre-submission validation
      if (!_validateFormForSubmission()) {
        return;
      }

      setState(() => _isLoading = true);

      // Determine endpoint and method
      Uri uri;
      String httpMethod;

      if (widget.propertyToEdit != null) {
        final propertyId = widget.propertyToEdit?['id'];
        if (propertyId == null) {
          _showErrorMessage('Error: Property ID is missing');
          setState(() => _isLoading = false);
          return;
        }
        uri = Uri.parse(ApiConfig.updatePropertyUrl(propertyId));
        httpMethod = 'PUT';
        print('📝 Updating property ID: $propertyId');
      } else {
        uri = Uri.parse(ApiConfig.addPropertyUrl);
        httpMethod = 'POST';
        print('📝 Creating new property');
      }

      print('📝 API Endpoint: $uri');
      print('📝 HTTP Method: $httpMethod');

      // Validate image file before proceeding
      if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
        _showErrorMessage('Please select an image for your property');
        setState(() => _isLoading = false);
        return;
      }

      final imageFile = File(_selectedImagePath!);
      if (!await imageFile.exists()) {
        _showErrorMessage('Selected image file no longer exists. Please select another image.');
        setState(() => _isLoading = false);
        return;
      }

      // Create multipart request
      final request = http.MultipartRequest(httpMethod, uri);

      // Calculate price per m² if not provided
      if (_pricePerM2Controller.text.isEmpty) {
        _calculatePricePerM2();
      }

      // Prepare form fields
      final fields = _prepareFormFields();
      print('📝 Form fields: $fields');

      request.fields.addAll(fields);

      // Add image file
      try {
        await _addImageToRequest(request);
      } catch (e) {
        _showErrorMessage('Failed to process image: $e');
        setState(() => _isLoading = false);
        return;
      }

      // Set headers for multipart request
      request.headers.addAll(ApiConfig.multipartHeaders);

      print('📝 Sending request...');

      // Send request with timeout
      http.StreamedResponse? streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          ApiConfig.sendTimeout,
          onTimeout: () {
            throw Exception('Request timeout - please check your internet connection');
          },
        );
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorMessage('Network error: $e');
        return;
      }

      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (!mounted) return;

      print('📝 Response status: ${response.statusCode}');
      print('📝 Response body: ${response.body}');

      if (ApiConfig.isSuccessStatusCode(response.statusCode)) {
        final successMessage = widget.propertyToEdit != null
            ? 'Property updated successfully!'
            : 'Property added successfully!';
        _showSuccessMessage(successMessage);

        // Add delay before navigation to ensure user sees success message
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _handleApiError(response);
      }

    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      print('❌ Form submission error: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        _showErrorMessage('An error occurred: ${e.toString()}');
      }
    }
  }

  bool _validateFormForSubmission() {
    try {
      // Validate form
      if (_formKey.currentState?.validate() != true) {
        print('❌ Form validation failed');
        return false;
      }

      // Check required image
      if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
        _showErrorMessage('Please add at least one property image');
        return false;
      }

      // Validate user session
      if (_userId <= 0) {
        _showErrorMessage('Error: Invalid user session. Please login again.');
        return false;
      }

      // Check required fields using Map instead of records
      final requiredFields = {
        'House Type': _houseType,
        'Size': _sizeController.text.trim(),
        'Bedrooms': _bedroomsController.text.trim(),
        'Bathrooms': _bathroomsController.text.trim(),
        'Region': _regionController.text.trim(),
        'City': _cityController.text.trim(),
        'Price': _priceController.text.trim(),
      };

      for (final entry in requiredFields.entries) {
        if (entry.value.isEmpty) {
          _showErrorMessage('${entry.key} is required');
          return false;
        }
      }

      // Validate numeric fields
      final sizeValue = int.tryParse(_sizeController.text.trim());
      if (sizeValue == null || sizeValue <= 0) {
        _showErrorMessage('Please enter a valid size');
        return false;
      }

      final bedroomsValue = int.tryParse(_bedroomsController.text.trim());
      if (bedroomsValue == null || bedroomsValue < 0) {
        _showErrorMessage('Please enter a valid number of bedrooms');
        return false;
      }

      final bathroomsValue = int.tryParse(_bathroomsController.text.trim());
      if (bathroomsValue == null || bathroomsValue < 0) {
        _showErrorMessage('Please enter a valid number of bathrooms');
        return false;
      }

      final priceValue = double.tryParse(_priceController.text.trim());
      if (priceValue == null || priceValue <= 0) {
        _showErrorMessage('Please enter a valid price');
        return false;
      }

      print('✅ Form validation passed');
      return true;
    } catch (e) {
      print('❌ Validation error: $e');
      _showErrorMessage('Validation error: $e');
      return false;
    }
  }

  Map<String, String> _prepareFormFields() {
    try {
      final fields = <String, String>{
        // Required fields (marked with * in API)
        'HouseType': _houseType ?? 'Apartment',
        'Size': _sizeController.text.trim(),
        'Bedrooms': _bedroomsController.text.trim(),
        'Bathrooms': _bathroomsController.text.trim(),
        'Region': _regionController.text.trim(),
        'City': _cityController.text.trim(),
        'Price': _priceController.text.trim(),

        // Optional fields
        'UserId': _userId.toString(),
        'Status': _status.toString(),
        'IsHighFloor': _isHighFloor.toString(),
      };

      // Add optional fields only if they have values
      if (_totalRoomsController.text.trim().isNotEmpty) {
        fields['TotalRooms'] = _totalRoomsController.text.trim();
      }
      if (_pricePerM2Controller.text.trim().isNotEmpty) {
        fields['PricePerM2'] = _pricePerM2Controller.text.trim();
      }

      // Add location if selected
      if (_selectedLocation != null) {
        fields['Latitude'] = _selectedLocation!.latitude.toString();
        fields['Longitude'] = _selectedLocation!.longitude.toString();
      }

      return fields;
    } catch (e) {
      print('❌ Error preparing form fields: $e');
      // Return minimal required fields
      return {
        'HouseType': _houseType ?? 'Apartment',
        'Size': _sizeController.text.trim(),
        'Bedrooms': _bedroomsController.text.trim(),
        'Bathrooms': _bathroomsController.text.trim(),
        'Region': _regionController.text.trim(),
        'City': _cityController.text.trim(),
        'Price': _priceController.text.trim(),
        'UserId': _userId.toString(),
        'Status': '0',
        'IsHighFloor': 'false',
      };
    }
  }

  Future<void> _addImageToRequest(http.MultipartRequest request) async {
    try {
      if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
        throw Exception('No image path provided');
      }

      final file = File(_selectedImagePath!);
      if (!await file.exists()) {
        throw Exception('Image file does not exist at path: $_selectedImagePath');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty (0 bytes)');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('Image file is too large (${fileSize} bytes). Maximum size is 10MB.');
      }

      print('📷 Adding image to request: $_selectedImagePath (${fileSize} bytes)');

      final imageFile = await http.MultipartFile.fromPath(
        'ImagePath', // Exact field name from API spec
        _selectedImagePath!,
      );
      request.files.add(imageFile);
      print('📷 Image added to request successfully');
    } catch (e) {
      print('❌ Error adding image to request: $e');
      throw Exception('Failed to process image: $e');
    }
  }

  void _handleApiError(http.Response response) {
    print('❌ API Error: ${response.statusCode}');
    print('❌ API Error Body: ${response.body}');

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
      _showErrorMessage(ApiConfig.getErrorMessage(response.statusCode));
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Debug methods for testing
  Future<void> _testConnection() async {
    try {
      _showSuccessMessage('Testing API connection...');

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/health'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      _showSuccessMessage('API connection test: ${response.statusCode}');
    } catch (e) {
      _showErrorMessage('API connection failed: $e');
    }
  }

  void _debugFormData() {
    final formData = _prepareFormFields();
    final imageValid = _selectedImagePath != null && File(_selectedImagePath!).existsSync();

    final debugInfo = '''
Form Data:
${formData.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

Image: ${_selectedImagePath ?? 'None'}
Image Valid: $imageValid
User ID: $_userId
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Form Debug Data'),
        content: SingleChildScrollView(
          child: Text(debugInfo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
                    _buildImagePage(),
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
          // Debug info
          if (ApiConfig.isDevelopment)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User ID: $_userId'),
                        Text('API URL: ${ApiConfig.addPropertyUrl}'),
                        Text('Has Image: ${_selectedImagePath != null}'),
                        Text('Session Valid: ${UserSession.validateSession()}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
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

  Widget _buildImagePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Property Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a high-quality image of your property',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Current image display
          if (_selectedImagePath != null && _selectedImagePath!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: FutureBuilder<bool>(
                      future: File(_selectedImagePath!).exists(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data == true) {
                          return Image.file(
                            File(_selectedImagePath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Error loading image: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error, size: 50, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Error loading image'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
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
                  _pickImageFromGallery,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildImageButton(
                  'Camera',
                  Icons.camera_alt,
                  _pickImageFromCamera,
                ),
              ),
            ],
          ),

          // Image requirements info
          const SizedBox(height: 20),
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
                      Icons.info_outline,
                      color: Colors.blue.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Image Guidelines',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Use high-quality, well-lit photos\n'
                      '• Show the property\'s best features\n'
                      '• Ensure the image is clear and focused\n'
                      '• Maximum file size: 10MB',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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

            // House Type (Required)
            _buildDropdown(),
            const SizedBox(height: 16),

            // Size (Required)
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

            // Bedrooms and Bathrooms (Required)
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

            // Total Rooms (Optional)
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

          // Location section (Required)
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

          // Location picker (Optional)
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
                          : 'Select location on map (optional)',
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

          // AI Price Prediction (Optional)
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
                    'Get an AI-powered price estimate',
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
                    'Predicted Price Range',
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
                        'Low',
                        _pricePrediction!['lowestPrice']?.toDouble() ?? 0.0,
                        Colors.orange.shade300,
                      ),
                      _buildPriceOption(
                        'Average',
                        _pricePrediction!['averagePrice']?.toDouble() ?? 0.0,
                        Colors.blue.shade300,
                      ),
                      _buildPriceOption(
                        'High',
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

          // Manual price input (Required)
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
              style: const TextStyle(
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
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _previousPage,
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
                onPressed: _isLoading ? null : () {
                  try {
                    _submitForm();
                  } catch (e) {
                    print('❌ Button press error: $e');
                    _showErrorMessage('Error: $e');
                  }
                },
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
      return 'Save Changes';
    } else {
      return 'Post Property';
    }
  }
}