import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_service.dart';
import 'auth_notifier.dart';

import '../platform_storage_stub.dart'
if (dart.library.html) '../platform_storage_web.dart';

class AuthService {
  // ================================================================
  // STORAGE
  // ================================================================

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';

  static final Map<String, String> _inMemory = {};

  // ================================================================
  // SAVE TOKEN
  // ================================================================

  static Future<void> setToken(
      String token,
      ) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    // --------------------------------------------------------------
    // Secure storage
    // --------------------------------------------------------------

    try {
      await _storage.write(
        key: _tokenKey,
        value: cleanToken,
      );
    } catch (_) {
      _inMemory[_tokenKey] = cleanToken;
    }

    // --------------------------------------------------------------
    // Memory fallback
    // --------------------------------------------------------------

    _inMemory[_tokenKey] = cleanToken;

    // --------------------------------------------------------------
    // Attach token immediately
    // --------------------------------------------------------------

    ApiService.instance.client.options.headers[
    'Authorization'] = 'Bearer $cleanToken';

    // --------------------------------------------------------------
    // Refresh current authenticated user
    // --------------------------------------------------------------

    try {
      await AuthNotifier.instance.refreshFromService();
    } catch (_) {
      // ------------------------------------------------------------
      // Backend unavailable:
      // restore basic identity from JWT
      // ------------------------------------------------------------

      final payload = _decodePayload(cleanToken);

      if (payload != null) {
        AuthNotifier.instance.setUser(
          payload,
        );
      }
    }
  }

  // ================================================================
  // GET TOKEN
  // ================================================================

  static Future<String?> getToken() async {
    // --------------------------------------------------------------
    // 1. Secure storage
    // --------------------------------------------------------------

    try {
      final value = await _storage.read(
        key: _tokenKey,
      );

      if (value != null && value.isNotEmpty) {
        _inMemory[_tokenKey] = value;
        return value;
      }
    } catch (_) {}

    // --------------------------------------------------------------
    // 2. Web storage
    // --------------------------------------------------------------

    try {
      final webToken = readWebAuthToken();

      if (webToken != null && webToken.isNotEmpty) {
        _inMemory[_tokenKey] = webToken;
        return webToken;
      }
    } catch (_) {}

    // --------------------------------------------------------------
    // 3. In-memory fallback
    // --------------------------------------------------------------

    final memoryToken = _inMemory[_tokenKey];

    if (memoryToken != null && memoryToken.isNotEmpty) {
      return memoryToken;
    }

    return null;
  }

  // ================================================================
  // CLEAR TOKEN / LOGOUT
  // ================================================================

  static Future<void> clearToken() async {
    try {
      await _storage.delete(
        key: _tokenKey,
      );
    } catch (_) {}

    _inMemory.remove(_tokenKey);

    // --------------------------------------------------------------
    // Remove Authorization header
    // --------------------------------------------------------------

    ApiService.instance.client.options.headers
        .remove('Authorization');

    // --------------------------------------------------------------
    // Clear authentication state
    // --------------------------------------------------------------

    try {
      AuthNotifier.instance.clear();
    } catch (_) {}
  }

  // ================================================================
  // DECODE JWT PAYLOAD
  // ================================================================

  static Map<String, dynamic>? _decodePayload(
      String token,
      ) {
    try {
      final parts = token.split('.');

      if (parts.length != 3) {
        return null;
      }

      final normalizedPayload =
      base64Url.normalize(parts[1]);

      final decodedBytes =
      base64Url.decode(normalizedPayload);

      final decoded =
      utf8.decode(decodedBytes);

      final payload =
      json.decode(decoded);

      if (payload is Map<String, dynamic>) {
        return payload;
      }

      if (payload is Map) {
        return Map<String, dynamic>.from(
          payload,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ================================================================
  // CURRENT USER
  // ================================================================

  static Future<Map<String, dynamic>?>
  currentUser() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    // --------------------------------------------------------------
    // Restore Authorization header
    // --------------------------------------------------------------

    ApiService.instance.client.options.headers[
    'Authorization'] = 'Bearer $token';

    // --------------------------------------------------------------
    // Ask backend for current user
    // --------------------------------------------------------------

    try {
      final response =
      await ApiService.instance.get(
        '/auth/me',
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is Map<String, dynamic>) {
          return data;
        }

        if (data is Map) {
          return Map<String, dynamic>.from(
            data,
          );
        }
      }
    } catch (_) {
      // Backend unavailable.
    }

    // --------------------------------------------------------------
    // JWT fallback
    // --------------------------------------------------------------

    return _decodePayload(token);
  }

  // ================================================================
  // TOKEN EXPIRY
  // ================================================================

  static Future<bool> isTokenExpired() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return true;
    }

    // IMPORTANT:
    // Read exp directly from JWT.
    //
    // /auth/me does NOT return exp.
    //

    final payload = _decodePayload(token);

    if (payload == null) {
      return true;
    }

    final exp = payload['exp'];

    if (exp == null) {
      return true;
    }

    int? expirySeconds;

    if (exp is int) {
      expirySeconds = exp;
    } else if (exp is num) {
      expirySeconds = exp.toInt();
    } else if (exp is String) {
      expirySeconds = int.tryParse(exp);
    }

    if (expirySeconds == null) {
      return true;
    }

    final nowSeconds =
        DateTime.now()
            .toUtc()
            .millisecondsSinceEpoch ~/
            1000;

    return nowSeconds >= expirySeconds;
  }

  // ================================================================
  // RESTORE SESSION
  // ================================================================

  static Future<bool> restoreSession() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    // --------------------------------------------------------------
    // Check JWT expiry locally
    // --------------------------------------------------------------

    final expired = await isTokenExpired();

    if (expired) {
      await clearToken();
      return false;
    }

    // --------------------------------------------------------------
    // Restore Authorization header
    // --------------------------------------------------------------

    ApiService.instance.client.options.headers[
    'Authorization'] = 'Bearer $token';

    // --------------------------------------------------------------
    // Validate with backend
    // --------------------------------------------------------------

    final user = await currentUser();

    if (user == null) {
      await clearToken();
      return false;
    }

    // --------------------------------------------------------------
    // Update notifier
    // --------------------------------------------------------------

    try {
      AuthNotifier.instance.setUser(
        user,
      );
    } catch (_) {}

    return true;
  }
}