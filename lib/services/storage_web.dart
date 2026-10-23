// lib/services/storage_web.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class StorageService {
  static void saveToken(String token) {
    try {
      html.window.localStorage['auth_token'] = token;
    } catch (_) {}
  }

  static String? getToken() {
    try {
      final token = html.window.localStorage['auth_token'];
      if (token != null && token.trim().isNotEmpty) {
        return token.trim();
      }
    } catch (_) {}
    return null;
  }

  static void saveUser(String userJson) {
    try {
      html.window.localStorage['user_data'] = userJson;
    } catch (_) {}
  }

  static String? getUser() {
    try {
      final user = html.window.localStorage['user_data'];
      if (user != null && user.trim().isNotEmpty) {
        return user.trim();
      }
    } catch (_) {}
    return null;
  }

  static void clear() {
    try {
      html.window.localStorage.remove('auth_token');
      html.window.localStorage.remove('user_data');
    } catch (_) {}
  }
}
