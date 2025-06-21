// lib/screens/viewing_requests_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/user_session.dart';
import '../utils/api_config.dart';

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
  List<Map<String, dynamic>> _viewingRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadViewingRequests();
  }

  // FIX: Enhanced viewing requests loading with better error handling
  Future<void> _loadViewingRequests() async {
    setState(() => _isLoading = true);

    try {
      String endpoint;
      Map<String, String> queryParams = {};

      if (widget.isSellerView && widget.propertyId != null) {
        // Get viewing requests for specific property (seller view)
        endpoint = '${ApiConfig.BASE_URL}/api/viewing-requests/property/${widget.propertyId}';
      } else {
        // Get all viewing requests for user (buyer view)
        endpoint = '${ApiConfig.BASE_URL}/api/viewing-requests/user/${UserSession.getCurrentUserId()}';
      }

      print('Loading viewing requests from: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: ApiConfig.headers,
      );

      print('Viewing requests response status: ${response.statusCode}');
      print('Viewing requests response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> requests = [];

        // Handle different response formats
        if (data is List) {
          requests = data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            requests = (data['data'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
          } else {
            // Single request wrapped in object
            requests = [Map<String, dynamic>.from(data)];
          }
        }

        print('Parsed ${requests.length} viewing requests');

        setState(() {
          _viewingRequests = requests;
          _errorMessage = null;
        });
      } else if (response.statusCode == 404) {
        // No requests found - this is normal
        setState(() {
          _viewingRequests = [];
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load viewing requests (${response.statusCode})';
        });
      }
    } catch (e) {
      print('Error loading viewing requests: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FIX: Enhanced status update with better API handling
  Future<void> _updateRequestStatus(int requestId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/update/$requestId'),
        headers: ApiConfig.headers,
        body: json.encode(status),
      );

      print('Update status response: ${response.statusCode}');
      print('Update status body: ${response.body}');

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

  // FIX: Add reschedule functionality
  Future<void> _rescheduleRequest(Map<String, dynamic> request) async {
    final DateTime? newDateTime = await _showDateTimePicker();
    if (newDateTime == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.BASE_URL}/api/viewing-requests/reschedule/${request['id']}'),
        headers: ApiConfig.headers,
        body: json.encode({
          'newDateTime': newDateTime.toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Request rescheduled to ${_formatDateTime(newDateTime)}');
        _loadViewingRequests();
      } else {
        _showErrorMessage('Failed to reschedule request');
      }
    } catch (e) {
      _showErrorMessage('Error rescheduling request: $e');
    }
  }

  // Add date/time picker for rescheduling
  Future<DateTime?> _showDateTimePicker() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Select new viewing date',
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
      helpText: 'Select new viewing time',
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
    return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Request ID', request['id']?.toString() ?? 'N/A'),

              if (widget.isSellerView) ...[
                _buildInfoRow('User ID', request['userId']?.toString() ?? 'N/A'),
                if (request['user'] != null) ...[
                  _buildInfoRow('Buyer Name', request['user']['fullName'] ?? 'Unknown'),
                  _buildInfoRow('Contact', request['user']['phoneNumber'] ?? request['user']['email'] ?? 'N/A'),
                ],
              ] else ...[
                _buildInfoRow('Property ID', request['propertyId']?.toString() ?? 'N/A'),
                if (request['property'] != null) ...[
                  _buildInfoRow('Property Type', request['property']['houseType'] ?? 'Property'),
                  _buildInfoRow('Location', '${request['property']['city'] ?? ''}, ${request['property']['region'] ?? ''}'),
                  _buildInfoRow('Price', '\$${request['property']['price'] ?? 0}'),
                ],
              ],

              _buildInfoRow('Status', _getStatusText(request['status'])),

              // FIX: Enhanced date/time display
              if (request['requestedDateTime'] != null)
                _buildInfoRow('Requested Date & Time',
                    _formatDateTime(DateTime.parse(request['requestedDateTime']))
                )
              else if (request['requestDate'] != null)
                _buildInfoRow('Request Date',
                    _formatDateTime(DateTime.parse(request['requestDate']))
                ),

              if (request['message'] != null)
                _buildInfoRow('Message', request['message']),
            ],
          ),
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
          SizedBox(
            width: 100,
            child: Text(
              '$label: ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Enhanced status text handling
  String _getStatusText(dynamic status) {
    if (status == null) return 'Unknown';

    // Handle numeric status values
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

    // Handle string status values
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'pending':
          return 'Pending';
        case 'approved':
          return 'Approved';
        case 'rejected':
          return 'Rejected';
        case 'cancelled':
          return 'Cancelled';
        case 'completed':
          return 'Completed';
        default:
          return status;
      }
    }

    return status.toString();
  }

  Color _getStatusColor(dynamic status) {
    final statusText = _getStatusText(status).toLowerCase();
    switch (statusText) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.yellow;
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSellerView
                      ? 'Viewing Requests'
                      : 'My Viewing Requests',
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
            Text(
              'Loading viewing requests...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
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
    return RefreshIndicator(
      onRefresh: _loadViewingRequests,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _viewingRequests.length,
        itemBuilder: (context, index) {
          final request = _viewingRequests[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildRequestCard(request),
          );
        },
      ),
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
                          ? 'Request #${request['id'] ?? 'N/A'}'
                          : 'Property Request',
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

              // Show additional details based on view type
              if (widget.isSellerView) ...[
                if (request['user'] != null)
                  Text(
                    'Buyer: ${request['user']['fullName'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
              ] else ...[
                if (request['property'] != null) ...[
                  Text(
                    '${request['property']['houseType'] ?? 'Property'} - \$${request['property']['price'] ?? 0}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                          '${request['property']['city'] ?? ''}, ${request['property']['region'] ?? ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 8),

              // FIX: Enhanced date/time display
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request['requestedDateTime'] != null)
                          Text(
                            'Requested: ${_formatDateTime(DateTime.parse(request['requestedDateTime']))}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else if (request['requestDate'] != null)
                          Text(
                            'Created: ${_formatDateTime(DateTime.parse(request['requestDate']))}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action buttons based on status and user type
              if (statusText.toLowerCase() == 'pending') ...[
                const SizedBox(height: 12),
                if (widget.isSellerView) ...[
                  // Seller actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateRequestStatus(request['id'], 'approved'),
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
                          onPressed: () => _updateRequestStatus(request['id'], 'rejected'),
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
                ] else ...[
                  // Buyer actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rescheduleRequest(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.schedule, color: Colors.white, size: 16),
                          label: const Text('Reschedule', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateRequestStatus(request['id'], 'cancelled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
                          label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}