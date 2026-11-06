import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  AuthProvider() {
    _restoreSession();
  }

  void _restoreSession() {
    ApiService.initSession();
    if (ApiService.authToken != null && ApiService.currentUser != null) {
      _currentUser = ApiService.currentUser;
      _isAuthenticated = true;
    }
  }

  Map<String, dynamic>? _lastLoginResponse;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get lastLoginResponse => _lastLoginResponse;

  // ============================================================
  // LOGIN STEP 1
  // ============================================================

  Future<Map<String, dynamic>> loginRequest(
    String username,
    String password,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.login(username, password);
      _lastLoginResponse = res;
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login(
    String username,
    String password,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res = await ApiService.login(
        username,
        password,
      );

      Map<String, dynamic>? loggedInUser;

      final rawUser = res['user'];

      if (rawUser is Map) {
        loggedInUser = Map<String, dynamic>.from(
          rawUser,
        );
      }

      if (loggedInUser == null) {
        final data = res['data'];

        if (data is Map && data['user'] is Map) {
          loggedInUser = Map<String, dynamic>.from(
            data['user'] as Map,
          );
        }
      }

      if (loggedInUser == null) {
        final result = res['result'];

        if (result is Map && result['user'] is Map) {
          loggedInUser = Map<String, dynamic>.from(
            result['user'] as Map,
          );
        }
      }

      if (loggedInUser == null &&
          ApiService.currentUser != null) {
        loggedInUser = Map<String, dynamic>.from(
          ApiService.currentUser!,
        );
      }

      if (loggedInUser == null ||
          loggedInUser.isEmpty) {
        _currentUser = null;
        _isAuthenticated = false;

        ApiService.currentUser = null;
        ApiService.authToken = null;

        _errorMessage =
            'Login succeeded but user information was not returned.';

        _isLoading = false;

        notifyListeners();

        return false;
      }

      _currentUser = Map<String, dynamic>.from(
        loggedInUser,
      );

      ApiService.currentUser = Map<String, dynamic>.from(
        loggedInUser,
      );

      _isAuthenticated = true;
      _errorMessage = null;

      final role = _extractRole(_currentUser);

      if (role == 'ADMIN') {
        _currentUser!['permission_codes'] =
            <String>[];

        _currentUser!['permissions'] =
            <Map<String, dynamic>>[];

        ApiService.currentUser =
            Map<String, dynamic>.from(
          _currentUser!,
        );
      } else {
        final userId = _extractUserId(
          _currentUser,
        );

        if (userId == null || userId <= 0) {
          _isAuthenticated = false;
          _currentUser = null;

          ApiService.currentUser = null;
          ApiService.authToken = null;

          _errorMessage =
              'Login succeeded but user ID was not returned.';

          _isLoading = false;

          notifyListeners();

          return false;
        }

        try {
          final permissionResult =
              await ApiService.getUserPermissions(
            userId,
          );

          final assignedCodes =
              <String>{};

          final rawCodes =
              permissionResult['permission_codes'];

          if (rawCodes is List) {
            for (final item in rawCodes) {
              final code =
                  _normalizePermissionCode(
                item.toString(),
              );

              if (code.isNotEmpty) {
                assignedCodes.add(code);
              }
            }
          }

          final rawPermissions =
              permissionResult['permissions'];

          if (assignedCodes.isEmpty &&
              rawPermissions is List) {
            for (final item in rawPermissions) {
              if (item is! Map) {
                continue;
              }

              final permission =
                  Map<String, dynamic>.from(item);

              final assigned =
                  permission['assigned'] == true ||
                  permission['is_assigned'] == true ||
                  permission['selected'] == true;

              if (!assigned) {
                continue;
              }

              final code =
                  _normalizePermissionCode(
                (
                  permission['permission_code'] ??
                  permission['code'] ??
                  permission['permission_key'] ??
                  ''
                ).toString(),
              );

              if (code.isNotEmpty) {
                assignedCodes.add(code);
              }
            }
          }

          _currentUser!['permission_codes'] =
              assignedCodes.toList();

          if (rawPermissions is List) {
            _currentUser!['permissions'] =
                rawPermissions
                    .whereType<Map>()
                    .map<Map<String, dynamic>>(
                      (item) =>
                          Map<String, dynamic>.from(
                        item,
                      ),
                    )
                    .toList();
          } else {
            _currentUser!['permissions'] =
                <Map<String, dynamic>>[];
          }

          ApiService.currentUser =
              Map<String, dynamic>.from(
            _currentUser!,
          );
        } catch (permissionError) {
          _isAuthenticated = false;
          _currentUser = null;

          ApiService.currentUser = null;
          ApiService.authToken = null;

          _errorMessage =
              'Unable to load user permissions. '
              'Please try logging in again.';

          _isLoading = false;

          notifyListeners();

          return false;
        }
      }

      _isLoading = false;

      notifyListeners();

      return _isAuthenticated;
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;

      ApiService.currentUser = null;
      ApiService.authToken = null;

      _isLoading = false;

      _errorMessage = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // VERIFY OTP (STEP 2)
  // ============================================================

  Future<bool> verifyOtp(
    String challengeId,
    String otp,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res = await ApiService.verifyOtp(challengeId, otp);

      Map<String, dynamic>? loggedInUser;
      final rawUser = res['user'] ?? res['data']?['user'];

      if (rawUser is Map) {
        loggedInUser = Map<String, dynamic>.from(rawUser);
      }

      if (loggedInUser == null || loggedInUser.isEmpty) {
        _currentUser = null;
        _isAuthenticated = false;
        ApiService.currentUser = null;
        ApiService.authToken = null;
        _errorMessage = 'OTP verified but user information was not returned.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = Map<String, dynamic>.from(loggedInUser);
      ApiService.currentUser = Map<String, dynamic>.from(loggedInUser);
      _isAuthenticated = true;
      _errorMessage = null;

      final role = _extractRole(_currentUser);

      if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
        _currentUser!['permission_codes'] = <String>[];
        _currentUser!['permissions'] = <Map<String, dynamic>>[];
        ApiService.currentUser = Map<String, dynamic>.from(_currentUser!);
      } else {
        final userId = _extractUserId(_currentUser);
        if (userId != null && userId > 0) {
          try {
            final permissionResult = await ApiService.getUserPermissions(userId);
            final assignedCodes = <String>{};
            final rawCodes = permissionResult['permission_codes'];
            if (rawCodes is List) {
              for (final item in rawCodes) {
                final code = _normalizePermissionCode(item.toString());
                if (code.isNotEmpty) assignedCodes.add(code);
              }
            }
            _currentUser!['permission_codes'] = assignedCodes.toList();
            ApiService.currentUser = Map<String, dynamic>.from(_currentUser!);
          } catch (_) {}
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      ApiService.currentUser = null;
      ApiService.authToken = null;
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<Map<String, dynamic>> resendOtp(String challengeId) async {
    try {
      final res = await ApiService.resendOtp(challengeId);
      return res;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      return {'success': false, 'message': msg};
    }
  }

  // ============================================================
  // SET AUTHENTICATED USER
  // ============================================================

  void setAuthenticatedUser(
    Map<String, dynamic> user,
  ) {
    if (user.isEmpty) {
      _currentUser = null;
      _isAuthenticated = false;

      ApiService.currentUser = null;

      notifyListeners();

      return;
    }

    _currentUser =
        Map<String, dynamic>.from(user);

    ApiService.currentUser =
        Map<String, dynamic>.from(user);

    _isAuthenticated = true;
    _errorMessage = null;

    notifyListeners();
  }

  // ============================================================
  // USER ID
  // ============================================================

  int? get currentUserId {
    return _extractUserId(
      _currentUser,
    );
  }

  int? _extractUserId(
    Map<String, dynamic>? user,
  ) {
    if (user == null) {
      return null;
    }

    const userIdKeys = <String>[
      'id',
      'user_id',
      'userId',
    ];

    for (final key in userIdKeys) {
      final value = user[key];

      if (value == null) {
        continue;
      }

      final id = int.tryParse(
        value.toString(),
      );

      if (id != null && id > 0) {
        return id;
      }
    }

    const nestedKeys = <String>[
      'user',
      'data',
      'result',
    ];

    for (final key in nestedKeys) {
      final nested = user[key];

      if (nested is Map) {
        final id = _extractUserId(
          Map<String, dynamic>.from(
            nested,
          ),
        );

        if (id != null && id > 0) {
          return id;
        }
      }
    }

    return null;
  }

  // ============================================================
  // ROLE
  // ============================================================

  String? get currentRole {
    return _extractRole(
      _currentUser,
    );
  }

  String? _extractRole(
    Map<String, dynamic>? user,
  ) {
    if (user == null) {
      return null;
    }

    const roleKeys = <String>[
      'role',
      'role_code',
      'role_name',
      'user_role',
      'userRole',
      'type',
    ];

    for (final key in roleKeys) {
      final value = user[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return value
            .toString()
            .trim()
            .toUpperCase()
            .replaceAll(
              '-',
              '_',
            )
            .replaceAll(
              ' ',
              '_',
            );
      }
    }

    const nestedKeys = <String>[
      'user',
      'data',
      'result',
    ];

    for (final key in nestedKeys) {
      final nested = user[key];

      if (nested is Map) {
        final role = _extractRole(
          Map<String, dynamic>.from(
            nested,
          ),
        );

        if (role != null &&
            role.isNotEmpty) {
          return role;
        }
      }
    }

    return null;
  }

  // ============================================================
  // ADMIN CHECK
  // ============================================================

  bool get isAdmin {
    return currentRole == 'ADMIN';
  }

  // ============================================================
  // PERMISSION NORMALIZATION
  // ============================================================

  String _normalizePermissionCode(
    String value,
  ) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(
          '.',
          '_',
        )
        .replaceAll(
          '-',
          '_',
        )
        .replaceAll(
          ' ',
          '_',
        )
        .replaceAll(
          RegExp(r'_+'),
          '_',
        )
        .replaceAll(
          RegExp(r'^_+|_+$'),
          '',
        );
  }

  // ============================================================
  // CURRENT USER PERMISSIONS
  // ============================================================

  List<String> get currentPermissionCodes {
    final user = _currentUser;

    if (user == null) {
      return <String>[];
    }

    if (_extractRole(user) == 'ADMIN') {
      return <String>[];
    }

    final codes = <String>{};

    final rawCodes =
        user['permission_codes'];

    if (rawCodes is List) {
      for (final item in rawCodes) {
        final code =
            _normalizePermissionCode(
          item.toString(),
        );

        if (code.isNotEmpty) {
          codes.add(code);
        }
      }
    }

    return codes.toList();
  }

  // ============================================================
  // PERMISSION CHECK
  // ============================================================

  bool hasPermission(
    String permissionCode,
  ) {
    if (isAdmin) {
      return true;
    }

    final required =
        _normalizePermissionCode(
      permissionCode,
    );

    if (required.isEmpty) {
      return false;
    }

    return currentPermissionCodes
        .contains(required);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void logout() {
    _isAuthenticated = false;
    _currentUser = null;
    _errorMessage = null;

    ApiService.authToken = null;
    ApiService.currentUser = null;
    StorageService.clear();

    notifyListeners();
  }
}
