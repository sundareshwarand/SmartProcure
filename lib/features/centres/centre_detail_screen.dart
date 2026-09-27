import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/government_card.dart';
import '../farmer/providers.dart';
// slot model import removed (not required here)

class CentreDetailScreen extends ConsumerStatefulWidget {
  final String centreId;
  const CentreDetailScreen({super.key, required this.centreId});

  @override
  ConsumerState<CentreDetailScreen> createState() => _CentreDetailScreenState();
}

class _CentreDetailScreenState extends ConsumerState<CentreDetailScreen> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(slotsProvider({'centreId': widget.centreId, 'date': selectedDate}));

    Widget slotWidget;
    if (slotsAsync.isLoading) {
      slotWidget = const Center(child: CircularProgressIndicator());
    } else if (slotsAsync.hasError) {
      slotWidget = const Center(child: Text('Unable to load slots'));
    } else {
      final slots = slotsAsync.value!;
      slotWidget = ListView.builder(itemCount: slots.length, itemBuilder: (context, i) => ListTile(title: Text('${slots[i].start.hour}:00 - ${slots[i].end.hour}:00'), subtitle: Text('Slots available: ${slots[i].capacity}'), trailing: ElevatedButton(onPressed: slots[i].capacity > 0 ? () { Navigator.of(context).pushNamed('/booking', arguments: {'centreId': widget.centreId, 'date': selectedDate}); } : null, child: const Text('Book'))));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Centre Details')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          GovernmentCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Central Procurement Centre', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Capacity: 200 today • Active Counters: 2 • Accepts: Paddy, Wheat')
          ])),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Select Date:'),
            const SizedBox(width: 12),
            TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30))); if (d!=null) setState(()=>selectedDate=d); }, child: Text('${selectedDate.toLocal()}'.split(' ')[0]))
          ]),
          const SizedBox(height: 8),
          Expanded(child: slotWidget),
        ]),
      ),
    );
  }
}
