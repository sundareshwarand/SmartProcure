import 'package:flutter/material.dart';

import '../../core/network/farmer_api_service.dart';
import '../../core/widgets/logout_menu.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _overview = {};
  List<dynamic> _users = [];
  List<dynamic> _centres = [];
  List<dynamic> _auditLogs = [];

  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        farmerApiService.getAdminOverview(),
        farmerApiService.getAdminUsers(),
        farmerApiService.getAdminCentres(),
        farmerApiService.getAdminAuditLogs(),
      ]);

      if (!mounted) return;

      setState(() {
        _overview = Map<String, dynamic>.from(
          results[0] as Map,
        );

        _users = List<dynamic>.from(
          results[1] as List,
        );

        _centres = List<dynamic>.from(
          results[2] as List,
        );

        _auditLogs = List<dynamic>.from(
          results[3] as List,
        );

        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'ADMIN DASHBOARD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
        'Unable to load admin dashboard. Please try again.';
      });
    }
  }

  int _intValue(String key) {
    final value = _overview[key];

    if (value == null) return 0;

    if (value is int) return value;

    return int.tryParse(
      value.toString(),
    ) ??
        0;
  }

  String _stringValue(
      dynamic value, {
        String fallback = '-',
      }) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'open':
      case 'online':
      case 'operational':
        return Colors.green;

      case 'busy':
      case 'warning':
        return Colors.orange;

      case 'offline':
      case 'closed':
      case 'inactive':
        return Colors.red;

      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Color(0xFF12372A),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'System Administration & Control',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed:
            _loading ? null : _loadAdminData,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh,
              color: Color(0xFF2E7D32),
            ),
          ),
          const LogoutMenu(
            iconColor: Color(0xFF12372A),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2E7D32),
        ),
      )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _loadAdminData,
        color: const Color(0xFF2E7D32),
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),

            const SizedBox(height: 18),

            _buildSectionSelector(),

            const SizedBox(height: 20),

            _buildSelectedSection(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF12372A),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: Colors.white,
            size: 38,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartProcure Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'System administration and monitoring',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Row(
      children: [
        _sectionButton(
          'Overview',
          Icons.dashboard_outlined,
          0,
        ),
        const SizedBox(width: 7),
        _sectionButton(
          'Users',
          Icons.people_outline,
          1,
        ),
        const SizedBox(width: 7),
        _sectionButton(
          'Centres',
          Icons.location_city_outlined,
          2,
        ),
        const SizedBox(width: 7),
        _sectionButton(
          'Audit',
          Icons.security_outlined,
          3,
        ),
      ],
    );
  }

  Widget _sectionButton(
      String title,
      IconData icon,
      int index,
      ) {
    final selected =
        _selectedSection == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSection = index;
          });
        },
        borderRadius:
        BorderRadius.circular(12),
        child: AnimatedContainer(
          duration:
          const Duration(milliseconds: 180),
          padding:
          const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2E7D32)
                : Colors.white,
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 1:
        return _buildUsers();

      case 2:
        return _buildCentres();

      case 3:
        return _buildAuditLogs();

      default:
        return _buildOverview();
    }
  }

  Widget _buildOverview() {
    final totalUsers =
    _intValue('total_users');

    final farmers =
    _intValue('farmers');

    final operators =
    _intValue('operators');

    final officers =
    _intValue('officers');

    final admins =
    _intValue('admins');

    final totalCentres =
    _intValue('total_centres');

    final totalAudits =
    _intValue('total_audits');

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'System Overview',
          Icons.dashboard_outlined,
        ),

        const SizedBox(height: 12),

        _statCard(
          'Total Users',
          '$totalUsers',
          Icons.people_outline,
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Farmers',
                '$farmers',
                Icons.agriculture_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Operators',
                '$operators',
                Icons.support_agent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Officers',
                '$officers',
                Icons.badge_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Admins',
                '$admins',
                Icons.admin_panel_settings_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _statCard(
                'Centres',
                '$totalCentres',
                Icons.location_city_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Audit Logs',
                '$totalAudits',
                Icons.security_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionHeading(
      String title,
      IconData icon,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF2E7D32),
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF12372A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding:
              const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color:
                const Color(0xFF2E7D32),
                size: 22,
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
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      Color(0xFF12372A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsers() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'User Management',
          Icons.people_outline,
        ),
        const SizedBox(height: 5),
        Text(
          '${_users.length} users found',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        if (_users.isEmpty)
          _emptyCard(
            Icons.people_outline,
            'No users found',
          )
        else
          ..._users.map((item) {
            final user =
            Map<String, dynamic>.from(
              item as Map,
            );

            return _userCard(user);
          }),
      ],
    );
  }

  Widget _userCard(
      Map<String, dynamic> user,
      ) {
    final name = _stringValue(
      user['full_name'],
      fallback: 'Unknown User',
    );

    final username = _stringValue(
      user['username'],
    );

    final mobile = _stringValue(
      user['mobile'],
    );

    final role = _stringValue(
      user['role'],
      fallback: 'user',
    );

    final district = _stringValue(
      user['district'],
    );

    final centreId = _stringValue(
      user['centre_id'],
    );

    final active =
        user['is_active'] == true;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin:
      const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                  const Color(0xFFE8F5E9),
                  child: Icon(
                    _roleIcon(role),
                    color:
                    const Color(0xFF2E7D32),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        username,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _roleChip(role),
              ],
            ),
            const Divider(height: 22),
            _infoRow(
              Icons.phone_outlined,
              'Mobile',
              mobile,
            ),
            _infoRow(
              Icons.location_on_outlined,
              'District',
              district,
            ),
            _infoRow(
              Icons.location_city_outlined,
              'Centre',
              centreId,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  active
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 17,
                  color:
                  active
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 7),
                Text(
                  active
                      ? 'Active'
                      : 'Inactive',
                  style: TextStyle(
                    color:
                    active
                        ? Colors.green
                        : Colors.red,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'farmer':
        return Icons.agriculture;
      case 'operator':
        return Icons.support_agent;
      case 'officer':
        return Icons.badge;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Widget _roleChip(String role) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCentres() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Procurement Centres',
          Icons.location_city_outlined,
        ),
        const SizedBox(height: 5),
        Text(
          '${_centres.length} centres found',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        if (_centres.isEmpty)
          _emptyCard(
            Icons.location_city_outlined,
            'No centres found',
          )
        else
          ..._centres.map((item) {
            final centre =
            Map<String, dynamic>.from(
              item as Map,
            );

            return _centreCard(centre);
          }),
      ],
    );
  }

  Widget _centreCard(
      Map<String, dynamic> centre,
      ) {
    final name = _stringValue(
      centre['name'],
      fallback: 'Unknown Centre',
    );

    final code = _stringValue(
      centre['code'],
    );

    final district = _stringValue(
      centre['district'],
    );

    final address = _stringValue(
      centre['address'],
    );

    final capacity = _stringValue(
      centre['daily_capacity'],
      fallback: '0',
    );

    final counters = _stringValue(
      centre['active_counters'],
      fallback: '0',
    );

    final avgTime = _stringValue(
      centre['average_processing_minutes'],
      fallback: '0',
    );

    final status = _stringValue(
      centre['status'],
      fallback: 'Unknown',
    );

    final isActive =
        centre['is_active'] == true;

    final statusColor =
    _statusColor(status);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin:
      const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(17),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFE8F5E9),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color:
                    Color(0xFF2E7D32),
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
                        style:
                        const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        code,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey.shade600,
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
                  decoration: BoxDecoration(
                    color: statusColor
                        .withValues(alpha: 0.1),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(
              Icons.map_outlined,
              'District',
              district,
            ),
            _infoRow(
              Icons.place_outlined,
              'Address',
              address,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    'Capacity',
                    capacity,
                    Icons.inventory_2_outlined,
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    'Counters',
                    counters,
                    Icons.point_of_sale_outlined,
                  ),
                ),
                Expanded(
                  child: _miniMetric(
                    'Avg Time',
                    '$avgTime min',
                    Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isActive
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 18,
                  color:
                  isActive
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 7),
                Text(
                  isActive
                      ? 'Centre is active'
                      : 'Centre is inactive',
                  style: TextStyle(
                    color:
                    isActive
                        ? Colors.green
                        : Colors.red,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(
      String title,
      String value,
      IconData icon,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogs() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Security & Audit Logs',
          Icons.security_outlined,
        ),
        const SizedBox(height: 5),
        Text(
          'Latest ${_auditLogs.length} audit records',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 14),
        if (_auditLogs.isEmpty)
          _emptyCard(
            Icons.security_outlined,
            'No audit logs found',
          )
        else
          ..._auditLogs.map((item) {
            final log =
            Map<String, dynamic>.from(
              item as Map,
            );

            return _auditCard(log);
          }),
      ],
    );
  }

  Widget _auditCard(
      Map<String, dynamic> log,
      ) {
    final action = _stringValue(
      log['action'],
      fallback: 'Unknown Action',
    );

    final role = _stringValue(
      log['actor_role'],
    );

    final actorId = _stringValue(
      log['actor_id'],
    );

    final centreId = _stringValue(
      log['centre_id'],
    );

    final targetType = _stringValue(
      log['target_type'],
    );

    final targetId = _stringValue(
      log['target_id'],
    );

    final success =
        log['success'] == true;

    final createdAt = _stringValue(
      log['created_at'],
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      margin:
      const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(15),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                  success
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  child: Icon(
                    success
                        ? Icons.check
                        : Icons.close,
                    color:
                    success
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        action,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Actor $actorId • $role',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  success
                      ? 'SUCCESS'
                      : 'FAILED',
                  style: TextStyle(
                    color:
                    success
                        ? Colors.green
                        : Colors.red,
                    fontSize: 10,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            _infoRow(
              Icons.location_city_outlined,
              'Centre',
              centreId,
            ),
            _infoRow(
              Icons.track_changes_outlined,
              'Target',
              '$targetType / $targetId',
            ),
            _infoRow(
              Icons.access_time_outlined,
              'Time',
              createdAt,
            ),
            if (!success &&
                log['failure_reason'] != null)
              _infoRow(
                Icons.warning_amber_outlined,
                'Failure',
                _stringValue(
                  log['failure_reason'],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color:
                Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
      IconData icon,
      String message,
      ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 50,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 15),
            Text(
              _error ??
                  'Unable to load admin data.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _loadAdminData,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Retry',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFF2E7D32),
                foregroundColor:
                Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}