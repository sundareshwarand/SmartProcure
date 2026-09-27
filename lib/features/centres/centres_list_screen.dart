import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/api_service.dart';
import '../../core/network/farmer_api_service.dart';

class CentresListScreen extends StatefulWidget {
  const CentresListScreen({super.key});

  @override
  State<CentresListScreen> createState() =>
      _CentresListScreenState();
}

class _CentresListScreenState
    extends State<CentresListScreen> {
  final FarmerApiService _api =
      FarmerApiService.instance;

  List<dynamic> _centres = [];

  bool _loading = true;
  bool _loadingRecommendation = false;

  String? _error;

  String _search = '';

  String _filter = 'All';

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _loadCentres() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final centres = await _api
          .getCentres()
          .timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      setState(() {
        _centres = centres;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
        'Unable to load procurement centres.';
      });
    }
  }

  // ===========================================================================
  // LOCATION
  // ===========================================================================

  Future<void> _findNearestCentre() async {
    if (_loadingRecommendation) return;

    setState(() {
      _loadingRecommendation = true;
    });

    try {
      final enabled =
      await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        _showMessage(
          'Please enable location services.',
          error: true,
        );

        return;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required for nearest-centre recommendation.',
          error: true,
        );

        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final response =
      await ApiService.instance.client.post(
        '/ai/recommend-centre',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      final data = response.data;

      if (!mounted) return;

      if (data is Map) {
        final recommendations =
        data['recommendations'];

        if (recommendations is List &&
            recommendations.isNotEmpty) {
          final best =
              recommendations.first;

          final map = best is Map
              ? Map<String, dynamic>.from(best)
              : <String, dynamic>{};

          final centreId =
          _toInt(
            map['centre_id'],
          );

          final centreName =
          map['centre_name']
              ?.toString();

          final distance =
          _toDouble(
            map['distance_km'],
          );

          if (centreId != null) {
            _showRecommendedCentre(
              centreId: centreId,
              name: centreName ??
                  'Recommended Centre',
              distance: distance,
              data: map,
            );
          }
        } else {
          _showMessage(
            'No centre recommendation is available.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to calculate the nearest centre.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecommendation = false;
        });
      }
    }
  }

  // ===========================================================================
  // FILTER
  // ===========================================================================

  List<dynamic> get _filteredCentres {
    final search =
    _search.trim().toLowerCase();

    return _centres.where((item) {
      if (item is! Map) {
        return false;
      }

      final centre =
      Map<String, dynamic>.from(item);

      final name =
      '${centre['name'] ?? ''}'
          .toLowerCase();

      final code =
      '${centre['code'] ?? ''}'
          .toLowerCase();

      final location =
      '${centre['location'] ?? ''}'
          .toLowerCase();

      final matchesSearch =
          search.isEmpty ||
              name.contains(search) ||
              code.contains(search) ||
              location.contains(search);

      if (!matchesSearch) {
        return false;
      }

      final status =
      '${centre['status'] ?? ''}'
          .toLowerCase();

      switch (_filter) {
        case 'Low Wait':
          final wait =
          _toInt(
            centre[
            'estimated_wait_minutes'],
          );

          return wait <= 20;

        case 'Available':
          final available =
          _toInt(
            centre[
            'available_capacity'],
          );

          return available > 0;

        case 'Busy':
          return status == 'busy' ||
              status == 'near capacity';

        default:
          return true;
      }
    }).toList();
  }

  // ===========================================================================
  // RECOMMENDATION DIALOG
  // ===========================================================================

  void _showRecommendedCentre({
    required int centreId,
    required String name,
    required double? distance,
    required Map<String, dynamic> data,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _RecommendationSheet(
          centreId: centreId,
          name: name,
          distance: distance,
          data: data,
          onUse: () {
            Navigator.of(context).pop();

            context.push(
              '/centres/$centreId',
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // CENTRE DETAILS
  // ===========================================================================

  Future<void> _showCentreDetails(
      int centreId,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final centre =
      await _api.getCentre(centreId);

      if (!mounted) return;

      Navigator.of(context).pop();

      final data =
      Map<String, dynamic>.from(
        centre,
      );

      final nested =
      data['centre'];

      final details =
      nested is Map
          ? Map<String, dynamic>.from(
        nested,
      )
          : data;

      _showDetailsSheet(details);
    } catch (_) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showMessage(
        'Unable to load centre details.',
        error: true,
      );
    }
  }

  void _showDetailsSheet(
      Map<String, dynamic> centre,
      ) {
    final id =
    _toInt(
      centre['centre_id'] ??
          centre['id'],
    );

    final name =
    _string(
      centre['name'],
      'Procurement Centre',
    );

    final code =
    _string(
      centre['code'],
      'Centre',
    );

    final queue =
    _toInt(
      centre['queue_length'] ??
          centre['current_queue'],
    );

    final wait =
    _toInt(
      centre[
      'estimated_wait_minutes'],
    );

    final capacity =
    _toInt(
      centre['capacity'],
    );

    final available =
    _toInt(
      centre[
      'available_capacity'],
    );

    final utilization =
    _toDouble(
      centre[
      'utilization_percentage'] ??
          centre['utilization'],
    );

    final counters =
    _toInt(
      centre['counters'],
    );

    final processing =
    _toDouble(
      centre[
      'average_processing_time'],
    );

    final congestion =
    _string(
      centre['congestion_level'] ??
          centre['congestion'],
      'Low',
    );

    final status =
    _string(
      centre['operational_status'] ??
          centre['status'],
      'Operational',
    );

    final location =
    _string(
      centre['location'],
      'Location unavailable',
    );

    final slots =
    centre['slots'] is List
        ? List<dynamic>.from(
      centre['slots'],
    )
        : <dynamic>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          expand: false,
          builder: (
              context,
              controller,
              ) {
            return Container(
              decoration:
              const BoxDecoration(
                color: Color(0xFFF5F8F6),
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: controller,
                padding:
                const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.grey.shade300,
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
                        width: 54,
                        height: 54,
                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFFE5F5EC,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color:
                          Color(0xFF16834B),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              name,
                              style:
                              const TextStyle(
                                fontSize: 20,
                                fontWeight:
                                FontWeight.w800,
                                color:
                                Color(
                                  0xFF173B2A,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              code,
                              style:
                              const TextStyle(
                                color:
                                Color(
                                  0xFF718078,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _statusBanner(
                    status,
                    congestion,
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _detailMetric(
                          Icons.groups_rounded,
                          'Queue',
                          '$queue',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailMetric(
                          Icons.timer_outlined,
                          'Wait',
                          '$wait min',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _detailMetric(
                          Icons.inventory_2_outlined,
                          'Capacity',
                          '$capacity',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailMetric(
                          Icons.event_available_outlined,
                          'Available',
                          '$available',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _detailMetric(
                          Icons.speed_rounded,
                          'Utilization',
                          '${utilization.toStringAsFixed(1)}%',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailMetric(
                          Icons.countertops_outlined,
                          'Counters',
                          '$counters',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _sectionCard(
                    title: 'Centre Information',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                      _infoRow(
                      Icons.place_outlined,
                      'Location',
                      location,
                    ),
                    _infoRow(
                      Icons.timer_outlined,
                      'Average processing',
                      '${processing.toStringAsFixed(1)} minutes',
                    ),
                    _infoRow(
                      Icons.event_available_outlined,
                      'Completed today',
                      '${_toInt(centre['completed_today'])}',
                    ),
                    _infoRow(
                        Icons.calendar_today_outlined,
                      "Today's bookings",
                    '${_toInt(centre['today_bookings'])}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _sectionCard(
            title: 'Today\'s Slots',
            icon: Icons.schedule_rounded,
            child: slots.isEmpty
            ? const Padding(
            padding:
            EdgeInsets.all(
            12,
            ),
            child: Text(
            'Slot information is currently unavailable.',
            ),
            )
                : Column(
            children:
            slots.map(
            (item) {
            final slot =
            item is Map
            ? Map<String,
            dynamic>.from(
            item,
            )
                : <String,
            dynamic>{};

            return _slotRow(
            slot,
            );
            },
            ).toList(),
            ),
            ),

            const SizedBox(height: 18),

            if (id != null)
            SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
            onPressed: () {
            Navigator.of(
            context,
            ).pop();

            context.push(
            '/booking',
            );
            },
            icon: const Icon(
            Icons.calendar_month_rounded,
            ),
            label: const Text(
            'Book a Procurement Slot',
            ),
            style:
            ElevatedButton.styleFrom(
            backgroundColor:
            const Color(
            0xFF16834B,
            ),
            foregroundColor:
            Colors.white,
            padding:
            const EdgeInsets
                .symmetric(
            vertical: 15,
            ),
            shape:
            RoundedRectangleBorder(
            borderRadius:
            BorderRadius
                .circular(
            15,
            ),
            ),
            ),
            ),
            ),

            const SizedBox(height: 10),

            if (id != null)
            SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
            onPressed: () {
            Navigator.of(
            context,
            ).pop();

            context.push(
            '/centres/$id',
            );
            },
            icon: const Icon(
            Icons.open_in_new_rounded,
            ),
            label: const Text(
            'Open Full Centre Details',
            ),
            ),
            ),

            const SizedBox(height: 30),
            ],
            ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final centres =
        _filteredCentres;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F8F6),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor:
        const Color(0xFF173B2A),
        title: const Text(
          'Procurement Centres',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            _loading
                ? null
                : _loadCentres,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadCentres,
        child: _loading
            ? const Center(
          child:
          CircularProgressIndicator(),
        )
            : _error != null
            ? _buildError()
            : ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30,
          ),
          children: [
            _buildHero(),

            const SizedBox(height: 16),

            _buildSearch(),

            const SizedBox(height: 12),

            _buildFilters(),

            const SizedBox(height: 16),

            _buildSummary(),

            const SizedBox(height: 16),

            if (centres.isEmpty)
              _buildEmpty()
            else
              ...centres.map(
                    (item) =>
                    _buildCentreCard(
                      item,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFF0E5C36),
            Color(0xFF16834B),
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
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Smart Procurement Network',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            'Compare queue, capacity and waiting time before choosing where to procure your crops.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              _loadingRecommendation
                  ? null
                  : _findNearestCentre,
              icon:
              _loadingRecommendation
                  ? const SizedBox(
                width: 17,
                height: 17,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(
                    0xFF16834B,
                  ),
                ),
              )
                  : const Icon(
                Icons.my_location_rounded,
              ),
              label: Text(
                _loadingRecommendation
                    ? 'Finding best centre...'
                    : 'Find Smart Recommended Centre',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.white,
                foregroundColor:
                const Color(0xFF16834B),
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
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
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      decoration:
      InputDecoration(
        hintText:
        'Search centre, code or location',
        prefixIcon:
        const Icon(
          Icons.search_rounded,
          color: Color(0xFF16834B),
        ),
        suffixIcon:
        _search.isNotEmpty
            ? IconButton(
          onPressed: () {
            setState(() {
              _search = '';
            });
          },
          icon: const Icon(
            Icons.clear_rounded,
          ),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          borderSide:
          BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      'All',
      'Low Wait',
      'Available',
      'Busy',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection:
        Axis.horizontal,
        itemCount:
        filters.length,
        separatorBuilder:
            (_, __) =>
        const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (_, index) {
          final value =
          filters[index];

          final selected =
              _filter == value;

          return ChoiceChip(
            label:
            Text(value),
            selected:
            selected,
            onSelected:
                (_) {
              setState(() {
                _filter = value;
              });
            },
            selectedColor:
            const Color(
              0xFFDDF2E6,
            ),
            backgroundColor:
            Colors.white,
            labelStyle:
            TextStyle(
              color: selected
                  ? const Color(
                0xFF16834B,
              )
                  : const Color(
                0xFF65736C,
              ),
              fontWeight:
              FontWeight.w700,
            ),
            side:
            BorderSide(
              color:
              selected
                  ? const Color(
                0xFF8ACAA5,
              )
                  : const Color(
                0xFFE1E8E3,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary() {
    int active = 0;
    int totalQueue = 0;
    int available = 0;

    for (final item
    in _centres) {
      if (item is! Map) {
        continue;
      }

      final centre =
      Map<String, dynamic>.from(
        item,
      );

      final status =
      '${centre['status'] ?? ''}'
          .toLowerCase();

      if (status != 'busy' &&
          status != 'near capacity') {
        active++;
      }

      totalQueue += _toInt(
        centre[
        'queue_length'],
      );

      available += _toInt(
        centre[
        'available_capacity'],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.location_on_outlined,
            '${_centres.length}',
            'Centres',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            Icons.groups_outlined,
            '$totalQueue',
            'In Queue',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            Icons.event_available_outlined,
            '$available',
            'Available',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
      IconData icon,
      String value,
      String label,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
            const Color(0xFF16834B),
            size: 21,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2A),
            ),
          ),
          Text(
            label,
            style:
            const TextStyle(
              fontSize: 10,
              color:
              Color(0xFF718078),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentreCard(
      dynamic item,
      ) {
    final centre =
    Map<String, dynamic>.from(
      item as Map,
    );

    final id =
    _toInt(
      centre['centre_id'] ??
          centre['id'],
    );

    final name =
    _string(
      centre['name'],
      'Procurement Centre',
    );

    final code =
    _string(
      centre['code'],
      'CENTRE',
    );

    final location =
    _string(
      centre['location'],
      'Location unavailable',
    );

    final queue =
    _toInt(
      centre['queue_length'] ??
          centre['current_queue'],
    );

    final wait =
    _toInt(
      centre[
      'estimated_wait_minutes'],
    );

    final capacity =
    _toInt(
      centre['capacity'],
    );

    final available =
    _toInt(
      centre[
      'available_capacity'],
    );

    final utilization =
    _toDouble(
      centre[
      'utilization_percentage'] ??
          centre['utilization'],
    );

    final congestion =
    _string(
      centre['congestion_level'] ??
          centre['congestion'],
      'Low',
    );

    final status =
    _string(
      centre['status'],
      'Operational',
    );

    final processing =
    _toDouble(
      centre[
      'average_processing_time'],
    );

    final statusColor =
    _statusColor(status);

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Color(0x0C000000),
            blurRadius: 12,
            offset:
            Offset(0, 5),
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
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFE7F5EC,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                const Icon(
                  Icons.location_on_rounded,
                  color:
                  Color(0xFF16834B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        Color(0xFF173B2A),
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      code,
                      style:
                      const TextStyle(
                        color:
                        Color(0xFF718078),
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    30,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style:
                  TextStyle(
                    color:
                    statusColor,
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 18,
                color:
                Color(0xFF718078),
              ),
              const SizedBox(
                width: 6,
              ),
              Expanded(
                child: Text(
                  location,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color:
                    Color(0xFF65736C),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _smallMetric(
                  Icons.groups_rounded,
                  '$queue',
                  'Queue',
                ),
              ),
              Expanded(
                child: _smallMetric(
                  Icons.timer_outlined,
                  '$wait min',
                  'Wait',
                ),
              ),
              Expanded(
                child: _smallMetric(
                  Icons.inventory_2_outlined,
                  '$available',
                  'Available',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child:
                const Text(
                  'Utilization',
                  style:
                  TextStyle(
                    fontSize: 11,
                    color:
                    Color(0xFF718078),
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${utilization.toStringAsFixed(0)}%',
                style:
                const TextStyle(
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF173B2A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              minHeight: 7,
              value:
              (utilization / 100)
                  .clamp(
                0.0,
                1.0,
              ),
              backgroundColor:
              const Color(
                0xFFE8EFEB,
              ),
              valueColor:
              AlwaysStoppedAnimation<
                  Color>(
                _utilizationColor(
                  utilization,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Avg. processing ${processing.toStringAsFixed(1)} min',
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF718078),
                  ),
                ),
              ),
              Text(
                congestion,
                style:
                TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  _congestionColor(
                    congestion,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                  id == null
                      ? null
                      : () =>
                      _showCentreDetails(
                        id,
                      ),
                  icon:
                  const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),
                  label:
                  const Text(
                    'Details',
                  ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(
                      0xFF16834B,
                    ),
                    side:
                    const BorderSide(
                      color:
                      Color(0xFFB9DCC7),
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
              const SizedBox(
                width: 9,
              ),
              Expanded(
                child:
                ElevatedButton.icon(
                  onPressed:
                  id == null
                      ? null
                      : () {
                    context.push(
                      '/booking',
                    );
                  },
                  icon:
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                  ),
                  label:
                  const Text(
                    'Book',
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF16834B,
                    ),
                    foregroundColor:
                    Colors.white,
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
        ],
      ),
    );
  }

  Widget _smallMetric(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color:
          const Color(0xFF238B57),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w800,
            fontSize: 13,
            color:
            Color(0xFF173B2A),
          ),
        ),
        Text(
          label,
          style:
          const TextStyle(
            fontSize: 9,
            color:
            Color(0xFF718078),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.all(30),
      children: [
        const SizedBox(
          height: 100,
        ),
        const Icon(
          Icons.cloud_off_rounded,
          size: 65,
          color: Colors.grey,
        ),
        const SizedBox(height: 18),
        const Text(
          'Unable to load procurement centres',
          textAlign: TextAlign.center,
          style:
          TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style:
          const TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed:
          _loadCentres,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
          label:
          const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding:
      const EdgeInsets.all(30),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 55,
            color: Colors.grey,
          ),
          SizedBox(height: 14),
          Text(
            'No centres found',
            style:
            TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try another search or filter.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(
      String status,
      String congestion,
      ) {
    final color =
    _statusColor(status);

    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        border:
        Border.all(
          color:
          color.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 11,
            color: color,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            status,
            style:
            TextStyle(
              color: color,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            'Congestion: $congestion',
            style:
            TextStyle(
              color:
              _congestionColor(
                congestion,
              ),
              fontWeight:
              FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailMetric(
      IconData icon,
      String label,
      String value,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(15),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
            const Color(0xFF16834B),
            size: 22,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w800,
                    color:
                    Color(0xFF173B2A),
                  ),
                ),
                Text(
                  label,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF718078),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
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
              Icon(
                icon,
                color:
                const Color(0xFF16834B),
                size: 20,
              ),
              const SizedBox(
                width: 8,
              ),
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF173B2A),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF718078),
          ),
          const SizedBox(
            width: 10,
          ),
          SizedBox(
            width: 125,
            child: Text(
              label,
              style:
              const TextStyle(
                fontSize: 12,
                color:
                Color(0xFF718078),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              style:
              const TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.w700,
                color:
                Color(0xFF26382E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotRow(
      Map<String, dynamic> slot,
      ) {
    final label =
    _string(
      slot['label'],
      '${slot['start'] ?? ''} - ${slot['end'] ?? ''}',
    );

    final available =
    _toInt(
      slot['available'],
    );

    final capacity =
    _toInt(
      slot['capacity'],
    );

    final isAvailable =
        slot['is_available'] == true ||
            available > 0;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
      const EdgeInsets.all(12),
      decoration:
      BoxDecoration(
        color:
        isAvailable
            ? const Color(
          0xFFF3FAF6,
        )
            : const Color(
          0xFFF8F8F8,
        ),
        borderRadius:
        BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            color:
            isAvailable
                ? const Color(
              0xFF16834B,
            )
                : Colors.grey,
            size: 20,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              label,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$available / $capacity',
            style:
            TextStyle(
              color:
              isAvailable
                  ? const Color(
                0xFF16834B,
              )
                  : Colors.grey,
              fontWeight:
              FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  String _string(
      dynamic value,
      String fallback,
      ) {
    final result =
    value?.toString().trim();

    if (result == null ||
        result.isEmpty ||
        result == 'null') {
      return fallback;
    }

    return result;
  }

  Color _statusColor(
      String status,
      ) {
    final value =
    status.toLowerCase();

    if (value.contains('busy')) {
      return const Color(
        0xFFE58A00,
      );
    }

    if (value.contains(
      'capacity',
    )) {
      return const Color(
        0xFFD64545,
      );
    }

    return const Color(
      0xFF16834B,
    );
  }

  Color _utilizationColor(
      double value,
      ) {
    if (value >= 80) {
      return const Color(
        0xFFD64545,
      );
    }

    if (value >= 50) {
      return const Color(
        0xFFE58A00,
      );
    }

    return const Color(
      0xFF16834B,
    );
  }

  Color _congestionColor(
      String congestion,
      ) {
    switch (
    congestion.toLowerCase()) {
      case 'high':
        return const Color(
          0xFFD64545,
        );

      case 'medium':
        return const Color(
          0xFFE58A00,
        );

      default:
        return const Color(
          0xFF16834B,
        );
    }
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          backgroundColor:
          error
              ? const Color(
            0xFFD64545,
          )
              : const Color(
            0xFF16834B,
          ),
          content:
          Text(message),
        ),
      );
  }
}


// ============================================================================
// RECOMMENDATION SHEET
// ============================================================================

class _RecommendationSheet
    extends StatelessWidget {
  final int centreId;
  final String name;
  final double? distance;
  final Map<String, dynamic> data;
  final VoidCallback onUse;

  const _RecommendationSheet({
    required this.centreId,
    required this.name,
    required this.distance,
    required this.data,
    required this.onUse,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final wait =
        data['estimated_wait_minutes']
            ?.toString() ??
            '-';

    final queue =
        data['queue_length']
            ?.toString() ??
            '0';

    final congestion =
        data['congestion']
            ?.toString() ??
            'Low';

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      decoration:
      const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 5,
            decoration:
            BoxDecoration(
              color:
              Colors.grey.shade300,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            size: 42,
            color:
            Color(0xFF16834B),
          ),
          const SizedBox(
            height: 12,
          ),
          const Text(
            'Smart Recommendation',
            style:
            TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2A),
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            name,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 16,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          Row(
            children: [
              Expanded(
                child: _recommendMetric(
                  Icons.route_rounded,
                  distance == null
                      ? '-'
                      : '${distance!.toStringAsFixed(1)} km',
                  'Distance',
                ),
              ),
              Expanded(
                child: _recommendMetric(
                  Icons.groups_rounded,
                  queue,
                  'Queue',
                ),
              ),
              Expanded(
                child: _recommendMetric(
                  Icons.timer_outlined,
                  '$wait min',
                  'Wait',
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            'Congestion: $congestion',
            style:
            const TextStyle(
              fontWeight:
              FontWeight.w700,
              color:
              Color(0xFF16834B),
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          SizedBox(
            width:
            double.infinity,
            child:
            ElevatedButton.icon(
              onPressed:
              onUse,
              icon:
              const Icon(
                Icons.check_circle_outline,
              ),
              label:
              const Text(
                'View This Centre',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF16834B,
                ),
                foregroundColor:
                Colors.white,
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
          ),
        ],
      ),
    );
  }

  Widget _recommendMetric(
      IconData icon,
      String value,
      String label,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color:
          const Color(0xFF16834B),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        Text(
          label,
          style:
          const TextStyle(
            fontSize: 10,
            color:
            Color(0xFF718078),
          ),
        ),
      ],
    );
  }
}