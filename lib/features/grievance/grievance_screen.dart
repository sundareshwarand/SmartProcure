import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/farmer_api_service.dart';

class GrievanceScreen extends StatefulWidget {
  const GrievanceScreen({super.key});

  @override
  State<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends State<GrievanceScreen> {
  final FarmerApiService _api = FarmerApiService.instance;

  final TextEditingController _descriptionController =
  TextEditingController();

  final TextEditingController _searchController =
  TextEditingController();

  bool _loading = true;
  bool _submitting = false;

  String? _error;

  String _selectedCategory = 'Procurement Delay';
  String _selectedStatus = 'All';

  List<dynamic> _grievances = [];

  final List<String> _categories = [
    'Procurement Delay',
    'Payment Issue',
    'Quality Dispute',
    'Weighing Issue',
    'Centre Service',
    'Slot / Booking Issue',
    'Queue Issue',
    'Other',
  ];

  final List<String> _statusFilters = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _loadGrievances();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // API
  // ===========================================================================

  Future<void> _loadGrievances() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getGrievances(
        farmerId: 1,
      );

      if (!mounted) return;

      setState(() {
        _grievances = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
        'Unable to load grievances. Please try again.';
      });
    }
  }

  Future<void> _submitGrievance() async {
    final description =
    _descriptionController.text.trim();

    if (description.isEmpty) {
      _showMessage(
        'Please describe your issue.',
      );
      return;
    }

    if (description.length < 10) {
      _showMessage(
        'Please provide more details about your issue.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _api.createGrievance(
        farmerId: 1,
        category: _selectedCategory,
        description: description,
      );

      if (!mounted) return;

      _descriptionController.clear();

      FocusScope.of(context).unfocus();

      setState(() {
        _submitting = false;
      });

      _showMessage(
        'Grievance submitted successfully.',
      );

      await _loadGrievances();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      _showMessage(
        'Unable to submit grievance. Please try again.',
      );
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _stringValue(
      Map<String, dynamic> item,
      String key, [
        String fallback = '',
      ]) {
    final value = item[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int? _getId(
      Map<String, dynamic> item,
      ) {
    return int.tryParse(
      item['id']?.toString() ?? '',
    );
  }

  String _getGrievanceId(
      Map<String, dynamic> item,
      ) {
    final value = _stringValue(
      item,
      'grievance_number',
    );

    if (value.isNotEmpty) {
      return value;
    }

    final grievanceId = _stringValue(
      item,
      'grievance_id',
    );

    if (grievanceId.isNotEmpty) {
      return grievanceId;
    }

    final id = _getId(item);

    if (id != null) {
      return 'GRV-${id.toString().padLeft(4, '0')}';
    }

    return 'GRV-UNKNOWN';
  }

  String _getCategory(
      Map<String, dynamic> item,
      ) {
    return _stringValue(
      item,
      'category',
      'General',
    );
  }

  String _getDescription(
      Map<String, dynamic> item,
      ) {
    return _stringValue(
      item,
      'description',
      'No description available.',
    );
  }

  String _getStatus(
      Map<String, dynamic> item,
      ) {
    final status = _stringValue(
      item,
      'status',
      'Open',
    );

    if (status.toLowerCase() == 'pending') {
      return 'Open';
    }

    if (status.toLowerCase() == 'processing') {
      return 'In Progress';
    }

    return status;
  }

  String _getCreatedText(
      Map<String, dynamic> item,
      ) {
    final raw = _stringValue(
      item,
      'created_at',
    );

    if (raw.isEmpty) {
      return 'Recently submitted';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw;
    }

    final difference =
    DateTime.now().difference(
      date.toLocal(),
    );

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ===========================================================================
  // COLORS
  // ===========================================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF1976D2);

      case 'in progress':
        return const Color(0xFFF57C00);

      case 'resolved':
        return const Color(0xFF2E7D32);

      case 'closed':
        return const Color(0xFF546E7A);

      case 'rejected':
        return const Color(0xFFD32F2F);

      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.mark_email_unread_rounded;

      case 'in progress':
        return Icons.autorenew_rounded;

      case 'resolved':
        return Icons.check_circle_rounded;

      case 'closed':
        return Icons.lock_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains('payment')) {
      return Icons.account_balance_wallet_rounded;
    }

    if (value.contains('quality')) {
      return Icons.verified_rounded;
    }

    if (value.contains('weigh')) {
      return Icons.scale_rounded;
    }

    if (value.contains('booking') ||
        value.contains('slot')) {
      return Icons.event_available_rounded;
    }

    if (value.contains('queue')) {
      return Icons.people_alt_rounded;
    }

    if (value.contains('centre') ||
        value.contains('center')) {
      return Icons.location_on_rounded;
    }

    if (value.contains('procurement')) {
      return Icons.agriculture_rounded;
    }

    return Icons.support_agent_rounded;
  }

  // ===========================================================================
  // COUNTS
  // ===========================================================================

  int _countStatus(String status) {
    if (status == 'All') {
      return _grievances.length;
    }

    return _grievances
        .map(_asMap)
        .where(
          (item) =>
      _getStatus(item).toLowerCase() ==
          status.toLowerCase(),
    )
        .length;
  }

  int get _openCount {
    return _grievances
        .map(_asMap)
        .where(
          (item) =>
      _getStatus(item).toLowerCase() ==
          'open',
    )
        .length;
  }

  int get _progressCount {
    return _grievances
        .map(_asMap)
        .where(
          (item) =>
      _getStatus(item).toLowerCase() ==
          'in progress',
    )
        .length;
  }

  int get _resolvedCount {
    return _grievances
        .map(_asMap)
        .where(
          (item) =>
      _getStatus(item).toLowerCase() ==
          'resolved',
    )
        .length;
  }

  // ===========================================================================
  // FILTERED DATA
  // ===========================================================================

  List<Map<String, dynamic>> get _filteredGrievances {
    final query =
    _searchController.text.trim().toLowerCase();

    return _grievances
        .map(_asMap)
        .where(
          (item) {
        final status = _getStatus(item);

        if (_selectedStatus != 'All' &&
            status.toLowerCase() !=
                _selectedStatus.toLowerCase()) {
          return false;
        }

        if (query.isEmpty) {
          return true;
        }

        final id =
        _getGrievanceId(item).toLowerCase();

        final category =
        _getCategory(item).toLowerCase();

        final description =
        _getDescription(item).toLowerCase();

        return id.contains(query) ||
            category.contains(query) ||
            description.contains(query);
      },
    )
        .toList();
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
          const Color(0xFF173B2B),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ===========================================================================
  // COPY ID
  // ===========================================================================

  Future<void> _copyId(String id) async {
    await Clipboard.setData(
      ClipboardData(text: id),
    );

    _showMessage(
      'Grievance ID copied.',
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEAF7EF),
            Color(0xFFF7FBF8),
          ],
        ),
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD5E7DA),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                const BoxDecoration(
                  color: Color(0xFFDDF1E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF16834B),
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Centre',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        Color(0xFF173B2B),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Track your complaints and service requests',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                        Color(0xFF6C7C73),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryBox(
                'Open',
                _openCount,
                const Color(0xFF1976D2),
              ),
              const SizedBox(width: 8),
              _summaryBox(
                'Processing',
                _progressCount,
                const Color(0xFFF57C00),
              ),
              const SizedBox(width: 8),
              _summaryBox(
                'Resolved',
                _resolvedCount,
                const Color(0xFF2E7D32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(
      String title,
      int value,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 8,
                fontWeight:
                FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUBMIT CARD
  // ===========================================================================

  Widget _buildSubmitCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE0E7E2),
        ),
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
                const BoxDecoration(
                  color: Color(0xFFEAF5EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_comment_rounded,
                  color: Color(0xFF16834B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Submit a Grievance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF3F5148),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          const Text(
            'Grievance Category',
            style: TextStyle(
              fontSize: 10,
              fontWeight:
              FontWeight.w600,
              color:
              Color(0xFF66756D),
            ),
          ),

          const SizedBox(height: 6),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F3),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child:
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                icon: const Icon(
                  Icons
                      .keyboard_arrow_down_rounded,
                ),
                items: _categories
                    .map(
                      (category) =>
                      DropdownMenuItem<
                          String>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(
                              _categoryIcon(
                                category,
                              ),
                              size: 18,
                              color:
                              const Color(
                                0xFF527263,
                              ),
                            ),
                            const SizedBox(
                                width: 10),
                            Text(
                              category,
                              style:
                              const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedCategory =
                        value;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Text(
                'Describe your issue',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  Color(0xFF66756D),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<
                  TextEditingValue>(
                valueListenable:
                _descriptionController,
                builder:
                    (
                    context,
                    value,
                    child,
                    ) {
                  return Text(
                    '${value.text.length}/500',
                    style:
                    const TextStyle(
                      fontSize: 9,
                      color:
                      Colors.black45,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          TextField(
            controller:
            _descriptionController,
            enabled: !_submitting,
            maxLines: 5,
            maxLength: 500,
            decoration:
            InputDecoration(
              hintText:
              'Explain the issue clearly so the centre team can help you...',
              hintStyle:
              const TextStyle(
                fontSize: 11,
                color: Colors.black38,
              ),
              filled: true,
              fillColor:
              const Color(0xFFF1F8F3),
              counterText: '',
              prefixIcon:
              const Padding(
                padding:
                EdgeInsets.only(
                  left: 12,
                  bottom: 70,
                ),
                child: Icon(
                  Icons
                      .description_outlined,
                  size: 20,
                  color:
                  Color(0xFF527263),
                ),
              ),
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                borderSide:
                BorderSide.none,
              ),
              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                borderSide:
                BorderSide.none,
              ),
              focusedBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                borderSide:
                const BorderSide(
                  color:
                  Color(0xFF79B78D),
                ),
              ),
              contentPadding:
              const EdgeInsets.fromLTRB(
                42,
                15,
                12,
                15,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitting
                  ? null
                  : _submitGrievance,
              icon: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                size: 17,
              ),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : 'Submit Grievance',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF2E7D32),
                foregroundColor:
                Colors.white,
                elevation: 0,
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

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE0E7E2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText:
          'Search grievance ID or issue...',
          hintStyle: const TextStyle(
            fontSize: 11,
            color: Colors.black38,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF527263),
          ),
          suffixIcon:
          _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.clear_rounded,
              size: 18,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map(
              (status) {
            final selected =
                _selectedStatus == status;

            return Padding(
              padding:
              const EdgeInsets.only(
                right: 8,
              ),
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedStatus =
                        status;
                  });
                },
                label: Text(
                  '$status ${_countStatus(status)}',
                ),
                selectedColor:
                const Color(0xFF16834B),
                backgroundColor:
                Colors.white,
                side: BorderSide(
                  color: selected
                      ? const Color(
                    0xFF16834B,
                  )
                      : const Color(
                    0xFFDDE5DF,
                  ),
                ),
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : const Color(
                    0xFF4F6258,
                  ),
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ===========================================================================
  // GRIEVANCE CARD
  // ===========================================================================

  Widget _buildGrievanceCard(
      Map<String, dynamic> item,
      ) {
    final id = _getGrievanceId(item);
    final category = _getCategory(item);
    final description =
    _getDescription(item);
    final status = _getStatus(item);

    final color = _statusColor(status);

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0E7E2),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: () {
          _showDetails(item);
        },
        child: Padding(
          padding:
          const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFEAF5EF,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      _categoryIcon(
                        category,
                      ),
                      color:
                      const Color(
                        0xFF2E7D32,
                      ),
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          id,
                          style:
                          const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight
                                .w800,
                            color:
                            Color(
                              0xFF52635A,
                            ),
                          ),
                        ),
                        const SizedBox(
                            height: 3),
                        Text(
                          _getCreatedText(
                            item,
                          ),
                          style:
                          const TextStyle(
                            fontSize: 9,
                            color:
                            Colors
                                .black45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      color.withValues(
                        alpha: 0.09,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        10,
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
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(
                            width: 4),
                        Text(
                          status,
                          style:
                          TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              // CATEGORY
              Row(
                children: [
                  Icon(
                    _categoryIcon(
                      category,
                    ),
                    size: 15,
                    color:
                    const Color(
                      0xFF16834B,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      category,
                      style:
                      const TextStyle(
                        fontSize: 11,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        Color(
                          0xFF3F5148,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // DESCRIPTION
              Text(
                description,
                maxLines: 3,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  fontSize: 10,
                  height: 1.45,
                  color:
                  Color(0xFF68766F),
                ),
              ),

              const SizedBox(height: 13),

              // FOOTER
              Row(
                children: [
                  const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 11,
                    color:
                    Color(0xFF16834B),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'View details',
                    style:
                    TextStyle(
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      Color(0xFF16834B),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      _copyId(id);
                    },
                    borderRadius:
                    BorderRadius.circular(
                      8,
                    ),
                    child:
                    const Padding(
                      padding:
                      EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color:
                        Colors.black38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons
                        .chevron_right_rounded,
                    size: 20,
                    color:
                    Colors.black26,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DETAILS BOTTOM SHEET
  // ===========================================================================

  void _showDetails(
      Map<String, dynamic> item,
      ) {
    final id = _getGrievanceId(item);
    final category = _getCategory(item);
    final description =
    _getDescription(item);
    final status = _getStatus(item);

    final color = _statusColor(status);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            25,
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
            child: SingleChildScrollView(
              child: Column(
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
                          0xFFD6DED9,
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
                        width: 50,
                        height: 50,
                        decoration:
                        const BoxDecoration(
                          color:
                          Color(0xFFEAF5EF),
                          shape:
                          BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .support_agent_rounded,
                          color:
                          Color(0xFF16834B),
                          size: 25,
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
                              'Grievance Details',
                              style:
                              TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight
                                    .w800,
                                color:
                                Color(
                                  0xFF173B2B,
                                ),
                              ),
                            ),
                            const SizedBox(
                                height: 4),
                            Text(
                              id,
                              style:
                              const TextStyle(
                                fontSize: 11,
                                color:
                                Colors
                                    .black54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          color.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Text(
                          status,
                          style:
                          TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _detailRow(
                    'Category',
                    category,
                    _categoryIcon(category),
                  ),

                  _detailRow(
                    'Submitted',
                    _getCreatedText(item),
                    Icons.schedule_rounded,
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Issue Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w800,
                      color:
                      Color(0xFF3F5148),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(
                      15,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFFF4F8F5,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Text(
                      description,
                      style:
                      const TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color:
                        Color(0xFF52635A),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Status Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w800,
                      color:
                      Color(0xFF3F5148),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildTimeline(status),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child:
                    OutlinedButton.icon(
                      onPressed: () {
                        _copyId(id);
                      },
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        'Copy Grievance ID',
                      ),
                      style:
                      OutlinedButton
                          .styleFrom(
                        foregroundColor:
                        const Color(
                          0xFF16834B,
                        ),
                        side:
                        const BorderSide(
                          color:
                          Color(
                            0xFF9CC9AA,
                          ),
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
      String label,
      String value,
      IconData icon,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF16834B),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style:
            const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign:
              TextAlign.right,
              style:
              const TextStyle(
                fontSize: 11,
                fontWeight:
                FontWeight.w700,
                color:
                Color(0xFF3F5148),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TIMELINE
  // ===========================================================================

  Widget _buildTimeline(
      String status,
      ) {
    int activeStep = 0;

    switch (status.toLowerCase()) {
      case 'open':
        activeStep = 0;
        break;

      case 'in progress':
        activeStep = 1;
        break;

      case 'resolved':
      case 'closed':
        activeStep = 2;
        break;

      default:
        activeStep = 0;
    }

    const steps = [
      'Grievance Submitted',
      'Under Review',
      'Resolution',
    ];

    return Column(
      children:
      List.generate(
        steps.length,
            (index) {
          final completed =
              index <= activeStep;

          final color = completed
              ? const Color(0xFF2E7D32)
              : const Color(0xFFCBD3CE);

          return Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    completed
                        ? Icons
                        .check_circle_rounded
                        : Icons
                        .radio_button_unchecked_rounded,
                    size: 21,
                    color: color,
                  ),
                  if (index <
                      steps.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: color,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 2,
                ),
                child: Text(
                  steps[index],
                  style:
                  TextStyle(
                    fontSize: 11,
                    fontWeight:
                    completed
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color:
                    completed
                        ? const Color(
                      0xFF3F5148,
                    )
                        : Colors
                        .black38,
                  ),
                ),
              ),
            ],
          );
        },
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
              width: 78,
              height: 78,
              decoration:
              const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: Color(0xFFD32F2F),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Unable to Load Grievances',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                Color(0xFF173B2B),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _error ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _loadGrievances,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF16834B),
                foregroundColor:
                Colors.white,
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    13,
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
  // EMPTY
  // ===========================================================================

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0E7E2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration:
            const BoxDecoration(
              color: Color(0xFFEAF5EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF16834B),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Grievances Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF173B2B),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'If you face an issue with procurement, payment, quality, weighing or centre services, submit it using the form above.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // NO FILTER RESULT
  // ===========================================================================

  Widget _buildNoResults() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0E7E2),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 45,
            color: Colors.black26,
          ),
          SizedBox(height: 12),
          Text(
            'No Matching Grievances',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF3F5148),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Try another search term or status filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUPPORT
  // ===========================================================================

  Widget _buildSupportCard() {
    return Container(
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF173B2B),
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color:
              Colors.white.withValues(
                alpha: 0.12,
              ),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.contact_support_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Use the Help & Support section for common questions.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons
                .arrow_forward_ios_rounded,
            color: Colors.white70,
            size: 15,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final filtered =
        _filteredGrievances;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F9F7),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        // WORKING BACK BUTTON
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/farmer/home');
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF173B2B),
          ),
        ),

        title: const Text(
          'Grievance & Support',
          style: TextStyle(
            color: Color(0xFF173B2B),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            _loading
                ? null
                : _loadGrievances,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF16834B),
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
            color: Color(0xFF16834B),
          ),
        )
            : _error != null
            ? _buildError()
            : RefreshIndicator(
          color:
          const Color(0xFF16834B),
          onRefresh:
          _loadGrievances,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              35,
            ),
            children: [
              // =====================================================
              // INFORMATION BANNER
              // =====================================================

              Container(
                padding:
                const EdgeInsets.all(
                  14,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFEAF5EF,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .support_agent_rounded,
                      color:
                      Color(
                        0xFF2E7D32,
                      ),
                      size: 24,
                    ),
                    const SizedBox(
                        width: 10),
                    const Expanded(
                      child: Text(
                        'Facing an issue with procurement, payment, quality, weighing or centre services? Submit a grievance and track its status here.',
                        style:
                        TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color:
                          Color(
                            0xFF52635A,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                  height: 14),

              // =====================================================
              // SUMMARY
              // =====================================================

              _buildSummary(),

              const SizedBox(
                  height: 16),

              // =====================================================
              // SUBMIT FORM
              // =====================================================

              _buildSubmitCard(),

              const SizedBox(
                  height: 20),

              // =====================================================
              // SEARCH
              // =====================================================

              _buildSearch(),

              const SizedBox(
                  height: 12),

              // =====================================================
              // FILTERS
              // =====================================================

              _buildFilters(),

              const SizedBox(
                  height: 18),

              // =====================================================
              // TITLE
              // =====================================================

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Grievances',
                      style:
                      TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight
                            .w800,
                        color:
                        Color(
                          0xFF3F5148,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} shown',
                    style:
                    const TextStyle(
                      fontSize: 9,
                      color:
                      Colors
                          .black45,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 10),

              // =====================================================
              // GRIEVANCE LIST
              // =====================================================

              if (_grievances.isEmpty)
                _buildEmpty()
              else if (filtered.isEmpty)
                _buildNoResults()
              else
                ...filtered.map(
                  _buildGrievanceCard,
                ),

              const SizedBox(
                  height: 8),

              // =====================================================
              // SUPPORT CARD
              // =====================================================

              _buildSupportCard(),
            ],
          ),
        ),
      ),
    );
  }
}