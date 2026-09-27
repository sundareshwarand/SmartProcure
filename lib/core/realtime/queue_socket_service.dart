import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class QueueSocketService {
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> connect({
    required int centreId,
  }) {
    _channel = WebSocketChannel.connect(
      Uri.parse(
        'ws://10.0.2.2:8000/api/v1/queue/ws?centre_id=$centreId',
      ),
    );

    return _channel!.stream.map((event) {
      if (event is String) {
        final decoded = jsonDecode(event);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      return <String, dynamic>{};
    });
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}