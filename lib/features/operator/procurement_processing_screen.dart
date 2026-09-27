import 'package:flutter/material.dart';

import '../../core/network/api_service.dart';

class ProcurementProcessingScreen extends StatefulWidget {
  final int bookingId;

  const ProcurementProcessingScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<ProcurementProcessingScreen> createState() =>
      _ProcurementProcessingScreenState();
}

class _ProcurementProcessingScreenState
    extends State<ProcurementProcessingScreen> {
  final ApiService _api = ApiService.instance;

  bool _loading = true;
  bool _actionLoading = false;

  String? _error;

  Map<String, dynamic>? _procurement;

  final TextEditingController _moistureController =
      TextEditingController(text: '12.5');

  final TextEditingController _foreignMatterController =
      TextEditingController(text: '1.0');

  final TextEditingController _damagedController =
      TextEditingController(text: '2.0');

  final TextEditingController _weightController =
      TextEditingController();

  final TextEditingController _remarksController =
      TextEditingController(text: 'Quality approved');

  @override
  void initState() {
    super.initState();
    _loadProcurement();
  }

  @override
  void dispose() {
    _moistureController.dispose();
    _foreignMatterController.dispose();
    _damagedController.dispose();
    _weightController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }

    if (value is Map) {
      final data = value['procurements'];

      if (data is List) {
        return data;
      }

      final nested = value['data'];

      if (nested is List) {
        return nested;
      }
    }

    return [];
  }

  String _value(
    Map<String, dynamic> data,
    String key, [
    String fallback = '-',
  ]) {
    final value = data[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  double _number(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get _status =>
      _value(_procurement ?? {}, 'status', 'In Progress');

  Future<void> _loadProcurement() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.get(
        '/procurement',
      );

      final list = _asList(response.data);

      Map<String, dynamic>? found;

      for (final item in list) {
        final map = _asMap(item);

        final bookingId = int.tryParse(
          map['booking_id']?.toString() ?? '',
        );

        if (bookingId == widget.bookingId) {
          found = map;
          break;
        }
      }

      if (!mounted) return;

      if (found == null && list.isNotEmpty) {
        found = _asMap(list.first);
      }

      setState(() {
        _procurement = found;
        _loading = false;

        if (found == null) {
          _error = 'No procurement record found for this booking.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load procurement details.';
      });
    }
  }

  Future<void> _qualityCheck() async {
    if (_procurement == null) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final response = await _api.post(
        '/procurement/${_procurement!['id']}/quality-check',
        queryParameters: {
          'quality_grade': 'A',
          'moisture_percentage':
              double.tryParse(_moistureController.text) ?? 0,
          'foreign_matter_percentage':
              double.tryParse(_foreignMatterController.text) ?? 0,
          'damaged_percentage':
              double.tryParse(_damagedController.text) ?? 0,
          'passed': true,
          'remarks': _remarksController.text,
        },
      );

      _showMessage(
        _asMap(response.data)['message']?.toString() ??
            'Quality inspection completed.',
      );

      await _loadProcurement();
    } catch (e) {
      _showMessage('Quality inspection failed.');
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _weigh() async {
    if (_procurement == null) return;

    final weight =
        double.tryParse(_weightController.text);

    if (weight == null || weight <= 0) {
      _showMessage('Enter a valid actual weight.');
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final response = await _api.post(
        '/procurement/${_procurement!['id']}/weigh',
        queryParameters: {
          'actual_weight_kg': weight,
        },
      );

      _showMessage(
        _asMap(response.data)['message']?.toString() ??
            'Digital weighing completed.',
      );

      await _loadProcurement();
    } catch (e) {
      _showMessage('Weighing failed.');
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _calculateAmount() async {
    if (_procurement == null) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final response = await _api.post(
        '/procurement/${_procurement!['id']}/calculate-amount',
      );

      final data = _asMap(response.data);

      _showMessage(
        data['message']?.toString() ??
            'Procurement amount calculated.',
      );

      await _loadProcurement();
    } catch (e) {
      _showMessage('Amount calculation failed.');
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _completeProcurement() async {
    if (_procurement == null) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final response = await _api.post(
        '/procurement/${_procurement!['id']}/complete',
      );

      final data = _asMap(response.data);

      _showMessage(
        data['message']?.toString() ??
            'Procurement completed successfully.',
      );

      await _loadProcurement();
    } catch (e) {
      _showMessage('Unable to complete procurement.');
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _triggerPayment() async {
    if (_procurement == null) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final response = await _api.post(
        '/procurement/${_procurement!['id']}/trigger-payment',
      );

      final data = _asMap(response.data);

      _showMessage(
        data['message']?.toString() ??
            'Payment triggered successfully.',
      );

      await _loadProcurement();
    } catch (e) {
      _showMessage('Unable to trigger payment.');
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _showReceipt() async {
    if (_procurement == null) return;

    try {
      final response = await _api.get(
        '/procurement/${_procurement!['id']}/receipt',
      );

      final data = _asMap(response.data);

      final receipt = _asMap(data['receipt']);

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Procurement Receipt',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _receiptRow(
                    'Receipt',
                    _value(
                      receipt,
                      'receipt_number',
                      _value(
                        _procurement!,
                        'procurement_code',
                      ),
                    ),
                  ),
                  _receiptRow(
                    'Crop',
                    _value(
                      receipt,
                      'crop',
                    ),
                  ),
                  _receiptRow(
                    'Booked Quantity',
                    '${_number(receipt, 'booked_quantity_kg')} kg',
                  ),
                  _receiptRow(
                    'Actual Weight',
                    '${_number(receipt, 'actual_weight_kg')} kg',
                  ),
                  _receiptRow(
                    'Net Payable',
                    '?${_number(receipt, 'net_payable').toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showMessage('Unable to load receipt.');
    }
  }

  Widget _receiptRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains('completed')) {
      return Colors.green;
    }

    if (value.contains('amount')) {
      return Colors.indigo;
    }

    if (value.contains('weighing')) {
      return Colors.orange;
    }

    if (value.contains('quality')) {
      return Colors.deepPurple;
    }

    return Colors.blue;
  }

  bool get _isQualityStage =>
      _status.toLowerCase() == 'in progress';

  bool get _isWeighingStage =>
      _status.toLowerCase() == 'quality checking';

  bool get _isAmountStage =>
      _status.toLowerCase() == 'weighing';

  bool get _isCompleteStage =>
      _status.toLowerCase() == 'amount calculated';

  bool get _isCompleted =>
      _status.toLowerCase() == 'completed';

  Widget _stageCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool active,
    required bool completed,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: completed
              ? Colors.green.shade50
              : active
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: completed
                ? Colors.green
                : active
                    ? Colors.blue
                    : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              completed
                  ? Icons.check_circle
                  : icon,
              color: completed
                  ? Colors.green
                  : active
                      ? Colors.blue
                      : Colors.grey,
              size: 25,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _actionLoading ? null : onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              color ?? const Color(0xFF16834B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final procurement = _procurement!;

    final status = _status;
    final color = _statusColor(status);

    return RefreshIndicator(
      onRefresh: _loadProcurement,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF12372A),
                  Color(0xFF2E7D32),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.agriculture_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Procurement Processing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _value(
                    procurement,
                    'procurement_code',
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking #${widget.bookingId}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_rounded,
                    color: color,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Status',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _stageCard(
                title: 'Quality',
                subtitle: 'Inspection',
                icon: Icons.verified_outlined,
                active: _isQualityStage,
                completed: !_isQualityStage &&
                    !_isWeighingStage &&
                    !_isAmountStage &&
                    !_isCompleteStage,
              ),
              _stageCard(
                title: 'Weighing',
                subtitle: 'Digital weight',
                icon: Icons.scale_outlined,
                active: _isWeighingStage,
                completed:
                    _isAmountStage ||
                    _isCompleteStage ||
                    _isCompleted,
              ),
              _stageCard(
                title: 'Amount',
                subtitle: 'Calculation',
                icon: Icons.calculate_outlined,
                active: _isAmountStage,
                completed:
                    _isCompleteStage ||
                    _isCompleted,
              ),
              _stageCard(
                title: 'Complete',
                subtitle: 'Finalise',
                icon: Icons.check_circle_outline,
                active: _isCompleteStage,
                completed: _isCompleted,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Procurement Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _receiptRow(
                    'Crop',
                    _value(
                      procurement,
                      'crop',
                    ),
                  ),
                  _receiptRow(
                    'Booked Quantity',
                    '${_number(procurement, 'quantity_kg')} kg',
                  ),
                  _receiptRow(
                    'Rate',
                    '?${_number(procurement, 'rate_per_kg').toStringAsFixed(2)} / kg',
                  ),
                  _receiptRow(
                    'Gross Amount',
                    '?${_number(procurement, 'gross_amount').toStringAsFixed(2)}',
                  ),
                  _receiptRow(
                    'Actual Weight',
                    '${_number(procurement, 'actual_weight_kg')} kg',
                  ),
                  _receiptRow(
                    'Net Payable',
                    '?${_number(procurement, 'net_payable').toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_isQualityStage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quality Inspection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _moistureController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText: 'Moisture %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller:
                          _foreignMatterController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Foreign Matter %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _damagedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText: 'Damaged %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(
                        labelText: 'Remarks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      text: 'Approve Quality',
                      icon: Icons.verified,
                      onPressed: _qualityCheck,
                    ),
                  ],
                ),
              ),
            ),

          if (_isWeighingStage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Digital Weighing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Booked: ${_number(procurement, 'quantity_kg')} kg',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Actual Weight (kg)',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.scale),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      text: 'Complete Weighing',
                      icon: Icons.scale,
                      onPressed: _weigh,
                    ),
                  ],
                ),
              ),
            ),

          if (_isAmountStage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount Calculation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Actual Weight: ${_number(procurement, 'actual_weight_kg')} kg',
                    ),
                    Text(
                      'Rate: ?${_number(procurement, 'rate_per_kg').toStringAsFixed(2)} / kg',
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      text: 'Calculate Procurement Amount',
                      icon: Icons.calculate,
                      onPressed: _calculateAmount,
                    ),
                  ],
                ),
              ),
            ),

          if (_isCompleteStage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finalise Procurement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Net Payable: ?${_number(procurement, 'net_payable').toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16834B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      text: 'Complete Procurement',
                      icon: Icons.check_circle,
                      onPressed:
                          _completeProcurement,
                    ),
                  ],
                ),
              ),
            ),

          if (_isCompleted)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 60,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Procurement Completed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _actionButton(
                      text: 'Trigger Payment',
                      icon: Icons.account_balance,
                      onPressed: _triggerPayment,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showReceipt,
                        icon: const Icon(
                          Icons.receipt_long,
                        ),
                        label:
                            const Text('View Receipt'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Procurement Processing',
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF12372A),
        elevation: 0,
        actions: [
          IconButton(
            onPressed:
                _loading ? null : _loadProcurement,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadProcurement,
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _procurement == null
                  ? const Center(
                      child: Text(
                        'No procurement record found.',
                      ),
                    )
                  : Stack(
                      children: [
                        _buildContent(),
                        if (_actionLoading)
                          Container(
                            color: Colors.black12,
                            child: const Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
