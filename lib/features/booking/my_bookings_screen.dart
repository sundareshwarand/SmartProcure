import 'package:flutter/material.dart';

import '../../core/network/farmer_api_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() =>
      _MyBookingsScreenState();
}

class _MyBookingsScreenState
    extends State<MyBookingsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookings =
      await farmerApiService.getBookings(
        farmerId: 1,
      );

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load bookings.';
      });
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _text(
      Map<String, dynamic> booking,
      String key, [
        String fallback = '-',
      ]) {
    final value = booking[key];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  String _status(Map<String, dynamic> booking) {
    return _text(
      booking,
      'status',
      'Booked',
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return Colors.green;

      case 'cancelled':
      case 'canceled':
      case 'no show':
        return Colors.red;

      case 'checked in':
      case 'called':
      case 'processing':
        return Colors.orange;

      case 'booked':
      case 'waiting':
      default:
        return Colors.blue;
    }
  }

  bool _canCancel(String status) {
    final normalized =
    status.toLowerCase().trim();

    return normalized != 'completed' &&
        normalized != 'cancelled' &&
        normalized != 'canceled' &&
        normalized != 'processing' &&
        normalized != 'no show';
  }

  String _formatDate(String value) {
    if (value == '-' || value.isEmpty) {
      return value;
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Widget _bookingCard(
      Map<String, dynamic> booking,
      ) {
    final status = _status(booking);
    final statusColor = _statusColor(status);

    final bookingId =
    _toInt(booking['id']);

    final code = _text(
      booking,
      'booking_code',
      _text(
        booking,
        'booking_number',
      ),
    );

    final token = _text(
      booking,
      'token',
      _text(
        booking,
        'token_number',
      ),
    );

    final crop = _text(
      booking,
      'crop',
    );

    final quantity = _text(
      booking,
      'quantity_kg',
      '0',
    );

    final date = _formatDate(
      _text(
        booking,
        'booking_date',
      ),
    );

    final slotStart = _text(
      booking,
      'slot_start',
    );

    final slotEnd = _text(
      booking,
      'slot_end',
    );

    final position = _text(
      booking,
      'queue_position',
      'Not assigned',
    );

    final wait = _text(
      booking,
      'estimated_wait_minutes',
      'Not available',
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight:
                      FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _info(
                    Icons.confirmation_number_outlined,
                    'Token',
                    token,
                  ),
                ),
                Expanded(
                  child: _info(
                    Icons.agriculture_outlined,
                    'Crop',
                    crop,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _info(
                    Icons.scale_outlined,
                    'Quantity',
                    '$quantity kg',
                  ),
                ),
                Expanded(
                  child: _info(
                    Icons.calendar_today_outlined,
                    'Date',
                    date,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _info(
              Icons.access_time_outlined,
              'Slot',
              '$slotStart - $slotEnd',
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _info(
                    Icons.people_outline,
                    'Queue',
                    position,
                  ),
                ),
                Expanded(
                  child: _info(
                    Icons.timer_outlined,
                    'Wait',
                    wait == 'Not available'
                        ? wait
                        : '$wait min',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showBookingDetails(
                        booking,
                      );
                    },
                    icon: const Icon(
                      Icons.visibility_outlined,
                    ),
                    label: const Text(
                      'Details',
                    ),
                  ),
                ),
                if (_canCancel(status)) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                      bookingId == null
                          ? null
                          : () {
                        _cancelBooking(
                          bookingId,
                        );
                      },
                      icon: const Icon(
                        Icons.cancel_outlined,
                      ),
                      label: const Text(
                        'Cancel',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(
      IconData icon,
      String title,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.green.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBookingDetails(
      Map<String, dynamic> booking,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _detail(
                  'Booking ID',
                  _text(
                    booking,
                    'id',
                  ),
                ),
                _detail(
                  'Booking Code',
                  _text(
                    booking,
                    'booking_code',
                  ),
                ),
                _detail(
                  'Token',
                  _text(
                    booking,
                    'token',
                  ),
                ),
                _detail(
                  'Crop',
                  _text(
                    booking,
                    'crop',
                  ),
                ),
                _detail(
                  'Quantity',
                  '${_text(booking, 'quantity_kg', '0')} kg',
                ),
                _detail(
                  'Date',
                  _formatDate(
                    _text(
                      booking,
                      'booking_date',
                    ),
                  ),
                ),
                _detail(
                  'Time',
                  '${_text(booking, 'slot_start')} - ${_text(booking, 'slot_end')}',
                ),
                _detail(
                  'Status',
                  _status(booking),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );
                    },
                    child: const Text(
                      'Close',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detail(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(
      int bookingId,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Booking?',
          ),
          content: const Text(
            'Are you sure you want to cancel this booking?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Yes, Cancel',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await farmerApiService.cancelBooking(
        bookingId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking cancelled successfully',
          ),
        ),
      );

      await _loadBookings();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to cancel booking',
          ),
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 55,
                ),
                const SizedBox(height: 12),
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadBookings,
                  child: const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_bookings.isEmpty) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 60,
                ),
                SizedBox(height: 12),
                Text(
                  'No bookings found',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(16),
            color: Colors.green.shade50,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_bookings.length} booking(s) loaded from SmartProcure',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._bookings.map(
              (booking) => _bookingCard(
            Map<String, dynamic>.from(
              booking,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Bookings',
        ),
        actions: [
          IconButton(
            onPressed:
            _loading
                ? null
                : _loadBookings,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: _buildBody(),
      ),
    );
  }
}