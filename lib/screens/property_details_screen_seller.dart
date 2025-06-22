// lib/screens/add_property_screen.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';
import 'map_screen.dart';

class AddPropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? propertyToEdit;

  const AddPropertyScreen({Key? key, this.propertyToEdit}) : super(key: key);

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // FIXED: Separate form keys for each page to avoid conflicts
  final _page1FormKey = GlobalKey<FormState>();
  final _page2FormKey = GlobalKey<FormState>();
  final _page3FormKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  final ImagePicker _picker = ImagePicker();

  // FIXED: Multiple image handling (max 10 images)
  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  File? _coverImage;
  String? _existingCoverImageUrl;
  static const int maxImages = 10;

  // Form controllers
  late final TextEditingController _sizeController;
  late final TextEditingController _priceController;
  late final TextEditingController _pricePerM2Controller;
  late final TextEditingController _floorController;
  late final TextEditingController _manualAddressController; // ADDED: Manual address controller

  // FIXED: Updated property types to match the new mapping
  String _propertyType = 'Apartment';
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _totalRooms = 2;
  bool _isHighFloor = false;
  bool _isAvailable = true;
  bool _isFurnished = false;
  int _floor = 1;

  // FIXED: City-Region data and controllers
  String? _selectedCity;
  String? _selectedRegion;
  List<String> _availableRegions = [];

  // FIXED: Egypt Cities and Regions mapping
  static const Map<String, List<String>> cityRegionsMap = {
    "alexandria": ["abu qir", "agami", "amreya", "bacchus", "cleopatra", "mandara", "manshiyya", "montazah", "ras al-bar", "ras el tin", "schutz", "sidi beshr", "sidi gaber", "smoha", "sporting", "stanley", "tersa", "victoria", "wardian", "warraq", "zahraa al maadi", "zamalek", "zezenia", "zohour district"],
    "aswan": ["aswan city"],
    "asyut": ["asyut city"],
    "beheira": ["agami", "damanhour"],
    "beni suef": ["beni suef city", "new beni suef"],
    "cairo": ["6th of october", "ain shams", "al manial", "almazah", "ard el lewa", "asafra", "bahtim", "bolkly", "camp caesar", "dar al-salaam", "dhahria", "dokki", "downtown cairo", "el max", "faisal", "fleming", "gamasa", "gesr al suez", "gomrok", "hadayek al-ahram", "hadayek al-kobba", "hadayek helwan", "haram", "heliopolis", "helmeyat el zaytoun", "helwan", "imbaba", "katameya", "mohandessin", "mokattam", "moneeb", "mostakbal city", "nasr city", "new cairo - el tagamoa", "new capital city", "new heliopolis", "new nozha", "obour city", "qasr al-nil", "rehab city", "roshdy", "saba pasha", "salam city", "san stefano", "sharq district", "shubra", "shubra al-khaimah", "zamalek"],
    "dakahlia": ["belqas", "mansura", "mit ghamr"],
    "damietta": ["damietta city", "new damietta"],
    "gharbia": ["banha", "zezenia"],
    "giza": ["6th of october", "hadayek 6th of october", "haram", "moharam bik", "pyramids", "sheikh zayed"],
    "ismailia": ["ismailia city"],
    "kafr al-sheikh": ["kafr al-sheikh city"],
    "matruh": ["alamein", "marsa matrouh"],
    "minya": ["minya city"],
    "monufia": ["shibin el-kom"],
    "port said": ["port fouad"],
    "qalyubia": ["10th of ramadan", "qalyub"],
    "qena": ["qena city"],
    "red sea": ["hurghada", "sharm al-sheikh"],
    "sharqia": ["zagazig"],
    "south sinai": ["sharm al-sheikh"],
    "suez": ["suez district"]
  };

  // Location
  LatLng? _selectedLocation;
  String _locationText = 'Select location on map or enter manually';
  bool _useMapLocation = true;

  // AI Integration
  Map<String, dynamic>? _aiPrediction;
  bool _isPredicting = false;
  bool _showPredictionResults = false;

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Change detection for updates
  bool _hasChanges = false;
  Map<String, dynamic>? _originalPropertyData;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingData();
  }

  void _initializeControllers() {
    _sizeController = TextEditingController();
    _priceController = TextEditingController();
    _pricePerM2Controller = TextEditingController();
    _floorController = TextEditingController(text: '1');
    _manualAddressController = TextEditingController(); // ADDED: Initialize manual address controller
  }

  void _loadExistingData() {
    if (widget.propertyToEdit != null) {
      final property = widget.propertyToEdit!;

      // Load basic data
      _propertyType = property['houseType'] ?? 'Apartment';
      _bedrooms = property['bedrooms'] ?? 1;
      _bathrooms = property['bathrooms'] ?? 1;
      _totalRooms = property['totalRooms'] ?? 2;
      _isHighFloor = property['isHighFloor'] ?? false;
      _isFurnished = property['isFurnished'] ?? false;
      _isAvailable = property['status'] == 0;
      _floor = property['floor'] ?? 1;

      // Load text fields
      _sizeController.text = property['size']?.toString() ?? '';
      _priceController.text = property['price']?.toString() ?? '';
      _pricePerM2Controller.text = property['pricePerM2']?.toString() ?? '';
      _floorController.text = _floor.toString();

      // FIXED: Load city and region
      _selectedCity = property['city']?.toLowerCase();
      _selectedRegion = property['region']?.toLowerCase();
      if (_selectedCity != null) {
        _availableRegions = cityRegionsMap[_selectedCity] ?? [];
      }

      // Load manual address if exists
      if (property['manualAddress'] != null) {
        _manualAddressController.text = property['manualAddress'];
        _useMapLocation = false;
      }

      // Load existing images
      if (property['coverImageUrl'] != null) {
        _existingCoverImageUrl = property['coverImageUrl'];
      }
      if (property['imageUrls'] != null && property['imageUrls'] is List) {
        _existingImageUrls = List<String>.from(property['imageUrls']);
      }

      _originalPropertyData = _getCurrentFormData();
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _priceController.dispose();
    _pricePerM2Controller.dispose();
    _floorController.dispose();
    _manualAddressController.dispose(); // ADDED: Dispose manual address controller
    _pageController.dispose();
    super.dispose();
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
                    _buildBasicInfoPage(),
                    _buildLocationAndDetailsPage(),
                    _buildPhotosAndPricePage(),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              widget.propertyToEdit != null ? 'Edit Property' : 'Add New Property',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // PAGE 1: Basic Information - FIXED with Form widget
  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _page1FormKey, // FIXED: Use page-specific form key
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // FIXED: Property Type with updated mapping
            _buildDropdownField(
              label: 'Property Type',
              icon: Icons.home,
              value: _propertyType,
              items: const ['Apartment', 'Duplex', 'Penthouse', 'Studio'],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _propertyType = value);
                  _checkForChanges();
                }
              },
            ),

            const SizedBox(height: 20),

            // Property Size
            _buildTextField(
              controller: _sizeController,
              label: 'Property Size (m²)',
              icon: Icons.square_foot,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter property size';
                }
                final size = double.tryParse(value!);
                if (size == null || size <= 0) {
                  return 'Please enter a valid size';
                }
                return null;
              },
              onChanged: (value) => _checkForChanges(),
            ),

            const SizedBox(height: 20),

            // Bedrooms and Bathrooms
            Row(
              children: [
                Expanded(
                  child: _buildCounterField(
                    label: 'Bedrooms',
                    icon: Icons.bed,
                    value: _bedrooms,
                    onChanged: (value) {
                      setState(() => _bedrooms = value);
                      _updateTotalRooms();
                      _checkForChanges();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCounterField(
                    label: 'Bathrooms',
                    icon: Icons.bathtub,
                    value: _bathrooms,
                    onChanged: (value) {
                      setState(() => _bathrooms = value);
                      _updateTotalRooms();
                      _checkForChanges();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Total Rooms (auto-calculated)
            _buildTextField(
              controller: TextEditingController(text: _totalRooms.toString()),
              label: 'Total Rooms',
              icon: Icons.room,
              enabled: false,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),

            // Floor
            _buildTextField(
              controller: _floorController,
              label: 'Floor Number',
              icon: Icons.layers,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final floor = int.tryParse(value);
                if (floor != null) {
                  setState(() {
                    _floor = floor;
                    _isHighFloor = floor >= 5;
                  });
                }
                _checkForChanges();
              },
            ),

            const SizedBox(height: 24),

            // Property Features
            const Text(
              'Property Features',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              title: 'Furnished',
              icon: Icons.chair,
              value: _isFurnished,
              onChanged: (value) {
                setState(() => _isFurnished = value);
                _checkForChanges();
              },
            ),

            _buildSwitchTile(
              title: 'High Floor (5+ floors)',
              icon: Icons.elevator,
              value: _isHighFloor,
              onChanged: (value) {
                setState(() => _isHighFloor = value);
                _checkForChanges();
              },
            ),

            _buildSwitchTile(
              title: 'Available for Sale/Rent',
              icon: Icons.check_circle,
              value: _isAvailable,
              onChanged: (value) {
                setState(() => _isAvailable = value);
                _checkForChanges();
              },
            ),
          ],
        ),
      ),
    );
  }

  // PAGE 2: Location and Details - FIXED with either map OR manual input
  Widget _buildLocationAndDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _page2FormKey, // FIXED: Use page-specific form key
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location & Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // FIXED: City Dropdown
            _buildDropdownField(
              label: 'City',
              icon: Icons.location_city,
              value: _selectedCity?.split(' ').map((word) =>
              word[0].toUpperCase() + word.substring(1)
              ).join(' '),
              items: cityRegionsMap.keys.map((city) =>
                  city.split(' ').map((word) =>
                  word[0].toUpperCase() + word.substring(1)
                  ).join(' ')
              ).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedCity = value.toLowerCase();
                    _selectedRegion = null;
                    _availableRegions = cityRegionsMap[_selectedCity] ?? [];
                  });
                  _checkForChanges();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a city';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // FIXED: Region Dropdown (dependent on city)
            _buildDropdownField(
              label: 'Region',
              icon: Icons.place,
              value: _selectedRegion?.split(' ').map((word) =>
              word[0].toUpperCase() + word.substring(1)
              ).join(' '),
              items: _availableRegions.map((region) =>
                  region.split(' ').map((word) =>
                  word[0].toUpperCase() + word.substring(1)
                  ).join(' ')
              ).toList(),
              onChanged: _selectedCity == null ? null : (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedRegion = value.toLowerCase();
                  });
                  _checkForChanges();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a region';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // FIXED: Location Input - Either Map OR Manual
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
                        Icons.location_on,
                        color: Colors.orange.withOpacity(0.8),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Specific Location (Optional)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Method Selection
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _useMapLocation = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _useMapLocation
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.map, color: Colors.white),
                          label: const Text(
                            'Use Map',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _useMapLocation = false;
                              _selectedLocation = null;
                              _locationText = 'Manual address selected';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_useMapLocation
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text(
                            'Manual Entry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_useMapLocation) ...[
                    // Map Location Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationText,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openMapForLocationSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                  ] else ...[
                    // Manual Address Entry
                    _buildTextField(
                      controller: _manualAddressController,
                      label: 'Enter Specific Address (Optional)',
                      icon: Icons.location_on,
                      keyboardType: TextInputType.text,
                      onChanged: (value) => _checkForChanges(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Example: Street name, building number, landmark',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PAGE 3: Photos and Pricing - FIXED with Form widget
  Widget _buildPhotosAndPricePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _page3FormKey, // FIXED: Use page-specific form key
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photos & Pricing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // FIXED: Multiple Photo Upload Section
            _buildPhotosSection(),

            const SizedBox(height: 24),

            // FIXED: AI Prediction Section
            _buildAIPredictionSection(),

            const SizedBox(height: 24),

            // Price Fields
            _buildTextField(
              controller: _priceController,
              label: 'Price (EGP)',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter the price';
                }
                final price = double.tryParse(value!);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
              onChanged: (value) {
                _calculatePricePerM2();
                _checkForChanges();
              },
            ),

            const SizedBox(height: 20),

            _buildTextField(
              controller: _pricePerM2Controller,
              label: 'Price per m² (EGP)',
              icon: Icons.calculate,
              keyboardType: TextInputType.number,
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Multiple Photos Section
  Widget _buildPhotosSection() {
    return Container(
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
                Icons.photo_camera,
                color: Colors.blue.withOpacity(0.8),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Property Photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedImages.length}/$maxImages',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to $maxImages photos. First photo will be the cover image.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Photo Grid
          if (_selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length + _existingImageUrls.length,
                itemBuilder: (context, index) {
                  if (index < _selectedImages.length) {
                    // New images
                    return _buildImageItem(_selectedImages[index], index, true);
                  } else {
                    // Existing images
                    final existingIndex = index - _selectedImages.length;
                    return _buildExistingImageItem(_existingImageUrls[existingIndex], existingIndex);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Add Photos Button
          if (_selectedImages.length < maxImages) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                    label: Text(
                      _selectedImages.isEmpty ? 'Add Photos' : 'Add More Photos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _takePicture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    'Camera',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageItem(File imageFile, int index, bool isNew) {
    final isCover = index == 0 && _selectedImages.isNotEmpty;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCover ? Colors.orange : Colors.white.withOpacity(0.3),
          width: isCover ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile,
              width: 160,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          if (isCover)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'COVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildExistingImageItem(String imageUrl, int index) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 160,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 160,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _removeExistingImage(index),
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
        ],
      ),
    );
  }

  // FIXED: AI Prediction Section
  Widget _buildAIPredictionSection() {
    return Container(
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
                color: Colors.purple.withOpacity(0.8),
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
                backgroundColor: Colors.purple.withOpacity(0.2),
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
                    '🤖 AI Prediction Results:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_aiPrediction!['predicted_price'] != null)
                    _buildPredictionRow('Predicted Price', '${_formatPrice(_aiPrediction!['predicted_price'])} EGP'),
                  if (_aiPrediction!['min_price'] != null && _aiPrediction!['max_price'] != null)
                    _buildPredictionRow('Price Range', '${_formatPrice(_aiPrediction!['min_price'])} - ${_formatPrice(_aiPrediction!['max_price'])} EGP'),
                  if (_aiPrediction!['avg_price'] != null)
                    _buildPredictionRow('Average Price', '${_formatPrice(_aiPrediction!['avg_price'])} EGP'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_aiPrediction!['avg_price'] != null) {
                              _priceController.text = _aiPrediction!['avg_price'].toStringAsFixed(0);
                              _calculatePricePerM2();
                              _showMessage('Average price applied!');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Use Average Price',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  // FIXED: Photo handling methods
  Future<void> _pickImages() async {
    if (_selectedImages.length >= maxImages) {
      _showMessage('Maximum $maxImages images allowed', isError: true);
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 70,
      );

      if (images.isNotEmpty) {
        final int availableSlots = maxImages - _selectedImages.length;
        final int imagesToAdd = images.length > availableSlots ? availableSlots : images.length;

        for (int i = 0; i < imagesToAdd; i++) {
          _selectedImages.add(File(images[i].path));
        }

        if (images.length > availableSlots) {
          _showMessage('Only $imagesToAdd images added. Maximum $maxImages allowed.', isError: true);
        } else {
          _showMessage('${images.length} image(s) added successfully!');
        }

        // Set first image as cover if none exists
        if (_coverImage == null && _selectedImages.isNotEmpty) {
          _coverImage = _selectedImages.first;
        }

        setState(() {});
        _checkForChanges();
      }
    } catch (e) {
      _showMessage('Error picking images: $e', isError: true);
    }
  }

  Future<void> _takePicture() async {
    if (_selectedImages.length >= maxImages) {
      _showMessage('Maximum $maxImages images allowed', isError: true);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        _selectedImages.add(File(image.path));

        // Set as cover if first image
        if (_coverImage == null) {
          _coverImage = File(image.path);
        }

        setState(() {});
        _checkForChanges();
        _showMessage('Photo captured successfully!');
      }
    } catch (e) {
      _showMessage('Error taking picture: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removedImage = _selectedImages.removeAt(index);

      // If removed image was cover, set new cover
      if (_coverImage == removedImage) {
        _coverImage = _selectedImages.isNotEmpty ? _selectedImages.first : null;
      }
    });
    _checkForChanges();
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
    _checkForChanges();
  }

  // FIXED: Map location selection (removed initialLocation parameter)
  void _openMapForLocationSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          isLocationPicker: true,
          onLocationSelected: (location) {
            setState(() {
              _selectedLocation = location;
              _locationText = 'Location selected (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})';
            });
            _checkForChanges();
          },
        ),
      ),
    );
  }

  // FIXED: AI Prediction with updated property type mapping
  Future<void> _predictPrice() async {
    if (!_validateFormForPrediction()) return;

    setState(() => _isPredicting = true);

    try {
      // FIXED: Use updated property type mapping
      final requestBody = {
        'property_type': _getPropertyTypeForAI(_propertyType),
        'area_m2': double.parse(_sizeController.text.trim()),
        'n_bedrooms': _bedrooms,
        'n_bathrooms': _bathrooms,
        'floor': _floor,
        'is_furnished': _isFurnished ? 1 : 0,
        'city': _getCityCodeForAI(_selectedCity ?? ''),
        'region': _getRegionCodeForAI(_selectedRegion ?? ''),
        'price_per_m2': _pricePerM2Controller.text.isNotEmpty
            ? double.parse(_pricePerM2Controller.text)
            : 0,
        'total_rooms': _totalRooms,
        'is_high_floor': _isHighFloor ? 1 : 0,
      };

      print('AI Prediction request: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConfig.AI_PREDICTION_URL),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('AI Prediction response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _aiPrediction = data;
          _showPredictionResults = true;
        });
        _showMessage('Price prediction completed successfully!');
      } else {
        _showMessage('Failed to predict price. Please try again.', isError: true);
      }
    } catch (e) {
      print('AI Prediction error: $e');
      _showMessage('AI service unavailable. Please enter price manually.', isError: true);
    } finally {
      setState(() => _isPredicting = false);
    }
  }

  // FIXED: AI helper methods with updated property type mapping
  int _getPropertyTypeForAI(String type) {
    const mapping = {
      'Apartment': 0,     // apartment
      'Duplex': 1,        // duplex
      'Penthouse': 2,     // penthouse
      'Studio': 3,        // studio
    };
    return mapping[type] ?? 0;
  }

  int _getCityCodeForAI(String city) {
    const mapping = {
      'cairo': 0,
      'alexandria': 1,
      'giza': 2,
      'red sea': 3,
      'south sinai': 4,
      'aswan': 5,
      'asyut': 6,
      'beheira': 7,
      'beni suef': 8,
      'dakahlia': 9,
      'damietta': 10,
      'gharbia': 11,
      'ismailia': 12,
      'kafr al-sheikh': 13,
      'matruh': 14,
      'minya': 15,
      'monufia': 16,
      'port said': 17,
      'qalyubia': 18,
      'qena': 19,
      'sharqia': 20,
      'suez': 21,
    };
    return mapping[city.toLowerCase()] ?? 0;
  }

  int _getRegionCodeForAI(String region) {
    // Create a simple hash-based mapping for regions
    // This can be enhanced with a proper mapping if needed
    final regionCode = region.toLowerCase().hashCode % 50;
    return regionCode.abs();
  }

  bool _validateFormForPrediction() {
    if (_sizeController.text.trim().isEmpty) {
      _showMessage('Please enter property size for prediction', isError: true);
      return false;
    }
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showMessage('Please select city for prediction', isError: true);
      return false;
    }
    if (_selectedRegion == null || _selectedRegion!.isEmpty) {
      _showMessage('Please select region for prediction', isError: true);
      return false;
    }
    return true;
  }

  // Helper methods
  void _updateTotalRooms() {
    setState(() {
      _totalRooms = _bedrooms + _bathrooms;
    });
  }

  void _calculatePricePerM2() {
    if (_priceController.text.isNotEmpty && _sizeController.text.isNotEmpty) {
      final price = double.tryParse(_priceController.text);
      final size = double.tryParse(_sizeController.text);
      if (price != null && size != null && size > 0) {
        _pricePerM2Controller.text = (price / size).toStringAsFixed(2);
      }
    }
  }

  void _checkForChanges() {
    if (widget.propertyToEdit != null) {
      final currentData = _getCurrentFormData();
      setState(() {
        _hasChanges = !_mapsEqual(_originalPropertyData, currentData);
      });
    }
  }

  Map<String, dynamic> _getCurrentFormData() {
    return {
      'propertyType': _propertyType,
      'size': _sizeController.text,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'totalRooms': _totalRooms,
      'floor': _floor,
      'isHighFloor': _isHighFloor,
      'isFurnished': _isFurnished,
      'isAvailable': _isAvailable,
      'city': _selectedCity,
      'region': _selectedRegion,
      'price': _priceController.text,
      'location': _selectedLocation?.toString(),
      'manualAddress': _manualAddressController.text,
      'useMapLocation': _useMapLocation,
      'imageCount': _selectedImages.length,
    };
  }

  bool _mapsEqual(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  // UI Helper Methods
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  // FIXED: Dropdown field with nullable onChanged type
  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged, // Made nullable
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF234E70),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
    );
  }

  Widget _buildCounterField({
    required String label,
    required IconData icon,
    required int value,
    required Function(int) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle, color: Colors.white),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        activeColor: Colors.orange,
        activeTrackColor: Colors.orange.withOpacity(0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                _currentPage < 2
                    ? 'Next'
                    : widget.propertyToEdit != null
                    ? 'Update Property'
                    : 'Add Property',
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

  // Navigation methods
  void _nextPage() {
    if (_currentPage < 2) {
      // Validate current page before proceeding
      if (_currentPage == 0 && !_validateBasicInfo()) return;
      if (_currentPage == 1 && !_validateLocationInfo()) return;

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
    if (_page1FormKey.currentState == null) return false;

    if (!_page1FormKey.currentState!.validate()) {
      return false;
    }

    if (_sizeController.text.trim().isEmpty) {
      _showMessage('Please enter property size', isError: true);
      return false;
    }

    // Validate that size is a valid number
    final size = double.tryParse(_sizeController.text.trim());
    if (size == null || size <= 0) {
      _showMessage('Please enter a valid property size', isError: true);
      return false;
    }

    return true;
  }

  bool _validateLocationInfo() {
    if (_page2FormKey.currentState == null) return false;

    if (!_page2FormKey.currentState!.validate()) {
      return false;
    }

    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showMessage('Please select a city', isError: true);
      return false;
    }
    if (_selectedRegion == null || _selectedRegion!.isEmpty) {
      _showMessage('Please select a region', isError: true);
      return false;
    }
    return true;
  }

  // FIXED: Form submission with proper form validation for current page
  Future<void> _submitForm() async {
    if (_currentPage < 2) {
      _nextPage();
      return;
    }

    // FIXED: Validate current page form
    GlobalKey<FormState> currentFormKey;
    switch (_currentPage) {
      case 0:
        currentFormKey = _page1FormKey;
        break;
      case 1:
        currentFormKey = _page2FormKey;
        break;
      case 2:
        currentFormKey = _page3FormKey;
        break;
      default:
        currentFormKey = _page3FormKey;
    }

    // Check if form key is null before validation
    if (currentFormKey.currentState == null) {
      _showMessage('Form validation error. Please try again.', isError: true);
      return;
    }

    // Validate the current page form
    if (!currentFormKey.currentState!.validate()) {
      _showMessage('Please fix the errors above', isError: true);
      return;
    }

    // FIXED: Additional validation for required fields
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showMessage('Please select a city', isError: true);
      return;
    }

    if (_selectedRegion == null || _selectedRegion!.isEmpty) {
      _showMessage('Please select a region', isError: true);
      return;
    }

    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showMessage('Please add at least one photo', isError: true);
      return;
    }

    // Validate all forms before submission
    bool allFormsValid = true;
    for (var formKey in [_page1FormKey, _page2FormKey, _page3FormKey]) {
      if (formKey.currentState == null || !formKey.currentState!.validate()) {
        allFormsValid = false;
        break;
      }
    }

    if (!allFormsValid) {
      _showMessage('Please complete all required fields correctly', isError: true);
      return;
    }

    if (widget.propertyToEdit != null) {
      await _performUpdateProperty();
    } else {
      await _performAddProperty();
    }
  }

  Future<void> _performAddProperty() async {
    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse(ApiConfig.addPropertyUrl);
      final request = http.MultipartRequest('POST', uri);

      final formFields = _prepareFormFields();
      if (formFields.isEmpty) {
        _showMessage('Error preparing form data', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      request.fields.addAll(formFields);

      // Add cover image (first image)
      if (_selectedImages.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'CoverImage',
          _selectedImages.first.path,
        ));

        // Add additional images
        for (int i = 1; i < _selectedImages.length; i++) {
          request.files.add(await http.MultipartFile.fromPath(
            'Images',
            _selectedImages[i].path,
          ));
        }
      }

      request.headers['accept'] = '*/*';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Property added successfully!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorMessage = 'Failed to add property';
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
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _performUpdateProperty() async {
    setState(() => _isSubmitting = true);

    try {
      final propertyId = widget.propertyToEdit!['id'];
      final uri = Uri.parse(ApiConfig.updatePropertyUrl(propertyId));
      final request = http.MultipartRequest('PUT', uri);

      final formFields = _prepareFormFields();
      request.fields.addAll(formFields);

      // Add new images if any
      if (_selectedImages.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'CoverImage',
          _selectedImages.first.path,
        ));

        for (int i = 1; i < _selectedImages.length; i++) {
          request.files.add(await http.MultipartFile.fromPath(
            'ImagePaths',
            _selectedImages[i].path,
          ));
        }
      }

      request.headers['accept'] = '*/*';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showMessage('Property updated successfully!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorMessage = 'Failed to update property';
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
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Map<String, String> _prepareFormFields() {
    _calculatePricePerM2();

    final userId = UserSession.getCurrentUserId();
    if (userId <= 0) {
      print('Warning: Invalid user ID: $userId');
      return {};
    }

    // FIXED: Ensure required fields are not null
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      print('Error: City is required but not selected');
      return {};
    }

    if (_selectedRegion == null || _selectedRegion!.isEmpty) {
      print('Error: Region is required but not selected');
      return {};
    }

    if (_sizeController.text.trim().isEmpty) {
      print('Error: Size is required but not provided');
      return {};
    }

    if (_priceController.text.trim().isEmpty) {
      print('Error: Price is required but not provided');
      return {};
    }

    final fields = <String, String>{
      'UserId': userId.toString(),
      'HouseType': _propertyType,
      'Size': _sizeController.text.trim(),
      'Bedrooms': _bedrooms.toString(),
      'Bathrooms': _bathrooms.toString(),
      'TotalRooms': _totalRooms.toString(),
      'IsHighFloor': _isHighFloor.toString().toLowerCase(),
      'IsFurnished': _isFurnished.toString().toLowerCase(),
      'Floor': _floor.toString(),
      'Status': _isAvailable ? '0' : '1',
      'Region': _selectedRegion!,
      'City': _selectedCity!,
      'Price': _priceController.text.trim(),
      'PricePerM2': _pricePerM2Controller.text.trim().isEmpty
          ? '0'
          : _pricePerM2Controller.text.trim(),
    };

    // Add location if selected
    if (_selectedLocation != null && _useMapLocation) {
      fields['Latitude'] = _selectedLocation!.latitude.toString();
      fields['Longitude'] = _selectedLocation!.longitude.toString();
    } else if (!_useMapLocation && _manualAddressController.text.trim().isNotEmpty) {
      fields['ManualAddress'] = _manualAddressController.text.trim();
    }

    print('Form fields prepared: $fields');
    return fields;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }
}