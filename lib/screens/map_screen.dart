// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'property_details_screen.dart';

class MapScreen extends StatefulWidget {
  final bool isLocationPicker; // For selecting location when adding property
  final Function(LatLng)? onLocationSelected;

  const MapScreen({
    Key? key,
    this.isLocationPicker = false,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String API_BASE_URL = 'https://gethome.runasp.net';

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _selectedLocation;
  LatLng _currentPosition = const LatLng(30.0444, 31.2357); // Default to Cairo
  bool _isLoading = true;
  List<Map<String, dynamic>> _properties = [];

  // Filter options
  RangeValues _priceRange = const RangeValues(0, 1000000);
  int _minBedrooms = 0;
  String _propertyType = 'All';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    if (!widget.isLocationPicker) {
      await _loadPropertiesForMap();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadPropertiesForMap() async {
    try {
      // Build query parameters for filtering
      final queryParams = <String, String>{
        'page': '1',
        'pageSize': '100', // Load more properties for map view
      };

      if (_priceRange.start > 0) {
        queryParams['minPrice'] = _priceRange.start.toString();
      }
      if (_priceRange.end < 1000000) {
        queryParams['maxPrice'] = _priceRange.end.toString();
      }
      if (_minBedrooms > 0) {
        queryParams['minBedrooms'] = _minBedrooms.toString();
      }

      final uri = Uri.parse('$API_BASE_URL/api/properties/search').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _properties = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _createMarkersFromProperties();
        });
      }
    } catch (e) {
      print('Error loading properties for map: $e');
    }
  }

  void _createMarkersFromProperties() {
    final markers = <Marker>{};

    for (final property in _properties) {
      // Skip properties without coordinates
      if (property['latitude'] == null || property['longitude'] == null) {
        continue;
      }

      final position = LatLng(
        property['latitude'].toDouble(),
        property['longitude'].toDouble(),
      );

      final marker = Marker(
        markerId: MarkerId(property['id'].toString()),
        position: position,
        infoWindow: InfoWindow(
          title: property['houseType'] ?? 'Property',
          snippet: '\$${property['price']} - ${property['bedrooms']} beds',
          onTap: () => _onMarkerTapped(property),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerColor(property['houseType']),
        ),
      );

      markers.add(marker);
    }

    setState(() {
      _markers = markers;
    });
  }

  double _getMarkerColor(String? houseType) {
    switch (houseType?.toLowerCase()) {
      case 'apartment':
        return BitmapDescriptor.hueBlue;
      case 'house':
        return BitmapDescriptor.hueGreen;
      case 'villa':
        return BitmapDescriptor.hueViolet;
      case 'studio':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  void _onMarkerTapped(Map<String, dynamic> property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPropertySheet(property),
    );
  }

  void _onMapTapped(LatLng position) {
    if (widget.isLocationPicker) {
      setState(() {
        _selectedLocation = position;
        _markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
      });
    }
  }

  void _confirmLocationSelection() {
    if (_selectedLocation != null && widget.onLocationSelected != null) {
      widget.onLocationSelected!(_selectedLocation!);
      Navigator.pop(context, _selectedLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
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
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 12.0,
              ),
              markers: _markers,
              onTap: _onMapTapped,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              compassEnabled: true,
              trafficEnabled: false,
            ),

          // Header
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.isLocationPicker
                          ? 'Select Location'
                          : 'Properties Map',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!widget.isLocationPicker) ...[
                    IconButton(
                      icon: Icon(
                        _showFilters ? Icons.close : Icons.filter_list,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                  ],
                  if (widget.isLocationPicker && _selectedLocation != null)
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _confirmLocationSelection,
                    ),
                ],
              ),
            ),
          ),

          // Filters panel
          if (_showFilters && !widget.isLocationPicker)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _buildFiltersPanel(),
                ),
              ),
            ),

          // My location button
          if (!_isLoading)
            Positioned(
              right: 16,
              bottom: widget.isLocationPicker ? 80 : 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _goToCurrentLocation,
                child: const Icon(Icons.my_location, color: Color(0xFF234E70)),
              ),
            ),

          // Confirm location button for location picker
          if (widget.isLocationPicker && _selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _confirmLocationSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF234E70),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Confirm Location',
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
    );
  }

  Widget _buildFiltersPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        const Text('Price Range'),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 1000000,
          divisions: 100,
          labels: RangeLabels(
            '\$${_priceRange.start.toStringAsFixed(0)}',
            '\$${_priceRange.end.toStringAsFixed(0)}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Min Bedrooms'),
                  DropdownButton<int>(
                    value: _minBedrooms,
                    isExpanded: true,
                    items: [0, 1, 2, 3, 4, 5].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value == 0 ? 'Any' : value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          _minBedrooms = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Property Type'),
                  DropdownButton<String>(
                    value: _propertyType,
                    isExpanded: true,
                    items: ['All', 'Apartment', 'House', 'Villa', 'Studio']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _propertyType = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _loadPropertiesForMap();
              setState(() {
                _showFilters = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF234E70),
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertySheet(Map<String, dynamic> property) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF234E70),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property['houseType'] ?? 'Property',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '\$${property['price']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${property['city']}, ${property['region']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPropertyFeature(
                Icons.straighten,
                '${property['size']} m²',
              ),
              _buildPropertyFeature(
                Icons.king_bed,
                '${property['bedrooms']} Beds',
              ),
              _buildPropertyFeature(
                Icons.bathtub,
                '${property['bathrooms']} Baths',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyDetailsScreen(property: property),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'View Details',
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
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _goToCurrentLocation() async {
    if (_mapController != null) {
      await _getCurrentLocation();
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    }
  }
}