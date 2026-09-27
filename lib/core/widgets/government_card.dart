import 'package:flutter/material.dart';

class GovernmentCard extends StatelessWidget {
  final Widget child;
  const GovernmentCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(12.0), child: child),
    );
  }
}
