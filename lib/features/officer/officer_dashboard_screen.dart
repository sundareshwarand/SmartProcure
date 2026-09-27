import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/farmer_api_service.dart';

class OfficerDashboardScreen extends StatefulWidget {
  const OfficerDashboardScreen({super.key});

  @override
  State<OfficerDashboardScreen> createState() =>
      _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState
    extends State<OfficerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FarmerApiService _api = FarmerApiService.instance;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  Map<String, dynamic> _overview = {};
  List<dynamic> _users = [];
  List<dynamic> _centres = [];
  List<dynamic> _auditLogs = [];

  late TabController _tabController;

  String _userSearch = '';
  String _centreSearch = '';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD DASHBOARD
  // ===========================================================================

  Future<void> _loadDashboard({
    bool refresh = false,
  }) async {
    if (refresh) {
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
      final results = await Future.wait<dynamic>([
        _api.getAdminOverview(),
        _api.getAdminUsers(),
        _api.getAdminCentres(),
        _api.getAdminAuditLogs(),
      ]);

      if (!mounted) return;

      final overviewResult = results[0];
      final usersResult = results[1];
      final centresResult = results[2];
      final auditResult = results[3];

      final Map<String, dynamic> overview =
      overviewResult is Map
          ? Map<String, dynamic>.from(overviewResult)
          : {};

      final List<dynamic> users =
      usersResult is List ? List<dynamic>.from(usersResult) : [];

      final List<dynamic> centres =
      centresResult is List
          ? List<dynamic>.from(centresResult)
          : [];

      final List<dynamic> auditLogs =
      auditResult is List
          ? List<dynamic>.from(auditResult)
          : [];

      setState(() {
        _overview = overview;
        _users = users;
        _centres = centres;
        _auditLogs = auditLogs;

        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint(
        'ADMIN DASHBOARD ERROR: $e',
      );

      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
        'Unable to load administrator dashboard.';
      });
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _logout() async {
    await AuthService.clearToken();

    if (!mounted) return;

    context.go('/login');
  }

  // ===========================================================================
  // VALUE HELPERS
  // ===========================================================================

  String _stringValue(
      dynamic value, {
        String fallback = '-',
      }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int _intValue(
      dynamic value, {
        int fallback = 0,
      }) {
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

  double _doubleValue(
      dynamic value, {
        double fallback = 0,
      }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        fallback;
  }

  bool _boolValue(
      dynamic value, {
        bool fallback = true,
      }) {
    if (value is bool) {
      return value;
    }

    final text = value?.toString().toLowerCase();

    if (text == 'false' ||
        text == '0' ||
        text == 'inactive' ||
        text == 'disabled') {
      return false;
    }

    if (text == 'true' ||
        text == '1' ||
        text == 'active' ||
        text == 'enabled') {
      return true;
    }

    return fallback;
  }

  // ===========================================================================
  // OVERVIEW VALUES
  // ===========================================================================

  int get _totalUsers {
    return _intValue(
      _overview['total_users'],
      fallback: _users.length,
    );
  }

  int get _farmers {
    final backendValue = _overview['farmers'];

    if (backendValue != null) {
      return _intValue(backendValue);
    }

    return _users.where((item) {
      if (item is! Map) return false;

      final user = Map<String, dynamic>.from(item);

      return _stringValue(
        user['role'],
      ).toLowerCase() ==
          'farmer';
    }).length;
  }

  int get _operators {
    final backendValue = _overview['operators'];

    if (backendValue != null) {
      return _intValue(backendValue);
    }

    return _users.where((item) {
      if (item is! Map) return false;

      final user = Map<String, dynamic>.from(item);

      return _stringValue(
        user['role'],
      ).toLowerCase() ==
          'operator';
    }).length;
  }

  int get _officers {
    final backendValue = _overview['officers'];

    if (backendValue != null) {
      return _intValue(backendValue);
    }

    return _users.where((item) {
      if (item is! Map) return false;

      final user = Map<String, dynamic>.from(item);

      return _stringValue(
        user['role'],
      ).toLowerCase() ==
          'officer';
    }).length;
  }

  int get _admins {
    final backendValue = _overview['admins'];

    if (backendValue != null) {
      return _intValue(backendValue);
    }

    return _users.where((item) {
      if (item is! Map) return false;

      final user = Map<String, dynamic>.from(item);

      return _stringValue(
        user['role'],
      ).toLowerCase() ==
          'admin';
    }).length;
  }

  int get _activeCentres {
    return _intValue(
      _overview['active_centres'],
      fallback: _centres.length,
    );
  }

  int get _systemActivity {
    return _intValue(
      _overview['system_activity'],
      fallback: _auditLogs.length,
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF16834B),
        ),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    return Column(
      children: [
        _buildHeader(),
        _buildTabs(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildUsersTab(),
              _buildCentresTab(),
              _buildAuditTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF17221D),
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/farmer/home');
          }
        },
      ),
      titleSpacing: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SmartProcure',
            style: TextStyle(
              color: Color(0xFF17221D),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Administrator Console',
            style: TextStyle(
              color: Color(0xFF748078),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (_refreshing)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
            ),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF16834B),
                ),
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF16834B),
            ),
            onPressed: () {
              _loadDashboard(refresh: true);
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Color(0xFF17221D),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        10,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF126B3D),
            Color(0xFF1A9557),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16834B).withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage users, centres, security and system activity.',
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
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
  // TABS
  // ===========================================================================

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF16834B),
        unselectedLabelColor: const Color(0xFF7B867F),
        indicatorColor: const Color(0xFF16834B),
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            icon: Icon(
              Icons.dashboard_rounded,
              size: 19,
            ),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(
              Icons.people_alt_rounded,
              size: 19,
            ),
            text: 'Users',
          ),
          Tab(
            icon: Icon(
              Icons.location_city_rounded,
              size: 19,
            ),
            text: 'Centres',
          ),
          Tab(
            icon: Icon(
              Icons.security_rounded,
              size: 19,
            ),
            text: 'Audit',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OVERVIEW
  // ===========================================================================

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color: const Color(0xFF16834B),
      onRefresh: () => _loadDashboard(
        refresh: true,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        children: [
          _sectionTitle(
            'System Overview',
            'Live administrative statistics',
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _metricCard(
                icon: Icons.people_alt_rounded,
                title: 'Total Users',
                value: '$_totalUsers',
                color: const Color(0xFF16834B),
              ),
              _metricCard(
                icon: Icons.agriculture_rounded,
                title: 'Farmers',
                value: '$_farmers',
                color: const Color(0xFF2D8A5A),
              ),
              _metricCard(
                icon: Icons.support_agent_rounded,
                title: 'Operators',
                value: '$_operators',
                color: const Color(0xFF2474B5),
              ),
              _metricCard(
                icon: Icons.badge_rounded,
                title: 'Officers',
                value: '$_officers',
                color: const Color(0xFF7B57B5),
              ),
              _metricCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admins',
                value: '$_admins',
                color: const Color(0xFFAF5B35),
              ),
              _metricCard(
                icon: Icons.location_city_rounded,
                title: 'Active Centres',
                value: '$_activeCentres',
                color: const Color(0xFF16834B),
              ),
            ],
          ),

          const SizedBox(height: 22),

          _sectionTitle(
            'System Health',
            'Current platform status',
          ),

          const SizedBox(height: 12),

          _systemHealthCard(),

          const SizedBox(height: 22),

          _sectionTitle(
            'Administrative Activity',
            'Latest system actions',
          ),

          const SizedBox(height: 12),

          _activitySummaryCard(),

          const SizedBox(height: 22),

          _sectionTitle(
            'Quick Management',
            'Open a management section',
          ),

          const SizedBox(height: 12),

          _quickAction(
            icon: Icons.people_alt_outlined,
            title: 'User Management',
            subtitle: 'View users and role information',
            onTap: () {
              _tabController.animateTo(1);
            },
          ),

          _quickAction(
            icon: Icons.location_city_outlined,
            title: 'Centre Management',
            subtitle: 'Review procurement centres',
            onTap: () {
              _tabController.animateTo(2);
            },
          ),

          _quickAction(
            icon: Icons.security_outlined,
            title: 'Security & Audit',
            subtitle: 'Review system activity logs',
            onTap: () {
              _tabController.animateTo(3);
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SYSTEM HEALTH
  // ===========================================================================

  Widget _systemHealthCard() {
    final backendStatus = _stringValue(
      _overview['backend_status'],
      fallback: 'Operational',
    );

    final databaseStatus = _stringValue(
      _overview['database_status'],
      fallback: 'Connected',
    );

    final aiStatus = _stringValue(
      _overview['ai_status'],
      fallback: 'Available',
    );

    final apiStatus = _stringValue(
      _overview['api_status'],
      fallback: 'Healthy',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E9E4),
        ),
      ),
      child: Column(
        children: [
          _healthRow(
            'Backend API',
            backendStatus,
            Icons.dns_rounded,
          ),
          _healthRow(
            'MySQL Database',
            databaseStatus,
            Icons.storage_rounded,
          ),
          _healthRow(
            'AI Engine',
            aiStatus,
            Icons.auto_awesome_rounded,
          ),
          _healthRow(
            'API Services',
            apiStatus,
            Icons.api_rounded,
          ),
        ],
      ),
    );
  }

  Widget _healthRow(
      String title,
      String status,
      IconData icon,
      ) {
    final lower = status.toLowerCase();

    final healthy =
        lower.contains('operational') ||
            lower.contains('connected') ||
            lower.contains('available') ||
            lower.contains('healthy') ||
            lower.contains('online');

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF16834B),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2821),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: healthy
                  ? const Color(0xFFEAF6EF)
                  : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: healthy
                        ? const Color(0xFF16834B)
                        : const Color(0xFFD64545),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: healthy
                        ? const Color(0xFF16834B)
                        : const Color(0xFFD64545),
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
  // ACTIVITY
  // ===========================================================================

  Widget _activitySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E9E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: Color(0xFF16834B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_systemActivity recorded administrative events',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9AA49E),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // USERS
  // ===========================================================================

  Widget _buildUsersTab() {
    final filtered = _users.where((item) {
      if (item is! Map) return false;

      final user = Map<String, dynamic>.from(item);

      final search = _userSearch.trim().toLowerCase();

      if (search.isEmpty) {
        return true;
      }

      final name = _stringValue(
        user['name'],
      ).toLowerCase();

      final fullName = _stringValue(
        user['full_name'],
      ).toLowerCase();

      final username = _stringValue(
        user['username'],
      ).toLowerCase();

      final mobile = _stringValue(
        user['mobile'],
      ).toLowerCase();

      final phone = _stringValue(
        user['phone'],
      ).toLowerCase();

      final role = _stringValue(
        user['role'],
      ).toLowerCase();

      return name.contains(search) ||
          fullName.contains(search) ||
          username.contains(search) ||
          mobile.contains(search) ||
          phone.contains(search) ||
          role.contains(search);
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFF16834B),
      onRefresh: () => _loadDashboard(
        refresh: true,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        children: [
          _sectionTitle(
            'User Management',
            '${filtered.length} users shown',
          ),
          const SizedBox(height: 12),

          _searchField(
            hint: 'Search name, username, mobile or role',
            onChanged: (value) {
              setState(() {
                _userSearch = value;
              });
            },
          ),

          const SizedBox(height: 14),

          if (filtered.isEmpty)
            _emptyState(
              Icons.people_outline_rounded,
              'No users found',
              'Try another search term.',
            )
          else
            ...filtered.map(
                  (item) => _userCard(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userCard(
      Map<String, dynamic> user,
      ) {
    final name = _stringValue(
      user['name'],
      fallback: _stringValue(
        user['full_name'],
        fallback: 'User',
      ),
    );

    final username = _stringValue(
      user['username'],
      fallback: '-',
    );

    final role = _stringValue(
      user['role'],
      fallback: 'farmer',
    );

    final mobile = _stringValue(
      user['mobile'],
      fallback: _stringValue(
        user['phone'],
        fallback: '-',
      ),
    );

    final active = _boolValue(
      user['is_active'],
      fallback: true,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _roleIcon(role),
              color: const Color(0xFF16834B),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mobile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _roleChip(role),
              const SizedBox(height: 6),
              _statusChip(active),
            ],
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'operator':
        return Icons.support_agent_rounded;

      case 'officer':
        return Icons.badge_rounded;

      case 'admin':
        return Icons.admin_panel_settings_rounded;

      default:
        return Icons.agriculture_rounded;
    }
  }

  Widget _roleChip(String role) {
    final normalized = role.toLowerCase();

    Color color;

    switch (normalized) {
      case 'admin':
        color = const Color(0xFFAF5B35);
        break;

      case 'officer':
        color = const Color(0xFF7B57B5);
        break;

      case 'operator':
        color = const Color(0xFF2474B5);
        break;

      default:
        color = const Color(0xFF16834B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFEAF6EF)
            : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: active
              ? const Color(0xFF16834B)
              : const Color(0xFFD64545),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ===========================================================================
  // CENTRES
  // ===========================================================================

  Widget _buildCentresTab() {
    final filtered = _centres.where((item) {
      if (item is! Map) return false;

      final centre = Map<String, dynamic>.from(item);

      final search = _centreSearch.trim().toLowerCase();

      if (search.isEmpty) {
        return true;
      }

      final name = _stringValue(
        centre['name'],
        fallback: _stringValue(
          centre['centre_name'],
        ),
      ).toLowerCase();

      final code = _stringValue(
        centre['code'],
        fallback: _stringValue(
          centre['centre_code'],
        ),
      ).toLowerCase();

      return name.contains(search) ||
          code.contains(search);
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFF16834B),
      onRefresh: () => _loadDashboard(
        refresh: true,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        children: [
          _sectionTitle(
            'Centre Management',
            '${filtered.length} centres shown',
          ),
          const SizedBox(height: 12),

          _searchField(
            hint: 'Search centre name or code',
            onChanged: (value) {
              setState(() {
                _centreSearch = value;
              });
            },
          ),

          const SizedBox(height: 14),

          if (filtered.isEmpty)
            _emptyState(
              Icons.location_city_outlined,
              'No centres found',
              'Try another search term.',
            )
          else
            ...filtered.map(
                  (item) => _centreCard(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _centreCard(
      Map<String, dynamic> centre,
      ) {
    final name = _stringValue(
      centre['name'],
      fallback: _stringValue(
        centre['centre_name'],
        fallback: 'Procurement Centre',
      ),
    );

    final code = _stringValue(
      centre['code'],
      fallback: _stringValue(
        centre['centre_code'],
        fallback: '-',
      ),
    );

    final capacity = _intValue(
      centre['capacity'],
    );

    final counters = _intValue(
      centre['counters'],
      fallback: _intValue(
        centre['counter_count'],
      ),
    );

    final processing = _doubleValue(
      centre['average_processing_time'],
      fallback: _doubleValue(
        centre['avg_processing_time'],
      ),
    );

    final status = _stringValue(
      centre['status'],
      fallback: 'Operational',
    );

    final utilization = _doubleValue(
      centre['utilization_percentage'],
      fallback: _doubleValue(
        centre['utilization'],
      ),
    );

    final utilizationValue =
    (utilization / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFF16834B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _centreStatusChip(status),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _miniStat(
                  Icons.people_alt_outlined,
                  'Capacity',
                  '$capacity',
                ),
              ),
              Expanded(
                child: _miniStat(
                  Icons.countertops_outlined,
                  'Counters',
                  '$counters',
                ),
              ),
              Expanded(
                child: _miniStat(
                  Icons.timer_outlined,
                  'Avg Time',
                  '${processing.toStringAsFixed(1)}m',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                size: 18,
                color: Color(0xFF16834B),
              ),
              const SizedBox(width: 8),
              const Text(
                'Utilization',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${utilization.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16834B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: utilizationValue,
              backgroundColor: const Color(0xFFE8EEE9),
              color: const Color(0xFF16834B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centreStatusChip(
      String status,
      ) {
    final lower = status.toLowerCase();

    final healthy =
        !lower.contains('closed') &&
            !lower.contains('inactive');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: healthy
            ? const Color(0xFFEAF6EF)
            : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: healthy
              ? const Color(0xFF16834B)
              : const Color(0xFFD64545),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _miniStat(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF16834B),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // AUDIT
  // ===========================================================================

  Widget _buildAuditTab() {
    return RefreshIndicator(
      color: const Color(0xFF16834B),
      onRefresh: () => _loadDashboard(
        refresh: true,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        children: [
          _sectionTitle(
            'Security & Audit',
            '${_auditLogs.length} recorded events',
          ),
          const SizedBox(height: 12),

          if (_auditLogs.isEmpty)
            _emptyState(
              Icons.security_outlined,
              'No audit activity',
              'There are no recorded audit events.',
            )
          else
            ..._auditLogs
                .take(50)
                .where((item) => item is Map)
                .map(
                  (item) => _auditCard(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _auditCard(
      Map<String, dynamic> audit,
      ) {
    final action = _stringValue(
      audit['action'],
      fallback: 'System Action',
    );

    final actor = _stringValue(
      audit['actor_id'],
      fallback: _stringValue(
        audit['actor'],
        fallback: 'System',
      ),
    );

    final role = _stringValue(
      audit['actor_role'],
      fallback: '-',
    );

    final centre = _stringValue(
      audit['centre_id'],
      fallback: '-',
    );

    final timestamp = _stringValue(
      audit['timestamp'],
      fallback: _stringValue(
        audit['created_at'],
        fallback: '-',
      ),
    );

    final success = _boolValue(
      audit['success'],
      fallback: true,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: success
                  ? const Color(0xFFEAF6EF)
                  : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              success
                  ? Icons.check_circle_outline
                  : Icons.error_outline_rounded,
              color: success
                  ? const Color(0xFF16834B)
                  : const Color(0xFFD64545),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Actor: $actor  •  Role: $role',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Centre: $centre',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timestamp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
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
  // COMMON UI
  // ===========================================================================

  Widget _sectionTitle(
      String title,
      String subtitle,
      ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17221D),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE1E8E3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF16834B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF8A958E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField({
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF16834B),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE1E8E3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE1E8E3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF16834B),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(
      IconData icon,
      String title,
      String message,
      ) {
    return Container(
      margin: const EdgeInsets.only(
        top: 30,
      ),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: const Color(0xFF9AA49E),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFD64545),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load Admin Dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _error ??
                  'Please check the SmartProcure server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _loadDashboard();
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF16834B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}