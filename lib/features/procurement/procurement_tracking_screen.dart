import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/farmer_api_service.dart';

class ProcurementTrackingScreen extends StatefulWidget {
  const ProcurementTrackingScreen({super.key});

  @override
  State<ProcurementTrackingScreen> createState() =>
      _ProcurementTrackingScreenState();
}

class _ProcurementTrackingScreenState
    extends State<ProcurementTrackingScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _procurements = [];

  @override
  void initState() {
    super.initState();
    _loadProcurements();
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _loadProcurements() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await farmerApiService.getProcurements(
        farmerId: 1,
      );

      if (!mounted) return;

      setState(() {
        _procurements = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load procurement details.';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _value(
      Map<String, dynamic> item,
      String key, [
        String fallback = '-',
      ]) {
    final value = item[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  double _number(
      Map<String, dynamic> item,
      String key,
      ) {
    final value = item[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0.00';

    final number = double.tryParse(value.toString()) ?? 0;

    return number.toStringAsFixed(2);
  }

  int _statusIndex(String status) {
    const statuses = [
      'In Progress',
      'Quality Checking',
      'Weighing',
      'Completed',
    ];

    final index = statuses.indexWhere(
          (item) =>
      item.toLowerCase().trim() ==
          status.toLowerCase().trim(),
    );

    return index < 0 ? 0 : index;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return const Color(0xFF2E7D32);

      case 'weighing':
        return const Color(0xFFEF6C00);

      case 'quality checking':
        return const Color(0xFF6A1B9A);

      case 'in progress':
        return const Color(0xFF1976D2);

      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return Icons.check_circle_rounded;

      case 'weighing':
        return Icons.scale_rounded;

      case 'quality checking':
        return Icons.verified_rounded;

      case 'in progress':
        return Icons.sync_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusDescription(String status) {
    switch (status.toLowerCase().trim()) {
      case 'completed':
        return 'Your produce has completed the procurement process.';

      case 'weighing':
        return 'Your produce is currently being weighed at the centre.';

      case 'quality checking':
        return 'Your produce is currently undergoing quality verification.';

      case 'in progress':
        return 'Your produce is being processed at the procurement centre.';

      default:
        return 'Your procurement status is being updated.';
    }
  }

  // ---------------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------------

  Widget _buildTimeline(String status) {
    const statuses = [
      'In Progress',
      'Quality Checking',
      'Weighing',
      'Completed',
    ];

    final currentIndex = _statusIndex(status);

    return Column(
      children: List.generate(
        statuses.length,
            (index) {
          final isCurrent = index == currentIndex;
          final isCompleted = index < currentIndex;
          final isReached = index <= currentIndex;
          final isLast = index == statuses.length - 1;

          final color = isReached
              ? _statusColor(status)
              : const Color(0xFFB0B8B3);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              SizedBox(
                width: 38,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 34 : 28,
                      height: isCurrent ? 34 : 28,
                      decoration: BoxDecoration(
                        color: isReached
                            ? color.withValues(alpha: 0.12)
                            : const Color(0xFFF1F3F2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isReached
                              ? color
                              : const Color(0xFFD0D6D2),
                          width: isCurrent ? 2 : 1.5,
                        ),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : _timelineIcon(index),
                        size: isCurrent ? 18 : 15,
                        color: color,
                      ),
                    ),

                    if (!isLast)
                      Container(
                        width: 2,
                        height: 45,
                        margin: const EdgeInsets.symmetric(
                          vertical: 2,
                        ),
                        color: index < currentIndex
                            ? color
                            : const Color(0xFFDDE2DE),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Timeline content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: isLast ? 0 : 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrent
                        ? Border.all(
                      color: color.withValues(alpha: 0.18),
                    )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              statuses[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isReached
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isReached
                                    ? const Color(0xFF173B2B)
                                    : const Color(0xFF8A938E),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Current stage',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _timelineIcon(int index) {
    switch (index) {
      case 0:
        return Icons.agriculture_rounded;
      case 1:
        return Icons.verified_rounded;
      case 2:
        return Icons.scale_rounded;
      case 3:
        return Icons.check_rounded;
      default:
        return Icons.circle;
    }
  }

  // ---------------------------------------------------------------------------
  // Procurement card
  // ---------------------------------------------------------------------------

  Widget _buildProcurementCard(
      Map<String, dynamic> item,
      ) {
    final status = _value(
      item,
      'status',
      'In Progress',
    );

    final crop = _value(
      item,
      'crop',
      'Crop',
    );

    final quantity = _number(
      item,
      'quantity_kg',
    );

    final rate = _number(
      item,
      'rate_per_kg',
    );

    final gross = _number(
      item,
      'gross_amount',
    );

    final code = _value(
      item,
      'procurement_code',
      'N/A',
    );

    final grade = _value(
      item,
      'quality_grade',
      'Not available',
    );

    final statusColor = _statusColor(status);

    return Column(
      children: [
        // ---------------------------------------------------------------
        // Current status hero
        // ---------------------------------------------------------------

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor,
                statusColor.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROCUREMENT STATUS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                _statusDescription(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------
        // Quick summary
        // ---------------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.agriculture_rounded,
                label: 'Crop',
                value: crop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.scale_rounded,
                label: 'Quantity',
                value: '${quantity.toStringAsFixed(1)} kg',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.verified_rounded,
                label: 'Quality',
                value: grade,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.currency_rupee_rounded,
                label: 'Rate',
                value:
                '₹${rate.toStringAsFixed(2)}/kg',
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------
        // Procurement details
        // ---------------------------------------------------------------

        _sectionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Procurement Details',
          child: Column(
            children: [
              _detailRow(
                Icons.confirmation_number_outlined,
                'Procurement ID',
                code,
              ),
              _detailDivider(),
              _detailRow(
                Icons.agriculture_outlined,
                'Crop',
                crop,
              ),
              _detailDivider(),
              _detailRow(
                Icons.scale_outlined,
                'Quantity',
                '${quantity.toStringAsFixed(1)} kg',
              ),
              _detailDivider(),
              _detailRow(
                Icons.verified_outlined,
                'Quality Grade',
                grade,
              ),
              _detailDivider(),
              _detailRow(
                Icons.currency_rupee_rounded,
                'Rate',
                '₹${rate.toStringAsFixed(2)} / kg',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------
        // Amount card
        // ---------------------------------------------------------------

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF12372A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gross Procurement Amount',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Amount calculated from quantity × rate',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '₹${_formatAmount(gross)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------
        // Progress tracker
        // ---------------------------------------------------------------

        _sectionCard(
          icon: Icons.timeline_rounded,
          title: 'Procurement Progress',
          child: _buildTimeline(status),
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------
        // Information card
        // ---------------------------------------------------------------

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD2E7FA),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9ECFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live status updates',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF174A73),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The procurement centre updates your '
                          'status as your produce moves through '
                          'each stage. Pull down or tap refresh '
                          'to get the latest information.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF42657E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary card
  // ---------------------------------------------------------------------------

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF2E7D32),
            size: 22,
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12372A),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section card
  // ---------------------------------------------------------------------------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2E7D32),
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173B2B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Detail row
  // ---------------------------------------------------------------------------

  Widget _detailRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF388E3C),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF707A74),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF294437),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _loadProcurements,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture_rounded,
                      size: 45,
                      color: Color(0xFF2E7D32),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'No Procurement Records',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF12372A),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Your procurement details will appear here '
                        'after your produce is processed at a '
                        'procurement centre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: _loadProcurements,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text(
                      'Refresh',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                      const Color(0xFF2E7D32),
                      side: const BorderSide(
                        color: Color(0xFF2E7D32),
                      ),
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
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

  // ---------------------------------------------------------------------------
  // Error
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _loadProcurements,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 110),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: Color(0xFFD32F2F),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Unable to Load Procurement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF12372A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _error ??
                        'Something went wrong. Please try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _loadProcurements,
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                      ),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,

        // ---------------------------------------------------------------
        // BACK BUTTON
        // ---------------------------------------------------------------

        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 21,
            color: Color(0xFF12372A),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/farmer/home');
            }
          },
        ),

        title: const Text(
          'Procurement Tracking',
          style: TextStyle(
            color: Color(0xFF12372A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _loadProcurements,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF2E7D32),
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),

      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading procurement details...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF12372A),
              ),
            ),
          ],
        ),
      )
          : _error != null
          ? _buildErrorState()
          : _procurements.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: const Color(0xFF2E7D32),
        onRefresh: _loadProcurements,
        child: ListView.builder(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30,
          ),
          itemCount: _procurements.length,
          itemBuilder: (
              context,
              index,
              ) {
            final raw =
            _procurements[index];

            final item =
            Map<String, dynamic>.from(
              raw as Map,
            );

            return _buildProcurementCard(
              item,
            );
          },
        ),
      ),
    );
  }
}