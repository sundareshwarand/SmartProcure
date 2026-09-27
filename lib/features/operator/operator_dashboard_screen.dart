import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/api_service.dart';
import '../../core/network/farmer_api_service.dart';

class OperatorDashboardScreen extends StatefulWidget {
  final int? centreId;

  const OperatorDashboardScreen({
    super.key,
    this.centreId,
  });

  @override
  State<OperatorDashboardScreen> createState() =>
      _OperatorDashboardScreenState();
}

class _OperatorDashboardScreenState
    extends State<OperatorDashboardScreen> {
  final FarmerApiService _api = FarmerApiService.instance;
  final ApiService _network = ApiService.instance;

  int get _centreId => widget.centreId ?? 1;

  bool _loading = true;
  bool _refreshing = false;
  bool _processingAction = false;

  String? _error;

  List<dynamic> _queue = [];
  Map<String, dynamic>? _centre;

  String _searchQuery = '';
  String _selectedFilter = 'All';

  bool _queuePaused = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({
    bool refresh = false,
  }) async {
    if (refresh) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.getQueue(
          centreId: _centreId,
        ),
        _api.getCentre(
          _centreId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _queue = results[0] as List<dynamic>;
        _centre = results[1] as Map<String, dynamic>?;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _friendlyError(e);
      });
    }
  }

  // ============================================================
  // FILTER QUEUE
  // ============================================================

  List<dynamic> get _filteredQueue {
    Iterable<dynamic> items = _queue;

    switch (_selectedFilter) {
      case 'Waiting':
        items = items.where(
              (item) => _status(item) == 'waiting',
        );
        break;

      case 'Called':
        items = items.where(
              (item) => _status(item) == 'called',
        );
        break;

      case 'Processing':
        items = items.where(
              (item) => _status(item) == 'processing',
        );
        break;

      case 'Completed':
        items = items.where(
              (item) => _status(item) == 'completed',
        );
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      items = items.where((item) {
        final farmer = _firstValue(
          item,
          [
            'farmer_name',
            'name',
            'farmer',
          ],
        ).toLowerCase();

        final token = _firstValue(
          item,
          [
            'token',
            'token_number',
            'queue_token',
          ],
        ).toLowerCase();

        final crop = _firstValue(
          item,
          [
            'crop',
            'crop_name',
          ],
        ).toLowerCase();

        return farmer.contains(query) ||
            token.contains(query) ||
            crop.contains(query);
      });
    }

    return items.toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _waitingCount {
    return _queue
        .where((item) => _status(item) == 'waiting')
        .length;
  }

  int get _calledCount {
    return _queue
        .where((item) => _status(item) == 'called')
        .length;
  }

  int get _processingCount {
    return _queue
        .where((item) => _status(item) == 'processing')
        .length;
  }

  int get _completedCount {
    return _queue
        .where((item) => _status(item) == 'completed')
        .length;
  }

  // ============================================================
  // CALL NEXT
  // ============================================================

  Future<void> _callNext() async {
    if (_processingAction) return;

    if (_queuePaused) {
      _showMessage(
        'Queue is currently paused.',
        isError: true,
      );
      return;
    }

    final waiting = _queue
        .where(
          (item) => _status(item) == 'waiting',
    )
        .toList();

    if (waiting.isEmpty) {
      _showMessage(
        'No waiting farmer is available.',
        isError: true,
      );
      return;
    }

    final next = waiting.first;

    final queueId = _toInt(
      next['id'] ??
          next['queue_id'] ??
          next['queueId'],
    );

    if (queueId == null) {
      _showMessage(
        'Queue ID is missing.',
        isError: true,
      );
      return;
    }

    await _updateQueueStatus(
      queueId: queueId,
      status: 'Called',
      successMessage: 'Next farmer has been called.',
    );
  }

  // ============================================================
  // START PROCESSING
  // ============================================================

  Future<void> _startProcessing(
      dynamic item,
      ) async {
    if (_processingAction) return;

    final queueId = _toInt(
      item['id'] ??
          item['queue_id'] ??
          item['queueId'],
    );

    if (queueId == null) {
      _showMessage(
        'Queue ID is missing.',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Start Procurement?',
      message:
      'Start procurement processing for this farmer?',
    );

    if (!confirmed) return;

    await _updateQueueStatus(
      queueId: queueId,
      status: 'Processing',
      successMessage: 'Farmer moved to processing.',
    );

    if (!mounted) return;

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (!mounted) return;

    await _openProcurementWorkflow(
      item,
    );
  }

  // ============================================================
  // OPEN PROCUREMENT WORKFLOW
  // ============================================================

  Future<void> _openProcurementWorkflow(
      dynamic queueItem,
      ) async {
    final farmerId = _toInt(
      queueItem['farmer_id'] ??
          queueItem['farmerId'],
    );

    final bookingId = _toInt(
      queueItem['booking_id'] ??
          queueItem['bookingId'],
    );

    final queueQuantity = _toDouble(
      queueItem['quantity_kg'] ??
          queueItem['quantity'],
    );

    final farmerName = _firstValue(
      queueItem,
      [
        'farmer_name',
        'name',
        'farmer',
      ],
      fallback: 'Farmer',
    );

    final crop = _firstValue(
      queueItem,
      [
        'crop',
        'crop_name',
      ],
      fallback: 'Paddy',
    );

    Map<String, dynamic>? procurement;

    try {
      final procurements = await _api.getProcurements(
        farmerId: farmerId,
        centreId: _centreId,
      );

      for (final item in procurements) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);

        final itemBookingId = _toInt(
          map['booking_id'],
        );

        if (bookingId != null &&
            itemBookingId == bookingId) {
          procurement = map;
          break;
        }

        if (procurement == null) {
          procurement = map;
        }
      }
    } catch (_) {
      // Workflow can still continue with queue information.
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ProcurementWorkflowSheet(
          farmerName: farmerName,
          crop: crop,
          bookedQuantityKg:
          queueQuantity ??
              _toDouble(
                procurement?['quantity_kg'],
              ) ??
              0,
          procurement: procurement,
          farmerId: farmerId,
          onStatusUpdate: _updateProcurementStatus,
          onPaymentTrigger: _triggerPayment,
          onCompleteQueue: () async {
            final queueId = _toInt(
              queueItem['id'] ??
                  queueItem['queue_id'] ??
                  queueItem['queueId'],
            );

            if (queueId != null) {
              await _updateQueueStatus(
                queueId: queueId,
                status: 'Completed',
                successMessage:
                'Procurement completed successfully.',
              );
            }
          },
        );
      },
    );

    if (mounted) {
      await _loadDashboard(
        refresh: true,
      );
    }
  }

  // ============================================================
  // UPDATE PROCUREMENT STATUS
  // ============================================================

  Future<bool> _updateProcurementStatus({
    required int procurementId,
    required String status,
  }) async {
    if (_processingAction) return false;

    try {
      setState(() {
        _processingAction = true;
      });

      await _api.updateProcurementStatus(
        procurementId: procurementId,
        status: status,
      );

      return true;
    } catch (e) {
      if (mounted) {
        _showMessage(
          _friendlyError(e),
          isError: true,
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _processingAction = false;
        });
      }
    }
  }

  // ============================================================
  // TRIGGER PAYMENT
  // ============================================================

  Future<Map<String, dynamic>?> _triggerPayment(
      int procurementId,
      ) async {
    try {
      final response = await _network.post(
        '/procurement/$procurementId/trigger-payment',
      );

      final data = response.data;

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return null;
    } catch (e) {
      if (mounted) {
        _showMessage(
          _friendlyError(e),
          isError: true,
        );
      }

      return null;
    }
  }

  // ============================================================
  // NO SHOW
  // ============================================================

  Future<void> _markNoShow(
      dynamic item,
      ) async {
    final queueId = _toInt(
      item['id'] ??
          item['queue_id'] ??
          item['queueId'],
    );

    if (queueId == null) {
      _showMessage(
        'Queue ID is missing.',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Mark No Show?',
      message:
      'This farmer will be removed from the active queue.',
    );

    if (!confirmed) return;

    await _updateQueueStatus(
      queueId: queueId,
      status: 'No Show',
      successMessage: 'Farmer marked as no-show.',
    );
  }

  // ============================================================
  // COMPLETE OLD PROCESSING
  // ============================================================

  Future<void> _completeProcessing(
      dynamic item,
      ) async {
    await _openProcurementWorkflow(
      item,
    );
  }

  // ============================================================
  // UPDATE QUEUE
  // ============================================================

  Future<void> _updateQueueStatus({
    required int queueId,
    required String status,
    required String successMessage,
  }) async {
    if (_processingAction) return;

    setState(() {
      _processingAction = true;
    });

    try {
      await _api.updateQueueStatus(
        queueId: queueId,
        status: status,
      );

      if (!mounted) return;

      _showMessage(
        successMessage,
      );

      await _loadDashboard(
        refresh: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(e),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingAction = false;
        });
      }
    }
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void _toggleQueuePause() {
    setState(() {
      _queuePaused = !_queuePaused;
    });

    _showMessage(
      _queuePaused
          ? 'Queue processing paused.'
          : 'Queue processing resumed.',
    );
  }

  // ============================================================
  // QUEUE INFO
  // ============================================================

  void _showQueueInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              18,
              22,
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Icon(
                      Icons.queue_rounded,
                      color: Color(0xFF087A55),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Queue Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _infoTile(
                  'Waiting',
                  '$_waitingCount',
                  Icons.groups_outlined,
                ),
                _infoTile(
                  'Called',
                  '$_calledCount',
                  Icons.campaign_outlined,
                ),
                _infoTile(
                  'Processing',
                  '$_processingCount',
                  Icons.sync_rounded,
                ),
                _infoTile(
                  'Completed',
                  '$_completedCount',
                  Icons.check_circle_outline,
                ),
                _infoTile(
                  'Queue Status',
                  _queuePaused
                      ? 'Paused'
                      : 'Active',
                  _queuePaused
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // REPORTS
  // ============================================================

  void _showReports() {
    final capacity = _toInt(
      _centre?['capacity'],
    ) ??
        0;

    final utilization = _toDouble(
      _centre?['utilization_percentage'] ??
          _centre?['utilization'],
    ) ??
        0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              18,
              22,
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                  child: _sheetHandle(),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Centre Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _centreName,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                _reportRow(
                  'Total Queue',
                  '${_queue.length}',
                ),
                _reportRow(
                  'Waiting',
                  '$_waitingCount',
                ),
                _reportRow(
                  'Called',
                  '$_calledCount',
                ),
                _reportRow(
                  'Processing',
                  '$_processingCount',
                ),
                _reportRow(
                  'Completed',
                  '$_completedCount',
                ),
                _reportRow(
                  'Capacity',
                  '$capacity farmers',
                ),
                _reportRow(
                  'Utilization',
                  '${utilization.toStringAsFixed(0)}%',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFEFFAF5),
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color:
                        Color(0xFF087A55),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reports are generated from live centre queue data.',
                          style: TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CENTRE DETAILS
  // ============================================================

  String get _centreName {
    return _firstValue(
      _centre,
      [
        'name',
        'centre_name',
        'centreName',
      ],
      fallback: 'Procurement Centre',
    );
  }

  String get _centreStatus {
    return _firstValue(
      _centre,
      [
        'operational_status',
        'status',
      ],
      fallback: 'Operational',
    );
  }

  int get _capacity {
    return _toInt(
      _centre?['capacity'],
    ) ??
        0;
  }

  double get _utilization {
    return _toDouble(
      _centre?['utilization_percentage'] ??
          _centre?['utilization'],
    ) ??
        0;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F9F7),
      body: SafeArea(
        child: _loading
            ? const Center(
          child:
          CircularProgressIndicator(
            color: Color(0xFF087A55),
          ),
        )
            : RefreshIndicator(
          color:
          const Color(0xFF087A55),
          onRefresh: () =>
              _loadDashboard(
                refresh: true,
              ),
          child: CustomScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverToBoxAdapter(
                child: _buildStats(),
              ),
              SliverToBoxAdapter(
                child: _buildOperations(),
              ),
              SliverToBoxAdapter(
                child:
                _buildOperatorControls(),
              ),
              SliverToBoxAdapter(
                child: _buildSearch(),
              ),
              SliverToBoxAdapter(
                child:
                _buildQueueHeader(),
              ),
              SliverToBoxAdapter(
                child: _buildFilters(),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: _buildError(),
                ),
              if (_filteredQueue.isEmpty)
                SliverToBoxAdapter(
                  child:
                  _buildEmptyQueue(),
                )
              else
                SliverList(
                  delegate:
                  SliverChildBuilderDelegate(
                        (context, index) {
                      return _buildQueueCard(
                        _filteredQueue[
                        index],
                      );
                    },
                    childCount:
                    _filteredQueue.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child:
                SizedBox(height: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        16,
        18,
        18,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF056B4D),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius:
            BorderRadius.circular(20),
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/farmer/home');
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
              Colors.white.withOpacity(.12),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.agriculture_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmartProcure',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _centreName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(.72),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing
                ? null
                : () => _loadDashboard(
              refresh: true,
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.groups_outlined,
              title: 'Waiting',
              value: '$_waitingCount',
              color:
              const Color(0xFF008C5A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              icon:
              Icons.campaign_outlined,
              title: 'Called',
              value: '$_calledCount',
              color:
              const Color(0xFFE58B00),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              icon: Icons.sync_rounded,
              title: 'Processing',
              value: '$_processingCount',
              color:
              const Color(0xFF6558D3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      height: 92,
      padding:
      const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(.09),
              borderRadius:
              BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight:
              FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color:
              Colors.grey.shade600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPERATIONS
  // ============================================================

  Widget _buildOperations() {
    final utilization =
    _utilization.clamp(0, 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        12,
        14,
        14,
      ),
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(19),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFEAF8F2),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color:
                  Color(0xFF008C5A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centre Operations',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Live capacity utilization',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${utilization.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color:
                  Color(0xFF008C5A),
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius:
            BorderRadius.circular(20),
            child:
            LinearProgressIndicator(
              value: utilization / 100,
              minHeight: 7,
              backgroundColor:
              const Color(0xFFE8F0EC),
              valueColor:
              const AlwaysStoppedAnimation(
                Color(0xFF008C5A),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                'Capacity $_capacity farmers',
                style: TextStyle(
                  fontSize: 9,
                  color:
                  Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Text(
                _centreStatus,
                style: const TextStyle(
                  fontSize: 9,
                  color:
                  Color(0xFF008C5A),
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROLS
  // ============================================================

  Widget _buildOperatorControls() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Operator Controls',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF33443D),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _controlButton(
                  icon:
                  Icons.campaign_outlined,
                  title: 'Call Next',
                  color:
                  const Color(0xFF008C5A),
                  onTap: _callNext,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _controlButton(
                  icon: _queuePaused
                      ? Icons
                      .play_arrow_rounded
                      : Icons.pause_rounded,
                  title: _queuePaused
                      ? 'Resume'
                      : 'Pause',
                  color:
                  const Color(0xFFE58B00),
                  onTap:
                  _toggleQueuePause,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _controlButton(
                  icon:
                  Icons.bar_chart_rounded,
                  title: 'Reports',
                  color:
                  const Color(0xFF6558D3),
                  onTap: _showReports,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showQueueInfo,
              icon: const Icon(
                Icons.queue_rounded,
                size: 17,
              ),
              label: const Text(
                'View Queue Information',
              ),
              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                const Color(0xFF087A55),
                side: BorderSide(
                  color: const Color(
                    0xFF087A55,
                  ).withOpacity(.25),
                ),
                minimumSize:
                const Size.fromHeight(
                  42,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed:
        _processingAction
            ? null
            : onTap,
        style:
        OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color:
            color.withOpacity(.28),
          ),
          backgroundColor:
          color.withOpacity(.035),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              13,
            ),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        0,
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration:
        InputDecoration(
          hintText:
          'Search farmer, token or crop',
          hintStyle: TextStyle(
            fontSize: 11,
            color:
            Colors.grey.shade500,
          ),
          prefixIcon:
          const Icon(
            Icons.search_rounded,
            size: 20,
            color:
            Color(0xFF008C5A),
          ),
          filled: true,
          fillColor: Colors.white,
          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              15,
            ),
            borderSide:
            BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUEUE HEADER
  // ============================================================

  Widget _buildQueueHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        20,
        14,
        8,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Queue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage farmers currently at the centre',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
              const Color(0xFFEAF8F2),
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              '${_queue.length} farmers',
              style: const TextStyle(
                color:
                Color(0xFF008C5A),
                fontSize: 9,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    const filters = [
      'All',
      'Waiting',
      'Called',
      'Processing',
      'Completed',
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        scrollDirection:
        Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder:
            (context, index) {
          final filter =
          filters[index];

          final selected =
              _selectedFilter ==
                  filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedFilter =
                    filter;
              });
            },
            selectedColor:
            const Color(0xFF008C5A),
            backgroundColor:
            Colors.white,
            side: BorderSide(
              color: selected
                  ? const Color(
                  0xFF008C5A)
                  : Colors.grey.shade300,
            ),
            labelStyle:
            TextStyle(
              fontSize: 10,
              fontWeight:
              FontWeight.w600,
              color: selected
                  ? Colors.white
                  : const Color(
                  0xFF33443D),
            ),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyQueue() {
    final hasSearch =
        _searchQuery.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        0,
      ),
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration:
            const BoxDecoration(
              color:
              Color(0xFFEAF8F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              color:
              Color(0xFF008C5A),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'No matching farmers'
                : 'No farmers in queue',
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasSearch
                ? 'Try another farmer, token or crop.'
                : _queuePaused
                ? 'Queue processing is currently paused.'
                : 'The centre currently has no active queue.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color:
              Colors.grey.shade600,
            ),
          ),
          if (!hasSearch &&
              !_queuePaused) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
              _loadDashboard,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text(
                'Refresh Queue',
              ),
              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                const Color(
                  0xFF008C5A,
                ),
                side:
                const BorderSide(
                  color:
                  Color(0xFF008C5A),
                ),
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
        ],
      ),
    );
  }

  // ============================================================
  // QUEUE CARD
  // ============================================================

  Widget _buildQueueCard(
      dynamic item,
      ) {
    final status = _status(item);

    final farmerName = _firstValue(
      item,
      [
        'farmer_name',
        'name',
        'farmer',
      ],
      fallback: 'Farmer',
    );

    final token = _firstValue(
      item,
      [
        'token',
        'token_number',
        'queue_token',
      ],
      fallback: 'N/A',
    );

    final crop = _firstValue(
      item,
      [
        'crop',
        'crop_name',
      ],
      fallback: 'Crop',
    );

    final quantity = _firstValue(
      item,
      [
        'quantity_kg',
        'quantity',
      ],
      fallback: '-',
    );

    final queueId = _toInt(
      item['id'] ??
          item['queue_id'] ??
          item['queueId'],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        6,
        14,
        8,
      ),
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(19),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                BoxDecoration(
                  color:
                  _statusColor(status)
                      .withOpacity(.09),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons.person_outline,
                  color:
                  _statusColor(status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      farmerName,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      '$crop • $quantity kg',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors
                            .grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .end,
                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFEAF8F2,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                    ),
                    child: Text(
                      token,
                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF008C5A,
                        ),
                        fontSize: 10,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _statusLabel(
                      status,
                    ),
                    style: TextStyle(
                      color:
                      _statusColor(
                        status,
                      ),
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 11),
          _buildQueueActions(
            item,
            status,
            queueId,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUEUE ACTIONS
  // ============================================================

  Widget _buildQueueActions(
      dynamic item,
      String status,
      int? queueId,
      ) {
    if (queueId == null) {
      return const SizedBox.shrink();
    }

    if (status == 'waiting') {
      return Row(
        children: [
          Expanded(
            child: _smallAction(
              icon:
              Icons.campaign_outlined,
              label: 'Call Farmer',
              color:
              const Color(0xFF008C5A),
              onTap: () {
                _updateQueueStatus(
                  queueId: queueId,
                  status: 'Called',
                  successMessage:
                  'Farmer has been called.',
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _smallAction(
              icon:
              Icons.person_off_outlined,
              label: 'No Show',
              color:
              const Color(0xFFD64545),
              onTap: () {
                _markNoShow(item);
              },
            ),
          ),
        ],
      );
    }

    if (status == 'called') {
      return Row(
        children: [
          Expanded(
            child: _smallAction(
              icon:
              Icons.play_arrow_rounded,
              label: 'Start Processing',
              color:
              const Color(0xFF6558D3),
              onTap: () {
                _startProcessing(item);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _smallAction(
              icon:
              Icons.person_off_outlined,
              label: 'No Show',
              color:
              const Color(0xFFD64545),
              onTap: () {
                _markNoShow(item);
              },
            ),
          ),
        ],
      );
    }

    if (status == 'processing') {
      return SizedBox(
        width: double.infinity,
        child: _smallAction(
          icon:
          Icons.precision_manufacturing_outlined,
          label: 'Open Procurement Processing',
          color:
          const Color(0xFF008C5A),
          onTap: () {
            _completeProcessing(item);
          },
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF4F8F6),
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          status == 'completed'
              ? 'Procurement completed'
              : status == 'no show'
              ? 'Farmer marked as no-show'
              : 'No further action',
          style: TextStyle(
            fontSize: 10,
            color:
            Colors.grey.shade600,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _smallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed:
      _processingAction
          ? null
          : onTap,
      icon: Icon(
        icon,
        size: 16,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow:
        TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight:
          FontWeight.w700,
        ),
      ),
      style:
      OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color:
          color.withOpacity(.25),
        ),
        minimumSize:
        const Size.fromHeight(
          40,
        ),
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
            11,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        4,
      ),
      padding:
      const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
        const Color(0xFFFFF1F1),
        borderRadius:
        BorderRadius.circular(13),
        border: Border.all(
          color:
          const Color(0xFFFFD1D1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color:
            Color(0xFFD64545),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color:
                Color(0xFFB52E2E),
                fontSize: 10,
              ),
            ),
          ),
          TextButton(
            onPressed:
            _loadDashboard,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _status(dynamic item) {
    final raw = _firstValue(
      item,
      [
        'status',
        'queue_status',
      ],
      fallback: 'waiting',
    );

    return raw
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ');
  }

  String _statusLabel(
      String status,
      ) {
    switch (status) {
      case 'waiting':
        return 'Waiting';

      case 'called':
        return 'Called';

      case 'processing':
        return 'Processing';

      case 'completed':
        return 'Completed';

      case 'no show':
        return 'No Show';

      default:
        return status;
    }
  }

  Color _statusColor(
      String status,
      ) {
    switch (status) {
      case 'waiting':
        return const Color(
          0xFF008C5A,
        );

      case 'called':
        return const Color(
          0xFFE58B00,
        );

      case 'processing':
        return const Color(
          0xFF6558D3,
        );

      case 'completed':
        return const Color(
          0xFF1684D8,
        );

      case 'no show':
        return const Color(
          0xFFD64545,
        );

      default:
        return Colors.grey;
    }
  }

  String _firstValue(
      dynamic source,
      List<String> keys, {
        String fallback = '',
      }) {
    if (source is! Map) {
      return fallback;
    }

    for (final key in keys) {
      final value = source[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  int? _toInt(
      dynamic value,
      ) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  double? _toDouble(
      dynamic value,
      ) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  String _friendlyError(
      dynamic error,
      ) {
    final text = error.toString();

    if (text.contains(
      'SocketException',
    )) {
      return 'Unable to connect to the backend.';
    }

    if (text.contains('404')) {
      return 'Requested service was not found.';
    }

    if (text.contains('401')) {
      return 'Your operator session has expired.';
    }

    if (text.contains('403')) {
      return 'You are not authorized for this centre.';
    }

    if (text.contains('409')) {
      return 'State changed. Please refresh.';
    }

    return 'Unable to complete the operation.';
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content:
          Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF087A55,
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _sheetHandle() {
    return Container(
      width: 45,
      height: 5,
      decoration: BoxDecoration(
        color:
        Colors.grey.shade300,
        borderRadius:
        BorderRadius.circular(20),
      ),
    );
  }

  Widget _infoTile(
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
      const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF6F9F7),
        borderRadius:
        BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF087A55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF087A55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color:
                Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w600,
            ),
          ),
          backgroundColor: isError
              ? const Color(0xFFD64545)
              : const Color(0xFF087A55),
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            16,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              12,
            ),
          ),
          duration:
          const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  Future<void> _logout() async {
    final confirmed =
    await _confirm(
      title: 'Logout',
      message:
      'Do you want to logout from the operator account?',
    );

    if (!confirmed) return;

    await AuthService.clearToken();

    if (!mounted) return;

    context.go('/login');
  }
}

// ============================================================================
// PROCUREMENT WORKFLOW SHEET
// ============================================================================

class _ProcurementWorkflowSheet
    extends StatefulWidget {
  final String farmerName;
  final String crop;
  final double bookedQuantityKg;
  final Map<String, dynamic>? procurement;
  final int? farmerId;

  final Future<bool> Function({
  required int procurementId,
  required String status,
  }) onStatusUpdate;

  final Future<Map<String, dynamic>?> Function(
      int procurementId,
      ) onPaymentTrigger;

  final Future<void> Function()
  onCompleteQueue;

  const _ProcurementWorkflowSheet({
    required this.farmerName,
    required this.crop,
    required this.bookedQuantityKg,
    required this.procurement,
    required this.farmerId,
    required this.onStatusUpdate,
    required this.onPaymentTrigger,
    required this.onCompleteQueue,
  });

  @override
  State<_ProcurementWorkflowSheet>
  createState() =>
      _ProcurementWorkflowSheetState();
}

class _ProcurementWorkflowSheetState
    extends State<
        _ProcurementWorkflowSheet> {
  final _formKey =
  GlobalKey<FormState>();

  final _moistureController =
  TextEditingController();

  final _foreignMatterController =
  TextEditingController();

  final _damagedController =
  TextEditingController();

  final _weightController =
  TextEditingController();

  final _rateController =
  TextEditingController();

  final _deductionController =
  TextEditingController();

  final _remarksController =
  TextEditingController();

  bool _qualityPassed = true;
  bool _saving = false;
  bool _paymentTriggered = false;

  String _currentStage =
      'Quality Checking';

  Map<String, dynamic>? _payment;

  int? get _procurementId {
    final value =
        widget.procurement?['id'] ??
            widget.procurement?[
            'procurement_id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  double get _bookedWeight =>
      widget.bookedQuantityKg;

  double get _actualWeight {
    return double.tryParse(
      _weightController.text
          .trim(),
    ) ??
        0;
  }

  double get _rate {
    return double.tryParse(
      _rateController.text
          .trim(),
    ) ??
        0;
  }

  double get _deductions {
    return double.tryParse(
      _deductionController.text
          .trim(),
    ) ??
        0;
  }

  double get _grossAmount =>
      _actualWeight * _rate;

  double get _netAmount =>
      (_grossAmount - _deductions)
          .clamp(0, double.infinity);

  double get _weightVariance =>
      _actualWeight - _bookedWeight;

  @override
  void initState() {
    super.initState();

    final procurement =
        widget.procurement;

    _moistureController.text =
        _numberText(
          procurement?[
          'moisture_percentage'],
        );

    _foreignMatterController.text =
        _numberText(
          procurement?[
          'foreign_matter_percentage'],
        );

    _damagedController.text =
        _numberText(
          procurement?[
          'damaged_percentage'],
        );

    _weightController.text =
    _numberText(
      procurement?[
      'actual_weight_kg'],
    ).isEmpty
        ? widget.bookedQuantityKg
        .toStringAsFixed(2)
        : _numberText(
      procurement?[
      'actual_weight_kg'],
    );

    _rateController.text =
    _numberText(
      procurement?['rate_per_kg'],
    ).isEmpty
        ? '23'
        : _numberText(
      procurement?[
      'rate_per_kg'],
    );

    _deductionController.text =
    _numberText(
      procurement?['deductions'],
    ).isEmpty
        ? '0'
        : _numberText(
      procurement?[
      'deductions'],
    );

    _remarksController.text =
        procurement?[
        'quality_remarks']
            ?.toString() ??
            '';

    final qualityPassed =
    procurement?['quality_passed'];

    if (qualityPassed is bool) {
      _qualityPassed =
          qualityPassed;
    }

    final status =
    procurement?['status']
        ?.toString();

    if (status != null &&
        status.isNotEmpty) {
      _currentStage = status;
    }
  }

  @override
  void dispose() {
    _moistureController.dispose();
    _foreignMatterController.dispose();
    _damagedController.dispose();
    _weightController.dispose();
    _rateController.dispose();
    _deductionController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _numberText(
      dynamic value,
      ) {
    if (value == null) return '';

    if (value is num) {
      return value.toString();
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints:
        BoxConstraints(
          maxHeight:
          MediaQuery.of(context)
              .size
              .height *
              .94,
        ),
        decoration:
        const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius:
          BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  28,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      _buildFarmerSummary(),
                      const SizedBox(
                        height: 14,
                      ),
                      _buildStageIndicator(),
                      const SizedBox(
                        height: 18,
                      ),
                      _buildQualitySection(),
                      const SizedBox(
                        height: 14,
                      ),
                      _buildWeighingSection(),
                      const SizedBox(
                        height: 14,
                      ),
                      _buildAmountSection(),
                      const SizedBox(
                        height: 14,
                      ),
                      _buildRemarksSection(),
                      const SizedBox(
                        height: 18,
                      ),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TOP BAR
  // ==========================================================

  Widget _buildTopBar() {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        15,
        12,
        15,
      ),
      decoration:
      const BoxDecoration(
        color: Color(0xFF056B4D),
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(
              color:
              Colors.white.withOpacity(
                .12,
              ),
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              Icons
                  .precision_manufacturing_outlined,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Procurement Processing',
                  style:
                  TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Quality • Weighing • Amount • Payment',
                  style:
                  TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                () => Navigator.pop(
              context,
            ),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FARMER
  // ==========================================================

  Widget _buildFarmerSummary() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(15),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            const BoxDecoration(
              color: Color(0xFFEAF8F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color:
              Color(0xFF087A55),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  widget.farmerName,
                  style:
                  const TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.crop} • ${widget.bookedQuantityKg.toStringAsFixed(2)} kg booked',
                  style:
                  TextStyle(
                    fontSize: 10,
                    color:
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STAGE
  // ==========================================================

  Widget _buildStageIndicator() {
    const stages = [
      'Quality',
      'Weighing',
      'Amount',
      'Payment',
    ];

    int activeIndex = 0;

    switch (_currentStage) {
      case 'Weighing':
        activeIndex = 1;
        break;

      case 'Completed':
        activeIndex = 3;
        break;

      default:
        activeIndex = 0;
    }

    return Row(
      children:
      List.generate(
        stages.length,
            (index) {
          final active =
              index <= activeIndex;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child:
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration:
                        BoxDecoration(
                          color: active
                              ? const Color(
                            0xFF087A55,
                          )
                              : const Color(
                            0xFFE0E8E3,
                          ),
                          shape:
                          BoxShape.circle,
                        ),
                        child: Icon(
                          active
                              ? Icons
                              .check_rounded
                              : Icons
                              .radio_button_unchecked,
                          color: active
                              ? Colors.white
                              : Colors
                              .grey
                              .shade500,
                          size: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        stages[index],
                        style:
                        TextStyle(
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w700,
                          color: active
                              ? const Color(
                            0xFF087A55,
                          )
                              : Colors
                              .grey
                              .shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index <
                    stages.length - 1)
                  Container(
                    width: 18,
                    height: 2,
                    color: index <
                        activeIndex
                        ? const Color(
                      0xFF087A55,
                    )
                        : const Color(
                      0xFFDDE5E0,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // QUALITY
  // ==========================================================

  Widget _buildQualitySection() {
    return _sectionCard(
      title: '1. Quality Inspection',
      icon:
      Icons.science_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller:
                  _moistureController,
                  label: 'Moisture %',
                  icon:
                  Icons.water_drop_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _numberField(
                  controller:
                  _foreignMatterController,
                  label:
                  'Foreign Matter %',
                  icon:
                  Icons.grass_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _numberField(
            controller:
            _damagedController,
            label: 'Damaged %',
            icon:
            Icons.warning_amber_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            padding:
            const EdgeInsets.all(12),
            decoration:
            BoxDecoration(
              color: _qualityPassed
                  ? const Color(
                0xFFEAF8F2,
              )
                  : const Color(
                0xFFFFF1F1,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _qualityPassed
                      ? Icons
                      .check_circle_outline
                      : Icons
                      .cancel_outlined,
                  color: _qualityPassed
                      ? const Color(
                    0xFF087A55,
                  )
                      : const Color(
                    0xFFD64545,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Quality inspection result',
                    style:
                    TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value:
                  _qualityPassed,
                  activeColor:
                  const Color(
                    0xFF087A55,
                  ),
                  onChanged:
                      (value) {
                    setState(() {
                      _qualityPassed =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // WEIGHING
  // ==========================================================

  Widget _buildWeighingSection() {
    return _sectionCard(
      title: '2. Digital Weighing',
      icon:
      Icons.monitor_weight_outlined,
      child: Column(
        children: [
          _numberField(
            controller:
            _weightController,
            label:
            'Actual Weight (kg)',
            icon:
            Icons.scale_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(13),
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFF3F7F5),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .compare_arrows_rounded,
                  color:
                  Color(0xFF087A55),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Weight variance',
                    style:
                    TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_weightVariance >= 0 ? '+' : ''}${_weightVariance.toStringAsFixed(2)} kg',
                  style:
                  TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w800,
                    color: _weightVariance >=
                        0
                        ? const Color(
                      0xFF087A55,
                    )
                        : const Color(
                      0xFFD64545,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // AMOUNT
  // ==========================================================

  Widget _buildAmountSection() {
    return _sectionCard(
      title: '3. Amount Calculation',
      icon:
      Icons.currency_rupee_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller:
                  _rateController,
                  label:
                  'Rate / kg',
                  icon:
                  Icons.price_change_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _numberField(
                  controller:
                  _deductionController,
                  label:
                  'Deductions',
                  icon:
                  Icons.remove_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _amountRow(
            'Actual Weight',
            '${_actualWeight.toStringAsFixed(2)} kg',
          ),
          _amountRow(
            'Rate',
            '₹${_rate.toStringAsFixed(2)} / kg',
          ),
          _amountRow(
            'Gross Amount',
            '₹${_grossAmount.toStringAsFixed(2)}',
          ),
          _amountRow(
            'Deductions',
            '- ₹${_deductions.toStringAsFixed(2)}',
          ),
          const Divider(height: 20),
          _amountRow(
            'NET PAYABLE',
            '₹${_netAmount.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // REMARKS
  // ==========================================================

  Widget _buildRemarksSection() {
    return _sectionCard(
      title: 'Inspection Remarks',
      icon:
      Icons.notes_outlined,
      child: TextFormField(
        controller:
        _remarksController,
        maxLines: 4,
        decoration:
        InputDecoration(
          hintText:
          'Enter quality or procurement remarks...',
          hintStyle:
          const TextStyle(
            fontSize: 11,
          ),
          filled: true,
          fillColor:
          const Color(0xFFF7FAF8),
          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              13,
            ),
            borderSide:
            BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Widget _buildActions() {
    final id = _procurementId;

    return Column(
      children: [
        if (id == null)
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(12),
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFFFF7E8),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color:
                  Color(0xFFE58B00),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No procurement record is linked to this queue entry yet.',
                    style:
                    TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (id != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed:
              _saving
                  ? null
                  : _saveQuality,
              icon: const Icon(
                Icons.science_outlined,
              ),
              label: const Text(
                'Complete Quality Check',
              ),
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF087A55,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
              _saving
                  ? null
                  : _completeAndPay,
              icon: const Icon(
                Icons
                    .account_balance_wallet_outlined,
              ),
              label: const Text(
                'Complete & Trigger Payment',
              ),
              style:
              OutlinedButton.styleFrom(
                foregroundColor:
                const Color(
                  0xFF087A55,
                ),
                side:
                const BorderSide(
                  color:
                  Color(0xFF087A55),
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // QUALITY SAVE
  // ==========================================================

  Future<void> _saveQuality() async {
    if (_procurementId == null) {
      _showMessage(
        'Procurement record not found.',
        error: true,
      );
      return;
    }

    if (!_qualityPassed) {
      _showMessage(
        'Quality check has failed. Resolve the quality issue before completion.',
        error: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final success =
      await widget.onStatusUpdate(
        procurementId:
        _procurementId!,
        status:
        'Quality Checking',
      );

      if (!success) return;

      if (!mounted) return;

      setState(() {
        _currentStage =
        'Quality Checking';
      });

      _showMessage(
        'Quality check completed.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================================
  // COMPLETE AND PAYMENT
  // ==========================================================

  Future<void> _completeAndPay() async {
    final id = _procurementId;

    if (id == null) {
      _showMessage(
        'Procurement record not found.',
        error: true,
      );
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (!_qualityPassed) {
      _showMessage(
        'Quality check must pass before completion.',
        error: true,
      );
      return;
    }

    if (_actualWeight <= 0) {
      _showMessage(
        'Enter a valid actual weight.',
        error: true,
      );
      return;
    }

    if (_rate <= 0) {
      _showMessage(
        'Enter a valid rate per kg.',
        error: true,
      );
      return;
    }

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
          const Text(
            'Complete Procurement?',
          ),
          content: Text(
            'Net payable amount is ₹${_netAmount.toStringAsFixed(2)}.\n\nComplete procurement and trigger payment?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF087A55,
                ),
              ),
              child:
              const Text('Complete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // --------------------------------------------------------
      // STEP 1: QUALITY
      // --------------------------------------------------------

      if (_currentStage !=
          'Quality Checking' &&
          _currentStage !=
              'Weighing' &&
          _currentStage !=
              'Completed') {
        final qualitySuccess =
        await widget.onStatusUpdate(
          procurementId: id,
          status:
          'Quality Checking',
        );

        if (!qualitySuccess) {
          return;
        }
      }

      // --------------------------------------------------------
      // STEP 2: WEIGHING
      // --------------------------------------------------------

      final weighingSuccess =
      await widget.onStatusUpdate(
        procurementId: id,
        status: 'Weighing',
      );

      if (!weighingSuccess) {
        return;
      }

      if (mounted) {
        setState(() {
          _currentStage =
          'Weighing';
        });
      }

      // --------------------------------------------------------
      // STEP 3: COMPLETE
      // --------------------------------------------------------

      final completeSuccess =
      await widget.onStatusUpdate(
        procurementId: id,
        status: 'Completed',
      );

      if (!completeSuccess) {
        return;
      }

      if (mounted) {
        setState(() {
          _currentStage =
          'Completed';
        });
      }

      // --------------------------------------------------------
      // STEP 4: TRIGGER PAYMENT
      // --------------------------------------------------------

      final payment =
      await widget.onPaymentTrigger(
        id,
      );

      if (!mounted) return;

      if (payment != null) {
        _payment = payment;
        _paymentTriggered = true;
      }

      // --------------------------------------------------------
      // STEP 5: COMPLETE QUEUE
      // --------------------------------------------------------

      await widget.onCompleteQueue();

      if (!mounted) return;

      await _showSuccessDialog();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          title: const Row(
            children: [
              Icon(
                Icons
                    .check_circle_rounded,
                color:
                Color(0xFF087A55),
              ),
              SizedBox(width: 10),
              Text(
                'Procurement Completed',
              ),
            ],
          ),
          content: Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              _successRow(
                'Farmer',
                widget.farmerName,
              ),
              _successRow(
                'Actual Weight',
                '${_actualWeight.toStringAsFixed(2)} kg',
              ),
              _successRow(
                'Rate',
                '₹${_rate.toStringAsFixed(2)} / kg',
              ),
              _successRow(
                'Gross Amount',
                '₹${_grossAmount.toStringAsFixed(2)}',
              ),
              _successRow(
                'Deductions',
                '₹${_deductions.toStringAsFixed(2)}',
              ),
              const Divider(),
              _successRow(
                'Net Payable',
                '₹${_netAmount.toStringAsFixed(2)}',
                bold: true,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(
                  11,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFEAF8F2,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .account_balance_outlined,
                      color:
                      Color(0xFF087A55),
                    ),
                    const SizedBox(
                        width: 8),
                    Expanded(
                      child: Text(
                        _paymentTriggered
                            ? 'Payment has been triggered successfully.'
                            : 'Procurement completed. Payment trigger response unavailable.',
                        style:
                        const TextStyle(
                          fontSize: 10,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
                Navigator.pop(
                  context,
                );
              },
              style:
              FilledButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF087A55,
                ),
              ),
              child:
              const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _successRow(
      String label,
      String value, {
        bool bold = false,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w800,
              color: bold
                  ? const Color(
                0xFF087A55,
              )
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION CARD
  // ==========================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(15),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFEAF8F2,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                  const Color(
                    0xFF087A55,
                  ),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ==========================================================
  // INPUT
  // ==========================================================

  Widget _numberField({
    required TextEditingController
    controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
      const TextInputType.numberWithOptions(
        decimal: true,
      ),
      onChanged: (_) {
        setState(() {});
      },
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Required';
        }

        if (double.tryParse(
          value.trim(),
        ) ==
            null) {
          return 'Invalid';
        }

        return null;
      },
      decoration:
      InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(
          fontSize: 10,
        ),
        prefixIcon:
        Icon(
          icon,
          size: 18,
          color:
          const Color(
            0xFF087A55,
          ),
        ),
        filled: true,
        fillColor:
        const Color(0xFFF7FAF8),
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            13,
          ),
          borderSide:
          BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _amountRow(
      String label,
      String value, {
        bool bold = false,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w800,
              color: bold
                  ? const Color(
                0xFF087A55,
              )
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _openProcurementProcessing(
      Map<String, dynamic> item,
      ) {
    final bookingId = int.tryParse(
      item['booking_id']?.toString() ?? '',
    );

    if (bookingId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Booking ID is unavailable.',
          ),
        ),
      );

      return;
    }

    context.push(
      '/operator/procurement/$bookingId',
    );
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? const Color(
            0xFFD64545,
          )
              : const Color(
            0xFF087A55,
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }
}