import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Centralize token expiry handling: clear token if expired.
  final expired = await AuthService.isTokenExpired();
  if (expired) {
    await AuthService.clearToken();
    return null;
  }
  final user = await AuthService.currentUser();
  return user;
});
