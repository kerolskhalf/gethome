// lib/screens/property_comparison_screen.dart
import 'package:flutter/material.dart';
import '../utils/api_config.dart';

class PropertyComparisonScreen extends StatelessWidget {
  final List<Map<String, dynamic>> selectedProperties;

  const PropertyComparisonScreen({
    Key? key,
    required this.selectedProperties,
  }) : super(key: key);

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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildImageComparison(),
                      const SizedBox(height: 20),
                      _buildBasicInfoComparison(),
                      const SizedBox(height: 20),
                      _buildDetailedComparison(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          const Text(
            'Compare Properties',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageComparison() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedProperties.length,
        itemBuilder: (context, index) {
          final property = selectedProperties[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildPropertyImage(property['imagePath']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyImage(String? imagePath) {
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

  Widget _buildBasicInfoComparison() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildComparisonRow(
            label: 'Price',
            values: selectedProperties.map((p) => '\$${p['price'] ?? 0}').toList(),
            isHeader: true,
          ),
          _buildComparisonRow(
            label: 'Size',
            values: selectedProperties.map((p) => '${p['size'] ?? 0} m²').toList(),
          ),
          _buildComparisonRow(
            label: 'Bedrooms',
            values: selectedProperties.map((p) => (p['bedrooms'] ?? 0).toString()).toList(),
          ),
          _buildComparisonRow(
            label: 'Bathrooms',
            values: selectedProperties.map((p) => (p['bathrooms'] ?? 0).toString()).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedComparison() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildComparisonRow(
            label: 'Type',
            values: selectedProperties.map((p) => (p['houseType'] ?? 'N/A').toString()).toList(),
          ),
          _buildComparisonRow(
            label: 'Location',
            values: selectedProperties.map((p) => '${p['city'] ?? ''}, ${p['region'] ?? ''}').toList(),
          ),
          _buildComparisonRow(
            label: 'Price per m²',
            values: selectedProperties.map((p) {
              final price = (p['price'] ?? 0) as num;
              final size = (p['size'] ?? 1) as num;
              if (size > 0) {
                return '\$${(price / size).toStringAsFixed(2)}';
              } else {
                return 'N/A';
              }
            }).toList(),
          ),
          if (selectedProperties.any((p) => p['totalRooms'] != null && p['totalRooms'] > 0))
            _buildComparisonRow(
              label: 'Total Rooms',
              values: selectedProperties.map((p) => (p['totalRooms'] ?? 0).toString()).toList(),
            ),
          _buildComparisonRow(
            label: 'High Floor',
            values: selectedProperties.map((p) => (p['isHighFloor'] == true) ? 'Yes' : 'No').toList(),
          ),
          _buildComparisonRow(
            label: 'Status',
            values: selectedProperties.map((p) => _getStatusText(p['status'])).toList(),
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

  Widget _buildComparisonRow({
    required String label,
    required List<String> values,
    bool isHeader = false,
    bool isMultiLine = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: values.map((value) {
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isHeader ? 18 : 14,
                        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: isMultiLine ? 5 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}