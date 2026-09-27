import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farmer/providers.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String centreId;
  const CheckInScreen({super.key, required this.bookingId, required this.centreId});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _doCheckIn() async {
    setState(() { _loading = true; _message = null; });
    final ok = await ref.read(checkInProvider({'bookingId': widget.bookingId, 'centreId': widget.centreId}).future);
    if (!mounted) return;
    setState(() { _loading = false; _message = ok ? 'Arrival Confirmed' : 'Check-in failed'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Check-in')),
      body: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
        const SizedBox(height: 12),
        const Center(child: SizedBox(width:150,height:150, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey)))),
        const SizedBox(height: 12),
        Text('Booking: ${widget.bookingId}'),
        Text('Centre: ${widget.centreId}'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loading ? null : _doCheckIn, child: _loading ? const CircularProgressIndicator() : const Text('Confirm Arrival')),
        if (_message!=null) Padding(padding: const EdgeInsets.only(top:12.0), child: Text(_message!)),
      ])),
    );
  }
}
