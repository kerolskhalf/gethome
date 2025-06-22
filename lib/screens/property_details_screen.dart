// lib/screens/property_details_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> with TickerProviderStateMixin {
  bool _isSaved = false;
  bool _isLoadingContact = false;
  bool _isCreatingViewingRequest = false;
  bool _isTogglingFavorite = false;
  bool _isCheckingFavorite = true;
  Map<String, dynamic>? _contactInfo;

  late AnimationController _favoriteAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _favoriteScaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkIfFavorite();
  }

  void _initializeAnimations() {
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _favoriteScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _favoriteAnimationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController.forward();
  }

  @override
  void dispose() {
    _favoriteAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  // FIXED: Enhanced favorite status checking
  Future<void> _checkIfFavorite() async {
    setState(() => _isCheckingFavorite = true);

    try {
      final userId = UserSession.getCurrentUserId();
      if (userId <= 0) {
        setState(() => _isCheckingFavorite = false);
        return;
      }

      print('🔍 Checking favorite status for property ${widget.property['id']} and user $userId');

      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/favorites/user/$userId?page=1&pageSize=100'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('📋 Favorites response: ${response.body}');

        bool isInFavorites = false;

        if (data is List) {
          // Direct array format
          isInFavorites = data.any((item) => item['id'] == widget.property['id']);
        } else if (data is Map<String, dynamic> && data.containsKey('data')) {
          // Wrapped format
          final favorites = data['data'] as List;
          isInFavorites = favorites.any((fav) {
            // Check both direct property ID and nested property ID
            return fav['id'] == widget.property['id'] ||
                fav['propertyId'] == widget.property['id'] ||
                (fav['property'] != null && fav['property']['id'] == widget.property['id']);
          });
        }

        setState(() {
          _isSaved = isInFavorites;
          _isCheckingFavorite = false;
        });

        print('✅ Property ${widget.property['id']} favorite status: $_isSaved');
      } else {
        print('⚠️ Failed to check favorite status: ${response.statusCode}');
        setState(() => _isCheckingFavorite = false);
      }
    } catch (e) {
      print('❌ Error checking favorite status: $e');
      setState(() => _isCheckingFavorite = false);
    }
  }

  // ENHANCED: Favorites toggle with animations
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    setState(() => _isTogglingFavorite = true);

    try {
      final userId = UserSession.getCurrentUserId();
      final propertyId = widget.property['id'];

      final uri = Uri.parse('${ApiConfig.BASE_URL}/api/favorites/toggle').replace(
        queryParameters: {
          'userId': userId.toString(),
          'propertyId': propertyId.toString(),
        },
      );

      print('💖 Toggling favorite: $uri');

      final response = await http.post(uri, headers: ApiConfig.headers);

      print('📡 Favorites toggle response: ${response.statusCode}');
      print('📋 Favorites toggle body: ${response.body}');

      if (response.statusCode == 200) {
        final newFavoriteStatus = !_isSaved;
        setState(() {
          _isSaved = newFavoriteStatus;
        });

        // Trigger animation
        _favoriteAnimationController.forward().then((_) {
          _favoriteAnimationController.reverse();
        });

        _showSuccessMessage(_isSaved ? '❤️ Added to favorites!' : '💔 Removed from favorites');
      } else {
        _showErrorMessage('Failed to update favorites');
      }
    } catch (e) {
      _showErrorMessage('Error updating favorites: $e');
    } finally {
      setState(() => _isTogglingFavorite = false);
    }
  }

  // ENHANCED: Viewing request creation with better UX
  Future<void> _createViewingRequest() async {
    final selectedDateTime = await _showDateTimePicker();
    if (selectedDateTime == null) return;

    final propertyId = widget.property['id'];
    final userId = UserSession.getCurrentUserId();

    if (propertyId == null || userId <= 0) {
      _showErrorMessage('Unable to create viewing request');
      return;
    }

    setState(() => _isCreatingViewingRequest = true);

    try {
      final requestBody = {
        'propertyId': propertyId,
        'userId': userId,
        'requestedDateTime': selectedDateTime.toUtc().toIso8601String(),
        'message': 'Viewing request for ${widget.property['houseType']} in ${widget.property['city']}',
      };

      print('📅 Creating viewing request: $requestBody');

      final response = await http.post(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/create'),
        headers: ApiConfig.headers,
        body: json.encode(requestBody),
      );

      print('📡 Viewing request response: ${response.statusCode}');
      print('📋 Viewing request body: ${response.body}');

      setState(() => _isCreatingViewingRequest = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showSuccessDialog(
          '✅ Viewing Scheduled!',
          'Your viewing request has been sent for ${_formatDateTime(selectedDateTime)}. The seller will contact you soon.',
        );
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          _showErrorMessage(errorData['message'] ?? 'Failed to create viewing request');
        } catch (e) {
          _showErrorMessage('You may already have a pending request for this property');
        }
      } else {
        _showErrorMessage('Failed to create viewing request');
      }
    } catch (e) {
      setState(() => _isCreatingViewingRequest = false);
      if (mounted) {
        _showErrorMessage('Network error. Please try again.');
      }
    }
  }

  // Enhanced contact information retrieval
  Future<void> _getSellerContact() async {
    final propertyId = widget.property['id'];
    if (propertyId == null) {
      _showErrorMessage('Property ID is missing');
      return;
    }

    setState(() => _isLoadingContact = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.BASE_URL}/api/properties/$propertyId/contact'),
        headers: ApiConfig.headers,
      );

      setState(() => _isLoadingContact = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final contactData = data['data'] ?? data;
          setState(() {
            _contactInfo = contactData;
          });
          _showContactDialog(contactData);
        } catch (e) {
          _showErrorMessage('Failed to parse contact information');
        }
      } else if (response.statusCode == 404) {
        _showErrorMessage('Contact information not available for this property');
      } else {
        _showErrorMessage('Failed to get contact information');
      }
    } catch (e) {
      setState(() => _isLoadingContact = false);
      if (mounted) {
        _showErrorMessage('Network error. Please check your connection.');
      }
    }
  }

  // Enhanced date/time picker
  Future<DateTime?> _showDateTimePicker() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Select viewing date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF234E70),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return null;
    if (!mounted) return null;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select viewing time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF234E70),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return null;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month $day at $hour:$minute';
  }

  void _showContactDialog(Map<String, dynamic> contactData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.contacts, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Seller Contact Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how you\'d like to contact the seller:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (contactData['sellerPhoneNumber'] != null) ...[
              _buildContactOption(
                Icons.phone,
                'Call Seller',
                contactData['sellerPhoneNumber'].toString(),
                onTap: () => _initiateCall(contactData['sellerPhoneNumber'].toString()),
              ),
              const SizedBox(height: 16),
            ],
            if (contactData['sellerEmail'] != null) ...[
              _buildContactOption(
                Icons.email,
                'Send Email',
                contactData['sellerEmail'].toString(),
                onTap: () => _initiateEmail(contactData['sellerEmail'].toString()),
              ),
            ],
            if (contactData['sellerPhoneNumber'] == null && contactData['sellerEmail'] == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No contact information available for this property.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.touch_app,
                color: Colors.green,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initiateCall(String phoneNumber) async {
    try {
      Navigator.pop(context); // Close the dialog first

      // Clean the phone number (remove spaces, dashes, etc.)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final telUrl = 'tel:$cleanNumber';

      if (await canLaunchUrl(Uri.parse(telUrl))) {
        await launchUrl(
          Uri.parse(telUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showErrorMessage('Unable to make phone call. Please dial $phoneNumber manually.');
      }
    } catch (e) {
      print('Error making phone call: $e');
      _showErrorMessage('Error making phone call: ${e.toString()}');
    }
  }

  void _initiateEmail(String email) async {
    try {
      Navigator.pop(context); // Close the dialog first

      final subject = Uri.encodeComponent('Inquiry about Property ID: ${widget.property['id']}');
      final body = Uri.encodeComponent('Hello,\n\nI am interested in your property (ID: ${widget.property['id']}) - ${widget.property['houseType']} in ${widget.property['city']}.\n\nPlease let me know more details.\n\nThank you.');

      final emailUrl = 'mailto:$email?subject=$subject&body=$body';

      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(
          Uri.parse(emailUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showErrorMessage('Unable to open email app. Please email $email manually.');
      }
    } catch (e) {
      print('Error opening email: $e');
      _showErrorMessage('Error opening email: ${e.toString()}');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(dynamic status) {
    if (status == 0 || status == 'Available') return 'Available';
    if (status == 1 || status == 'NotAvailable') return 'Not Available';
    return 'Unknown';
  }

  Color _getStatusColor(dynamic status) {
    if (status == 0 || status == 'Available') return Colors.green;
    if (status == 1 || status == 'NotAvailable') return Colors.red;
    return Colors.grey;
  }

  Widget _buildPropertyImage() {
    final imagePath = widget.property['imagePath'];

    if (!ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[300]!,
              Colors.grey[400]!,
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.home, size: 120, color: Colors.white),
        ),
      );
    }

    final imageUrl = ApiConfig.getImageUrl(imagePath);
    return Stack(
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.broken_image, size: 120, color: Colors.white),
              ),
            );
          },
        ),
        // Gradient overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
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
                // Enhanced App Bar with image
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  stretch: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildPropertyImage(),
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                  ),
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isCheckingFavorite
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                          : IconButton(
                        icon: AnimatedBuilder(
                          animation: _favoriteScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _favoriteScaleAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _isSaved
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isSaved ? Icons.favorite : Icons.favorite_border,
                                  color: _isSaved ? Colors.red : Colors.white,
                                  size: 26,
                                ),
                              ),
                            );
                          },
                        ),
                        onPressed: _isTogglingFavorite ? null : _toggleFavorite,
                      ),
                    ),
                  ],
                ),

                // Property details with enhanced design
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1a237e),
                          Color(0xFF234E70),
                          Color(0xFF305F80),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPropertyHeader(),
                          const SizedBox(height: 24),
                          _buildLocationSection(),
                          const SizedBox(height: 24),
                          _buildPropertyFeatures(),
                          const SizedBox(height: 24),
                          _buildPropertyInfo(),
                          const SizedBox(height: 32),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property['houseType'] ?? 'Property',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: ${widget.property['id']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.property['status']).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(widget.property['status']).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      _getStatusText(widget.property['status']),
                      style: TextStyle(
                        color: _getStatusColor(widget.property['status']),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.property['price'] ?? 0} LE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.property['pricePerM2'] != null && widget.property['pricePerM2'] > 0)
                    Text(
                      '${widget.property['pricePerM2']} LE/m²',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.property['city'] ?? ''}, ${widget.property['region'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (widget.property['isHighFloor'] == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.height,
                    color: Colors.blue.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'High Floor Property',
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_city,
                      color: Colors.white.withOpacity(0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'City',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.property['city'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: Colors.white.withOpacity(0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Region',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.property['region'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.property['address'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.home,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Address',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Expanded(
                        flex: 2,
                        child: Text(
                          widget.property['address'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Location Button
          InkWell(
            onTap: _openLocationOnMap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'View Location on Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLocationOnMap() async {
    try {
      final city = widget.property['city'] ?? '';
      final region = widget.property['region'] ?? '';
      final address = widget.property['address'] ?? '';

      // Create search query for the location
      String locationQuery = '';
      if (address.isNotEmpty) {
        locationQuery = address;
      } else if (city.isNotEmpty && region.isNotEmpty) {
        locationQuery = '$city, $region';
      } else if (city.isNotEmpty) {
        locationQuery = city;
      } else {
        _showErrorMessage('Location information not available');
        return;
      }

      // Encode the query for URL
      final encodedQuery = Uri.encodeComponent(locationQuery);

      // Try to open Google Maps first
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to basic maps URL
        final fallbackUrl = 'https://maps.google.com/?q=$encodedQuery';
        if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
          await launchUrl(
            Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          _showErrorMessage('Unable to open maps application');
        }
      }
    } catch (e) {
      print('Error opening map: $e');
      _showErrorMessage('Error opening map: ${e.toString()}');
    }
  }

  Widget _buildPropertyFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                child: const Icon(Icons.apartment, color: Colors.white, size: 20),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  Icons.straighten,
                  '${widget.property['size'] ?? 0} m²',
                  const Color(0xFFFF8C00), // Orange
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  Icons.single_bed,
                  '${widget.property['bedrooms'] ?? 0}',
                  const Color(0xFF32CD32), // Green
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  Icons.bathtub_outlined,
                  '${widget.property['bathrooms'] ?? 0}',
                  const Color(0xFF1E90FF), // Blue
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  Icons.room_outlined,
                  widget.property['totalRooms'] != null && widget.property['totalRooms'] > 0
                      ? '${widget.property['totalRooms']}'
                      : '${widget.property['floor'] ?? 0}',
                  const Color(0xFF9932CC), // Purple
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String value, Color color) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
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
          _buildInfoRow('Floor', '${widget.property['floor'] ?? 0}'),
          _buildInfoRow('Furnished', widget.property['isFurnished'] == true ? 'Yes' : 'No'),
          _buildInfoRow('High Floor', widget.property['isHighFloor'] == true ? 'Yes' : 'No'),
          _buildInfoRow('Status', _getStatusText(widget.property['status'])),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Schedule Viewing',
            Icons.calendar_today,
            _isCreatingViewingRequest ? null : _createViewingRequest,
            isLoading: _isCreatingViewingRequest,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            'Contact Seller',
            Icons.message,
            _isLoadingContact ? null : _getSellerContact,
            isLoading: _isLoadingContact,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label,
      IconData icon,
      VoidCallback? onTap, {
        bool isLoading = false,
        Color color = Colors.white,
        bool isPrimary = false,
      }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color.withOpacity(0.2) : Colors.white.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        side: BorderSide(
          color: isPrimary ? color.withOpacity(0.5) : Colors.white.withOpacity(0.3),
        ),
      ),
      icon: isLoading
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isPrimary ? color : Colors.white,
          ),
        ),
      )
          : Icon(
        icon,
        color: isPrimary ? color : Colors.white,
        size: 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isPrimary ? color : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}