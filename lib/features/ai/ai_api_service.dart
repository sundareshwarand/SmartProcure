import '../../core/network/api_service.dart';

class AiApiService {
  final ApiService _api = ApiService.instance;

  Future<Map<String, dynamic>> health() async {
    final response = await _api.get(
      '/api/v1/ai/health',
    );

    return _map(response.data);
  }

  Future<Map<String, dynamic>> predictWaitTime({
    required int currentQueue,
    required double averageProcessingTime,
    required int activeOperators,
    required int expectedArrivals,
  }) async {
    final response = await _api.post(
      '/api/v1/ai/predict/wait-time',
      data: {
        'current_queue': currentQueue,
        'average_processing_time': averageProcessingTime,
        'active_operators': activeOperators,
        'expected_arrivals': expectedArrivals,
      },
    );

    return _map(response.data);
  }

  Future<Map<String, dynamic>> predictDemand({
    required int hour,
    required int currentQueue,
    required int activeOperators,
  }) async {
    final response = await _api.post(
      '/api/v1/ai/predict/demand',
      data: {
        'hour': hour,
        'current_queue': currentQueue,
        'active_operators': activeOperators,
      },
    );

    return _map(response.data);
  }

  Future<Map<String, dynamic>> predictDelay({
    required int currentQueue,
    required double averageProcessingTime,
    required int activeOperators,
    required int expectedArrivals,
  }) async {
    final response = await _api.post(
      '/api/v1/ai/predict/delay',
      data: {
        'current_queue': currentQueue,
        'average_processing_time': averageProcessingTime,
        'active_operators': activeOperators,
        'expected_arrivals': expectedArrivals,
      },
    );

    return _map(response.data);
  }

  Future<Map<String, dynamic>> recommendCentre({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _api.post(
      '/api/v1/ai/recommend-centre',
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    return _map(response.data);
  }

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }
}