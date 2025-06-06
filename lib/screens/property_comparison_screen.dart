//property_comparison_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';

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
              child: property['imagePath'] != null
                  ? Image.file(
                File(property['imagePath']),
                fit: BoxFit.cover,
              )
                  : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.home, size: 100),
              ),
            ),
          );
        },
      ),
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
            values: selectedProperties.map((p) => '\$${p['price']}').toList(),
            isHeader: true,
          ),
          _buildComparisonRow(
            label: 'Size',
            values: selectedProperties.map((p) => '${p['size']} m²').toList(),
          ),
          _buildComparisonRow(
            label: 'Bedrooms',
            values: selectedProperties.map((p) => p['bedrooms'].toString()).toList(),
          ),
          _buildComparisonRow(
            label: 'Bathrooms',
            values: selectedProperties.map((p) => p['bathrooms'].toString()).toList(),
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
            values: selectedProperties.map((p) => p['propertyType'].toString()).toList(),
          ),
          _buildComparisonRow(
            label: 'Address',
            values: selectedProperties.map((p) => p['address'].toString()).toList(),
          ),
          _buildComparisonRow(
            label: 'Price per m²',
            values: selectedProperties.map((p) {
              final price = p['price'] as int;
              final size = p['size'] as int;
              return '\$${(price / size).toStringAsFixed(2)}';
            }).toList(),
          ),
          _buildComparisonRow(
            label: 'Description',
            values: selectedProperties.map((p) => p['description'].toString()).toList(),
            isMultiLine: true,
          ),
        ],
      ),
    );
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