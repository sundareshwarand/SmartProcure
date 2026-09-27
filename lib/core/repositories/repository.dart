import '../../core/repositories/mock_repository.dart';
import '../../core/network/api_service.dart';
import '../../core/models/farmer.dart';
import '../../core/models/centre.dart';
import '../../core/models/booking.dart';
import '../../models/slot_model.dart';
import '../../models/queue_status_model.dart';
import '../../models/wait_prediction_model.dart';
// notification model not used in this file
import '../auth/auth_service.dart';
import '../network/http_exceptions.dart';

enum RepositoryMode { mock, api }

class Repository {
  final RepositoryMode mode;
  final MockRepository _mock = MockRepository();
  final ApiService _api = ApiService.instance;
  // testing-only in-memory audit log store for mock mode
  final List<Map<String, dynamic>> _mockAuditLogs = [];
  final Set<String> _processingQueueIds = {};
  final Set<String> _completedQueueIds = {};

  Repository({this.mode = RepositoryMode.mock});

  Future<Farmer> fetchFarmerProfile() async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/farmer/profile');
      final data = r.data;
      return Farmer(id: data['id'], name: data['name'], village: data['village'], district: data['district'], mobile: data['mobile'], preferredLanguage: data['preferredLanguage']);
    }
    return _mock.fetchFarmerProfile();
  }

  Future<List<Centre>> fetchCentres() async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/centres');
      final list = (r.data as List<dynamic>);
      return list.map((e) => Centre(id: e['id'], name: e['name'], distanceKm: (e['distanceKm'] as num).toDouble(), currentQueue: e['currentQueue'], capacityToday: e['capacityToday'])).toList();
    }
    return _mock.fetchCentres();
  }

  Future<List<Booking>> fetchBookings() async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/bookings');
      final list = (r.data as List<dynamic>);
      return list.map((e) => Booking(id: e['id'], token: e['token'], centreName: e['centreName'], date: DateTime.parse(e['date']), slot: e['slot'])).toList();
    }
    return _mock.fetchBookings();
  }

  // Slot and booking operations are mocked for now
  Future<List<SlotModel>> fetchSlotsForCentre(String centreId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.generate(6, (i) => SlotModel(id: 'S$i', start: DateTime(date.year, date.month, date.day, 8 + i), end: DateTime(date.year, date.month, date.day, 9 + i), capacity: 10 - i));
  }

  Future<Booking> createBooking({required String farmerId, required String centreId, required String crop, required double quantity, required DateTime date, required String slotId}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final booking = Booking(id: 'B-${DateTime.now().millisecondsSinceEpoch}', token: 'SP-${1000 + DateTime.now().millisecondsSinceEpoch % 9000}', centreName: 'Centre $centreId', date: date, slot: '${date.hour}:00 - ${date.hour+1}:00');
    return booking;
  }

  Future<QueueStatusModel> fetchQueueStatusForBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return QueueStatusModel(bookingToken: 'SP-1047', nowServing: 'SP-1036', farmersAhead: 11, estimatedWaitMinutes: 42, currentCounter: 2, status: 'Your turn approaching');
  }

  Future<WaitPredictionModel> fetchWaitPrediction(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return WaitPredictionModel(estimatedMinutes: 42, confidence: 'High', factors: {
      'farmersAhead': 11,
      'activeCounters': 2,
      'avgProcessingPerFarmerMin': 4,
      'centreLoad': 'Moderate'
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      {'id': 'N1', 'title': 'Booking confirmed', 'body': 'Your slot tomorrow at 10:00 AM', 'category': 'booking', 'read': false, 'timestamp': DateTime.now().toIso8601String()},
      {'id': 'N2', 'title': 'Farmers ahead update', 'body': 'Only 6 farmers are ahead of you', 'category': 'queue', 'read': false, 'timestamp': DateTime.now().toIso8601String()},
    ];
  }

  Future<bool> checkIn({required String bookingId, required String centreId}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock success
    return true;
  }

  // Operator APIs (mocked when mode==mock)
  Future<Map<String, dynamic>> fetchOperatorDashboard(String centreId) async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/operator/dashboard?centreId=$centreId');
      if (r.statusCode == 401) throw UnauthorizedException();
      if (r.statusCode == 403) throw ForbiddenException();
      return r.data as Map<String, dynamic>;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'centreName': 'Centre $centreId',
      'date': DateTime.now().toIso8601String(),
      'totalBookings': 142,
      'checkedIn': 20,
      'waiting': 18,
      'processing': 3,
      'completed': 95,
      'noShow': 6,
      'availableCapacity': 50,
      'activeCounters': 4,
    };
  }

  Future<List<Map<String, dynamic>>> fetchOperatorQueue(String centreId) async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/operator/queue?centreId=$centreId');
      if (r.statusCode == 401) throw UnauthorizedException();
      if (r.statusCode == 403) throw ForbiddenException();
      return (r.data as List<dynamic>).cast<Map<String, dynamic>>();
    }
    await Future.delayed(const Duration(milliseconds: 250));
    return List.generate(8, (i) => {
      'queueId': 'Q${100 + i}',
      'token': 'SP-${1030 + i}',
      'farmerName': 'Farmer ${i+1}',
      'crop': 'Wheat',
      'expectedQty': 100.0 + i * 5,
      'bookingTime': DateTime.now().subtract(Duration(minutes: i * 4)).toIso8601String(),
      'checkInStatus': i < 3 ? 'CHECKED_IN' : (i==3? 'ARRIVED': 'WAITING'),
      'waitingMinutes': i * 5,
      'counter': i < 2 ? 1 : null,
      'bookingId': 'B-${1000 + i}'
    });
  }

  Future<Map<String, dynamic>> fetchOperatorFarmer(String bookingId) async {
    if (mode == RepositoryMode.api) {
      final r = await _api.get('/api/v1/operator/farmers?bookingId=$bookingId');
      if (r.statusCode == 401) throw UnauthorizedException();
      if (r.statusCode == 403) throw ForbiddenException();
      return r.data as Map<String, dynamic>;
    }
    await Future.delayed(const Duration(milliseconds: 250));
    return {
      'bookingId': bookingId,
      'farmerName': 'Ram Kumar',
      'token': 'SP-1042',
      'crop': 'Rice',
      'expectedQty': 120.0,
      'vehicle': 'Truck-1234',
      'slot': '10:00 - 11:00',
      'queuePosition': 3,
      'checkInStatus': 'CHECKED_IN'
    };
  }

  Future<bool> operatorCallNext(String queueId) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/call');
        if (r.statusCode == 401) throw UnauthorizedException();
        if (r.statusCode == 403) throw ForbiddenException();
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'CALL_FARMER', targetId: queueId, success: ok, metadata: {'response': r.data});
        return ok;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'CALL_FARMER', targetId: queueId, success: true, metadata: null);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'CALL_FARMER', targetId: queueId, success: false, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  Future<bool> operatorStartProcessing(String queueId) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/start');
        if (r.statusCode == 401) throw UnauthorizedException();
        if (r.statusCode == 403) throw ForbiddenException();
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'START_PROCESSING', targetId: queueId, success: ok, metadata: {'response': r.data});
        return ok;
      }
      // mock mode: prevent starting if already completed
      if (_completedQueueIds.contains(queueId)) {
        await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'START_PROCESSING', targetId: queueId, success: false, metadata: {'reason': 'already_completed'});
        return false;
      }
      // mark processing and record audit
      if (_processingQueueIds.contains(queueId)) {
        await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'START_PROCESSING', targetId: queueId, success: false, metadata: {'reason': 'already_processing'});
        return false;
      }
      _processingQueueIds.add(queueId);
      await Future.delayed(const Duration(milliseconds: 200));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'START_PROCESSING', targetId: queueId, success: true, metadata: null);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'START_PROCESSING', targetId: queueId, success: false, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  Future<bool> operatorMarkNoShow(String queueId) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/no-show');
        if (r.statusCode == 401) throw UnauthorizedException();
        if (r.statusCode == 403) throw ForbiddenException();
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'MARK_NO_SHOW', targetId: queueId, success: ok, metadata: {'response': r.data});
        return ok;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'MARK_NO_SHOW', targetId: queueId, success: true, metadata: null);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'MARK_NO_SHOW', targetId: queueId, success: false, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  Future<bool> operatorComplete(String queueId) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/complete');
        if (r.statusCode == 401) throw UnauthorizedException();
        if (r.statusCode == 403) throw ForbiddenException();
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'COMPLETE_PROCUREMENT', targetId: queueId, success: ok, metadata: {'response': r.data});
        return ok;
      }
      // mock mode: prevent duplicate completion
      if (_completedQueueIds.contains(queueId)) {
        await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'COMPLETE_PROCUREMENT', targetId: queueId, success: false, metadata: {'reason': 'already_completed'});
        return false;
      }
      _completedQueueIds.add(queueId);
      // clear processing if present
      _processingQueueIds.remove(queueId);
      await Future.delayed(const Duration(milliseconds: 400));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'COMPLETE_PROCUREMENT', targetId: queueId, success: true, metadata: null);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'COMPLETE_PROCUREMENT', targetId: queueId, success: false, metadata: {'error': e.toString()});
      rethrow;
    }
  }

  Future<bool> operatorPostQualityCheck(String queueId, Map<String, dynamic> payload) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/quality-check', data: payload);
        if (r.statusCode == 401) throw UnauthorizedException();
        if (r.statusCode == 403) throw ForbiddenException();
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'QUALITY_CHECK', targetId: queueId, success: ok, metadata: payload);
        return ok;
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'QUALITY_CHECK', targetId: queueId, success: true, metadata: payload);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'QUALITY_CHECK', targetId: queueId, success: false, metadata: {'error': e.toString(), 'payload': payload});
      rethrow;
    }
  }

  Future<bool> operatorPostWeigh(String queueId, Map<String, dynamic> payload) async {
    try {
      if (mode == RepositoryMode.api) {
        final r = await _api.post('/api/v1/operator/queue/$queueId/weigh', data: payload);
        final ok = r.statusCode == 200;
        await createAuditLog(actorId: 'unknown', actorRole: 'operator', centreId: 'unknown', action: 'WEIGHING', targetId: queueId, success: ok, metadata: payload);
        return ok;
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'WEIGHING', targetId: queueId, success: true, metadata: payload);
      return true;
    } catch (e) {
      await createAuditLog(actorId: 'mock-operator', actorRole: 'operator', centreId: 'C1', action: 'WEIGHING', targetId: queueId, success: false, metadata: {'error': e.toString(), 'payload': payload});
      rethrow;
    }
  }

  Future<void> createAuditLog({required String actorId, required String actorRole, required String centreId, required String action, required String targetId, required bool success, Map<String, dynamic>? metadata}) async {
    var actualActorId = actorId;
    var actualActorRole = actorRole;
    var actualCentreId = centreId;
    try {
      if (actorId == 'unknown') {
        final cu = await AuthService.currentUser();
        if (cu != null) {
          actualActorId = cu['sub'] ?? actualActorId;
          actualActorRole = cu['role'] ?? actualActorRole;
          if ((cu['centre_ids'] as List?)?.isNotEmpty ?? false) {
            actualCentreId = (cu['centre_ids'] as List).first as String;
          }
        }
      }
    } catch (_) {}

    final log = {
      'actorId': actualActorId,
      'actorRole': actualActorRole,
      'centreId': actualCentreId,
      'action': action,
      'targetId': targetId,
      'timestamp': DateTime.now().toIso8601String(),
      'success': success,
      'metadata': metadata ?? {}
    };
    if (mode == RepositoryMode.api) {
      try {
        await _api.post('/api/v1/audit', data: log);
      } catch (_) {
        // Do not fail operator action if audit endpoint fails, but log locally in future.
      }
    } else {
      // For mock mode we persist logs in-memory for test verification and print.
      _mockAuditLogs.add(log);
      // ignore: avoid_print
      print('AUDIT_LOG: $log');
    }
  }

  /// Testing helper: returns a copy of mock audit logs (only in mock mode)
  List<Map<String, dynamic>> getMockAuditLogs() => List.unmodifiable(_mockAuditLogs);

  Future<bool> sendNotificationToFarmer(String farmerId, String title, String body) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  Future<Map<String, dynamic>> createPaymentRecord(String bookingId, double amount) async {
    if (mode == RepositoryMode.api) {
      final r = await _api.post('/api/v1/payments', data: {'bookingId': bookingId, 'amount': amount});
      return r.data as Map<String, dynamic>;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    return {'paymentId': 'P-${DateTime.now().millisecondsSinceEpoch}', 'status': 'PENDING', 'amount': amount};
  }
}
