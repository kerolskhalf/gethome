// lib/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

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

  String? _selectedImagePath;

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
  late String _status;
  late bool _isHighFloor;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
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

    _houseType = widget.propertyToEdit?['houseType']?.toString() ?? 'Apartment';
    _status = widget.propertyToEdit?['status']?.toString() ?? 'Available';
    _isHighFloor = widget.propertyToEdit?['isHighFloor'] as bool? ?? false;

    final imagePath = widget.propertyToEdit?['imagePath']?.toString();
    if (imagePath != null && imagePath.isNotEmpty) {
      _selectedImagePath = imagePath;
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

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && image.path.isNotEmpty) {
        final file = File(image.path);
        if (await file.exists()) {
          setState(() {
            _selectedImagePath = image.path;
          });
          _showSuccessMessage('Image selected successfully!');
        }
      }
    } catch (e) {
      _showErrorMessage('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && image.path.isNotEmpty) {
        final file = File(image.path);
        if (await file.exists()) {
          setState(() {
            _selectedImagePath = image.path;
          });
          _showSuccessMessage('Photo taken successfully!');
        }
      }
    } catch (e) {
      _showErrorMessage('Failed to take photo: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
    _showSuccessMessage('Image removed');
  }

  void _calculatePricePerM2() {
    try {
      final priceText = _priceController.text.trim();
      final sizeText = _sizeController.text.trim();

      if (priceText.isEmpty || sizeText.isEmpty) return;

      final price = double.tryParse(priceText);
      final size = double.tryParse(sizeText);

      if (price != null && size != null && size > 0) {
        final pricePerM2 = price / size;
        _pricePerM2Controller.text = pricePerM2.toStringAsFixed(2);
      }
    } catch (e) {
      // Ignore calculation errors
    }
  }

  Future<void> _submitForm() async {
    if (_currentPage < 2) {
      _nextPage();
      return;
    }

    if (!_validateFormForSubmission()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
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
      } else {
        uri = Uri.parse(ApiConfig.addPropertyUrl);
        httpMethod = 'POST';
      }

      final request = http.MultipartRequest(httpMethod, uri);

      // Calculate price per m² if not provided
      if (_pricePerM2Controller.text.isEmpty) {
        _calculatePricePerM2();
      }

      // Prepare form fields matching the PropertyDTO
      final fields = _prepareFormFields();
      request.fields.addAll(fields);

      // Debug: Print fields being sent
      print('Sending fields: $fields');

      // Add image file
      if (_selectedImagePath != null) {
        final imageFile = await http.MultipartFile.fromPath(
          'ImagePath',
          _selectedImagePath!,
        );
        request.files.add(imageFile);
        print('Added image file: $_selectedImagePath');
      }

      request.headers.addAll(ApiConfig.multipartHeaders);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (!mounted) return;

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final successMessage = widget.propertyToEdit != null
            ? 'Property updated successfully!'
            : 'Property added successfully!';
        _showSuccessMessage(successMessage);

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Parse error response
        String errorMessage = 'Failed to save property. Please try again.';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['errors'] != null) {
            // Handle validation errors
            final errors = errorData['errors'] as Map<String, dynamic>;
            final errorList = <String>[];
            errors.forEach((key, value) {
              if (value is List) {
                errorList.addAll(value.cast<String>());
              } else {
                errorList.add(value.toString());
              }
            });
            errorMessage = errorList.join('\n');
          }
        } catch (e) {
          print('Error parsing response: $e');
        }
        _showErrorMessage(errorMessage);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorMessage('Network error: ${e.toString()}');
      }
      print('Network error: $e');
    }
  }

  bool _validateFormForSubmission() {
    // Validate all required fields
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
      _showErrorMessage('Please add a property image');
      return false;
    }

    // Validate Size
    if (_sizeController.text.trim().isEmpty) {
      _showErrorMessage('Property size is required');
      return false;
    }
    final size = double.tryParse(_sizeController.text.trim());
    if (size == null || size <= 0 || size > 1000000) {
      _showErrorMessage('Size must be between 1 and 1,000,000 m²');
      return false;
    }

    // Validate Bedrooms
    if (_bedroomsController.text.trim().isEmpty) {
      _showErrorMessage('Number of bedrooms is required');
      return false;
    }
    final bedrooms = int.tryParse(_bedroomsController.text.trim());
    if (bedrooms == null || bedrooms < 1 || bedrooms > 10) {
      _showErrorMessage('Bedrooms must be between 1 and 10');
      return false;
    }

    // Validate Bathrooms
    if (_bathroomsController.text.trim().isEmpty) {
      _showErrorMessage('Number of bathrooms is required');
      return false;
    }
    final bathrooms = int.tryParse(_bathroomsController.text.trim());
    if (bathrooms == null || bathrooms < 1 || bathrooms > 10) {
      _showErrorMessage('Bathrooms must be between 1 and 10');
      return false;
    }

    // Validate Total Rooms
    if (_totalRoomsController.text.trim().isNotEmpty) {
      final totalRooms = int.tryParse(_totalRoomsController.text.trim());
      if (totalRooms == null || totalRooms < 0 || totalRooms > 50) {
        _showErrorMessage('Total rooms must be between 0 and 50');
        return false;
      }
    }

    // Validate Region
    if (_regionController.text.trim().isEmpty) {
      _showErrorMessage('Region is required');
      return false;
    }

    // Validate City
    if (_cityController.text.trim().isEmpty) {
      _showErrorMessage('City is required');
      return false;
    }

    // Validate Price
    if (_priceController.text.trim().isEmpty) {
      _showErrorMessage('Price is required');
      return false;
    }
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 1000 || price > 999999999) {
      _showErrorMessage('Price must be between 1,000 and 999,999,999');
      return false;
    }

    return true;
  }

  Map<String, String> _prepareFormFields() {
    // Calculate price per m² if empty
    if (_pricePerM2Controller.text.trim().isEmpty) {
      _calculatePricePerM2();
    }

    // Match PropertyDTO fields exactly
    return {
      'UserId': UserSession.getCurrentUserId().toString(),
      'HouseType': _houseType,
      'Size': _sizeController.text.trim(),
      'Bedrooms': _bedroomsController.text.trim(),
      'Bathrooms': _bathroomsController.text.trim(),
      'TotalRooms': _totalRoomsController.text.trim().isEmpty
          ? '0'
          : _totalRoomsController.text.trim(),
      'IsHighFloor': _isHighFloor ? 'true' : 'false',
      'Status': _status == 'Available' ? '0' : '1', // 0 = Available, 1 = NotAvailable
      'Region': _regionController.text.trim(),
      'City': _cityController.text.trim(),
      'Price': _priceController.text.trim(),
      'PricePerM2': _pricePerM2Controller.text.trim().isEmpty
          ? '0'
          : _pricePerM2Controller.text.trim(),
    };
  }

  void _nextPage() {
    if (_currentPage < 2) {
      // Validate current page before moving to next
      if (_currentPage == 0 && (_selectedImagePath == null || _selectedImagePath!.isEmpty)) {
        _showErrorMessage('Please add a property image before continuing');
        return;
      }

      if (_currentPage == 1) {
        // Validate basic info
        if (_sizeController.text.trim().isEmpty ||
            _bedroomsController.text.trim().isEmpty ||
            _bathroomsController.text.trim().isEmpty) {
          _showErrorMessage('Please fill in all required fields');
          return;
        }
      }

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
            'Add a high-quality image of your property *',
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
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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
                final size = double.tryParse(value!);
                if (size == null || size <= 0 || size > 1000000) {
                  return 'Size must be between 1 and 1,000,000 m²';
                }
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
                      if (bedrooms == null || bedrooms < 1 || bedrooms > 10) {
                        return 'Must be 1-10';
                      }
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
                      if (bathrooms == null || bathrooms < 1 || bathrooms > 10) {
                        return 'Must be 1-10';
                      }
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
              label: 'Total Rooms (optional)',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  final totalRooms = int.tryParse(value!);
                  if (totalRooms == null || totalRooms < 0 || totalRooms > 50) {
                    return 'Must be 0-50';
                  }
                }
                return null;
              },
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
          const SizedBox(height: 20),

          // Price section
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
                      return 'Price must be 1,000 - 999,999,999';
                    }
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'High Floor Property',
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
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability Status',
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
              value: _status,
              isExpanded: true,
              dropdownColor: const Color(0xFF234E70),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem<String>(value: 'Available', child: Text('Available')),
                DropdownMenuItem<String>(value: 'NotAvailable', child: Text('Not Available')),
              ],
              onChanged: (String? newValue) {
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