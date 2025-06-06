// lib/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddPropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? propertyToEdit;

  const AddPropertyScreen({Key? key, this.propertyToEdit}) : super(key: key);

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;

  // Replace with your actual API base URL
  static const String API_BASE_URL = 'https://getawayanapp.runasp.net';

  // Form controllers matching the API schema
  late final TextEditingController _sizeController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _regionController;
  late final TextEditingController _cityController;
  late final TextEditingController _priceController;

  late String _houseType;
  late int _status;
  late int _userId; // You'll need to get this from your authentication system

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if editing
    _sizeController = TextEditingController(text: widget.propertyToEdit?['size']?.toString() ?? '');
    _bedroomsController = TextEditingController(text: widget.propertyToEdit?['bedrooms']?.toString() ?? '');
    _bathroomsController = TextEditingController(text: widget.propertyToEdit?['bathrooms']?.toString() ?? '');
    _regionController = TextEditingController(text: widget.propertyToEdit?['region'] ?? '');
    _cityController = TextEditingController(text: widget.propertyToEdit?['city'] ?? '');
    _priceController = TextEditingController(text: widget.propertyToEdit?['price']?.toString() ?? '');

    _houseType = widget.propertyToEdit?['houseType'] ?? 'Apartment';
    _status = widget.propertyToEdit?['status'] ?? 0; // 0 = Available, 1 = Sold, etc.
    _selectedImagePath = widget.propertyToEdit?['imagePath'];

    // TODO: Get actual user ID from your authentication system
    _userId = 1; // This should come from your logged-in user data
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Validation functions for required fields
  String? _validateRequired(String? value, String fieldName) {
    if (value?.isEmpty ?? true) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateSize(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Size is required';
    }
    final size = int.tryParse(value!);
    if (size == null || size <= 0) {
      return 'Please enter a valid size';
    }
    if (size > 10000) {
      return 'Size seems too large, please check';
    }
    return null;
  }

  String? _validateBedrooms(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Number of bedrooms is required';
    }
    final bedrooms = int.tryParse(value!);
    if (bedrooms == null || bedrooms < 0) {
      return 'Please enter a valid number of bedrooms';
    }
    if (bedrooms > 20) {
      return 'Number of bedrooms seems too high';
    }
    return null;
  }

  String? _validateBathrooms(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Number of bathrooms is required';
    }
    final bathrooms = int.tryParse(value!);
    if (bathrooms == null || bathrooms < 0) {
      return 'Please enter a valid number of bathrooms';
    }
    if (bathrooms > 20) {
      return 'Number of bathrooms seems too high';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Price is required';
    }
    final price = double.tryParse(value!);
    if (price == null || price <= 0) {
      return 'Please enter a valid price';
    }
    if (price > 1000000000) {
      return 'Price seems too high, please check';
    }
    return null;
  }

  String? _validateImage() {
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
      return 'Property image is required';
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      _showErrorMessage('Failed to pick image: $e');
    }
  }

  Future<void> _submitForm() async {
    // Validate image first since it's not in the form
    final imageError = _validateImage();
    if (imageError != null) {
      _showErrorMessage(imageError);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create multipart request
      final uri = Uri.parse('$API_BASE_URL/api/properties/add');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'Accept': '*/*',
        // Add authorization header if needed
        // 'Authorization': 'Bearer $your_token_here',
      });

      // Add form fields
      request.fields.addAll({
        'UserId': _userId.toString(),
        'HouseType': _houseType,
        'Size': _sizeController.text.trim(),
        'Bedrooms': _bedroomsController.text.trim(),
        'Bathrooms': _bathroomsController.text.trim(),
        'Status': _status.toString(),
        'Region': _regionController.text.trim(),
        'City': _cityController.text.trim(),
        'Price': _priceController.text.trim(),
      });

      // Add image file
      if (_selectedImagePath != null) {
        final imageFile = await http.MultipartFile.fromPath(
          'ImagePath',
          _selectedImagePath!,
        );
        request.files.add(imageFile);
      }

      // Debug logging
      print('Request URL: ${request.url}');
      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.map((f) => f.field)}');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (!mounted) return;

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        _showSuccessMessage('Property added successfully!');

        // Parse response if needed
        try {
          final responseData = json.decode(response.body);
          // You can use responseData here if needed

          // Return to previous screen with success
          Navigator.pop(context, true);
        } catch (e) {
          // If response is not JSON, still consider it success
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 400) {
        // Handle validation errors
        _handle400ValidationError(response.body);
      } else if (response.statusCode == 401) {
        _showErrorMessage('Unauthorized. Please log in again.');
      } else if (response.statusCode == 413) {
        _showErrorMessage('Image file is too large. Please choose a smaller image.');
      } else if (response.statusCode == 422) {
        _showErrorMessage('Invalid data format. Please check your inputs.');
      } else {
        _showErrorMessage('Server error (${response.statusCode}). Please try again later.');
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        print('Network error: $e');
        _showErrorMessage('Network error. Please check your internet connection and try again.');
      }
    }
  }

  void _handle400ValidationError(String responseBody) {
    try {
      final errorData = json.decode(responseBody);

      if (errorData.containsKey('errors')) {
        // Handle validation errors object
        final errors = errorData['errors'] as Map<String, dynamic>;
        final List<String> errorMessages = [];

        errors.forEach((field, messages) {
          if (messages is List) {
            for (final message in messages) {
              errorMessages.add('$field: $message');
            }
          } else {
            errorMessages.add('$field: $messages');
          }
        });

        _showErrorMessage('Validation errors:\n${errorMessages.join('\n')}');
      } else if (errorData.containsKey('message')) {
        _showErrorMessage(errorData['message']);
      } else if (errorData.containsKey('title')) {
        String message = errorData['title'];
        if (errorData.containsKey('detail')) {
          message += ': ${errorData['detail']}';
        }
        _showErrorMessage(message);
      } else {
        _showErrorMessage('Validation failed. Please check all required fields:\n'
            '• Property image is required\n'
            '• House type, size, bedrooms, bathrooms are required\n'
            '• Region, city, and price are required');
      }
    } catch (e) {
      _showErrorMessage('Please check all required fields and try again.');
    }
  }

  void _showErrorMessage(String message) {
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
      body: Stack(
        children: [
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
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildImagePicker(),
                    const SizedBox(height: 20),
                    _buildForm(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 16),
        Text(
          widget.propertyToEdit != null ? 'Edit Property' : 'Add New Property',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _validateImage() != null ? Colors.red : Colors.white.withOpacity(0.2),
            width: _validateImage() != null ? 2 : 1,
          ),
        ),
        child: _selectedImagePath != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            File(_selectedImagePath!),
            fit: BoxFit.cover,
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 50,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Property Image *',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            if (_validateImage() != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Image is required',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // House Type (Required)
            _buildDropdown(),
            const SizedBox(height: 16),

            // Size (Required)
            _buildTextField(
              controller: _sizeController,
              label: 'Size (m²) *',
              keyboardType: TextInputType.number,
              validator: _validateSize,
            ),
            const SizedBox(height: 16),

            // Bedrooms and Bathrooms Row (Both Required)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _bedroomsController,
                    label: 'Bedrooms *',
                    keyboardType: TextInputType.number,
                    validator: _validateBedrooms,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _bathroomsController,
                    label: 'Bathrooms *',
                    keyboardType: TextInputType.number,
                    validator: _validateBathrooms,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Dropdown
            _buildStatusDropdown(),
            const SizedBox(height: 16),

            // Region (Required)
            _buildTextField(
              controller: _regionController,
              label: 'Region *',
              validator: (value) => _validateRequired(value, 'Region'),
            ),
            const SizedBox(height: 16),

            // City (Required)
            _buildTextField(
              controller: _cityController,
              label: 'City *',
              validator: (value) => _validateRequired(value, 'City'),
            ),
            const SizedBox(height: 16),

            // Price (Required)
            _buildTextField(
              controller: _priceController,
              label: 'Price (\$) *',
              keyboardType: TextInputType.number,
              validator: _validatePrice,
            ),
            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),
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
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
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
        ),
      ],
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
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
          widget.propertyToEdit != null ? 'Save Changes' : 'Add Property',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}