import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// wait prediction model import removed (not required here)
import '../farmer/providers.dart';

class WaitPredictionCard extends ConsumerWidget {
  final String bookingId;
  const WaitPredictionCard({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predAsync = ref.watch(waitPredictionProvider(bookingId));
    return predAsync.when(
      data: (p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Smart Wait Prediction', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Estimated wait: ${p.estimatedMinutes} minutes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Confidence: ${p.confidence}'),
            const SizedBox(height: 8),
            Wrap(children: p.factors.entries.map((e) => Padding(padding: const EdgeInsets.only(right:8.0), child: Chip(label: Text('${e.key}: ${e.value}')))).toList()),
            TextButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(12.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Why this estimate?', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height:8), Text('This estimate uses current queue length, active counters and average processing time to predict wait.')]))) , child: const Text('Why this estimate?'))
          ]),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}
