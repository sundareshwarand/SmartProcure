import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/repository.dart';
import '../../models/operator_queue_item.dart';

final operatorRepositoryProvider = Provider<Repository>((ref) => Repository(mode: RepositoryMode.mock));

final operatorDashboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, centreId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.fetchOperatorDashboard(centreId);
});

final operatorQueueProvider = FutureProvider.family<List<OperatorQueueItem>, String>((ref, centreId) async {
  final repo = ref.read(operatorRepositoryProvider);
  final list = await repo.fetchOperatorQueue(centreId);
  return list.map((m) => OperatorQueueItem.fromMap(m)).toList();
});

final currentFarmerProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookingId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.fetchOperatorFarmer(bookingId);
});

final callNextProvider = FutureProvider.family<bool, String>((ref, queueId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorCallNext(queueId);
});

final startProcessingProvider = FutureProvider.family<bool, String>((ref, queueId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorStartProcessing(queueId);
});

final markNoShowProvider = FutureProvider.family<bool, String>((ref, queueId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorMarkNoShow(queueId);
});

final completeProvider = FutureProvider.family<bool, String>((ref, queueId) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorComplete(queueId);
});

final qualityCheckProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, args) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorPostQualityCheck(args['queueId']!, args['payload']!);
});

final weighProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, args) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.operatorPostWeigh(args['queueId']!, args['payload']!);
});

final sendNotificationProvider = FutureProvider.family<bool, Map<String, String>>((ref, args) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.sendNotificationToFarmer(args['farmerId']!, args['title']!, args['body']!);
});

final createPaymentProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, args) async {
  final repo = ref.read(operatorRepositoryProvider);
  return repo.createPaymentRecord(args['bookingId']!, args['amount']!);
});
