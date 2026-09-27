import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/farmer_api_service.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
  });

  @override
  State<QueueScreen> createState() =>
      _QueueScreenState();
}

class _QueueScreenState
    extends State<QueueScreen> {
  bool _loading = true;
  bool _connected = false;

  String? _error;

  List<dynamic> _queue = [];

  WebSocketChannel? _channel;

  Timer? _pingTimer;

  // Demo centre.
  // This matches your seeded Centre 1.
  final int _centreId = 1;

  @override
  void initState() {
    super.initState();

    _loadQueue();

    _connectWebSocket();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();

    _channel?.sink.close();

    super.dispose();
  }

  // -------------------------------------------------------
  // Initial REST load
  // -------------------------------------------------------

  Future<void> _loadQueue() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data =
      await farmerApiService.getQueue();

      if (!mounted) return;

      setState(() {
        _queue = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
        'Unable to load live queue.';
        _loading = false;
      });
    }
  }

  // -------------------------------------------------------
  // WebSocket connection
  // -------------------------------------------------------

  void _connectWebSocket() {
    try {
      _channel?.sink.close();

      final uri = Uri.parse(
        'ws://127.0.0.1:8000/api/v1/queue/ws'
            '?centre_id=$_centreId',
      );

      final channel =
      WebSocketChannel.connect(uri);

      _channel = channel;

      channel.stream.listen(
            (message) {
          _handleWebSocketMessage(
            message,
          );
        },
        onError: (_) {
          _handleWebSocketDisconnected();
        },
        onDone: () {
          _handleWebSocketDisconnected();
        },
        cancelOnError: false,
      );

      setState(() {
        _connected = true;
      });

      // Keep connection alive.
      _pingTimer?.cancel();

      _pingTimer = Timer.periodic(
        const Duration(seconds: 20),
            (_) {
          try {
            _channel?.sink.add(
              'ping',
            );
          } catch (_) {}
        },
      );
    } catch (_) {
      _handleWebSocketDisconnected();
    }
  }

  void _handleWebSocketMessage(
      dynamic message,
      ) {
    try {
      final decoded =
      jsonDecode(message.toString());

      if (decoded is! Map) {
        return;
      }

      final type =
      decoded['type']?.toString();

      if (type == 'queue_snapshot' ||
          type == 'queue_updated') {
        final queue =
        decoded['queue'];

        if (queue is List &&
            mounted) {
          setState(() {
            _queue =
            List<dynamic>.from(
              queue,
            );

            _error = null;
          });
        }
      }
    } catch (_) {
      // Ignore malformed messages.
    }
  }

  void _handleWebSocketDisconnected() {
    if (!mounted) return;

    setState(() {
      _connected = false;
    });

    _pingTimer?.cancel();

    // Automatically reconnect.
    Future.delayed(
      const Duration(seconds: 3),
          () {
        if (mounted &&
            !_connected) {
          _connectWebSocket();
        }
      },
    );
  }

  // -------------------------------------------------------
  // Status
  // -------------------------------------------------------

  Color _statusColor(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange;

      case 'called':
        return Colors.blue;

      case 'processing':
        return Colors.deepPurple;

      case 'completed':
        return Colors.green;

      case 'no show':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Icons.hourglass_top;

      case 'called':
        return Icons.campaign_outlined;

      case 'processing':
        return Icons.sync;

      case 'completed':
        return Icons.check_circle_outline;

      case 'no show':
        return Icons.person_off_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // -------------------------------------------------------
  // Statistics
  // -------------------------------------------------------

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 8,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                Colors.green.shade700,
                size: 25,
              ),
              const SizedBox(height: 7),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color:
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Queue Card
  // -------------------------------------------------------

  Widget _queueCard(
      Map<String, dynamic> item,
      ) {
    final token =
        item['token']
            ?.toString() ??
            'N/A';

    final position =
        item['position']
            ?.toString() ??
            '-';

    final status =
        item['status']
            ?.toString() ??
            'Waiting';

    final colour =
    _statusColor(status);

    return Card(
      elevation: 0,
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor:
          colour.withValues(
            alpha: 0.1,
          ),
          child: Text(
            position,
            style: TextStyle(
              color: colour,
              fontWeight:
              FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          token,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding:
          const EdgeInsets.only(
            top: 5,
          ),
          child: Text(
            'Queue position: $position',
          ),
        ),
        trailing: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration:
          BoxDecoration(
            color:
            colour.withValues(
              alpha: 0.1,
            ),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          child: Row(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                _statusIcon(status),
                size: 15,
                color: colour,
              ),
              const SizedBox(width: 5),
              Text(
                status,
                style: TextStyle(
                  color: colour,
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Live connection indicator
  // -------------------------------------------------------

  Widget _liveIndicator() {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _connected
            ? Colors.green.withValues(
          alpha: 0.08,
        )
            : Colors.orange.withValues(
          alpha: 0.08,
        ),
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration:
            BoxDecoration(
              color: _connected
                  ? Colors.green
                  : Colors.orange,
              shape:
              BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _connected
                  ? 'Live queue connected'
                  : 'Connecting to live queue...',
              style: const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Text(
            _connected
                ? 'LIVE'
                : 'OFFLINE',
            style: TextStyle(
              color: _connected
                  ? Colors.green
                  : Colors.orange,
              fontSize: 12,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Error
  // -------------------------------------------------------

  Widget _errorWidget() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 60,
              color:
              Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              _error ??
                  'Unable to load queue.',
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed:
              _loadQueue,
              icon:
              const Icon(
                Icons.refresh,
              ),
              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    int waitingCount = 0;
    int processingCount = 0;
    int completedCount = 0;

    for (final item in _queue) {
      if (item is! Map) continue;

      final status =
      item['status']
          ?.toString()
          .toLowerCase();

      if (status == 'waiting') {
        waitingCount++;
      }

      if (status == 'processing') {
        processingCount++;
      }

      if (status == 'completed') {
        completedCount++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Live Queue'),
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : _loadQueue,
            icon:
            const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : _error != null
          ? _errorWidget()
          : RefreshIndicator(
        onRefresh:
        _loadQueue,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.all(
            16,
          ),
          children: [
            _liveIndicator(),

            const SizedBox(
              height: 16,
            ),

            Row(
              children: [
                _statCard(
                  'Waiting',
                  '$waitingCount',
                  Icons.people_outline,
                ),
                const SizedBox(
                  width: 10,
                ),
                _statCard(
                  'Processing',
                  '$processingCount',
                  Icons.sync,
                ),
                const SizedBox(
                  width: 10,
                ),
                _statCard(
                  'Completed',
                  '$completedCount',
                  Icons.check_circle_outline,
                ),
              ],
            ),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Current Queue',
              style:
              TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            if (_queue.isEmpty)
              Padding(
                padding:
                const EdgeInsets
                    .all(
                  40,
                ),
                child:
                Column(
                  children: [
                    Icon(
                      Icons
                          .people_outline,
                      size: 60,
                      color: Colors
                          .grey
                          .shade400,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'Queue is currently empty',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w600,
                        fontSize:
                        16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._queue.map(
                    (item) {
                  final queueItem =
                  Map<String,
                      dynamic>.from(
                    item,
                  );

                  return _queueCard(
                    queueItem,
                  );
                },
              ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}