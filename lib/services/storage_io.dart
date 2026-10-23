// lib/services/storage_io.dart

class StorageService {
  static String? _token;
  static String? _user;

  static void saveToken(String token) {
    _token = token;
  }

  static String? getToken() {
    return _token;
  }

  static void saveUser(String userJson) {
    _user = userJson;
  }

  static String? getUser() {
    return _user;
  }

  static void clear() {
    _token = null;
    _user = null;
  }
}
