import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_service.dart';

class AiDashboardScreen extends StatefulWidget {
  const AiDashboardScreen({super.key});

  @override
  State<AiDashboardScreen> createState() =>
      _AiDashboardScreenState();
}

class _AiDashboardScreenState
    extends State<AiDashboardScreen> {
  final Dio _client =
      ApiService.instance.client;

  int _selectedCentreId = 1;

  bool _loading = true;
  bool _backendAvailable = false;
  bool _refreshing = false;

  String? _error;

  Map<String, dynamic>? _dashboard;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _loadDashboard();

    // Refresh operational intelligence every 30 seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        _loadDashboard(
          silent: true,
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ==========================================================
  // API
  // ==========================================================

  Future<void> _loadDashboard({
    bool silent = false,
  }) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    if (silent && mounted) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final response =
      await _client
          .get(
        '/ai/dashboard',
        queryParameters: {
          'centre_id':
          _selectedCentreId,
        },
      )
          .timeout(
        const Duration(
          seconds: 6,
        ),
      );

      final data =
      _toStringMap(
        response.data,
      );

      if (!mounted) return;

      if (data['success'] == false) {
        throw Exception(
          data['message'] ??
              'AI dashboard unavailable',
        );
      }

      setState(() {
        _dashboard = data;
        _backendAvailable = true;
        _error = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _backendAvailable = false;
        _loading = false;
        _refreshing = false;
        _error = _friendlyError(e);
      });
    }
  }

  // ==========================================================
  // SAFE MAP CONVERSION
  // ==========================================================

  Map<String, dynamic> _toStringMap(
      dynamic value,
      ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _section(
      String key,
      ) {
    final value =
    _dashboard?[key];

    return _toStringMap(value);
  }

  dynamic _value(
      String section,
      String key,
      ) {
    return _section(section)[key];
  }

  String _text(
      dynamic value, [
        String fallback = '--',
      ]) {
    if (value == null) {
      return fallback;
    }

    final result =
    value.toString().trim();

    if (result.isEmpty) {
      return fallback;
    }

    return result;
  }

  int _int(
      dynamic value, [
        int fallback = 0,
      ]) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        fallback;
  }

  double _double(
      dynamic value, [
        double fallback = 0,
      ]) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        fallback;
  }

  // ==========================================================
  // FRIENDLY ERROR
  // ==========================================================

  String _friendlyError(
      dynamic error,
      ) {
    if (error is TimeoutException) {
      return 'AI server took too long to respond.';
    }

    if (error is DioException) {
      if (error.type ==
          DioExceptionType.connectionError) {
        return 'Cannot connect to the AI server.';
      }

      if (error.response?.statusCode ==
          404) {
        return 'AI dashboard endpoint was not found.';
      }

      if (error.response?.statusCode ==
          500) {
        return 'AI server returned an internal error.';
      }

      return 'AI service is temporarily unavailable.';
    }

    return 'AI service is temporarily unavailable.';
  }

  // ==========================================================
  // CENTRE CHANGE
  // ==========================================================

  Future<void> _changeCentre(
      int centreId,
      ) async {
    if (_selectedCentreId ==
        centreId) {
      return;
    }

    setState(() {
      _selectedCentreId =
          centreId;
      _dashboard = null;
      _loading = true;
      _error = null;
    });

    await _loadDashboard();
  }

  // ==========================================================
  // BACK
  // ==========================================================

  void _goBack() {
    if (Navigator.of(context)
        .canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(
        '/farmer/home',
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF4F8F5),
      appBar: AppBar(
        backgroundColor:
        Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF12372A),
          ),
        ),
        title: const Text(
          'AI Intelligence',
          style: TextStyle(
            color: Color(0xFF12372A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh AI',
            onPressed:
            _refreshing
                ? null
                : () =>
                _loadDashboard(),
            icon: _refreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,
              color:
              Color(0xFF12372A),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  // ==========================================================
  // BODY
  // ==========================================================

  Widget _buildBody() {
    if (_loading &&
        _dashboard == null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildCentreSelector(),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding:
              EdgeInsets.all(30),
              child:
              CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      children: [
        _buildHeroCard(),

        const SizedBox(height: 12),

        if (!_backendAvailable)
          _buildOfflineBanner(),

        const SizedBox(height: 12),

        _buildCentreSelector(),

        const SizedBox(height: 20),

        _buildLiveSection(),

        const SizedBox(height: 24),

        _buildPredictiveSection(),

        const SizedBox(height: 24),

        _buildActionPlan(),

        const SizedBox(height: 24),

        _buildArrivalAdvisor(),

        const SizedBox(height: 24),

        _buildExplainableAi(),

        const SizedBox(height: 20),

        if (!_backendAvailable)
          _buildRetryButton(),
      ],
    );
  }

  // ==========================================================
  // HERO
  // ==========================================================

  Widget _buildHeroCard() {
    final centre =
    _section('centre');

    final centreName =
    _text(
      centre['name'],
      'Procurement Centre',
    );

    return Container(
      padding:
      const EdgeInsets.all(20),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFF0F6B43),
            Color(0xFF218653),
          ],
        ),
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.15,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child:
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'SmartProcure AI',
                      style: TextStyle(
                        color:
                        Colors.white,
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Intelligent procurement decision engine',
                      style: TextStyle(
                        color:
                        Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            centreName,
            style:
            const TextStyle(
              color: Colors.white,
              fontWeight:
              FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Real-time queue intelligence, demand forecasting, delay prediction and smart slot planning.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // OFFLINE / ERROR BANNER
  // ==========================================================

  Widget _buildOfflineBanner() {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        const Color(0xFFFFF7EA),
        borderRadius:
        BorderRadius.circular(16),
        border:
        Border.all(
          color:
          const Color(0xFFFFD39A),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color:
            Color(0xFFE58A00),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'AI service temporarily unavailable',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    fontSize: 12,
                    color:
                    Color(0xFF8A5600),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  _error ??
                      'Connect to the backend and retry.',
                  style:
                  const TextStyle(
                    fontSize: 11,
                    color:
                    Color(0xFF8A5600),
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
  // CENTRE SELECTOR
  // ==========================================================

  Widget _buildCentreSelector() {
    final centre =
    _section('centre');

    final name =
    _text(
      centre['name'],
      'Kancheepuram Procurement Centre',
    );

    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFEAF7EF),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child:
            const Icon(
              Icons.location_on_rounded,
              color:
              Color(0xFF15935C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Analysing Centre',
                  style: TextStyle(
                    fontSize: 10,
                    color:
                    Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF18372B),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip:
            'Change centre',
            icon: const Icon(
              Icons
                  .keyboard_arrow_down_rounded,
              color:
              Color(0xFF18372B),
            ),
            onSelected:
            _changeCentre,
            itemBuilder:
                (context) => [
              const PopupMenuItem(
                value: 1,
                child: Text(
                  'Kancheepuram Centre',
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text(
                  'Sriperumbudur Centre',
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: Text(
                  'Walajabad Centre',
                ),
              ),
              const PopupMenuItem(
                value: 4,
                child: Text(
                  'Uthiramerur Centre',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LIVE INTELLIGENCE
  // ==========================================================

  Widget _buildLiveSection() {
    final live =
    _section('live');

    final waiting =
    _int(
      live['waiting'],
    );

    final processing =
    _int(
      live['processing'],
    );

    final utilization =
    _double(
      live[
      'utilization_percentage'
      ],
    );

    final completed =
    _int(
      live['completed'],
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons
              .multiline_chart_rounded,
          'Live Operational Intelligence',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics:
          const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio:
          1.45,
          children: [
            _metricCard(
              icon:
              Icons.groups_rounded,
              iconColor:
              const Color(0xFF1976D2),
              title: 'Waiting',
              value:
              waiting.toString(),
              suffix: 'farmers',
            ),
            _metricCard(
              icon:
              Icons.access_time_rounded,
              iconColor:
              const Color(0xFFFF6F00),
              title:
              'AI Wait',
              value:
              _aiWaitText(),
              suffix:
              _aiWaitSuffix(),
            ),
            _metricCard(
              icon:
              Icons.speed_rounded,
              iconColor:
              const Color(0xFF15935C),
              title:
              'Utilization',
              value:
              '${utilization.toStringAsFixed(1)}%',
              suffix:
              'capacity',
            ),
            _metricCard(
              icon:
              Icons
                  .precision_manufacturing_rounded,
              iconColor:
              const Color(0xFF6A45C7),
              title:
              'Processing',
              value:
              processing.toString(),
              suffix:
              'active',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(14),
            border:
            Border.all(
              color:
              const Color(0xFFE0E8E3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .check_circle_outline_rounded,
                color:
                Color(0xFF15935C),
                size: 19,
              ),
              const SizedBox(
                width: 8,
              ),
              const Expanded(
                child: Text(
                  'Completed procurement',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                    Colors.grey,
                  ),
                ),
              ),
              Text(
                completed.toString(),
                style:
                const TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF15935C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _aiWaitText() {
    final predictions =
    _section(
      'predictions',
    );

    final value =
    predictions[
    'estimated_wait_minutes'
    ];

    if (value == null) {
      return '--';
    }

    return _int(
      value,
    ).toString();
  }

  String _aiWaitSuffix() {
    final predictions =
    _section(
      'predictions',
    );

    if (predictions[
    'estimated_wait_minutes'
    ] ==
        null) {
      return 'predicted';
    }

    return 'minutes';
  }

  // ==========================================================
  // PREDICTIVE ANALYTICS
  // ==========================================================

  Widget _buildPredictiveSection() {
    final predictions =
    _section(
      'predictions',
    );

    final wait =
    _int(
      predictions[
      'estimated_wait_minutes'
      ],
      -1,
    );

    final demand =
    _double(
      predictions[
      'predicted_demand'
      ],
      -1,
    );

    final demandLevel =
    _text(
      predictions[
      'demand_level'
      ],
      'Unavailable',
    );

    final congestion =
    _text(
      predictions[
      'congestion'
      ],
      'Unavailable',
    );

    final delayRisk =
    _text(
      predictions[
      'delay_risk'
      ],
      'Unavailable',
    );

    final confidence =
    _double(
      predictions[
      'confidence'
      ],
      -1,
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.auto_graph_rounded,
          'Predictive Analytics',
        ),
        const SizedBox(height: 12),
        _predictionCard(
          icon:
          Icons.access_time_rounded,
          color:
          const Color(0xFFFF6F00),
          title:
          'Wait-Time Prediction',
          value:
          wait < 0
              ? 'Unavailable'
              : '$wait minutes',
          subtitle:
          wait < 0
              ? 'AI data unavailable'
              : 'Estimated farmer waiting time',
        ),
        const SizedBox(height: 10),
        _predictionCard(
          icon:
          Icons.trending_up_rounded,
          color:
          const Color(0xFF1976D2),
          title:
          'Demand Forecast',
          value:
          demand < 0
              ? 'Unavailable'
              : demand.toStringAsFixed(
            1,
          ),
          subtitle:
          demand < 0
              ? 'AI data unavailable'
              : '$demandLevel demand expected',
        ),
        const SizedBox(height: 10),
        _predictionCard(
          icon:
          Icons.warning_amber_rounded,
          color:
          _riskColor(
            delayRisk,
          ),
          title:
          'Delay Risk',
          value:
          delayRisk,
          subtitle:
          'Operational delay assessment',
        ),
        const SizedBox(height: 10),
        _predictionCard(
          icon:
          Icons.psychology_rounded,
          color:
          const Color(0xFF6A45C7),
          title:
          'AI Confidence',
          value:
          confidence < 0
              ? 'Unavailable'
              : '${confidence.toStringAsFixed(0)}%',
          subtitle:
          'Confidence based on available operational data',
        ),
        const SizedBox(height: 10),
        _statusRow(
          'Current congestion',
          congestion,
          _congestionColor(
            congestion,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ACTION PLAN
  // ==========================================================

  Widget _buildActionPlan() {
    final recommendation =
    _section(
      'recommendation',
    );

    final priority =
    _text(
      recommendation[
      'priority'
      ],
      'UNAVAILABLE',
    );

    final action =
    _text(
      recommendation[
      'action'
      ],
      'AI recommendation unavailable',
    );

    final reason =
    _text(
      recommendation[
      'reason'
      ],
      'Connect to the backend to receive an operational recommendation.',
    );

    final color =
    _priorityColor(
      priority,
    );

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color:
          color.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .bolt_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'AI Action Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF18372B),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 10,
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
              priority,
              style:
              TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            action,
            style:
            const TextStyle(
              fontSize: 15,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF18372B),
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            reason,
            style:
            const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ARRIVAL ADVISOR
  // ==========================================================

  Widget _buildArrivalAdvisor() {
    final predictions =
    _section(
      'predictions',
    );

    final wait =
    _int(
      predictions[
      'estimated_wait_minutes'
      ],
      -1,
    );

    if (wait < 0) {
      return _unavailableFeatureCard(
        Icons.schedule_rounded,
        'AI Arrival Advisor',
        'Waiting-time intelligence is currently unavailable.',
      );
    }

    final now =
    DateTime.now();

    final arrival =
    now.add(
      Duration(
        minutes:
        wait > 10
            ? wait - 10
            : 0,
      ),
    );

    final hour =
    arrival.hour
        .toString()
        .padLeft(
      2,
      '0',
    );

    final minute =
    arrival.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFFEAF7EF),
            Color(0xFFF5FBF7),
          ],
        ),
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color:
          const Color(0xFFCDE8D8),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color:
                  Colors.white,
                  borderRadius:
                  BorderRadius
                      .circular(
                    13,
                  ),
                ),
                child:
                const Icon(
                  Icons
                      .schedule_rounded,
                  color:
                  Color(0xFF15935C),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'AI Arrival Advisor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        Color(0xFF18372B),
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Reduce unnecessary waiting at the centre',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'Recommended arrival window',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            '$hour:$minute',
            style:
            const TextStyle(
              fontSize: 28,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF0F6B43),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            'Based on the current estimated wait of $wait minutes.',
            style:
            const TextStyle(
              fontSize: 11,
              color:
              Color(0xFF456056),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EXPLAINABLE AI
  // ==========================================================

  Widget _buildExplainableAi() {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .psychology_alt_rounded,
                color:
                Color(0xFF6A45C7),
                size: 22,
              ),
              const SizedBox(
                width: 8,
              ),
              const Text(
                'Why This Prediction?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF18372B),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          _reasonItem(
            Icons.groups_rounded,
            'Current queue',
          ),
          _reasonItem(
            Icons.speed_rounded,
            'Centre processing speed',
          ),
          _reasonItem(
            Icons
                .account_balance_rounded,
            'Centre capacity',
          ),
          _reasonItem(
            Icons.trending_up_rounded,
            'Current demand',
          ),
          _reasonItem(
            Icons
                .donut_large_rounded,
            'Centre utilization',
          ),
        ],
      ),
    );
  }

  Widget _reasonItem(
      IconData icon,
      String text,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
            const Color(0xFF15935C),
          ),
          const SizedBox(
            width: 9,
          ),
          Text(
            text,
            style:
            const TextStyle(
              fontSize: 11,
              color:
              Color(0xFF4C5C53),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RETRY
  // ==========================================================

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
        _loading
            ? null
            : _loadDashboard,
        icon: const Icon(
          Icons.refresh_rounded,
        ),
        label: const Text(
          'Retry AI Analysis',
        ),
        style:
        FilledButton.styleFrom(
          backgroundColor:
          const Color(0xFF15935C),
          padding:
          const EdgeInsets
              .symmetric(
            vertical: 14,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // METRIC CARD
  // ==========================================================

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String suffix,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(17),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: iconColor,
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                  title,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style:
            TextStyle(
              fontSize: 21,
              fontWeight:
              FontWeight.w800,
              color: value == '--'
                  ? Colors.grey
                  : iconColor,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            suffix,
            style:
            const TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PREDICTION CARD
  // ==========================================================

  Widget _predictionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(17),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
            BoxDecoration(
              color:
              color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child:
            Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF18372B),
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            value,
            textAlign:
            TextAlign.right,
            style:
            TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS ROW
  // ==========================================================

  Widget _statusRow(
      String title,
      String value,
      Color color,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
              const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 10,
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
              value,
              style:
              TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // UNAVAILABLE CARD
  // ==========================================================

  Widget _unavailableFeatureCard(
      IconData icon,
      String title,
      String message,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border:
        Border.all(
          color:
          const Color(0xFFE0E8E3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
            const Color(0xFFFF9800),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  message,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
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
  // SECTION TITLE
  // ==========================================================

  Widget _sectionTitle(
      IconData icon,
      String title,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color:
          const Color(0xFF12372A),
        ),
        const SizedBox(
          width: 6,
        ),
        Text(
          title,
          style:
          const TextStyle(
            fontSize: 14,
            fontWeight:
            FontWeight.w800,
            color:
            Color(0xFF12372A),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // COLORS
  // ==========================================================

  Color _riskColor(
      String risk,
      ) {
    switch (
    risk.toLowerCase()) {
      case 'high':
        return const Color(
          0xFFD32F2F,
        );

      case 'medium':
        return const Color(
          0xFFF57C00,
        );

      case 'low':
        return const Color(
          0xFF15935C,
        );

      default:
        return Colors.grey;
    }
  }

  Color _congestionColor(
      String value,
      ) {
    return _riskColor(
      value,
    );
  }

  Color _priorityColor(
      String priority,
      ) {
    switch (
    priority.toUpperCase()) {
      case 'URGENT':
        return const Color(
          0xFFD32F2F,
        );

      case 'ATTENTION':
        return const Color(
          0xFFF57C00,
        );

      case 'NORMAL':
        return const Color(
          0xFF15935C,
        );

      default:
        return Colors.grey;
    }
  }
}