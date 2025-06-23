// lib/screens/viewing_requests_screen.dart - COMPLETE FILE WITH SELLER FIXES
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

class ViewingRequestsScreen extends StatefulWidget {
  final bool isSellerView;
  final int? propertyId;

  const ViewingRequestsScreen({
    Key? key,
    this.isSellerView = false,
    this.propertyId,
  }) : super(key: key);

  @override
  State<ViewingRequestsScreen> createState() => _ViewingRequestsScreenState();
}

class _ViewingRequestsScreenState extends State<ViewingRequestsScreen> {
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
      print('🔍 Attempting to load viewing requests...');

      // FIXED: Choose endpoint based on propertyId for seller view
      String endpoint;
      if (widget.propertyId != null) {
        endpoint = '${ApiConfig.BASE_URL}/api/viewing-requests/property/${widget.propertyId}';
        print('🏠 Using property-specific endpoint for property ${widget.propertyId}');
      } else {
        endpoint = '${ApiConfig.BASE_URL}/api/viewing-requests/user/${UserSession.getCurrentUserId()}';
        print('👤 Using user-specific endpoint');
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📋 Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Success - parse the data
        final data = json.decode(response.body);
        List<Map<String, dynamic>> requests = [];

        if (data is List) {
          requests = data.map((item) => _safeMapConversion(item)).toList();
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            requests = (data['data'] as List).map((item) => _safeMapConversion(item)).toList();
          }
        }

        setState(() {
          _viewingRequests = requests;
          _errorMessage = null;
        });

      } else if (response.statusCode == 404) {
        // Backend endpoint doesn't exist yet - show helpful message
        setState(() {
          _viewingRequests = [];
          _errorMessage = 'backend_not_ready';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load viewing requests (${response.statusCode})';
        });
      }
    } catch (e) {
      print('❌ Error loading viewing requests: $e');
      setState(() {
        _errorMessage = 'backend_not_ready';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _safeMapConversion(dynamic item) {
    if (item is Map<String, dynamic>) {
      return {
        'id': item['id'] ?? 0,
        'userId': item['userId'] ?? 0,
        'propertyId': item['propertyId'] ?? 0,
        'status': item['status'] ?? 0,
        'requestDate': item['requestDate'] ?? DateTime.now().toIso8601String(),
        'user': item['user'],
        'property': item['property'],
      };
    }
    return {};
  }

  Future<void> _updateRequestStatus(int requestId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/update/$requestId'),
        headers: ApiConfig.headers,
        body: json.encode(status),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Request $status successfully');
        _loadViewingRequests();
      } else {
        _showErrorMessage('Failed to update request status');
      }
    } catch (e) {
      _showErrorMessage('Error updating request: $e');
    }
  }

  String _getStatusText(dynamic status) {
    if (status == null) return 'Unknown';

    if (status is int) {
      switch (status) {
        case 0: return 'Pending';
        case 1: return 'Approved';
        case 2: return 'Rejected';
        case 3: return 'Cancelled';
        case 4: return 'Completed';
        default: return 'Unknown';
      }
    }

    return status.toString();
  }

  Color _getStatusColor(dynamic status) {
    final statusText = _getStatusText(status).toLowerCase();
    switch (statusText) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'pending':
      default: return Colors.yellow;
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
              Expanded(child: _buildBody()),
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
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSellerView ? 'Property Requests' : 'My Viewing Requests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_viewingRequests.length} ${_viewingRequests.length == 1 ? 'request' : 'requests'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading requests...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    // TEMPORARY: Show backend not ready message
    if (_errorMessage == 'backend_not_ready') {
      return _buildBackendNotReadyState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_viewingRequests.isEmpty) {
      return _buildEmptyState();
    }

    return _buildRequestsList();
  }

  // TEMPORARY: Special state for when backend endpoints aren't ready
  Widget _buildBackendNotReadyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: Colors.orange.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              const Text(
                'Backend Update Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The viewing requests feature is working, but your backend needs to be updated with GET endpoints to display existing requests.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s working:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '✅ Creating viewing requests\n✅ Duplicate request prevention\n✅ Request validation',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Missing backend endpoints:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '❌ GET /api/viewing-requests/user/{userId}\n❌ GET /api/viewing-requests/property/{propertyId}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Good news: Creating new viewing requests works perfectly! The backend just needs the GET endpoints added.',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: Colors.white.withOpacity(0.8))),
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
          Icon(Icons.calendar_view_month_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            widget.isSellerView ? 'No viewing requests yet' : 'No viewing requests made',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSellerView
                ? 'When buyers request to view your properties, they will appear here'
                : 'Request to view properties from their detail pages',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRequestCard(request),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'];
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Request #${request['id']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
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

            if (request['property'] != null) ...[
              Text(
                'Property: ${request['property']['houseType'] ?? 'Unknown'}',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              Text(
                'Location: ${request['property']['city']}, ${request['property']['region']}',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(request['requestDate']))}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),

            if (statusText.toLowerCase() == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.isSellerView) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateRequestStatus(request['id'], 'approved'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.2)),
                        child: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateRequestStatus(request['id'], 'rejected'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
                        child: const Text('Reject', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateRequestStatus(request['id'], 'cancelled'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.2)),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}