import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/farmer_api_service.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() =>
      _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState
    extends State<FarmerDashboardScreen> {
  final FarmerApiService _api = FarmerApiService.instance;

  static const int _farmerId = 1;

  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  List<dynamic> _bookings = [];
  List<dynamic> _procurements = [];
  List<dynamic> _payments = [];
  List<dynamic> _notifications = [];
  List<dynamic> _queue = [];

  String _farmerName = 'Farmer';

  String _token = '--';
  int _queuePosition = 0;
  int _estimatedWait = 0;

  double _totalQuantity = 0;
  double _totalProcured = 0;
  double _totalPayment = 0;

  String _paymentStatus = 'No Payment';
  String _procurementStatus = 'No Active Procurement';

  int _unreadNotifications = 0;

  String _centreName = 'Procurement Centre';
  String _crop = 'Paddy';
  String _bookingStatus = 'No Active Booking';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ===========================================================================
  // LOAD DASHBOARD
  // ===========================================================================

  Future<void> _loadDashboard({
    bool isRefresh = false,
  }) async {
    if (isRefresh) {
      setState(() {
        _refreshing = true;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.getBookings(
          farmerId: _farmerId,
        ),
        _api.getProcurements(
          farmerId: _farmerId,
        ),
        _api.getPayments(
          farmerId: _farmerId,
        ),
        _api.getNotifications(
          farmerId: _farmerId,
        ),
      ]);

      _bookings = results[0];
      _procurements = results[1];
      _payments = results[2];
      _notifications = results[3];

      await _loadQueue();

      _processDashboardData();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Unable to load dashboard data.';
      });
    }
  }

  // ===========================================================================
  // QUEUE
  // ===========================================================================

  Future<void> _loadQueue() async {
    try {
      int centreId = 1;

      if (_bookings.isNotEmpty) {
        final booking = _asMap(
          _bookings.first,
        );

        centreId = _toInt(
          booking['centre_id'] ??
              booking['centreId'] ??
              booking['center_id'],
        ) ??
            1;
      }

      _queue = await _api.getQueue(
        centreId: centreId,
      );
    } catch (_) {
      _queue = [];
    }
  }

  // ===========================================================================
  // PROCESS DATA
  // ===========================================================================

  void _processDashboardData() {
    _token = '--';
    _queuePosition = 0;
    _estimatedWait = 0;
    _totalQuantity = 0;
    _totalProcured = 0;
    _totalPayment = 0;
    _unreadNotifications = 0;

    if (_bookings.isNotEmpty) {
      final booking = _asMap(
        _bookings.first,
      );

      _token = _stringValue(
        booking['token_number'] ??
            booking['token'] ??
            booking['tokenNumber'],
        fallback: '--',
      );

      _queuePosition = _toInt(
        booking['queue_position'] ??
            booking['queuePosition'] ??
            booking['position'],
      ) ??
          0;

      _estimatedWait = _toInt(
        booking['estimated_wait_minutes'] ??
            booking['estimatedWaitMinutes'] ??
            booking['wait_minutes'] ??
            booking['estimated_wait'],
      ) ??
          0;

      _centreName = _stringValue(
        booking['centre_name'] ??
            booking['center_name'] ??
            booking['centreName'] ??
            booking['name'],
        fallback: 'Procurement Centre',
      );

      _crop = _stringValue(
        booking['crop'],
        fallback: 'Paddy',
      );

      _bookingStatus = _stringValue(
        booking['status'],
        fallback: 'Booked',
      );

      _totalQuantity = _toDouble(
        booking['quantity_kg'] ??
            booking['quantityKg'] ??
            booking['quantity'],
      );
    }

    for (final item in _procurements) {
      final procurement = _asMap(item);

      _totalProcured += _toDouble(
        procurement['quantity_kg'] ??
            procurement['quantityKg'] ??
            procurement['quantity'],
      );
    }

    if (_procurements.isNotEmpty) {
      final procurement = _asMap(
        _procurements.first,
      );

      _procurementStatus = _stringValue(
        procurement['status'],
        fallback: 'In Progress',
      );
    }

    for (final item in _payments) {
      final payment = _asMap(item);

      _totalPayment += _toDouble(
        payment['amount'] ??
            payment['amount_inr'] ??
            payment['payment_amount'],
      );
    }

    if (_payments.isNotEmpty) {
      final payment = _asMap(
        _payments.first,
      );

      _paymentStatus = _stringValue(
        payment['status'],
        fallback: 'Processing',
      );
    }

    for (final item in _notifications) {
      final notification = _asMap(item);

      final isRead = notification['is_read'] ??
          notification['isRead'] ??
          notification['read'] ??
          false;

      if (isRead == false) {
        _unreadNotifications++;
      }
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFD32F2F),
              ),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from SmartProcure?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await AuthService.clearToken();
    } catch (_) {}

    if (!mounted) return;

    context.go('/login');
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _open(String route) {
    context.go(route);
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
      dynamic value, {
        String fallback = '',
      }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      body: SafeArea(
        child: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF138A43),
          ),
        )
            : RefreshIndicator(
          color: const Color(0xFF138A43),
          onRefresh: () {
            return _loadDashboard(
              isRefresh: true,
            );
          },
          child: CustomScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  30,
                ),
                sliver: SliverList(
                  delegate:
                  SliverChildListDelegate(
                    [
                      if (_error != null) ...[
                        _buildErrorCard(),
                        const SizedBox(height: 16),
                      ],

                      _buildWelcomeSection(),

                      const SizedBox(height: 18),

                      _buildLiveTokenCard(),

                      const SizedBox(height: 24),

                      _buildSectionTitle(
                        'Quick Actions',
                        'Everything you need, one tap away',
                      ),

                      const SizedBox(height: 12),

                      _buildQuickActions(),

                      const SizedBox(height: 22),

                      _buildSmartBookingCard(),

                      const SizedBox(height: 24),

                      _buildSectionTitle(
                        'Procurement Overview',
                        'Your latest SmartProcure activity',
                      ),

                      const SizedBox(height: 12),

                      _buildOverviewCards(),

                      const SizedBox(height: 24),

                      _buildLatestUpdate(),

                      const SizedBox(height: 20),

                      _buildSecureFooter(),
                    ],
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
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        12,
        18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D8B43),
                  Color(0xFF20A653),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.agriculture_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartProcure',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12372A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Smart Farmer Procurement Platform',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718078),
                  ),
                ),
              ],
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  _open('/notifications');
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 28,
                  color: Color(0xFF12372A),
                ),
              ),

              if (_unreadNotifications > 0)
                Positioned(
                  right: 5,
                  top: 4,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints:
                    const BoxConstraints(
                      minWidth: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9363E),
                      borderRadius:
                      BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _unreadNotifications > 9
                          ? '9+'
                          : '$_unreadNotifications',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFF12372A),
              size: 27,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD32F2F),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WELCOME
  // ===========================================================================

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;

    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $_farmerName 👋',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17382A),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Manage your procurement journey easily.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF68776F),
                  ),
                ),
              ],
            ),
          ),
          if (_refreshing)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF138A43),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIVE TOKEN CARD
  // ===========================================================================

  Widget _buildLiveTokenCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087F3E),
            Color(0xFF16A052),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300C7D3D),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR LIVE TOKEN',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Procurement queue status',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 12,
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
                  Colors.white.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                  BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                      const BoxDecoration(
                        color: Color(0xFFB8F5C9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _bookingStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      _token,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(
                        bottom: 7,
                      ),
                      child: Text(
                        'TOKEN',
                        style: TextStyle(
                          color: Color(0xDFFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 55,
                color:
                Colors.white.withValues(
                  alpha: 0.25,
                ),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POSITION',
                    style: TextStyle(
                      color: Color(0xDFFFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _queuePosition > 0
                        ? '#$_queuePosition'
                        : '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:
              Colors.white.withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _estimatedWait > 0
                        ? 'Estimated waiting time: $_estimatedWait minutes'
                        : 'Waiting time will update with the live queue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                _open('/queue');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor:
                const Color(0xFF087F3E),
                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Track My Queue',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xDFFFFFFF),
                size: 14,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _centreName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xDFFFFFFF),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _buildSectionTitle(
      String title,
      String subtitle,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17382A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF7A867F),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Book Slot',
                subtitle: 'AI Smart Booking',
                icon: Icons.calendar_month_rounded,
                iconBackground:
                const Color(0xFFE5F6EB),
                iconColor:
                const Color(0xFF0B8B43),
                onTap: () {
                  _open('/booking');
                },
                large: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'My Token',
                subtitle: _token == '--'
                    ? 'View queue'
                    : _token,
                icon:
                Icons.confirmation_number_rounded,
                iconBackground:
                const Color(0xFFE9F1FF),
                iconColor:
                const Color(0xFF2368B5),
                onTap: () {
                  _open('/queue');
                },
                large: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Find Centre',
                subtitle: 'Live centre status',
                icon:
                Icons.location_on_rounded,
                iconBackground:
                const Color(0xFFFFF1DF),
                iconColor:
                const Color(0xFFD87800),
                onTap: () {
                  _open('/centres');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Procurement',
                subtitle: _procurementStatus,
                icon:
                Icons.inventory_2_rounded,
                iconBackground:
                const Color(0xFFEDE7FF),
                iconColor:
                const Color(0xFF6C4BC4),
                onTap: () {
                  _open('/procurement');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Payment',
                subtitle: _paymentStatus,
                icon:
                Icons.account_balance_wallet_rounded,
                iconBackground:
                const Color(0xFFE5F7F4),
                iconColor:
                const Color(0xFF008C7A),
                onTap: () {
                  _open('/payment');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Notifications',
                subtitle:
                _unreadNotifications > 0
                    ? '$_unreadNotifications new alerts'
                    : 'All caught up',
                icon:
                Icons.notifications_active_rounded,
                iconBackground:
                const Color(0xFFFFE9EB),
                iconColor:
                const Color(0xFFD9363E),
                onTap: () {
                  _open('/notifications');
                },
                badge:
                _unreadNotifications > 0
                    ? _unreadNotifications
                    : null,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Grievance',
                subtitle: 'Raise & track issue',
                icon:
                Icons.support_agent_rounded,
                iconBackground:
                const Color(0xFFFFF0F5),
                iconColor:
                const Color(0xFFB84472),
                onTap: () {
                  _open('/grievance');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'AI Assistant',
                subtitle: 'Smart insights',
                icon:
                Icons.auto_awesome_rounded,
                iconBackground:
                const Color(0xFFE8F3FF),
                iconColor:
                const Color(0xFF356FD8),
                onTap: () {
                  _open('/ai');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required VoidCallback onTap,
    bool large = false,
    int? badge,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: large ? 118 : 105,
          ),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE7ECE9),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: large ? 47 : 43,
                    height: large ? 47 : 43,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: large ? 25 : 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize:
                      large ? 15 : 14,
                      fontWeight:
                      FontWeight.w800,
                      color:
                      const Color(0xFF18372A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color:
                      Color(0xFF7B8780),
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ],
              ),

              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color:
                  Colors.grey.shade400,
                ),
              ),

              if (badge != null)
                Positioned(
                  right: 0,
                  top: 24,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFD9363E),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 9
                          ? '9+'
                          : '$badge',
                      style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight:
                        FontWeight.w800,
                      ),
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
  // SMART BOOKING
  // ===========================================================================

  Widget _buildSmartBookingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF102E22),
            Color(0xFF174C35),
          ],
        ),
        borderRadius:
        BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 7),
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
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFF2C9C5D),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Booking Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'AI-powered procurement planning',
                      style: TextStyle(
                        color:
                        Color(0xBFFFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                  const Color(0xFF2C9C5D),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          const Text(
            'Find a suitable procurement centre and time slot based on your crop, quantity, queue and location.',
            style: TextStyle(
              color: Color(0xDFFFFFFF),
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              _buildSmartFeature(
                Icons.location_on_outlined,
                'Centre',
              ),
              const SizedBox(width: 10),
              _buildSmartFeature(
                Icons.schedule_outlined,
                'Best time',
              ),
              const SizedBox(width: 10),
              _buildSmartFeature(
                Icons.trending_down_rounded,
                'Less wait',
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                _open('/booking');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor:
                const Color(0xFF12372A),
                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Find My Best Slot',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.w800,
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

  Widget _buildSmartFeature(
      IconData icon,
      String text,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color:
          Colors.white.withValues(
            alpha: 0.08,
          ),
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color:
            Colors.white.withValues(
              alpha: 0.10,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
              const Color(0xFF8FE3AE),
              size: 19,
            ),
            const SizedBox(height: 5),
            Text(
              text,
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                color:
                Color(0xDFFFFFFF),
                fontSize: 9,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // OVERVIEW
  // ===========================================================================

  Widget _buildOverviewCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Booked Quantity',
                value:
                '${_formatNumber(_totalQuantity)} kg',
                icon: Icons.scale_rounded,
                color:
                const Color(0xFF0B8B43),
                background:
                const Color(0xFFE6F6EC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Procured',
                value:
                '${_formatNumber(_totalProcured)} kg',
                icon:
                Icons.inventory_rounded,
                color:
                const Color(0xFF6B4AC4),
                background:
                const Color(0xFFEDE8FF),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Payment',
                value: _totalPayment > 0
                    ? _formatCurrency(
                  _totalPayment,
                )
                    : '₹0',
                icon:
                Icons.currency_rupee_rounded,
                color:
                const Color(0xFF008B78),
                background:
                const Color(0xFFE3F6F2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                title: 'Alerts',
                value:
                '$_unreadNotifications',
                icon:
                Icons.notifications_active_rounded,
                color:
                const Color(0xFFD9363E),
                background:
                const Color(0xFFFFE9EB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE8ECEA),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 9,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF7B8780),
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color:
                    Color(0xFF17382A),
                    fontWeight:
                    FontWeight.w800,
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
  // LATEST UPDATE
  // ===========================================================================

  Widget _buildLatestUpdate() {
    String title = 'No recent updates';
    String subtitle =
        'Your SmartProcure activity will appear here.';
    IconData icon =
        Icons.info_outline_rounded;
    Color color =
    const Color(0xFF1769AA);
    Color background =
    const Color(0xFFE9F2FF);

    if (_notifications.isNotEmpty) {
      final notification =
      _asMap(_notifications.first);

      title = _stringValue(
        notification['title'],
        fallback: 'SmartProcure Update',
      );

      subtitle = _stringValue(
        notification['message'] ??
            notification['body'] ??
            notification['description'],
        fallback:
        'You have a new SmartProcure notification.',
      );

      icon =
          Icons.notifications_active_rounded;
    } else if (_procurements.isNotEmpty) {
      title = 'Procurement Update';
      subtitle =
      'Your procurement record has been updated.';
      icon = Icons.inventory_2_rounded;
      color = const Color(0xFF6B4AC4);
      background =
      const Color(0xFFEDE8FF);
    } else if (_payments.isNotEmpty) {
      title = 'Payment Update';
      subtitle =
      'Your payment information is available.';
      icon =
          Icons.account_balance_wallet_rounded;
      color = const Color(0xFF008B78);
      background =
      const Color(0xFFE3F6F2);
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE7ECE9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: background,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Update',
                  style: TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF7B8780),
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color:
                    Color(0xFF17382A),
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF7B8780),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _open('/notifications');
            },
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0xFF7B8780),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius:
        BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFFFD0D0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFD9363E),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Unable to refresh some dashboard data.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B252B),
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _loadDashboard();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _buildSecureFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              'Secure Government Procurement Platform',
              style: TextStyle(
                fontSize: 9,
                color:
                Colors.grey.shade600,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Ministry of Consumer Affairs, Food & Public Distribution',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8,
            color:
            Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}