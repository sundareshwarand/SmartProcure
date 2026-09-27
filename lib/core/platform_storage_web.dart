import 'dart:convert';
import 'dart:html' as html;

// Read common token locations used by the web build / fallbacks.
String? readWebAuthToken() {
  try {
    final t = html.window.localStorage['auth_token'];
    if (t != null && t.isNotEmpty) return t;
    final fss = html.window.localStorage['flutter_secure_storage'];
    if (fss != null && fss.isNotEmpty) {
      try {
        final decoded = json.decode(fss);
        if (decoded is Map && decoded['auth_token'] != null) return decoded['auth_token'].toString();
      } catch (_) {}
    }
  } catch (_) {}
  return null;
}
