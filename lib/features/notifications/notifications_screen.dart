import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/farmer_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final FarmerApiService _api =
      FarmerApiService.instance;

  final TextEditingController _searchController =
  TextEditingController();

  bool _loading = true;
  String? _error;

  List<dynamic> _notifications = [];

  String _selectedFilter = 'All';

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD NOTIFICATIONS
  // ===========================================================================

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getNotifications(
        farmerId: 1,
      );

      if (!mounted) return;

      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
        'Unable to load notifications.';
      });
    }
  }

  // ===========================================================================
  // DATA HELPERS
  // ===========================================================================

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _value(
      Map<String, dynamic> item,
      String key, [
        String fallback = '',
      ]) {
    final value = item[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  int? _id(Map<String, dynamic> item) {
    return int.tryParse(
      item['id']?.toString() ?? '',
    );
  }

  String _type(
      Map<String, dynamic> item,
      ) {
    return _value(
      item,
      'notification_type',
      'general',
    ).toLowerCase();
  }

  bool _isRead(
      Map<String, dynamic> item,
      ) {
    final value = item['is_read'];

    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() ==
            'true' ||
        value?.toString() == '1';
  }

  int get _unreadCount {
    return _notifications
        .map(_map)
        .where(
          (item) => !_isRead(item),
    )
        .length;
  }

  int _countByType(String type) {
    if (type == 'All') {
      return _notifications.length;
    }

    return _notifications
        .map(_map)
        .where(
          (item) =>
      _type(item) == type.toLowerCase(),
    )
        .length;
  }

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  List<Map<String, dynamic>>
  get _filteredNotifications {
    final query =
    _searchController.text.trim().toLowerCase();

    return _notifications
        .map(_map)
        .where((item) {
      if (_selectedFilter != 'All') {
        if (_type(item) !=
            _selectedFilter.toLowerCase()) {
          return false;
        }
      }

      if (query.isEmpty) {
        return true;
      }

      final title = _value(
        item,
        'title',
      ).toLowerCase();

      final message = _value(
        item,
        'message',
      ).toLowerCase();

      final type = _type(item);

      return title.contains(query) ||
          message.contains(query) ||
          type.contains(query);
    })
        .toList();
  }

  // ===========================================================================
  // MARK AS READ
  // ===========================================================================

  Future<void> _markAsRead(
      int id,
      ) async {
    try {
      await _api.markNotificationRead(id);

      if (!mounted) return;

      setState(() {
        for (final raw in _notifications) {
          final item = _map(raw);

          if (_id(item) == id) {
            item['is_read'] = true;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to mark notification as read.',
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ===========================================================================
  // MARK ALL AS READ
  // ===========================================================================

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) {
      return;
    }

    try {
      await _api.markAllNotificationsRead();

      if (!mounted) return;

      setState(() {
        for (final raw in _notifications) {
          final item = _map(raw);
          item['is_read'] = true;
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'All notifications marked as read',
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update notifications.',
            ),
            behavior:
            SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ===========================================================================
  // NOTIFICATION ICON
  // ===========================================================================

  IconData _notificationIcon(
      String type,
      ) {
    switch (type.toLowerCase()) {
      case 'booking':
        return Icons.event_available_rounded;

      case 'queue':
        return Icons.people_alt_rounded;

      case 'procurement':
        return Icons.agriculture_rounded;

      case 'payment':
        return Icons.account_balance_wallet_rounded;

      case 'alert':
        return Icons.warning_amber_rounded;

      case 'grievance':
        return Icons.support_agent_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  // ===========================================================================
  // NOTIFICATION COLOR
  // ===========================================================================

  Color _notificationColor(
      String type,
      ) {
    switch (type.toLowerCase()) {
      case 'booking':
        return const Color(0xFF1976D2);

      case 'queue':
        return const Color(0xFFF57C00);

      case 'procurement':
        return const Color(0xFF2E7D32);

      case 'payment':
        return const Color(0xFF9C27B0);

      case 'alert':
        return const Color(0xFFD32F2F);

      case 'grievance':
        return const Color(0xFF00897B);

      default:
        return const Color(0xFF546E7A);
    }
  }

  // ===========================================================================
  // TIME
  // ===========================================================================

  String _timeText(
      Map<String, dynamic> item,
      ) {
    final raw =
    _value(item, 'created_at');

    if (raw.isEmpty) {
      return 'Recently';
    }

    DateTime? date;

    try {
      date = DateTime.tryParse(raw);
    } catch (_) {
      date = null;
    }

    if (date == null) {
      return raw;
    }

    final now = DateTime.now();

    final difference =
    now.difference(date.toLocal());

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
  // COPY MESSAGE
  // ===========================================================================

  Future<void> _copyMessage(
      String message,
      ) async {
    await Clipboard.setData(
      ClipboardData(
        text: message,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Notification message copied',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _openRelatedPage(
      Map<String, dynamic> item,
      ) {
    final type = _type(item);

    switch (type) {
      case 'booking':
        context.push('/my-bookings');
        break;

      case 'queue':
        context.push('/queue');
        break;

      case 'payment':
        context.push('/payment');
        break;

      case 'procurement':
        context.push('/procurement');
        break;

      case 'grievance':
        context.push('/grievance');
        break;

      case 'alert':
        context.push('/help');
        break;

      default:
        break;
    }
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  void _showNotificationDetails(
      Map<String, dynamic> item,
      ) {
    final id = _id(item);

    if (id != null && !_isRead(item)) {
      _markAsRead(id);
    }

    final title = _value(
      item,
      'title',
      'Notification',
    );

    final message = _value(
      item,
      'message',
      'No message available.',
    );

    final type = _type(item);

    final color =
    _notificationColor(type);

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
            28,
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
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
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
                        0xFFD5DDD8,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration:
                      BoxDecoration(
                        color:
                        color.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Icon(
                        _notificationIcon(
                          type,
                        ),
                        color: color,
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      width: 13,
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
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w800,
                              color:
                              Color(
                                0xFF173B2B,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            type
                                .toUpperCase(),
                            style:
                            TextStyle(
                              fontSize: 10,
                              fontWeight:
                              FontWeight.w800,
                              color: color,
                              letterSpacing:
                              0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 22,
                ),

                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    const Color(
                      0xFFF6F9F7,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Text(
                    message,
                    style:
                    const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color:
                      Color(0xFF45544C),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color:
                      Colors.black45,
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      _timeText(item),
                      style:
                      const TextStyle(
                        fontSize: 11,
                        color:
                        Colors.black54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _copyMessage(
                            message,
                          );
                        },
                        icon:
                        const Icon(
                          Icons.copy_rounded,
                          size: 17,
                        ),
                        label:
                        const Text(
                          'Copy',
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                          );
                          _openRelatedPage(
                            item,
                          );
                        },
                        icon:
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 17,
                        ),
                        label:
                        const Text(
                          'Open',
                        ),
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          const Color(
                            0xFF16834B,
                          ),
                          foregroundColor:
                          Colors.white,
                          elevation: 0,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
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
          ),
        );
      },
    );
  }

  // ===========================================================================
  // FILTER CHIP
  // ===========================================================================

  Widget _filterChip(
      String label,
      String type,
      ) {
    final selected =
        _selectedFilter == label;

    final count =
    _countByType(type);

    return Padding(
      padding:
      const EdgeInsets.only(
        right: 8,
      ),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = label;
          });
        },
        label: Text(
          '$label $count',
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
  }

  // ===========================================================================
  // NOTIFICATION CARD
  // ===========================================================================

  Widget _notificationCard(
      Map<String, dynamic> item,
      ) {
    final id = _id(item);

    final title = _value(
      item,
      'title',
      'Notification',
    );

    final message = _value(
      item,
      'message',
    );

    final type = _type(item);

    final isRead =
    _isRead(item);

    final color =
    _notificationColor(type);

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Material(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            _showNotificationDetails(
              item,
            );
          },
          borderRadius:
          BorderRadius.circular(18),
          child: Container(
            padding:
            const EdgeInsets.all(15),
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: isRead
                    ? const Color(
                  0xFFE1E8E3,
                )
                    : color.withValues(
                  alpha: 0.30,
                ),
                width:
                isRead ? 1 : 1.2,
              ),
              color: isRead
                  ? Colors.white
                  : color.withValues(
                alpha: 0.035,
              ),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration:
                  BoxDecoration(
                    color:
                    color.withValues(
                      alpha: 0.11,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    _notificationIcon(
                      type,
                    ),
                    color: color,
                    size: 23,
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
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              TextStyle(
                                color:
                                const Color(
                                  0xFF173B2B,
                                ),
                                fontSize: 13,
                                fontWeight:
                                isRead
                                    ? FontWeight
                                    .w600
                                    : FontWeight
                                    .w800,
                              ),
                            ),
                          ),

                          if (!isRead)
                            Container(
                              width: 9,
                              height: 9,
                              margin:
                              const EdgeInsets
                                  .only(
                                left: 7,
                                top: 4,
                              ),
                              decoration:
                              const BoxDecoration(
                                color:
                                Color(
                                  0xFF16834B,
                                ),
                                shape:
                                BoxShape
                                    .circle,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        message,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF718078,
                          ),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(
                        height: 9,
                      ),

                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              color.withValues(
                                alpha: 0.09,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                8,
                              ),
                            ),
                            child: Text(
                              type
                                  .toUpperCase(),
                              style:
                              TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight:
                                FontWeight
                                    .w800,
                                letterSpacing:
                                0.5,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Icon(
                            Icons
                                .schedule_outlined,
                            size: 13,
                            color:
                            Colors.black38,
                          ),

                          const SizedBox(
                            width: 4,
                          ),

                          Text(
                            _timeText(item),
                            style:
                            const TextStyle(
                              fontSize: 9,
                              color:
                              Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 4,
                ),

                PopupMenuButton<String>(
                  padding:
                  EdgeInsets.zero,
                  icon: const Icon(
                    Icons
                        .more_vert_rounded,
                    size: 20,
                    color:
                    Colors.black38,
                  ),
                  onSelected: (value) {
                    if (value ==
                        'read') {
                      if (id != null) {
                        _markAsRead(id);
                      }
                    }

                    if (value ==
                        'open') {
                      _showNotificationDetails(
                        item,
                      );
                    }

                    if (value ==
                        'copy') {
                      _copyMessage(
                        message,
                      );
                    }
                  },
                  itemBuilder:
                      (context) {
                    return [
                      if (!isRead)
                        const PopupMenuItem<
                            String>(
                          value: 'read',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .done_rounded,
                                size: 18,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Mark as read',
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem<
                          String>(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .open_in_new_rounded,
                              size: 18,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'View details',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<
                          String>(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .copy_rounded,
                              size: 18,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'Copy message',
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUMMARY HEADER
  // ===========================================================================

  Widget _buildSummary() {
    final unread =
        _unreadCount;

    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        gradient:
        const LinearGradient(
          colors: [
            Color(0xFFEAF7EF),
            Color(0xFFF8FBF9),
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xFFCDE5D5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            const BoxDecoration(
              color:
              Color(0xFFDDF1E3),
              shape:
              BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .notifications_active_rounded,
              color:
              Color(0xFF16834B),
              size: 24,
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
                  unread == 0
                      ? 'You are all caught up'
                      : '$unread unread notification${unread == 1 ? '' : 's'}',
                  style:
                  const TextStyle(
                    color:
                    Color(0xFF173B2B),
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${_notifications.length} total notification${_notifications.length == 1 ? '' : 's'}',
                  style:
                  const TextStyle(
                    color:
                    Color(0xFF718078),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          if (unread > 0)
            TextButton(
              onPressed:
              _markAllAsRead,
              child:
              const Text(
                'Read all',
                style:
                TextStyle(
                  color:
                  Color(0xFF16834B),
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

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch() {
    return Container(
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          const Color(0xFFE0E7E2),
        ),
      ),
      child: TextField(
        controller:
        _searchController,
        decoration:
        InputDecoration(
          hintText:
          'Search notifications...',
          hintStyle:
          const TextStyle(
            color:
            Colors.black38,
            fontSize: 12,
          ),
          prefixIcon:
          const Icon(
            Icons.search_rounded,
            color:
            Color(0xFF527263),
            size: 21,
          ),
          suffixIcon:
          _searchController
              .text
              .isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController
                  .clear();
            },
            icon:
            const Icon(
              Icons
                  .clear_rounded,
              size: 18,
            ),
          )
              : null,
          border:
          InputBorder.none,
          contentPadding:
          const EdgeInsets
              .symmetric(
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
      scrollDirection:
      Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            'All',
            'All',
          ),
          _filterChip(
            'Booking',
            'booking',
          ),
          _filterChip(
            'Queue',
            'queue',
          ),
          _filterChip(
            'Payment',
            'payment',
          ),
          _filterChip(
            'Procurement',
            'procurement',
          ),
          _filterChip(
            'Alert',
            'alert',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY FILTER
  // ===========================================================================

  Widget _buildFilterEmpty() {
    return Container(
      padding:
      const EdgeInsets.all(28),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xFFE1E8E3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .filter_alt_off_rounded,
            size: 42,
            color:
            Colors.black26,
          ),
          const SizedBox(
            height: 12,
          ),
          const Text(
            'No matching notifications',
            style: TextStyle(
              color:
              Color(0xFF173B2B),
              fontSize: 14,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          const Text(
            'Try another category or search term.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY ALL
  // ===========================================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      color:
      const Color(0xFF16834B),
      onRefresh:
      _loadNotifications,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(
            height: 130,
          ),
          Center(
            child: Padding(
              padding:
              const EdgeInsets.all(
                30,
              ),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration:
                    const BoxDecoration(
                      color:
                      Color(0xFFEAF5EF),
                      shape:
                      BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons
                          .notifications_none_rounded,
                      color:
                      Color(0xFF16834B),
                      size: 43,
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Text(
                    'No Notifications',
                    style:
                    TextStyle(
                      color:
                      Color(0xFF173B2B),
                      fontSize: 19,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  const Text(
                    'You are all caught up. New booking, queue, procurement and payment updates will appear here.',
                    textAlign:
                    TextAlign.center,
                    style:
                    TextStyle(
                      color:
                      Colors.black54,
                      fontSize: 12,
                      height: 1.45,
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
              width: 76,
              height: 76,
              decoration:
              const BoxDecoration(
                color:
                Color(0xFFFFEBEE),
                shape:
                BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .cloud_off_rounded,
                color:
                Color(0xFFD32F2F),
                size: 36,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Unable to Load Notifications',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                Color(0xFF173B2B),
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _error ??
                  'Something went wrong.',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                Colors.black54,
                fontSize: 12,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton.icon(
              onPressed:
              _loadNotifications,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text(
                'Try Again',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF16834B,
                ),
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
  // BUILD
  // ===========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final filtered =
        _filteredNotifications;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F9F7),

      appBar: AppBar(
        automaticallyImplyLeading:
        false,
        backgroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                '/farmer/home',
              );
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color:
            Color(0xFF173B2B),
          ),
        ),

        title: const Text(
          'Notifications',
          style: TextStyle(
            color:
            Color(0xFF173B2B),
            fontSize: 18,
            fontWeight:
            FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            _loading
                ? null
                : _loadNotifications,
            icon: const Icon(
              Icons.refresh_rounded,
              color:
              Color(0xFF16834B),
            ),
          ),
          const SizedBox(
            width: 4,
          ),
        ],
      ),

      body: SafeArea(
        child: _loading
            ? const Center(
          child:
          CircularProgressIndicator(
            color:
            Color(0xFF16834B),
          ),
        )
            : _error != null
            ? _buildError()
            : _notifications.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
          color:
          const Color(
            0xFF16834B,
          ),
          onRefresh:
          _loadNotifications,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding:
            const EdgeInsets
                .fromLTRB(
              16,
              16,
              16,
              35,
            ),
            children: [
              _buildSummary(),

              const SizedBox(
                height: 14,
              ),

              _buildSearch(),

              const SizedBox(
                height: 13,
              ),

              _buildFilters(),

              const SizedBox(
                height: 17,
              ),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Updates',
                      style:
                      TextStyle(
                        color:
                        Color(
                          0xFF173B2B,
                        ),
                        fontSize: 16,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} shown',
                    style:
                    const TextStyle(
                      color:
                      Colors
                          .black45,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              if (filtered.isEmpty)
                _buildFilterEmpty()
              else
                ...filtered.map(
                  _notificationCard,
                ),
            ],
          ),
        ),
      ),
    );
  }
}