import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: const Text('SmartProcure')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          Text(loc.translate('welcome'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          const Text('Plan your procurement visit. Avoid unnecessary waiting.'),
          const Spacer(),
          PrimaryButton(label: loc.translate('get_started'), onPressed: () => context.go('/farmer/home')),
          const SizedBox(height: 12),
          TextButton(onPressed: () {}, child: Text(loc.translate('already_registered')))
        ]),
      ),
    );
  }
}
