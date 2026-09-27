import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/farmer/providers.dart';
import '../../core/widgets/government_card.dart';

class LiveQueueScreen extends ConsumerWidget {
  final String bookingId;

  const LiveQueueScreen({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(queueStatusProvider(bookingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,

        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF12372A),
            size: 21,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/farmer/home');
            }
          },
        ),

        title: const Text(
          'Live Queue',
          style: TextStyle(
            color: Color(0xFF12372A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: stream.when(
            data: (status) {
              return RefreshIndicator(
                color: const Color(0xFF2E7D32),
                onRefresh: () async {
                  ref.invalidate(
                    queueStatusProvider(bookingId),
                  );

                  await Future<void>.delayed(
                    const Duration(milliseconds: 500),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // --------------------------------------------------
                    // Header
                    // --------------------------------------------------
                    const Text(
                      'Your Queue Status',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF12372A),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Track your position and estimated waiting time.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --------------------------------------------------
                    // Your Token Card
                    // --------------------------------------------------
                    GovernmentCard(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 16,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'YOUR TOKEN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Color(0xFF557064),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFB7DDB9),
                                ),
                              ),
                              child: Text(
                                status.bookingToken,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B5E20),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --------------------------------------------------
                    // Now Serving
                    // --------------------------------------------------
                    GovernmentCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 22,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'Now Serving',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF12372A),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Center(
                              child: Text(
                                status.nowServing,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Divider(height: 1),

                            const SizedBox(height: 14),

                            // --------------------------------------------------
                            // Queue Statistics
                            // --------------------------------------------------
                            Row(
                              children: [
                                Expanded(
                                  child: _QueueStatCard(
                                    icon: Icons.people_alt_rounded,
                                    title: 'Farmers Ahead',
                                    value: '${status.farmersAhead}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QueueStatCard(
                                    icon: Icons.schedule_rounded,
                                    title: 'Estimated Wait',
                                    value:
                                    '${status.estimatedWaitMinutes} min',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _QueueInfoRow(
                                    icon: Icons.countertops_rounded,
                                    title: 'Counter',
                                    value:
                                    '${status.currentCounter}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QueueInfoRow(
                                    icon: Icons.info_outline_rounded,
                                    title: 'Status',
                                    value: status.status,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --------------------------------------------------
                    // Status Message
                    // --------------------------------------------------
                    _buildStatusBanner(status.status),

                    const SizedBox(height: 20),

                    // --------------------------------------------------
                    // Refresh Button
                    // --------------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(
                            queueStatusProvider(bookingId),
                          );
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Refresh Queue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --------------------------------------------------
                    // Pull to refresh hint
                    // --------------------------------------------------
                    const Center(
                      child: Text(
                        'Pull down to refresh the latest queue status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },

            // ----------------------------------------------------------
            // Loading
            // ----------------------------------------------------------
            loading: () {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your queue...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF12372A),
                      ),
                    ),
                  ],
                ),
              );
            },

            // ----------------------------------------------------------
            // Error
            // ----------------------------------------------------------
            error: (error, stackTrace) {
              return Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 46,
                            color: Color(0xFFD32F2F),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Unable to load queue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF12372A),
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Please check your internet connection '
                              'and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(
                                queueStatusProvider(bookingId),
                              );
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                            ),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Queue status banner
  // --------------------------------------------------------------------
  Widget _buildStatusBanner(String status) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;
    IconData icon;
    String message;

    if (normalized.contains('serving') ||
        normalized.contains('processing')) {
      background = const Color(0xFFE8F5E9);
      foreground = const Color(0xFF1B5E20);
      icon = Icons.play_circle_fill_rounded;
      message = 'Your procurement process is currently active.';
    } else if (normalized.contains('approach')) {
      background = const Color(0xFFFFF8E1);
      foreground = const Color(0xFFF57F17);
      icon = Icons.notifications_active_rounded;
      message = 'Your turn is approaching. Please stay ready.';
    } else if (normalized.contains('complete')) {
      background = const Color(0xFFE8F5E9);
      foreground = const Color(0xFF1B5E20);
      icon = Icons.check_circle_rounded;
      message = 'Your queue process has been completed.';
    } else {
      background = const Color(0xFFE3F2FD);
      foreground = const Color(0xFF1565C0);
      icon = Icons.access_time_rounded;
      message = 'Please wait for your turn.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: foreground.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: foreground,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: foreground.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Queue Stat Card
// ======================================================================

class _QueueStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _QueueStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E8E2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF2E7D32),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12372A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Queue Info Row
// ======================================================================

class _QueueInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _QueueInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E8E2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF557064),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12372A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}