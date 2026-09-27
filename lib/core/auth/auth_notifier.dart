import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier._internal();

  static final AuthNotifier instance = AuthNotifier._internal();

  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  bool get isAuthenticated => _user != null;

  String get role => (_user?['role'] ?? 'farmer').toString().toLowerCase();

  void setUser(Map<String, dynamic>? u) {
    _user = u;
    notifyListeners();
  }

  Future<void> refreshFromService() async {
    final u = await AuthService.currentUser();
    _user = u;
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
