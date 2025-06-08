// lib/screens/viewing_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/user_session.dart';

class ViewingRequestsScreen extends StatefulWidget {
  final bool isSellerView;
  final int? propertyId; // For seller view - show requests for specific property

  const ViewingRequestsScreen({
    Key? key,
    this.isSellerView = false,
    this.propertyId,
  }) : super(key: key);

  @override
  State<ViewingRequestsScreen> createState() => _ViewingRequestsScreenState();
}

class _ViewingRequestsScreenState extends State<ViewingRequestsScreen> {
  static const String API_BASE_URL = 'https://gethome.runasp.net';

  List<Map<String, dynamic>> _viewingRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadViewingRequests();
  }

  Future<void> _loadViewingRequests() async {
    setState(() => _isLoading = true);

    try {
      String endpoint;
      if (widget.isSellerView && widget.propertyId != null) {
        // Get viewing requests for specific property (seller view)
        endpoint = '$API_BASE_URL/api/viewing-requests/property/${widget.propertyId}';
      } else {
        // Get all viewing requests for user (buyer view)
        endpoint = '$API_BASE_URL/api/viewing-requests/user/${UserSession.getCurrentUserId()}';
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _viewingRequests = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load viewing requests';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRequestStatus(int requestId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$API_BASE_URL/api/viewing-requests/update/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(status),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Request $status successfully');
        _loadViewingRequests(); // Reload the list
      } else {
        _showErrorMessage('Failed to update request status');
      }
    } catch (e) {
      _showErrorMessage('Error updating request: $e');
    }
  }

  Future<void> _createViewingRequest(int propertyId) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/viewing-requests/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'propertyId': propertyId,
          'userId': UserSession.getCurrentUserId(),
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Viewing request created successfully');
        _loadViewingRequests();
      } else {
        _showErrorMessage('Failed to create viewing request');
      }
    } catch (e) {
      _showErrorMessage('Error creating request: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showRequestDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF234E70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          widget.isSellerView ? 'Viewing Request Details' : 'Your Request',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSellerView) ...[
              _buildInfoRow('Buyer', request['buyerName'] ?? 'Unknown'),
              _buildInfoRow('Contact', request['buyerPhone'] ?? 'N/A'),
            ] else ...[
              _buildInfoRow('Property', request['propertyTitle'] ?? 'Property'),
              _buildInfoRow('Address', request['propertyAddress'] ?? 'N/A'),
            ],
            _buildInfoRow('Status', request['status'] ?? 'Pending'),
            _buildInfoRow('Requested Date',
                request['requestedDate'] != null
                    ? DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.parse(request['requestedDate']))
                    : 'N/A'
            ),
            if (request['message'] != null && request['message'].isNotEmpty)
              _buildInfoRow('Message', request['message']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
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
              Expanded(
                child: _buildBody(),
              ),
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
              widget.isSellerView
                  ? 'Viewing Requests'
                  : 'My Viewing Requests',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadViewingRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_viewingRequests.isEmpty) {
      return _buildEmptyState();
    }

    return _buildRequestsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadViewingRequests,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_month_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isSellerView
                ? 'No viewing requests yet'
                : 'No viewing requests made',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSellerView
                ? 'When buyers request to view your properties, they will appear here'
                : 'Request to view properties from their detail pages',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _viewingRequests.length,
      itemBuilder: (context, index) {
        final request = _viewingRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _showRequestDialog(request),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.isSellerView
                          ? request['buyerName'] ?? 'Buyer Request'
                          : request['propertyTitle'] ?? 'Property Viewing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (request['requestedDate'] != null)
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(
                          DateTime.parse(request['requestedDate'])
                      ),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (!widget.isSellerView && request['propertyAddress'] != null)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request['propertyAddress'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              if (widget.isSellerView && status == 'Pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateRequestStatus(request['id'], 'Approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check, color: Colors.white, size: 16),
                        label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateRequestStatus(request['id'], 'Rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        label: const Text('Reject', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}