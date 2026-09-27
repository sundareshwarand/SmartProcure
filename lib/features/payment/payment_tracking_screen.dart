import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/farmer_api_service.dart';

class PaymentTrackingScreen extends StatefulWidget {
  const PaymentTrackingScreen({super.key});

  @override
  State<PaymentTrackingScreen> createState() =>
      _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState
    extends State<PaymentTrackingScreen> {
  final FarmerApiService _api =
      FarmerApiService.instance;

  bool _loading = true;
  String? _error;

  List<dynamic> _payments = [];

  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  // ===========================================================================
  // LOAD PAYMENTS
  // ===========================================================================

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getPayments(
        farmerId: 1,
      );

      if (!mounted) return;

      setState(() {
        _payments = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
        'Unable to load payment information.';
      });
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _value(
      Map<String, dynamic> map,
      String key, [
        String fallback = '-',
      ]) {
    final value = map[key];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  double _amount(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  Color _statusColor(String status) {
    final value =
    status.toLowerCase();

    if (value.contains('paid') ||
        value.contains('completed') ||
        value.contains('success')) {
      return const Color(0xFF16834B);
    }

    if (value.contains('processing') ||
        value.contains('pending')) {
      return const Color(0xFFE58A00);
    }

    if (value.contains('failed') ||
        value.contains('cancel')) {
      return const Color(0xFFD64545);
    }

    return const Color(0xFF3578C6);
  }

  IconData _statusIcon(String status) {
    final value =
    status.toLowerCase();

    if (value.contains('paid') ||
        value.contains('completed') ||
        value.contains('success')) {
      return Icons.check_circle_rounded;
    }

    if (value.contains('processing')) {
      return Icons.sync_rounded;
    }

    if (value.contains('pending')) {
      return Icons.schedule_rounded;
    }

    if (value.contains('failed')) {
      return Icons.error_outline_rounded;
    }

    return Icons.info_outline_rounded;
  }

  bool _matchesFilter(
      Map<String, dynamic> payment,
      ) {
    if (_filter == 'All') {
      return true;
    }

    final status = _value(
      payment,
      'status',
      '',
    ).toLowerCase();

    return status == _filter.toLowerCase();
  }

  List<Map<String, dynamic>>
  get _filteredPayments {
    return _payments
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .where(_matchesFilter)
        .toList();
  }

  Map<String, dynamic>? get _latestPayment {
    if (_payments.isEmpty) {
      return null;
    }

    final map =
    _asMap(_payments.first);

    return map;
  }

  double get _totalAmount {
    double total = 0;

    for (final item in _payments) {
      final payment = _asMap(item);

      if (payment == null) {
        continue;
      }

      total += _amount(
        payment['amount'],
      );
    }

    return total;
  }

  double get _paidAmount {
    double total = 0;

    for (final item in _payments) {
      final payment = _asMap(item);

      if (payment == null) {
        continue;
      }

      final status = _value(
        payment,
        'status',
        '',
      ).toLowerCase();

      if (status == 'paid' ||
          status == 'completed' ||
          status == 'success') {
        total += _amount(
          payment['amount'],
        );
      }
    }

    return total;
  }

  double get _processingAmount {
    double total = 0;

    for (final item in _payments) {
      final payment = _asMap(item);

      if (payment == null) {
        continue;
      }

      final status = _value(
        payment,
        'status',
        '',
      ).toLowerCase();

      if (status == 'processing' ||
          status == 'pending') {
        total += _amount(
          payment['amount'],
        );
      }
    }

    return total;
  }

  // ===========================================================================
  // COPY TRANSACTION
  // ===========================================================================

  Future<void> _copyReference(
      String reference,
      ) async {
    if (reference == '-' ||
        reference == 'Not available' ||
        reference.isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: reference,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Transaction reference copied',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  // ===========================================================================
  // PAYMENT DETAILS
  // ===========================================================================

  void _showPaymentDetails(
      Map<String, dynamic> payment,
      ) {
    final amount = _amount(
      payment['amount'],
    );

    final status = _value(
      payment,
      'status',
      'Unknown',
    );

    final method = _value(
      payment,
      'payment_method',
      _value(
        payment,
        'method',
        'Not available',
      ),
    );

    final reference = _value(
      payment,
      'transaction_reference',
      _value(
        payment,
        'transaction_ref',
        'Not available',
      ),
    );

    final procurementId = _value(
      payment,
      'procurement_id',
      'Not available',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return Container(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          decoration:
          const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFD5DDD7,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                      BoxDecoration(
                        color:
                        const Color(
                          0xFFE8F5E9,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .account_balance_wallet_rounded,
                        color:
                        Color(0xFF2E7D32),
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight:
                          FontWeight.w800,
                          color:
                          Color(0xFF173B2B),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(16),
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFF5F8F6,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Column(
                    children: [
                      _bottomDetailRow(
                        Icons
                            .currency_rupee_rounded,
                        'Amount',
                        _formatAmount(
                          amount,
                        ),
                      ),
                      _bottomDetailRow(
                        Icons
                            .account_balance_outlined,
                        'Payment Method',
                        method,
                      ),
                      _bottomDetailRow(
                        Icons
                            .receipt_long_outlined,
                        'Transaction',
                        reference,
                      ),
                      _bottomDetailRow(
                        Icons
                            .inventory_2_outlined,
                        'Procurement ID',
                        procurementId,
                      ),
                      _bottomDetailRow(
                        _statusIcon(status),
                        'Status',
                        status,
                        last: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (reference !=
                    'Not available' &&
                    reference != '-') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _copyReference(
                          reference,
                        );
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                      ),
                      label: const Text(
                        'Copy Transaction Reference',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);

                      context.push(
                        '/grievance',
                      );
                    },
                    icon: const Icon(
                      Icons.support_agent_rounded,
                    ),
                    label: const Text(
                      'Report Payment Issue',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(
                        0xFF2E7D32,
                      ),
                      foregroundColor:
                      Colors.white,
                      elevation: 0,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
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

  Widget _bottomDetailRow(
      IconData icon,
      String title,
      String value, {
        bool last = false,
      }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 11,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
          bottom: BorderSide(
            color:
            Color(0xFFE3EAE5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
            const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color:
                Colors.black54,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color:
                Color(0xFF173B2B),
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MAIN SCREEN
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F9F7),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/farmer/home');
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color:
            Color(0xFF173B2B),
          ),
        ),

        title: const Text(
          'Payment Tracking',
          style: TextStyle(
            color:
            Color(0xFF173B2B),
            fontSize: 18,
            fontWeight:
            FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            _loading
                ? null
                : _loadPayments,
            icon: const Icon(
              Icons.refresh_rounded,
              color:
              Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: _loading
            ? const Center(
          child:
          CircularProgressIndicator(
            color:
            Color(0xFF2E7D32),
          ),
        )
            : _error != null
            ? _buildError()
            : _payments.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
          color:
          const Color(
            0xFF2E7D32,
          ),
          onRefresh:
          _loadPayments,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets
                .fromLTRB(
              16,
              16,
              16,
              35,
            ),
            children: [
              _buildSummary(),

              const SizedBox(
                height: 16,
              ),

              _buildLatestPayment(),

              const SizedBox(
                height: 18,
              ),

              _buildQuickActions(),

              const SizedBox(
                height: 20,
              ),

              _buildHistoryHeader(),

              const SizedBox(
                height: 10,
              ),

              _buildFilters(),

              const SizedBox(
                height: 12,
              ),

              if (_filteredPayments
                  .isEmpty)
                _buildNoFilterResults()
              else
                ..._filteredPayments
                    .map(
                  _buildHistoryCard,
                ),

              const SizedBox(
                height: 8,
              ),

              _buildSecurityCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary() {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            Color(0xFFFF9800),
            Color(0xFFFFB74D),
          ],
        ),
        borderRadius:
        BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
            const Color(0xFFFF9800)
                .withValues(
              alpha: 0.18,
            ),
            blurRadius: 14,
            offset:
            const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 9),
              Text(
                'Payment Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Text(
            _formatAmount(
              _totalAmount,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Total payment value',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  'Paid',
                  _formatAmount(
                    _paidAmount,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 35,
                color:
                Colors.white30,
              ),
              Expanded(
                child: _summaryMetric(
                  'Processing',
                  _formatAmount(
                    _processingAmount,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 35,
                color:
                Colors.white30,
              ),
              Expanded(
                child: _summaryMetric(
                  'Records',
                  '${_payments.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
      String title,
      String value,
      ) {
    return Column(
      children: [
        Text(
          value,
          textAlign:
          TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LATEST PAYMENT
  // ===========================================================================

  Widget _buildLatestPayment() {
    final payment =
        _latestPayment;

    if (payment == null) {
      return const SizedBox();
    }

    final amount = _amount(
      payment['amount'],
    );

    final status = _value(
      payment,
      'status',
      'Processing',
    );

    final method = _value(
      payment,
      'payment_method',
      _value(
        payment,
        'method',
        'Bank Transfer',
      ),
    );

    final reference = _value(
      payment,
      'transaction_reference',
      _value(
        payment,
        'transaction_ref',
        'Not available',
      ),
    );

    final procurementId =
    _value(
      payment,
      'procurement_id',
      'Not available',
    );

    final color =
    _statusColor(status);

    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Latest Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    Color(0xFF173B2B),
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                  color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(
                        status,
                      ),
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(
                        width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color:
              const Color(0xFFF8FAF8),
              borderRadius:
              BorderRadius.circular(
                15,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFE8F5E9,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      13,
                    ),
                  ),
                  child:
                  const Icon(
                    Icons
                        .currency_rupee_rounded,
                    color:
                    Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(
                    width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Text(
                        'Payment Amount',
                        style:
                        TextStyle(
                          color:
                          Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(
                          height: 3),
                      Text(
                        _formatAmount(
                          amount,
                        ),
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF173B2B,
                          ),
                          fontSize: 21,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          _paymentInfoRow(
            Icons
                .account_balance_outlined,
            'Payment Method',
            method,
          ),

          _paymentInfoRow(
            Icons
                .receipt_long_outlined,
            'Transaction Reference',
            reference,
            trailingAction:
            reference !=
                'Not available' &&
                reference != '-'
                ? IconButton(
              onPressed: () =>
                  _copyReference(
                    reference,
                  ),
              icon:
              const Icon(
                Icons.copy_rounded,
                size: 17,
              ),
              tooltip:
              'Copy reference',
            )
                : null,
          ),

          _paymentInfoRow(
            Icons
                .inventory_2_outlined,
            'Procurement ID',
            procurementId,
          ),

          const SizedBox(height: 14),

          _buildProgressTimeline(
            status,
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showPaymentDetails(
                  payment,
                );
              },
              icon: const Icon(
                Icons.visibility_outlined,
                size: 18,
              ),
              label: const Text(
                'View Complete Payment Details',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentInfoRow(
      IconData icon,
      String title,
      String value, {
        Widget? trailingAction,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF527263),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 11,
                color:
                Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              maxLines: 2,
              overflow:
              TextOverflow.ellipsis,
              style:
              const TextStyle(
                fontSize: 11,
                color:
                Color(0xFF173B2B),
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
          if (trailingAction !=
              null)
            trailingAction,
        ],
      ),
    );
  }

  // ===========================================================================
  // PROGRESS
  // ===========================================================================

  Widget _buildProgressTimeline(
      String status,
      ) {
    final value =
    status.toLowerCase();

    final initiated = true;

    final processing =
        value.contains(
          'processing',
        ) ||
            value.contains(
              'paid',
            ) ||
            value.contains(
              'completed',
            );

    final completed =
        value.contains(
          'paid',
        ) ||
            value.contains(
              'completed',
            ) ||
            value.contains(
              'success',
            );

    return Container(
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF8FAF8),
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2B),
            ),
          ),

          const SizedBox(height: 13),

          _timelineStep(
            title: 'Payment Initiated',
            subtitle:
            'Payment request created',
            active: initiated,
            completed: true,
            isLast: false,
          ),

          _timelineStep(
            title: 'Payment Processing',
            subtitle:
            'Bank/payment system processing',
            active: processing,
            completed:
            completed,
            isLast: false,
          ),

          _timelineStep(
            title: 'Payment Completed',
            subtitle:
            'Amount credited to farmer',
            active: completed,
            completed:
            completed,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required String title,
    required String subtitle,
    required bool active,
    required bool completed,
    required bool isLast,
  }) {
    final color = completed
        ? const Color(0xFF43A047)
        : active
        ? const Color(0xFFFF9800)
        : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration:
                  BoxDecoration(
                    color: completed
                        ? color
                        : Colors.white,
                    shape:
                    BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 1.5,
                    ),
                  ),
                  child: completed
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  )
                      : active
                      ? Container(
                    margin:
                    const EdgeInsets
                        .all(4),
                    decoration:
                    BoxDecoration(
                      color:
                      color,
                      shape:
                      BoxShape
                          .circle,
                    ),
                  )
                      : null,
                ),

                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color:
                      completed
                          ? const Color(
                        0xFF81C784,
                      )
                          : const Color(
                        0xFFE0E0E0,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.only(
                bottom: 14,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      active
                          ? const Color(
                        0xFF173B2B,
                      )
                          : Colors
                          .black45,
                    ),
                  ),
                  const SizedBox(
                      height: 2),
                  Text(
                    subtitle,
                    style:
                    const TextStyle(
                      fontSize: 9,
                      color:
                      Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            icon:
            Icons.receipt_long_rounded,
            title:
            'Payment Details',
            onTap: () {
              final payment =
                  _latestPayment;

              if (payment != null) {
                _showPaymentDetails(
                  payment,
                );
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            icon:
            Icons.support_agent_rounded,
            title:
            'Payment Help',
            onTap: () {
              context.push(
                '/grievance',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(15),
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(15),
            border: Border.all(
              color:
              const Color(0xFFE1E8E3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding:
                const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                  const Color(
                    0xFFE8F5E9,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color:
                  const Color(
                    0xFF2E7D32,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF173B2B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HISTORY
  // ===========================================================================

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Payment History',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2B),
            ),
          ),
        ),
        Text(
          '${_payments.length} records',
          style:
          const TextStyle(
            fontSize: 10,
            color:
            Colors.black45,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const filters = [
      'All',
      'Processing',
      'Paid',
      'Pending',
      'Failed',
    ];

    return SingleChildScrollView(
      scrollDirection:
      Axis.horizontal,
      child: Row(
        children: filters.map(
              (filter) {
            final selected =
                _filter == filter;

            return Padding(
              padding:
              const EdgeInsets
                  .only(
                right: 8,
              ),
              child: ChoiceChip(
                label: Text(
                  filter,
                ),
                selected:
                selected,
                onSelected:
                    (_) {
                  setState(() {
                    _filter =
                        filter;
                  });
                },
                selectedColor:
                const Color(
                  0xFF2E7D32,
                ),
                backgroundColor:
                Colors.white,
                labelStyle:
                TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : const Color(
                    0xFF527263,
                  ),
                ),
                side:
                BorderSide(
                  color: selected
                      ? const Color(
                    0xFF2E7D32,
                  )
                      : const Color(
                    0xFFE1E8E3,
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildHistoryCard(
      Map<String, dynamic> payment,
      ) {
    final amount = _amount(
      payment['amount'],
    );

    final status = _value(
      payment,
      'status',
      'Unknown',
    );

    final method = _value(
      payment,
      'payment_method',
      _value(
        payment,
        'method',
        'Bank Transfer',
      ),
    );

    final procurementId =
    _value(
      payment,
      'procurement_id',
      '-',
    );

    final color =
    _statusColor(status);

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 11,
      ),
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: InkWell(
        onTap: () {
          _showPaymentDetails(
            payment,
          );
        },
        borderRadius:
        BorderRadius.circular(17),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration:
                  BoxDecoration(
                    color:
                    color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    _statusIcon(
                      status,
                    ),
                    color: color,
                    size: 22,
                  ),
                ),

                const SizedBox(
                    width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        _formatAmount(
                          amount,
                        ),
                        style:
                        const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w900,
                          color:
                          Color(
                            0xFF173B2B,
                          ),
                        ),
                      ),
                      const SizedBox(
                          height: 3),
                      Text(
                        method,
                        style:
                        const TextStyle(
                          fontSize: 10,
                          color:
                          Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    status,
                    style:
                    TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            Container(
              height: 1,
              color:
              const Color(0xFFEAF0EC),
            ),

            const SizedBox(height: 11),

            Row(
              children: [
                const Icon(
                  Icons
                      .inventory_2_outlined,
                  size: 15,
                  color:
                  Colors.black45,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Procurement',
                  style:
                  TextStyle(
                    fontSize: 9,
                    color:
                    Colors.black45,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    procurementId,
                    style:
                    const TextStyle(
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      Color(
                        0xFF355443,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 13,
                  color:
                  Colors.black26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECURITY CARD
  // ===========================================================================

  Widget _buildSecurityCard() {
    return Container(
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
        const Color(0xFFEFF8F1),
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color:
            Color(0xFF2E7D32),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'Secure Payment Information',
                  style: TextStyle(
                    color:
                    Color(0xFF1B5E20),
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Payment information is retrieved from the SmartProcure procurement system. Keep your transaction reference secure.',
                  style: TextStyle(
                    color:
                    Color(0xFF527263),
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      color:
      const Color(0xFF2E7D32),
      onRefresh:
      _loadPayments,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Padding(
              padding:
              const EdgeInsets.all(30),
              child: Column(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration:
                    const BoxDecoration(
                      color:
                      Color(0xFFE8F5E9),
                      shape:
                      BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons
                          .account_balance_wallet_outlined,
                      size: 42,
                      color:
                      Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(
                      height: 18),
                  const Text(
                    'No Payment Records',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                      FontWeight.w800,
                      color:
                      Color(
                        0xFF173B2B,
                      ),
                    ),
                  ),
                  const SizedBox(
                      height: 8),
                  const Text(
                    'Your payment information will appear here after procurement processing.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                      Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration:
              const BoxDecoration(
                color:
                Color(0xFFFFEBEE),
                shape:
                BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .cloud_off_rounded,
                size: 35,
                color:
                Color(0xFFC62828),
              ),
            ),

            const SizedBox(
                height: 18),

            const Text(
              'Unable to Load Payments',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                Color(0xFF173B2B),
              ),
            ),

            const SizedBox(
                height: 7),

            Text(
              _error ??
                  'Something went wrong.',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                fontSize: 12,
                color:
                Colors.black54,
              ),
            ),

            const SizedBox(
                height: 20),

            ElevatedButton.icon(
              onPressed:
              _loadPayments,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text(
                'Try Again',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF2E7D32,
                ),
                foregroundColor:
                Colors.white,
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FILTER EMPTY
  // ===========================================================================

  Widget _buildNoFilterResults() {
    return Container(
      padding:
      const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 40,
            color: Colors.black26,
          ),
          SizedBox(height: 10),
          Text(
            'No matching payments',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w700,
              color:
              Color(0xFF173B2B),
            ),
          ),
        ],
      ),
    );
  }
}