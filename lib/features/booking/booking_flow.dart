import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/farmer_api_service.dart';
import '../../core/network/api_service.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  int _step = 0;

  String _crop = 'Paddy';
  double _quantityQuintals = 0;

  int? _centreId;
  String _centreName = '';

  DateTime _selectedDate =
  DateTime.now().add(const Duration(days: 1));

  String? _slotStart;
  String? _slotEnd;

  bool _loadingCentres = true;
  bool _loadingAi = false;
  bool _loadingSmartSlot = false;
  bool _loadingSlots = false;
  bool _booking = false;

  String? _error;

  List<dynamic> _centres = [];
  List<dynamic> _recommendations = [];
  List<dynamic> _smartSlotRecommendations = [];
  List<dynamic> _availableSlots = [];

  Map<String, dynamic>? _bestSmartSlot;

  double? _latitude;
  double? _longitude;

  final TextEditingController _quantityController =
  TextEditingController();

  final FarmerApiService _api =
      FarmerApiService.instance;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _quantityController.addListener(() {
      final value =
          double.tryParse(_quantityController.text) ?? 0;

      if (value != _quantityQuintals) {
        setState(() {
          _quantityQuintals = value;
          _smartSlotRecommendations = [];
          _bestSmartSlot = null;
        });
      }
    });

    _loadCentres();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double get _quantityKg =>
      _quantityQuintals * 100;

  String _dateText(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

  int? _toInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<dynamic> _listFromResponse(
      dynamic response,
      String key,
      ) {
    if (response is List) {
      return response;
    }

    if (response is Map) {
      final value = response[key];

      if (value is List) {
        return value;
      }
    }

    return [];
  }

  // ---------------------------------------------------------------------------
  // Centres
  // ---------------------------------------------------------------------------

  Future<void> _loadCentres() async {
    setState(() {
      _loadingCentres = true;
      _error = null;
    });

    try {
      final data = await _api.getCentres();

      if (!mounted) return;

      setState(() {
        _centres = data;
        _loadingCentres = false;
      });

      await _loadAiRecommendations();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingCentres = false;
        _error = 'Unable to load procurement centres.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  Future<void> _getFarmerLocation() async {
    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) return;

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      // Location is optional.
    }
  }

  // ---------------------------------------------------------------------------
  // AI Centre Recommendation
  // ---------------------------------------------------------------------------

  Future<void> _loadAiRecommendations() async {
    if (_centres.isEmpty) return;

    setState(() {
      _loadingAi = true;
    });

    try {
      await _getFarmerLocation();

      final latitude =
          _latitude ?? 12.8342;

      final longitude =
          _longitude ?? 80.2245;

      final response =
      await ApiService.instance.client.post(
        '/api/v1/ai/recommend-centre',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      final data = response.data;

      List<dynamic> recommendations = [];

      if (data is Map) {
        recommendations =
            _listFromResponse(
              data,
              'recommendations',
            );
      }

      if (!mounted) return;

      setState(() {
        _recommendations = recommendations;
        _loadingAi = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _recommendations = [];
        _loadingAi = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Apply centre
  // ---------------------------------------------------------------------------

  void _selectCentre(
      int centreId,
      String centreName,
      ) {
    setState(() {
      _centreId = centreId;
      _centreName = centreName;
      _slotStart = null;
      _slotEnd = null;
      _availableSlots = [];
      _smartSlotRecommendations = [];
      _bestSmartSlot = null;
    });

    _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    if (_centreId == null) return;

    setState(() {
      _loadingSlots = true;
      _availableSlots = [];
      _slotStart = null;
      _slotEnd = null;
    });

    try {
      final slots = await _api
          .getAvailableSlots(
        centreId: _centreId!,
        bookingDate: _selectedDate,
      )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
      });
      _showMessage('Slot availability request timed out.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableSlots = [];
        _loadingSlots = false;
      });
      _showMessage('Unable to load slot availability.');
    }
  }

  // ---------------------------------------------------------------------------
  // AI Smart Slot
  // ---------------------------------------------------------------------------

  Future<void> _findSmartSlot() async {
    if (_quantityKg <= 0) {
      _showMessage(
        'Enter the expected quantity first.',
      );
      return;
    }

    setState(() {
      _loadingSmartSlot = true;
      _smartSlotRecommendations = [];
      _bestSmartSlot = null;
    });

    try {
      await _getFarmerLocation();



      final result =
      await _api.recommendSmartSlot(
        bookingDate: _selectedDate,
        crop: _crop,
        quantityKg: _quantityKg,
        latitude: _latitude,
        longitude: _longitude,
      ).timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) return;

      final recommendations =
      result['recommendations'] is List
          ? List<dynamic>.from(
        result['recommendations'],
      )
          : <dynamic>[];

      final best =
      _asMap(
        result['best_recommendation'],
      );

      setState(() {
        _smartSlotRecommendations =
            recommendations;

        _bestSmartSlot = best;

        _loadingSmartSlot = false;
      });

      if (best == null &&
          recommendations.isEmpty) {
        _showMessage(
          'No suitable smart slots are available for this date.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingSmartSlot = false;
      });

      _showMessage(
        'Unable to get AI slot recommendations.',
      );
    }
  }
  // ---------------------------------------------------------------------------
  // Apply smart slot
  // ---------------------------------------------------------------------------

  void _applySmartSlotRecommendation(
      Map<String, dynamic> recommendation,
      ) {
    final centreId =
    _toInt(
      recommendation['centre_id'],
    );

    final centreName =
    _value(
      recommendation,
      'centre_name',
      'Procurement Centre',
    );

    final start =
    _value(
      recommendation,
      'slot_start',
      '',
    );

    final end =
    _value(
      recommendation,
      'slot_end',
      '',
    );

    if (centreId == null ||
        start.isEmpty ||
        end.isEmpty) {
      _showMessage(
        'Invalid smart slot recommendation.',
      );
      return;
    }

    setState(() {
      _centreId = centreId;
      _centreName = centreName;
      _slotStart = start;
      _slotEnd = end;
    });

    _showMessage(
      'AI recommendation applied successfully.',
    );
  }

  // ---------------------------------------------------------------------------
  // Date
  // ---------------------------------------------------------------------------

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final picked =
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(
        today.year,
        today.month,
        today.day,
      ),
      lastDate: today.add(
        const Duration(days: 30),
      ),
      builder: (
          context,
          child,
          ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
            const ColorScheme.light(
              primary: Color(0xFF2E7D32),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _slotStart = null;
      _slotEnd = null;
      _availableSlots = [];
      _smartSlotRecommendations = [];
      _bestSmartSlot = null;
    });

    if (_centreId != null) {
      _loadAvailableSlots();
    }
  }

  // ---------------------------------------------------------------------------
  // Slot
  // ---------------------------------------------------------------------------

  void _selectSlot(
      String start,
      String end,
      ) {
    setState(() {
      _slotStart = start;
      _slotEnd = end;
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _validateStep() {
    if (_step == 0) {
      if (_quantityQuintals <= 0) {
        _showMessage(
          'Please enter a valid quantity.',
        );
        return false;
      }

      return true;
    }

    if (_step == 1) {
      if (_centreId == null) {
        _showMessage(
          'Please select a procurement centre.',
        );
        return false;
      }

      return true;
    }

    if (_step == 2) {
      if (_slotStart == null ||
          _slotEnd == null) {
        _showMessage(
          'Please select a procurement slot.',
        );
        return false;
      }

      return true;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Next
  // ---------------------------------------------------------------------------

  void _nextStep() {
    if (!_validateStep()) return;

    if (_step < 3) {
      setState(() {
        _step++;
      });

      if (_step == 2 &&
          _bestSmartSlot == null) {
        _findSmartSlot();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Back
  // ---------------------------------------------------------------------------

  void _backStep() {
    if (_step > 0) {
      setState(() {
        _step--;
      });
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/farmer/home');
    }
  }

  // ---------------------------------------------------------------------------
  // Create booking
  // ---------------------------------------------------------------------------

  Future<void> _createBooking() async {
    if (!_validateStep()) return;

    if (_centreId == null ||
        _slotStart == null ||
        _slotEnd == null) {
      return;
    }

    setState(() {
      _booking = true;
      _error = null;
    });

    try {
      final response =
      await _api.createBooking(
        farmerId: 1,
        centreId: _centreId!,
        crop: _crop,
        quantityKg: _quantityKg,
        bookingDate: _selectedDate,
        slotStart: _slotStart!,
        slotEnd: _slotEnd!,
      );

      if (!mounted) return;

      setState(() {
        _booking = false;
      });

      final booking =
      _asMap(response);

      final bookingId =
      _toInt(
        booking?['id'] ??
            booking?['booking_id'],
      );

      context.push(
        '/booking/confirmation',
        extra: {
          'bookingId': bookingId,
          'booking': booking,
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _booking = false;
        _error =
        'Unable to create booking. Please try again.';
      });

      _showMessage(
        'Booking could not be created.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Message
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
          SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
          backgroundColor:
          const Color(0xFF12372A),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Step indicator
  // ---------------------------------------------------------------------------

  Widget _buildProgress() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        0,
      ),
      child: Row(
        children: List.generate(
          4,
              (index) {
            final active =
                index <= _step;

            return Expanded(
              child: Container(
                height: 4,
                margin:
                EdgeInsets.only(
                  right:
                  index == 3 ? 0 : 6,
                ),
                decoration:
                BoxDecoration(
                  color: active
                      ? const Color(
                    0xFF198754,
                  )
                      : const Color(
                    0xFFDDE3DF,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step title
  // ---------------------------------------------------------------------------

  Widget _buildStepHeading(
      String number,
      String title,
      String subtitle,
      ) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        10,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Step $number of 4',
            style: const TextStyle(
              color: Color(0xFF16834A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF173B2B),
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1
  // ---------------------------------------------------------------------------

  Widget _buildCropStep() {
    return ListView(
      padding:
      const EdgeInsets.only(
        bottom: 120,
      ),
      children: [
        _buildStepHeading(
          '1',
          'Crop & Quantity',
          'Tell us about the produce you want to procure.',
        ),

        const SizedBox(height: 8),

        _section(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Crop',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF294437),
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _cropChip('Paddy'),
                  _cropChip('Wheat'),
                  _cropChip('Other'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _section(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Expected Quantity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF294437),
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Enter quantity in quintals.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                _quantityController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                InputDecoration(
                  hintText: 'e.g. 40',
                  suffixText: 'quintals',
                  filled: true,
                  fillColor:
                  const Color(0xFFF4F9F5),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                ),
              ),

              if (_quantityQuintals > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.all(12),
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFE8F5E9,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.scale_rounded,
                        color:
                        Color(
                          0xFF2E7D32,
                        ),
                        size: 19,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        'Approx. ${_quantityKg.toStringAsFixed(0)} kg',
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF1B5E20,
                          ),
                          fontWeight:
                          FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _cropChip(String crop) {
    final selected = _crop == crop;

    return InkWell(
      borderRadius:
      BorderRadius.circular(30),
      onTap: () {
        setState(() {
          _crop = crop;
          _smartSlotRecommendations = [];
          _bestSmartSlot = null;
        });
      },
      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 180,
        ),
        padding:
        const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        decoration:
        BoxDecoration(
          color: selected
              ? const Color(0xFF2E7D32)
              : const Color(0xFFEAF4EC),
          borderRadius:
          BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC8DCCB),
          ),
        ),
        child: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              crop,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                FontWeight.w700,
                color: selected
                    ? Colors.white
                    : const Color(
                  0xFF355443,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 - Centre
  // ---------------------------------------------------------------------------

  Widget _buildCentreStep() {
    return ListView(
      padding:
      const EdgeInsets.only(
        bottom: 120,
      ),
      children: [
        _buildStepHeading(
          '2',
          'Choose Procurement Centre',
          'Select a nearby centre or use our AI recommendation.',
        ),

        if (_loadingAi)
          Container(
            margin:
            const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            padding:
            const EdgeInsets.all(14),
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFE8F5E9),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    Color(0xFF2E7D32),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Finding the best centre for you...',
                  style: TextStyle(
                    color:
                    Color(0xFF1B5E20),
                    fontWeight:
                    FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        if (_recommendations.isNotEmpty)
          _buildAiCentreCard(),

        const SizedBox(height: 8),

        if (_loadingCentres)
          const Padding(
            padding:
            EdgeInsets.all(40),
            child: Center(
              child:
              CircularProgressIndicator(
                color:
                Color(0xFF2E7D32),
              ),
            ),
          )
        else if (_centres.isEmpty)
          _emptyCentres()
        else
          ..._centres.map(
                (centre) {
              final map =
                  _asMap(centre) ??
                      <String, dynamic>{};

              final id =
              _toInt(
                map['id'] ??
                    map['centre_id'],
              );

              final name =
              _value(
                map,
                'name',
                _value(
                  map,
                  'centre_name',
                  'Procurement Centre',
                ),
              );

              if (id == null) {
                return const SizedBox.shrink();
              }

              return _buildCentreCard(
                id,
                name,
                map,
              );
            },
          ),
      ],
    );
  }

  Widget _buildAiCentreCard() {
    final first =
    _asMap(
      _recommendations.first,
    );

    if (first == null) {
      return const SizedBox.shrink();
    }

    final centreId =
    _toInt(
      first['centre_id'],
    );

    final centreName =
    _value(
      first,
      'centre_name',
      'Recommended Centre',
    );

    final wait =
    _value(
      first,
      'estimated_wait_minutes',
      '0',
    );

    final congestion =
    _value(
      first,
      'congestion',
      'Low',
    );

    final distance =
    _value(
      first,
      'distance_km',
      '-',
    );

    return Container(
      margin:
      const EdgeInsets.fromLTRB(
        18,
        4,
        18,
        12,
      ),
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFF0F7A45),
            Color(0xFF2E9D62),
          ],
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF0F7A45,
            ).withValues(
              alpha: 0.18,
            ),
            blurRadius: 15,
            offset:
            const Offset(0, 7),
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
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.16,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Recommended Centre',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            centreName,
            style:
            const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _aiMiniInfo(
                Icons.schedule_rounded,
                '$wait min',
              ),
              const SizedBox(width: 8),
              _aiMiniInfo(
                Icons.traffic_rounded,
                congestion,
              ),
              if (distance != '-')
                ...[
                  const SizedBox(width: 8),
                  _aiMiniInfo(
                    Icons.location_on_rounded,
                    '$distance km',
                  ),
                ],
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: centreId == null
                  ? null
                  : () {
                _selectCentre(
                  centreId,
                  centreName,
                );
                _showMessage(
                  'AI recommended centre selected.',
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.white,
                foregroundColor:
                const Color(
                  0xFF0F7A45,
                ),
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: const Text(
                'Use This Centre',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiMiniInfo(
      IconData icon,
      String text,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 8,
        ),
        decoration:
        BoxDecoration(
          color: Colors.white
              .withValues(
            alpha: 0.12,
          ),
          borderRadius:
          BorderRadius.circular(
            10,
          ),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentreCard(
      int id,
      String name,
      Map<String, dynamic> map,
      ) {
    final selected =
        _centreId == id;

    final capacity =
    _value(
      map,
      'capacity',
      '-',
    );

    final counters =
    _value(
      map,
      'counters',
      '-',
    );

    return Container(
      margin:
      const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        12,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        onTap: () {
          _selectCentre(
            id,
            name,
          );
        },
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: selected
                  ? const Color(
                0xFF2E7D32,
              )
                  : const Color(
                0xFFE1E8E3,
              ),
              width:
              selected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.025,
                ),
                blurRadius: 8,
                offset:
                const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                BoxDecoration(
                  color: selected
                      ? const Color(
                    0xFFE8F5E9,
                  )
                      : const Color(
                    0xFFF3F7F4,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: selected
                      ? const Color(
                    0xFF2E7D32,
                  )
                      : const Color(
                    0xFF607D6B,
                  ),
                ),
              ),

              const SizedBox(width: 13),

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
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        Color(
                          0xFF173B2B,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capacity: $capacity  •  Counters: $counters',
                      style:
                      const TextStyle(
                        fontSize: 11,
                        color:
                        Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons
                    .radio_button_unchecked_rounded,
                color: selected
                    ? const Color(
                  0xFF2E7D32,
                )
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCentres() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Text(
          'No procurement centres available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 - Slot
  // ---------------------------------------------------------------------------

  Widget _buildSlotStep() {
    return ListView(
      padding:
      const EdgeInsets.only(
        bottom: 120,
      ),
      children: [
        _buildStepHeading(
          '3',
          'Choose Date & Slot',
          'Let AI find a suitable time or select one yourself.',
        ),

        // Date
        _section(
          child: InkWell(
            onTap: _selectDate,
            borderRadius:
            BorderRadius.circular(
              14,
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
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color:
                    Color(
                      0xFF2E7D32,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Procurement Date',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                          Colors.black45,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _dateText(
                          _selectedDate,
                        ),
                        style:
                        const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w800,
                          color:
                          Color(
                            0xFF173B2B,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 16,
                  color:
                  Colors.black38,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // AI Smart Slot
        _buildSmartSlotCard(),

        const SizedBox(height: 16),

        _section(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Time Slots',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF173B2B),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _centreName.isEmpty
                    ? 'Select a centre first.'
                    : _centreName,
                style:
                const TextStyle(
                  fontSize: 12,
                  color:
                  Colors.black45,
                ),
              ),
              const SizedBox(height: 15),
              if (_loadingSlots)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Checking slot availability...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_availableSlots.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 42,
                          color: Colors.black38,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No slot information available.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._availableSlots.map((slot) {
                  final map = _asMap(slot);
                  if (map == null) {
                    return const SizedBox.shrink();
                  }

                  final start = _value(map, 'start', '');
                  final end = _value(map, 'end', '');
                  final available = _toInt(map['available']) ?? 0;
                  final capacity = _toInt(map['capacity']) ?? 0;
                  final booked = _toInt(map['booked']) ?? 0;
                  final isAvailable =
                      map['is_available'] == true && available > 0;

                  return _slotCard(
                    start,
                    end,
                    available: available,
                    capacity: capacity,
                    booked: booked,
                    isAvailable: isAvailable,
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartSlotCard() {
    final best =
        _bestSmartSlot;

    return Container(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF12372A),
            Color(0xFF237B4B),
          ],
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.13,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
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
                      'AI Smart Slot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Best time based on queue & capacity',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (_loadingSmartSlot)
            const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Analysing available slots...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (best != null)
            _smartSlotResult(best)
          else
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find the most suitable slot automatically.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed:
                    _findSmartSlot,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Find Best Slot',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.white,
                      foregroundColor:
                      const Color(
                        0xFF12372A,
                      ),
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
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _smartSlotResult(
      Map<String, dynamic> best,
      ) {
    final centre =
    _value(
      best,
      'centre_name',
      _centreName,
    );

    final start =
    _value(
      best,
      'slot_start',
      '-',
    );

    final end =
    _value(
      best,
      'slot_end',
      '-',
    );

    final wait =
    _value(
      best,
      'expected_wait_minutes',
      '0',
    );

    final congestion =
    _value(
      best,
      'congestion_level',
      'Low',
    );

    final available =
    _value(
      best,
      'available',
      '-',
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight:
            FontWeight.w700,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          '$start - $end',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight:
            FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          centre,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight:
            FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            _smartResultChip(
              Icons.schedule_rounded,
              '$wait min wait',
            ),
            const SizedBox(width: 7),
            _smartResultChip(
              Icons.people_alt_rounded,
              '$available available',
            ),
            const SizedBox(width: 7),
            _smartResultChip(
              Icons.traffic_rounded,
              congestion,
            ),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 43,
                child: ElevatedButton(
                  onPressed: () {
                    _applySmartSlotRecommendation(
                      best,
                    );
                  },
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.white,
                    foregroundColor:
                    const Color(
                      0xFF12372A,
                    ),
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        11,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Use Recommendation',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Find again',
              onPressed:
              _findSmartSlot,
              style:
              IconButton.styleFrom(
                backgroundColor:
                Colors.white
                    .withValues(
                  alpha: 0.12,
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _smartResultChip(
      IconData icon,
      String text,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 8,
        ),
        decoration:
        BoxDecoration(
          color: Colors.white
              .withValues(
            alpha: 0.10,
          ),
          borderRadius:
          BorderRadius.circular(
            9,
          ),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotCard(
      String start,
      String end, {
        required int available,
        required int capacity,
        required int booked,
        required bool isAvailable,
      }) {
    final selected = _slotStart == start && _slotEnd == end;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: isAvailable
            ? () => _selectSlot(start, end)
            : null,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: !isAvailable
                ? const Color(0xFFF5F5F5)
                : selected
                ? const Color(0xFFE8F5E9)
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: !isAvailable
                  ? const Color(0xFFE0E0E0)
                  : selected
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE1E8E3),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: !isAvailable
                      ? const Color(0xFFE0E0E0)
                      : selected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFF1F6F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  !isAvailable
                      ? Icons.block_rounded
                      : Icons.schedule_rounded,
                  color: !isAvailable
                      ? Colors.grey
                      : selected
                      ? Colors.white
                      : const Color(0xFF527263),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$start - $end',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: !isAvailable
                            ? Colors.black38
                            : const Color(0xFF173B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !isAvailable
                          ? 'FULL • $booked/$capacity booked'
                          : '$available slots available • $booked booked',
                      style: TextStyle(
                        fontSize: 11,
                        color: !isAvailable
                            ? const Color(0xFFC62828)
                            : Colors.black45,
                        fontWeight: !isAvailable
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isAvailable)
                const Text(
                  'FULL',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4 - Review
  // ---------------------------------------------------------------------------

  Widget _buildReviewStep() {
    return ListView(
      padding:
      const EdgeInsets.only(
        bottom: 120,
      ),
      children: [
        _buildStepHeading(
          '4',
          'Review & Confirm',
          'Check your booking details before confirming.',
        ),

        const SizedBox(height: 8),

        Container(
          margin:
          const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          padding:
          const EdgeInsets.all(
            18,
          ),
          decoration:
          BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
              const Color(
                0xFFE1E8E3,
              ),
            ),
          ),
          child: Column(
            children: [
              _reviewRow(
                Icons.agriculture_rounded,
                'Crop',
                _crop,
              ),
              _reviewDivider(),
              _reviewRow(
                Icons.scale_rounded,
                'Quantity',
                '${_quantityKg.toStringAsFixed(0)} kg',
              ),
              _reviewDivider(),
              _reviewRow(
                Icons.location_on_rounded,
                'Centre',
                _centreName,
              ),
              _reviewDivider(),
              _reviewRow(
                Icons.calendar_month_rounded,
                'Date',
                _shortDate(
                  _selectedDate,
                ),
              ),
              _reviewDivider(),
              _reviewRow(
                Icons.schedule_rounded,
                'Time Slot',
                '$_slotStart - $_slotEnd',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Smart booking confirmation
        Container(
          margin:
          const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
            color:
            const Color(0xFFE8F5E9),
            borderRadius:
            BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color:
              const Color(0xFFC8E6C9),
            ),
          ),
          child: const Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_rounded,
                color:
                Color(0xFF2E7D32),
                size: 23,
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to book',
                      style:
                      TextStyle(
                        color:
                        Color(0xFF1B5E20),
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your slot will be reserved at the selected procurement centre.',
                      style:
                      TextStyle(
                        color:
                        Color(0xFF416B49),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 15),
          Container(
            margin:
            const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            padding:
            const EdgeInsets.all(
              14,
            ),
            decoration:
            BoxDecoration(
              color:
              const Color(0xFFFFEBEE),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: Text(
              _error!,
              style:
              const TextStyle(
                color:
                Color(0xFFC62828),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
          BoxDecoration(
            color:
            const Color(0xFFE8F5E9),
            borderRadius:
            BorderRadius.circular(
              11,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
            const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style:
            const TextStyle(
              fontSize: 12,
              color:
              Colors.black45,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign:
            TextAlign.right,
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewDivider() {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Divider(
        height: 1,
        color:
        Colors.grey.shade200,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Common section
  // ---------------------------------------------------------------------------

  Widget _section({
    required Widget child,
  }) {
    return Container(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.02,
            ),
            blurRadius: 8,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final isLast =
        _step == 3;

    final canContinue =
        !_booking &&
            (_step != 0 ||
                _quantityQuintals > 0);

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 15,
            offset:
            const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              SizedBox(
                width: 52,
                height: 50,
                child: OutlinedButton(
                  onPressed:
                  _booking
                      ? null
                      : _backStep,
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(
                      0xFF12372A,
                    ),
                    side:
                    const BorderSide(
                      color:
                      Color(
                        0xFFD5DED8,
                      ),
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .arrow_back_ios_new_rounded,
                    size: 18,
                  ),
                ),
              ),

            if (_step > 0)
              const SizedBox(width: 10),

            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                  !canContinue
                      ? null
                      : isLast
                      ? _createBooking
                      : _nextStep,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF198754,
                    ),
                    disabledBackgroundColor:
                    const Color(
                      0xFFD9DDDA,
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
                  child: _booking
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isLast
                        ? 'Confirm Booking'
                        : 'Continue',
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F8F6),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        elevation: 0,
        toolbarHeight: 64,

        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color:
            Color(0xFF12372A),
          ),
          onPressed:
          _booking
              ? null
              : _backStep,
        ),

        title: const Text(
          'Book Procurement Slot',
          style: TextStyle(
            color:
            Color(0xFF12372A),
            fontSize: 19,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),

      body: Column(
        children: [
          _buildProgress(),

          Expanded(
            child: AnimatedSwitcher(
              duration:
              const Duration(
                milliseconds: 200,
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  _step,
                ),
                child: _step == 0
                    ? _buildCropStep()
                    : _step == 1
                    ? _buildCentreStep()
                    : _step == 2
                    ? _buildSlotStep()
                    : _buildReviewStep(),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar:
      _buildBottomBar(),
    );
  }
}
