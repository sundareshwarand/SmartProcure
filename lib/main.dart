import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_notifier.dart';
import 'core/network/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup session restoration: if a token exists in secure storage, set header and refresh auth state
  try {
    final token = await AuthService.getToken();
    if (token != null) {
      ApiService.instance.client.options.headers['Authorization'] = 'Bearer $token';
      await AuthNotifier.instance.refreshFromService();
      if (!AuthNotifier.instance.isAuthenticated) {
        await AuthService.clearToken();
      }
    }
  } catch (_) {}

  runApp(const ProviderScope(child: SmartProcureApp()));
}
