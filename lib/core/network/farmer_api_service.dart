import 'package:dio/dio.dart';

import 'api_service.dart';

class FarmerApiService {
  FarmerApiService._();

  static final FarmerApiService instance = FarmerApiService._();

  final Dio _client = ApiService.instance.client;

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  List<dynamic> _listFromResponse(
      Response response,
      String key,
      ) {
    final data = response.data;

    if (data is List) {
      return data;
    }

    if (data is Map) {
      final value = data[key];

      if (value is List) {
        return value;
      }

      final nestedData = data['data'];

      if (nestedData is List) {
        return nestedData;
      }

      final items = data['items'];

      if (items is List) {
        return items;
      }
    }

    return [];
  }

  Map<String, dynamic> _mapFromResponse(
      Response response,
      ) {
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // BOOKINGS + AI SMART SLOT
  // ===========================================================================

  Future<Map<String, dynamic>> recommendSmartSlot({
    required DateTime bookingDate,
    required String crop,
    required double quantityKg,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.post(
      '/ai/recommend-slot',
      data: {
        'booking_date': _formatDate(bookingDate),
        'crop': crop,
        'quantity_kg': quantityKg,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    return _mapFromResponse(response);
  }

  Future<List<dynamic>> getBookings({
    int? farmerId,
    int? centreId,
  }) async {
    final response = await _client.get(
      '/bookings',
      queryParameters: {
        if (farmerId != null) 'farmer_id': farmerId,
        if (centreId != null) 'centre_id': centreId,
      },
    );

    return _listFromResponse(
      response,
      'bookings',
    );
  }

  Future<List<dynamic>> getAvailableSlots({
    required int centreId,
    required DateTime bookingDate,
  }) async {
    final response = await _client.get(
      '/slots',
      queryParameters: {
        'centre_id': centreId,
        'booking_date': _formatDate(bookingDate),
      },
    );

    return _listFromResponse(
      response,
      'slots',
    );
  }

  Future<Map<String, dynamic>> getBooking(
      int bookingId,
      ) async {
    final response = await _client.get(
      '/bookings/$bookingId',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> createBooking({
    required int farmerId,
    required int centreId,
    required String crop,
    required double quantityKg,
    required DateTime bookingDate,
    required String slotStart,
    required String slotEnd,
  }) async {
    final response = await _client.post(
      '/bookings',
      queryParameters: {
        'farmer_id': farmerId,
        'centre_id': centreId,
        'crop': crop,
        'quantity_kg': quantityKg,
        'booking_date': _formatDate(bookingDate),
        'slot_start': slotStart,
        'slot_end': slotEnd,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> cancelBooking(
      int bookingId,
      ) async {
    final response = await _client.patch(
      '/bookings/$bookingId/cancel',
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // QUEUE
  // ===========================================================================

  Future<List<dynamic>> getQueue({
    int? centreId,
    int? farmerId,
  }) async {
    final response = await _client.get(
      '/queue',
      queryParameters: {
        if (centreId != null) 'centre_id': centreId,
        if (farmerId != null) 'farmer_id': farmerId,
      },
    );

    return _listFromResponse(
      response,
      'queue',
    );
  }

  Future<Map<String, dynamic>> getQueueEntry(
      int queueId,
      ) async {
    final response = await _client.get(
      '/queue/$queueId',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> updateQueueStatus({
    required int queueId,
    required String status,
  }) async {
    final response = await _client.patch(
      '/queue/$queueId/status',
      queryParameters: {
        'status': status,
      },
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // PROCUREMENT
  // ===========================================================================

  Future<List<dynamic>> getProcurements({
    int? farmerId,
    int? centreId,
  }) async {
    final response = await _client.get(
      '/procurement',
      queryParameters: {
        if (farmerId != null) 'farmer_id': farmerId,
        if (centreId != null) 'centre_id': centreId,
      },
    );

    return _listFromResponse(
      response,
      'procurements',
    );
  }

  Future<Map<String, dynamic>> getProcurement(
      int procurementId,
      ) async {
    final response = await _client.get(
      '/procurement/$procurementId',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> updateProcurementStatus({
    required int procurementId,
    required String status,
  }) async {
    final response = await _client.patch(
      '/procurement/$procurementId/status',
      queryParameters: {
        'status': status,
      },
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // PAYMENTS
  // ===========================================================================

  Future<List<dynamic>> getPayments({
    int? farmerId,
    int? procurementId,
  }) async {
    final response = await _client.get(
      '/payments',
      queryParameters: {
        if (farmerId != null) 'farmer_id': farmerId,
        if (procurementId != null)
          'procurement_id': procurementId,
      },
    );

    return _listFromResponse(
      response,
      'payments',
    );
  }

  Future<Map<String, dynamic>> getPayment(
      int paymentId,
      ) async {
    final response = await _client.get(
      '/payments/$paymentId',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> updatePaymentStatus({
    required int paymentId,
    required String status,
  }) async {
    final response = await _client.patch(
      '/payments/$paymentId/status',
      queryParameters: {
        'status': status,
      },
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<List<dynamic>> getNotifications({
    int? farmerId,
  }) async {
    final response = await _client.get(
      '/notifications',
      queryParameters: {
        if (farmerId != null) 'farmer_id': farmerId,
      },
    );

    return _listFromResponse(
      response,
      'notifications',
    );
  }

  Future<Map<String, dynamic>> getNotification(
      int notificationId,
      ) async {
    final response = await _client.get(
      '/notifications/$notificationId',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> markNotificationRead(
      int notificationId,
      ) async {
    final response = await _client.patch(
      '/notifications/$notificationId/read',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final response = await _client.patch(
      '/notifications/read-all',
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // GRIEVANCES
  // ===========================================================================

  Future<List<dynamic>> getGrievances({
    int? farmerId,
  }) async {
    final response = await _client.get(
      '/grievances',
      queryParameters: {
        if (farmerId != null) 'farmer_id': farmerId,
      },
    );

    return _listFromResponse(
      response,
      'grievances',
    );
  }

  Future<Map<String, dynamic>> createGrievance({
    required int farmerId,
    required String category,
    required String description,
  }) async {
    final response = await _client.post(
      '/grievances',
      queryParameters: {
        'farmer_id': farmerId,
        'category': category,
        'description': description,
      },
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // CENTRES
  // ===========================================================================

  Future<List<dynamic>> getCentres() async {
    final response = await _client.get(
      '/centres',
    );

    return _listFromResponse(
      response,
      'centres',
    );
  }

  Future<Map<String, dynamic>> getCentre(
      int centreId,
      ) async {
    final response = await _client.get(
      '/centres/$centreId',
    );

    final data = _mapFromResponse(response);

    final centre = data['centre'];

    if (centre is Map) {
      return Map<String, dynamic>.from(centre);
    }

    return data;
  }

  Future<Map<String, dynamic>> processPayment(
      int paymentId,
      ) async {
    final response = await _client.post(
      '/payments/$paymentId/process',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> completePayment(
      int paymentId, {
        String? transactionReference,
      }) async {
    final response = await _client.post(
      '/payments/$paymentId/complete',
      queryParameters: {
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transaction_reference':
          transactionReference.trim(),
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> failPayment(
      int paymentId, {
        String reason = 'Bank transaction failed',
      }) async {
    final response = await _client.post(
      '/payments/$paymentId/fail',
      queryParameters: {
        'reason': reason,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> retryPayment(
      int paymentId,
      ) async {
    final response = await _client.post(
      '/payments/$paymentId/retry',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> cancelPayment(
      int paymentId,
      ) async {
    final response = await _client.post(
      '/payments/$paymentId/cancel',
    );

    return _mapFromResponse(response);
  }
  Future<Map<String, dynamic>> getProcurementByBooking(
      int bookingId,
      ) async {
    final response = await _client.get(
      '/procurement/booking/$bookingId',
    );

    final data = _mapFromResponse(response);

    final procurement = data['procurement'];

    if (procurement is Map) {
      return Map<String, dynamic>.from(
        procurement,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> qualityCheck(
      int procurementId, {
        required String qualityGrade,
        required double moisturePercentage,
        required double foreignMatterPercentage,
        required double damagedPercentage,
        String qualityRemarks = '',
      }) async {
    final response = await _client.post(
      '/procurement/$procurementId/quality-check',
      queryParameters: {
        'quality_grade': qualityGrade,
        'moisture_percentage':
        moisturePercentage,
        'foreign_matter_percentage':
        foreignMatterPercentage,
        'damaged_percentage':
        damagedPercentage,
        'quality_remarks':
        qualityRemarks,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> completeWeighing(
      int procurementId, {
        required double actualWeightKg,
      }) async {
    final response = await _client.post(
      '/procurement/$procurementId/weigh',
      queryParameters: {
        'actual_weight_kg':
        actualWeightKg,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> calculateProcurementAmount(
      int procurementId, {
        double deductions = 0,
      }) async {
    final response = await _client.post(
      '/procurement/$procurementId/calculate-amount',
      queryParameters: {
        'deductions':
        deductions,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> completeProcurement(
      int procurementId,
      ) async {
    final response = await _client.post(
      '/procurement/$procurementId/complete',
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> triggerProcurementPayment(
      int procurementId,
      ) async {
    final response = await _client.post(
      '/procurement/$procurementId/trigger-payment',
    );

    return _mapFromResponse(response);
  }

  

  Future<Map<String, dynamic>> getProcurementReceipt(
      int procurementId,
      ) async {
    final response = await _client.get(
      '/procurement/$procurementId/receipt',
    );

    return _mapFromResponse(response);
  }
  // ===========================================================================
  // OPERATOR
  // ===========================================================================

  Future<Map<String, dynamic>> getOperatorOverview({
    required int centreId,
  }) async {
    final response = await _client.get(
      '/operator/overview',
      queryParameters: {
        'centre_id': centreId,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> getOperatorCentre({
    required int centreId,
  }) async {
    final response = await _client.get(
      '/operator/centre',
      queryParameters: {
        'centre_id': centreId,
      },
    );

    return _mapFromResponse(response);
  }

  // ===========================================================================
  // OFFICER
  // ===========================================================================

  Future<Map<String, dynamic>> getOfficerOverview() async {
    final response = await _client.get(
      '/officer/overview',
    );

    final data = _mapFromResponse(response);

    final overview = data['overview'];

    if (overview is Map) {
      return Map<String, dynamic>.from(
        overview,
      );
    }

    return data;
  }

  Future<List<dynamic>> getOfficerCentres() async {
    final response = await _client.get(
      '/officer/centres',
    );

    return _listFromResponse(
      response,
      'centres',
    );
  }

  // ===========================================================================
  // ADMIN
  // ===========================================================================

  Future<Map<String, dynamic>> getAdminOverview() async {
    final response = await _client.get(
      '/admin/overview',
    );

    final data = _mapFromResponse(response);

    final overview = data['overview'];

    if (overview is Map) {
      return Map<String, dynamic>.from(
        overview,
      );
    }

    return data;
  }

  Future<List<dynamic>> getAdminUsers() async {
    final response = await _client.get(
      '/admin/users',
    );

    return _listFromResponse(
      response,
      'users',
    );
  }

  Future<List<dynamic>> getAdminCentres() async {
    final response = await _client.get(
      '/admin/centres',
    );

    return _listFromResponse(
      response,
      'centres',
    );
  }

  Future<List<dynamic>> getAdminAuditLogs() async {
    final response = await _client.get(
      '/admin/audit',
    );

    return _listFromResponse(
      response,
      'audit',
    );
  }

  // ===========================================================================
  // AUDIT
  // ===========================================================================

  Future<List<dynamic>> getAuditLogs({
    int? actorId,
    int? centreId,
  }) async {
    final response = await _client.get(
      '/audit',
      queryParameters: {
        if (actorId != null) 'actor_id': actorId,
        if (centreId != null) 'centre_id': centreId,
      },
    );

    return _listFromResponse(
      response,
      'audit',
    );
  }

  // ===========================================================================
  // AI
  // ===========================================================================

  Future<Map<String, dynamic>> predictWaitTime({
    required int currentQueue,
    required double averageProcessingTime,
    required int activeOperators,
    int expectedArrivals = 0,
  }) async {
    final response = await _client.post(
      '/ai/predict/wait-time',
      data: {
        'current_queue': currentQueue,
        'average_processing_time':
        averageProcessingTime,
        'active_operators': activeOperators,
        'expected_arrivals': expectedArrivals,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> predictDemand({
    required int hour,
    required int currentQueue,
    required int activeOperators,
  }) async {
    final response = await _client.post(
      '/ai/predict/demand',
      data: {
        'hour': hour,
        'current_queue': currentQueue,
        'active_operators': activeOperators,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> predictDelay({
    required int currentQueue,
    required double averageProcessingTime,
    required int activeOperators,
    int expectedArrivals = 0,
  }) async {
    final response = await _client.post(
      '/ai/predict/delay',
      data: {
        'current_queue': currentQueue,
        'average_processing_time':
        averageProcessingTime,
        'active_operators': activeOperators,
        'expected_arrivals': expectedArrivals,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> recommendCentre({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.post(
      '/ai/recommend-centre',
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return _mapFromResponse(response);
  }

  Future<Map<String, dynamic>> getAiHealth() async {
    final response = await _client.get(
      '/ai/health',
    );

    return _mapFromResponse(response);
  }
}

// ===========================================================================
// SINGLETON
// ===========================================================================

final farmerApiService = FarmerApiService.instance;