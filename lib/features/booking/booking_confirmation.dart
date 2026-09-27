import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/government_card.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic>? booking;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingId,
    this.booking,
  });

  String _value(String key, [String fallback = 'Not available']) {
    final value = booking?[key];

    if (value == null || value.toString().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  String _firstValue(
      List<String> keys, [
        String fallback = 'Not available',
      ]) {
    for (final key in keys) {
      final value = booking?[key];

      if (value != null &&
          value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  String _quantity() {
    final value = booking?['quantity_kg'] ??
        booking?['quantity'];

    if (value == null) {
      return 'Not available';
    }

    final number = double.tryParse(
      value.toString(),
    );

    if (number == null) {
      return value.toString();
    }

    return '${number.toStringAsFixed(0)} kg';
  }

  String _formatDate(String value) {
    if (value.isEmpty ||
        value == 'Not available') {
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final token = _firstValue([
      'token_number',
      'token',
      'queue_token',
    ]);

    final centre = _firstValue([
      'centre_name',
      'center_name',
      'centre',
    ]);

    final crop = _value('crop');

    final bookingDate = _firstValue([
      'booking_date',
      'date',
    ]);

    final slotStart = _value(
      'slot_start',
      '',
    );

    final slotEnd = _value(
      'slot_end',
      '',
    );

    final slot = slotStart.isNotEmpty &&
        slotEnd.isNotEmpty
        ? '$slotStart - $slotEnd'
        : _firstValue([
      'slot',
      'slot_name',
    ]);

    final status = _firstValue([
      'status',
      'booking_status',
    ], 'Booked');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Booking Confirmed',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 68,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Booking Successful!',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your procurement slot has been booked successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 22),

              GovernmentCard(
                child: Column(
                  children: [
                    const Text(
                      'Digital Token',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      token,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF0B7A53),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Booking ID: $bookingId',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              GovernmentCard(
                child: Column(
                  children: [
                    _detailRow(
                      Icons.agriculture_outlined,
                      'Crop',
                      crop,
                    ),
                    _detailRow(
                      Icons.scale_outlined,
                      'Quantity',
                      _quantity(),
                    ),
                    _detailRow(
                      Icons.location_on_outlined,
                      'Centre',
                      centre,
                    ),
                    _detailRow(
                      Icons.calendar_today_outlined,
                      'Date',
                      _formatDate(
                        bookingDate,
                      ),
                    ),
                    _detailRow(
                      Icons.access_time_outlined,
                      'Time',
                      slot,
                    ),
                    _detailRow(
                      Icons.info_outline,
                      'Status',
                      status,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              GovernmentCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 110,
                      color: Color(0xFF12372A),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Show your digital token at the procurement centre.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go(
                      '/queue',
                      extra: {
                        'bookingId': bookingId,
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.people_alt_outlined,
                  ),
                  label: const Text(
                    'Track Live Queue',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.go(
                      '/my-bookings',
                    );
                  },
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                  ),
                  label: const Text(
                    'View My Bookings',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
                  context.go(
                    '/farmer/home',
                  );
                },
                child: const Text(
                  'Back to Dashboard',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF0B7A53),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}