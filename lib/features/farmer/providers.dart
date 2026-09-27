import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/repository.dart';
import '../../core/models/farmer.dart';
import '../../core/models/centre.dart';
import '../../core/models/booking.dart';
import '../../models/queue_status_model.dart';
import '../../models/slot_model.dart';
import '../../models/wait_prediction_model.dart';
import '../../models/notification_model.dart';

final repositoryProvider = Provider<Repository>((ref) => Repository(mode: RepositoryMode.mock));

final farmerProfileProvider = FutureProvider<Farmer>((ref) async {
  final repo = ref.read(repositoryProvider);
  return repo.fetchFarmerProfile();
});

final centresProvider = FutureProvider<List<Centre>>((ref) async {
  final repo = ref.read(repositoryProvider);
  return repo.fetchCentres();
});

final bookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final repo = ref.read(repositoryProvider);
  return repo.fetchBookings();
});

final slotsProvider = FutureProvider.family<List<SlotModel>, Map<String, dynamic>>((ref, args) async {
  final repo = ref.read(repositoryProvider);
  final centreId = args['centreId'] as String;
  final date = args['date'] as DateTime;
  return repo.fetchSlotsForCentre(centreId, date);
});

final createBookingProvider = FutureProvider.family<Booking, Map<String, dynamic>>((ref, args) async {
  final repo = ref.read(repositoryProvider);
  return repo.createBooking(farmerId: args['farmerId'], centreId: args['centreId'], crop: args['crop'], quantity: args['quantity'], date: args['date'], slotId: args['slotId']);
});

final queueStatusProvider = StreamProvider.family<QueueStatusModel, String>((ref, bookingId) {
  final repo = ref.read(repositoryProvider);
  // simulate polling every 5 seconds
  return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) => repo.fetchQueueStatusForBooking(bookingId));
});

final waitPredictionProvider = FutureProvider.family<WaitPredictionModel, String>((ref, bookingId) async {
  final repo = ref.read(repositoryProvider);
  return repo.fetchWaitPrediction(bookingId);
});

final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final repo = ref.read(repositoryProvider);
  final list = await repo.fetchNotifications();
  return list.map((m) => NotificationModel.fromMap(m)).toList();
});

final checkInProvider = FutureProvider.family<bool, Map<String, String>>((ref, args) async {
  final repo = ref.read(repositoryProvider);
  return repo.checkIn(bookingId: args['bookingId']!, centreId: args['centreId']!);
});
