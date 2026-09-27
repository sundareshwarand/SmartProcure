import 'package:flutter/material.dart';

import 'operator_dashboard_screen.dart';

class OperatorGuard extends StatelessWidget {
  final String centreId;

  const OperatorGuard({
    super.key,
    required this.centreId,
  });

  int? get parsedCentreId {
    final value = centreId.trim();

    if (value.isEmpty) {
      return null;
    }

    return int.tryParse(value);
  }

  @override
  Widget build(BuildContext context) {
    return OperatorDashboardScreen(
      centreId: parsedCentreId,
    );
  }
}