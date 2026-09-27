import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class WeighingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const WeighingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends ConsumerState<WeighingScreen> {
  final _formKey = GlobalKey<FormState>();
  double expected = 0;
  double actual = 0;
  String unit = 'kg';
  String reference = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final payload = {'expected': expected, 'actual': actual, 'unit': unit, 'reference': reference, 'source': 'MANUAL'};
    await ref.read(weighProvider({'queueId': widget.bookingId, 'payload': payload}).future);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weighing recorded (simulated)')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Weighing')), body: Padding(padding: const EdgeInsets.all(12.0), child: Form(key: _formKey, child: Column(children: [
      TextFormField(decoration: const InputDecoration(labelText: 'Expected quantity'), keyboardType: TextInputType.number, onSaved: (v) => expected = double.tryParse(v ?? '0') ?? 0),
      TextFormField(decoration: const InputDecoration(labelText: 'Actual quantity'), keyboardType: TextInputType.number, onSaved: (v) => actual = double.tryParse(v ?? '0') ?? 0),
      TextFormField(decoration: const InputDecoration(labelText: 'Unit'), initialValue: 'kg', onSaved: (v) => unit = v ?? 'kg'),
      TextFormField(decoration: const InputDecoration(labelText: 'Reference'), onSaved: (v) => reference = v ?? ''),
      const SizedBox(height:12),
      ElevatedButton(onPressed: _submit, child: const Text('Save Weighing'))
    ]))));
  }
}
