// lib/screens/property_details_screen_seller.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
          'Are you sure you want to delete this property? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: _isDeleting ? null : () async {
              Navigator.pop(context); // Close dialog
              await _performDelete();
            },
            child: _isDeleting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            )
                : const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    setState(() => _isDeleting = true);

    try {
      final propertyId = widget.property['id'];
      final response = await http.delete(
        Uri.parse(ApiConfig.deletePropertyUrl(propertyId)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Property deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onDelete();
          Navigator.pop(context); // Go back to dashboard
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete property: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _editProperty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedAddPropertyScreen(
          propertyToEdit: widget.property,
        ),
      ),
    );

    if (result != null && result == true) {
      // Property was successfully updated
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to refresh the list
      }
    }
  }

  void _viewPropertyRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewingRequestsScreen(
          isSellerView: true,
          propertyId: widget.property['id'],
        ),
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

  // FIX: Add method to build property image widget with network image
  Widget _buildPropertyImage() {
    final imagePath = widget.property['imagePath'];

    if (!ApiConfig.isValidImagePath(imagePath)) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.home, size: 100, color: Colors.grey),
        ),
      );
    }

    final imageUrl = ApiConfig.getImageUrl(imagePath);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        );
      },
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
                  background: _buildPropertyImage(), // FIX: Use network image
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye),
                    onPressed: _viewPropertyRequests,
                    tooltip: 'View Requests',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _editProperty,
                    tooltip: 'Edit Property',
                  ),
                  IconButton(
                    icon: _isDeleting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.delete),
                    onPressed: _isDeleting ? null : _deleteProperty,
                    tooltip: 'Delete Property',
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
                      // Title, price and status
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Property ID: ${widget.property['id']}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(widget.property['status'])
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStatusText(widget.property['status']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${widget.property['price'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.property['pricePerM2'] != null)
                                Text(
                                  '\$${widget.property['pricePerM2']} per m²',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.property['city'] ?? ''}, ${widget.property['region'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      // High Floor indicator
                      if (widget.property['isHighFloor'] == true) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.height,
                              color: Colors.blue.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'High Floor Property',
                              style: TextStyle(
                                color: Colors.blue.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Property features
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildFeature(
                                  Icons.straighten,
                                  'Size',
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
                              const SizedBox(height: 16),
                              _buildFeature(
                                Icons.room,
                                'Total Rooms',
                                '${widget.property['totalRooms']}',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Property Information
                      _buildInfoSection(),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'View Requests',
                              Icons.remove_red_eye,
                              _viewPropertyRequests,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'Edit Property',
                              Icons.edit,
                              _editProperty,
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

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Property Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('House Type', widget.property['houseType'] ?? 'N/A'),
          _buildInfoRow('Region', widget.property['region'] ?? 'N/A'),
          _buildInfoRow('City', widget.property['city'] ?? 'N/A'),
          _buildInfoRow('Size', '${widget.property['size'] ?? 0} m²'),
          _buildInfoRow('Bedrooms', '${widget.property['bedrooms'] ?? 0}'),
          _buildInfoRow('Bathrooms', '${widget.property['bathrooms'] ?? 0}'),
          if (widget.property['totalRooms'] != null && widget.property['totalRooms'] > 0)
            _buildInfoRow('Total Rooms', '${widget.property['totalRooms']}'),
          _buildInfoRow('High Floor', widget.property['isHighFloor'] == true ? 'Yes' : 'No'),
          _buildInfoRow('Status', _getStatusText(widget.property['status'])),
          _buildInfoRow('Price', '\$${widget.property['price'] ?? 0}'),
          if (widget.property['pricePerM2'] != null)
            _buildInfoRow('Price per m²', '\$${widget.property['pricePerM2']}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      icon: Icon(icon, color: Colors.white),
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