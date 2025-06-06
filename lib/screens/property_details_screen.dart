// lib/screens/property_details_screen.dart (for buyers)
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool _isSaved = false;
  bool _isLoadingContact = false;
  DateTime? _selectedViewingDate;
  Map<String, dynamic>? _contactInfo;

  // Replace with your actual API base URL
  static const String API_BASE_URL = 'https://getawayanapp.runasp.net';

  String? _validatePropertyId() {
    final propertyId = widget.property['id'];
    if (propertyId == null) {
      return 'Property ID is missing';
    }
    if (propertyId.toString().isEmpty) {
      return 'Property ID cannot be empty';
    }
    // Additional validation for ID format if needed
    final id = int.tryParse(propertyId.toString());
    if (id == null || id <= 0) {
      return 'Invalid property ID format';
    }
    return null;
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Property saved to favorites' : 'Property removed from favorites'),
        backgroundColor: _isSaved ? Colors.green : Colors.grey,
      ),
    );
  }

  void _scheduleViewing() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedViewingDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });

        // Show confirmation
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF234E70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                'Viewing Scheduled',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Your viewing is scheduled for ${_selectedViewingDate!.toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _getSellerContact() async {
    // Validate property ID first
    final idError = _validatePropertyId();
    if (idError != null) {
      _showErrorMessage(idError);
      return;
    }

    setState(() => _isLoadingContact = true);

    try {
      final propertyId = widget.property['id'].toString();
      final uri = Uri.parse('$API_BASE_URL/api/properties/$propertyId/contact');

      print('Contact request URL: $uri'); // Debug log

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $your_token_here',
        },
      );

      setState(() => _isLoadingContact = false);

      if (!mounted) return;

      print('Contact response status: ${response.statusCode}'); // Debug log
      print('Contact response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        // Success - parse contact information
        try {
          final contactData = json.decode(response.body);
          setState(() {
            _contactInfo = contactData;
          });
          _showContactDialog(contactData);
        } catch (e) {
          _showErrorMessage('Failed to parse contact information');
        }
      } else if (response.statusCode == 400) {
        // Handle validation errors
        _handle400ValidationError(response.body);
      } else if (response.statusCode == 401) {
        _showErrorMessage('Unauthorized. Please log in to view contact information.');
      } else if (response.statusCode == 404) {
        _showErrorMessage('Property not found or contact information unavailable.');
      } else if (response.statusCode == 403) {
        _showErrorMessage('You don\'t have permission to view this contact information.');
      } else {
        _showErrorMessage('Server error (${response.statusCode}). Please try again later.');
      }

    } catch (e) {
      setState(() => _isLoadingContact = false);
      if (mounted) {
        print('Contact network error: $e'); // Debug log
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
        _showErrorMessage('Invalid property ID or contact information unavailable.');
      }
    } catch (e) {
      _showErrorMessage('Failed to get contact information. Please check the property ID and try again.');
    }
  }

  void _showContactDialog(Map<String, dynamic> contactData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Seller Contact Information',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contactData['sellerName'] != null)
              _buildContactOption(
                Icons.person,
                'Seller Name',
                contactData['sellerName'].toString(),
              ),
            const SizedBox(height: 16),
            if (contactData['phone'] != null)
              _buildContactOption(
                Icons.phone,
                'Phone Number',
                contactData['phone'].toString(),
                onTap: () => _initiateCall(contactData['phone'].toString()),
              ),
            const SizedBox(height: 16),
            if (contactData['email'] != null)
              _buildContactOption(
                Icons.email,
                'Email',
                contactData['email'].toString(),
                onTap: () => _initiateEmail(contactData['email'].toString()),
              ),
            const SizedBox(height: 16),
            if (contactData['whatsapp'] != null)
              _buildContactOption(
                Icons.chat,
                'WhatsApp',
                contactData['whatsapp'].toString(),
                onTap: () => _initiateWhatsApp(contactData['whatsapp'].toString()),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? (() {
        // Copy to clipboard functionality
        _showSuccessMessage('$title copied to clipboard');
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _initiateCall(String phoneNumber) {
    Navigator.pop(context);
    _showSuccessMessage('Opening phone app to call $phoneNumber');
    // In a real app, you would use url_launcher to open the phone app
    // launch('tel:$phoneNumber');
  }

  void _initiateEmail(String email) {
    Navigator.pop(context);
    _showSuccessMessage('Opening email app for $email');
    // In a real app, you would use url_launcher to open the email app
    // launch('mailto:$email?subject=Property Inquiry');
  }

  void _initiateWhatsApp(String whatsapp) {
    Navigator.pop(context);
    _showSuccessMessage('Opening WhatsApp for $whatsapp');
    // In a real app, you would use url_launcher to open WhatsApp
    // launch('https://wa.me/$whatsapp');
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

          // Main content
          CustomScrollView(
            slivers: [
              // App Bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: widget.property['imagePath'] != null
                      ? Image.file(
                    File(widget.property['imagePath']),
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.home, size: 100),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(_isSaved ? Icons.favorite : Icons.favorite_border),
                    onPressed: _toggleSave,
                  ),
                ],
              ),

              // Property details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.property['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '\$${widget.property['price']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Property ID display
                      Row(
                        children: [
                          Icon(
                            Icons.tag,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Property ID: ${widget.property['id'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Address
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
                              widget.property['address'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Property features
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeature(
                              Icons.straighten,
                              'Size',
                              '${widget.property['size']} m²',
                            ),
                            _buildFeature(
                              Icons.king_bed,
                              'Bedrooms',
                              '${widget.property['bedrooms']}',
                            ),
                            _buildFeature(
                              Icons.bathtub,
                              'Bathrooms',
                              '${widget.property['bathrooms']}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.property['description'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Schedule Viewing',
                              Icons.calendar_today,
                              _scheduleViewing,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'Contact Seller',
                              Icons.message,
                              _isLoadingContact ? null : _getSellerContact,
                              isLoading: _isLoadingContact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onTap, {bool isLoading = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}