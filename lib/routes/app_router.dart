import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_notifier.dart';

import '../features/auth/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';

import '../features/farmer/dashboard_screen.dart';

import '../features/centres/centres_list_screen.dart';
import '../features/centres/centre_detail_screen.dart';

import '../features/booking/booking_flow.dart';
import '../features/booking/booking_confirmation.dart';
import '../features/booking/my_bookings_screen.dart';

import '../features/queue/live_queue_screen.dart';

import '../features/notifications/notifications_screen.dart';

import '../features/qr/checkin_screen.dart';

import '../features/profile/profile_screen.dart';

import '../features/procurement/procurement_tracking_screen.dart';

import '../features/payment/payment_tracking_screen.dart';

import '../features/grievance/grievance_screen.dart';

import '../features/help/help_support_screen.dart';

import '../features/operator/operator_guard.dart';

import '../features/officer/officer_dashboard_screen.dart'
as officer_screen;

import '../features/admin/admin_dashboard_screen.dart'
as admin_screen;

import '../features/ai/ai_dashboard_screen.dart';

import '../features/operator/procurement_processing_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',

    refreshListenable: AuthNotifier.instance,

    redirect: (context, state) {
      final auth = AuthNotifier.instance;

      final loggedIn = auth.isAuthenticated;

      final currentPath = state.uri.path;

      final loggingIn = currentPath == '/login';

      final publicPaths = {
        '/',
        '/login',
        '/splash',
      };

      if (!loggedIn &&
          !loggingIn &&
          !publicPaths.contains(currentPath)) {
        return '/login';
      }

      if (loggedIn && loggingIn) {
        final role = AuthNotifier.instance.role;

        switch (role) {
          case 'operator':
            return '/operator';

          case 'officer':
            return '/officer';

          case 'admin':
            return '/admin';

          case 'farmer':
          default:
            return '/farmer/home';
        }
      }

      return null;
    },

    routes: [
      // ============================================================
      // SPLASH
      // ============================================================

      GoRoute(
        path: '/splash',
        builder: (context, state) {
          return const SplashScreen();
        },
      ),


      GoRoute(
        path: '/operator/procurement/:bookingId',
        builder: (context, state) {
          final bookingId = int.tryParse(
            state.pathParameters['bookingId'] ?? '',
          );

          if (bookingId == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Invalid booking ID',
                ),
              ),
            );
          }

          return ProcurementProcessingScreen(
            bookingId: bookingId,
          );
        },
      ),

      // ============================================================
      // ONBOARDING
      // ============================================================

      GoRoute(
        path: '/',
        builder: (context, state) {
          return const OnboardingScreen();
        },
      ),

      // ============================================================
      // LOGIN
      // ============================================================

      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const LoginScreen();
        },
      ),

      // ============================================================
      // FARMER DASHBOARD
      // ============================================================

      GoRoute(
        path: '/farmer/home',
        builder: (context, state) {
          return const FarmerDashboardScreen();
        },
      ),

      // ============================================================
      // PROFILE
      // ============================================================

      GoRoute(
        path: '/profile',
        builder: (context, state) {
          return const ProfileScreen();
        },
      ),

      // ============================================================
      // CENTRES
      // ============================================================

      GoRoute(
        path: '/centres',
        builder: (context, state) {
          return const CentresListScreen();
        },
      ),

      GoRoute(
        path: '/centres/:id',
        builder: (context, state) {
          final centreId =
              state.pathParameters['id'] ?? '';

          return CentreDetailScreen(
            centreId: centreId,
          );
        },
      ),

      // ============================================================
      // BOOKING
      // ============================================================

      GoRoute(
        path: '/booking',
        builder: (context, state) {
          return const BookingFlowScreen();
        },
      ),

      GoRoute(
        path: '/booking/confirmation',
        builder: (context, state) {
          final extra = state.extra;

          String bookingId = '';

          Map<String, dynamic>? booking;

          if (extra is Map) {
            bookingId =
                extra['bookingId']?.toString() ?? '';

            final rawBooking =
            extra['booking'];

            if (rawBooking is Map) {
              booking =
              Map<String, dynamic>.from(
                rawBooking,
              );
            }
          }

          return BookingConfirmationScreen(
            bookingId: bookingId,
            booking: booking,
          );
        },
      ),

      // ============================================================
      // MY BOOKINGS
      // ============================================================

      GoRoute(
        path: '/my-bookings',
        builder: (context, state) {
          return const MyBookingsScreen();
        },
      ),

      // ============================================================
      // LIVE QUEUE
      // ============================================================

      GoRoute(
        path: '/queue',
        builder: (context, state) {
          final extra = state.extra;

          String bookingId = '';

          if (extra is Map) {
            bookingId =
                extra['bookingId']?.toString() ?? '';
          }

          return LiveQueueScreen(
            bookingId: bookingId,
          );
        },
      ),

      // ============================================================
      // NOTIFICATIONS
      // ============================================================

      GoRoute(
        path: '/notifications',
        builder: (context, state) {
          return const NotificationsScreen();
        },
      ),

      // ============================================================
      // CHECK-IN / QR
      // ============================================================

      GoRoute(
        path: '/checkin',
        builder: (context, state) {
          final extra = state.extra;

          String bookingId = '';

          String centreId = '';

          if (extra is Map) {
            bookingId =
                extra['bookingId']?.toString() ?? '';

            centreId =
                extra['centreId']?.toString() ?? '';
          }

          return CheckInScreen(
            bookingId: bookingId,
            centreId: centreId,
          );
        },
      ),

      // ============================================================
      // PROCUREMENT
      // ============================================================

      GoRoute(
        path: '/procurement',
        builder: (context, state) {
          return const ProcurementTrackingScreen();
        },
      ),

      // ============================================================
      // PAYMENT
      // ============================================================

      GoRoute(
        path: '/payment',
        builder: (context, state) {
          return const PaymentTrackingScreen();
        },
      ),

      // ============================================================
      // GRIEVANCE
      // ============================================================

      GoRoute(
        path: '/grievance',
        builder: (context, state) {
          return const GrievanceScreen();
        },
      ),

      // ============================================================
      // HELP
      // ============================================================

      GoRoute(
        path: '/help',
        builder: (context, state) {
          return const HelpSupportScreen();
        },
      ),

      // ============================================================
      // OPERATOR
      // ============================================================

      GoRoute(
        path: '/operator',
        builder: (context, state) {
          final extra = state.extra;

          String centreId = 'C1';

          if (extra is Map) {
            centreId =
                extra['centreId']?.toString() ??
                    'C1';
          }

          return OperatorGuard(
            centreId: centreId,
          );
        },
      ),

      // ============================================================
      // OFFICER
      // ============================================================

      GoRoute(
        path: '/officer',
        builder: (context, state) {
          return const officer_screen.OfficerDashboardScreen();
        },
      ),

      // ============================================================
      // AI
      // ============================================================

      GoRoute(
        path: '/ai',
        builder: (context, state) {
          return const AiDashboardScreen();
        },
      ),

      // ============================================================
      // ADMIN
      // ============================================================

      GoRoute(
        path: '/admin',
        builder: (context, state) {
          return const admin_screen
              .AdminDashboardScreen();
        },
      ),
    ],

    // ============================================================
    // ERROR PAGE
    // ============================================================

    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor:
        const Color(0xFFF4FAF4),

        appBar: AppBar(
          title: const Text(
            'Page Not Found',
          ),
        ),

        body: Center(
          child: Padding(
            padding:
            const EdgeInsets.all(24),

            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons.error_outline,
                  size: 70,
                  color: Color(0xFFD32F2F),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Page not found',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    Color(0xFF12372A),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  state.uri.path,
                  textAlign:
                  TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    context.go(
                      '/farmer/home',
                    );
                  },

                  icon: const Icon(
                    Icons.home_outlined,
                  ),

                  label: const Text(
                    'Go to Home',
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