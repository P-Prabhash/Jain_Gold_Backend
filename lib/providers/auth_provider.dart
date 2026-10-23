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

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

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

      // ========================================================
      // 1. PREFERRED: ROOT-LEVEL USER
      // ========================================================

      final rawUser = res['user'];

      if (rawUser is Map) {
        loggedInUser = Map<String, dynamic>.from(
          rawUser,
        );
      }

      // ========================================================
      // 2. FALLBACK: USER INSIDE DATA
      // ========================================================

      if (loggedInUser == null) {
        final data = res['data'];

        if (data is Map && data['user'] is Map) {
          loggedInUser = Map<String, dynamic>.from(
            data['user'] as Map,
          );
        }
      }

      // ========================================================
      // 3. FALLBACK: USER INSIDE RESULT
      // ========================================================

      if (loggedInUser == null) {
        final result = res['result'];

        if (result is Map && result['user'] is Map) {
          loggedInUser = Map<String, dynamic>.from(
            result['user'] as Map,
          );
        }
      }

      // ========================================================
      // 4. FALLBACK: APISERVICE CURRENT USER
      // ========================================================

      if (loggedInUser == null &&
          ApiService.currentUser != null) {
        loggedInUser = Map<String, dynamic>.from(
          ApiService.currentUser!,
        );
      }

      // ========================================================
      // 5. USER MUST EXIST
      // ========================================================

      if (loggedInUser == null ||
          loggedInUser.isEmpty) {
        _currentUser = null;
        _isAuthenticated = false;

        ApiService.currentUser = null;
        ApiService.authToken = null;

        _errorMessage =
            'Login succeeded but user information was not returned.';

        debugPrint(
          'AUTH LOGIN ERROR: API response did not contain user information.',
        );

        debugPrint(
          'AUTH LOGIN RESPONSE: $res',
        );

        _isLoading = false;

        notifyListeners();

        return false;
      }

      // ========================================================
      // 6. STORE INITIAL USER
      // ========================================================

      _currentUser = Map<String, dynamic>.from(
        loggedInUser,
      );

      ApiService.currentUser = Map<String, dynamic>.from(
        loggedInUser,
      );

      _isAuthenticated = true;
      _errorMessage = null;

      debugPrint(
        'AUTH LOGIN: Authentication successful',
      );

      debugPrint(
        'AUTH LOGIN: currentUser=$_currentUser',
      );

      debugPrint(
        'AUTH LOGIN: role=${_extractRole(_currentUser)}',
      );

      // ========================================================
      // 7. LOAD STAFF PERMISSIONS
      //
      // ADMIN:
      //   Full unrestricted access.
      //
      // STAFF / OTHER ROLES:
      //   Load only permissions assigned by ADMIN.
      // ========================================================

      final role = _extractRole(_currentUser);

      if (role == 'ADMIN') {
        // ADMIN has unrestricted access.
        //
        // We intentionally do not require permission records
        // for ADMIN because ADMIN is the controlling role.
        _currentUser!['permission_codes'] =
            <String>[];

        _currentUser!['permissions'] =
            <Map<String, dynamic>>[];

        ApiService.currentUser =
            Map<String, dynamic>.from(
          _currentUser!,
        );

        debugPrint(
          'AUTH PERMISSIONS: ADMIN unrestricted access',
        );
      } else {
        // ------------------------------------------------------
        // STAFF / NON-ADMIN
        // ------------------------------------------------------

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

          debugPrint(
            'AUTH PERMISSIONS ERROR: Invalid user ID.',
          );

          _isLoading = false;

          notifyListeners();

          return false;
        }

        try {
          final permissionResult =
              await ApiService.getUserPermissions(
            userId,
          );

          // ----------------------------------------------------
          // ASSIGNED PERMISSION CODES
          // ----------------------------------------------------

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

          // ----------------------------------------------------
          // FALLBACK:
          // Some backend versions may return the complete
          // permissions catalogue with an `assigned` flag.
          // ----------------------------------------------------

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

          // ----------------------------------------------------
          // STORE ASSIGNED PERMISSIONS IN CURRENT USER
          // ----------------------------------------------------

          _currentUser!['permission_codes'] =
              assignedCodes.toList();

          // Keep the complete returned permission data too.
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

          debugPrint(
            'AUTH PERMISSIONS: userId=$userId',
          );

          debugPrint(
            'AUTH PERMISSIONS: role=$role',
          );

          debugPrint(
            'AUTH PERMISSIONS: assigned=${assignedCodes.toList()}',
          );
        } catch (permissionError) {
          // ----------------------------------------------------
          // FAIL CLOSED
          //
          // STAFF must never receive unrestricted access if
          // permission loading fails.
          // ----------------------------------------------------

          _isAuthenticated = false;
          _currentUser = null;

          ApiService.currentUser = null;
          ApiService.authToken = null;

          _errorMessage =
              'Unable to load user permissions. '
              'Please try logging in again.';

          debugPrint(
            'AUTH PERMISSIONS ERROR: $permissionError',
          );

          _isLoading = false;

          notifyListeners();

          return false;
        }
      }

      // ========================================================
      // 8. FINAL AUTHENTICATED STATE
      // ========================================================

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

      debugPrint(
        'AUTH LOGIN EXCEPTION: $_errorMessage',
      );

      notifyListeners();

      return false;
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

    debugPrint(
      'AUTH USER SET: $_currentUser',
    );

    debugPrint(
      'AUTH ROLE: ${_extractRole(_currentUser)}',
    );

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

    // Some APIs may wrap the user object.
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

    // Some APIs may wrap the actual user object.
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

    // ADMIN is unrestricted.
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
    // ADMIN has unrestricted access.
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

    debugPrint(
      'AUTH LOGOUT: session cleared',
    );

    notifyListeners();
  }
}