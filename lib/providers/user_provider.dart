// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  // ============================================================
  // USERS
  // ============================================================

  List<Map<String, dynamic>> _users = [];

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;

  // ============================================================
  // SEARCH / FILTER
  // ============================================================

  String _search = '';
  String _selectedStatus = 'ALL';
  String _selectedRole = 'ALL';

  int _currentPage = 1;
  int _limit = 25;
  int _totalRecords = 0;
  int _totalPages = 0;

  // ============================================================
  // SELECTED USER
  // ============================================================

  Map<String, dynamic>? _selectedUser;

  List<Map<String, dynamic>> _selectedUserRoles = [];

  List<Map<String, dynamic>> _selectedUserPermissions = [];

  List<String> _selectedPermissionCodes = [];

  Map<String, dynamic> _permissionsByModule = {};

  // ============================================================
  // ROLES
  // ============================================================

  List<Map<String, dynamic>> _roles = [];

  List<Map<String, dynamic>> _permissions = [];

  Map<String, dynamic> _permissionsGroupedByModule = {};

  // ============================================================
  // GETTERS
  // ============================================================

  List<Map<String, dynamic>> get users => _users;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String get search => _search;

  String get selectedStatus => _selectedStatus;

  String get selectedRole => _selectedRole;

  int get currentPage => _currentPage;

  int get limit => _limit;

  int get totalRecords => _totalRecords;

  int get totalPages => _totalPages;

  bool get hasNextPage =>
      _currentPage < _totalPages;

  bool get hasPreviousPage =>
      _currentPage > 1;

  Map<String, dynamic>? get selectedUser =>
      _selectedUser;

  List<Map<String, dynamic>>
      get selectedUserRoles =>
          _selectedUserRoles;

  List<Map<String, dynamic>>
      get selectedUserPermissions =>
          _selectedUserPermissions;

  List<String>
      get selectedPermissionCodes =>
          _selectedPermissionCodes;

  Map<String, dynamic>
      get permissionsByModule =>
          _permissionsByModule;

  List<Map<String, dynamic>> get roles =>
      _roles;

  List<Map<String, dynamic>> get permissions =>
      _permissions;

  Map<String, dynamic>
      get permissionsGroupedByModule =>
          _permissionsGroupedByModule;

  // ============================================================
  // FETCH USERS
  // ============================================================

  Future<void> fetchUsers({
    String? search,
    String? status,
    String? role,
    int page = 1,
    int limit = 25,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    _search = search?.trim() ?? _search;

    if (status != null) {
      _selectedStatus = status;
    }

    if (role != null) {
      _selectedRole = role;
    }

    _currentPage = page;
    _limit = limit;

    notifyListeners();

    try {
      final result =
          await ApiService.searchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: page,
        limit: limit,
      );

      final rawData = result['data'];

      if (rawData is List) {
        _users = rawData
            .map<Map<String, dynamic>>(
              (item) =>
                  Map<String, dynamic>.from(
                item as Map,
              ),
            )
            .toList();
      } else {
        _users = [];
      }

      final rawPagination =
          result['pagination'];

      if (rawPagination is Map) {
        _currentPage =
            int.tryParse(
                  '${rawPagination['page']}',
                ) ??
                page;

        _limit =
            int.tryParse(
                  '${rawPagination['limit']}',
                ) ??
                limit;

        _totalRecords =
            int.tryParse(
                  '${rawPagination['total_records']}',
                ) ??
                0;

        _totalPages =
            int.tryParse(
                  '${rawPagination['total_pages']}',
                ) ??
                0;
      } else {
        _totalRecords = _users.length;
        _totalPages = 1;
      }

      _isLoading = false;

      notifyListeners();
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> searchUsers(
    String value,
  ) async {
    _search = value.trim();

    await fetchUsers(
      search: _search,
      status: _selectedStatus,
      role: _selectedRole,
      page: 1,
      limit: _limit,
    );
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  Future<void> filterByStatus(
    String status,
  ) async {
    _selectedStatus = status;

    await fetchUsers(
      search: _search,
      status: status,
      role: _selectedRole,
      page: 1,
      limit: _limit,
    );
  }

  // ============================================================
  // ROLE FILTER
  // ============================================================

  Future<void> filterByRole(
    String role,
  ) async {
    _selectedRole = role;

    await fetchUsers(
      search: _search,
      status: _selectedStatus,
      role: role,
      page: 1,
      limit: _limit,
    );
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  Future<void> clearFilters() async {
    _search = '';
    _selectedStatus = 'ALL';
    _selectedRole = 'ALL';
    _currentPage = 1;

    await fetchUsers(
      search: '',
      status: 'ALL',
      role: 'ALL',
      page: 1,
      limit: _limit,
    );
  }

  // ============================================================
  // NEXT PAGE
  // ============================================================

  Future<void> nextPage() async {
    if (!hasNextPage || _isLoading) {
      return;
    }

    await fetchUsers(
      search: _search,
      status: _selectedStatus,
      role: _selectedRole,
      page: _currentPage + 1,
      limit: _limit,
    );
  }

  // ============================================================
  // PREVIOUS PAGE
  // ============================================================

  Future<void> previousPage() async {
    if (!hasPreviousPage || _isLoading) {
      return;
    }

    await fetchUsers(
      search: _search,
      status: _selectedStatus,
      role: _selectedRole,
      page: _currentPage - 1,
      limit: _limit,
    );
  }

  // ============================================================
  // PAGE SIZE
  // ============================================================

  Future<void> changePageSize(
    int newLimit,
  ) async {
    if (newLimit <= 0) {
      return;
    }

    _limit = newLimit;

    await fetchUsers(
      search: _search,
      status: _selectedStatus,
      role: _selectedRole,
      page: 1,
      limit: newLimit,
    );
  }

  // ============================================================
  // GET USER DETAILS
  // ============================================================

  Future<bool> fetchUserDetails(
    int userId,
  ) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final result =
          await ApiService.getUser(
        userId,
      );

      _selectedUser =
          Map<String, dynamic>.from(
        result['user'] ?? {},
      );

      final rawRoles =
          result['roles'];

      if (rawRoles is List) {
        _selectedUserRoles =
            rawRoles
                .map<Map<String, dynamic>>(
                  (item) =>
                      Map<String, dynamic>.from(
                    item as Map,
                  ),
                )
                .toList();
      } else {
        _selectedUserRoles = [];
      }

      final rawPermissions =
          result['permissions'];

      if (rawPermissions is List) {
        _selectedUserPermissions =
            rawPermissions
                .whereType<Map>()
                .map<Map<String, dynamic>>(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList();

        // The permissions API returns the complete permission catalogue
        // together with an `assigned` flag. Build the grouped structure
        // used by the Manage Permissions dialog.
        _permissions = _deduplicatePermissions(
          _selectedUserPermissions,
        );

        _selectedUserPermissions = List<Map<String, dynamic>>.from(
          _permissions,
        );

        _permissionsGroupedByModule =
            _groupPermissionsByModule(_permissions);
      } else {
        _selectedUserPermissions = [];
        _permissions = [];
        _permissionsGroupedByModule = {};
      }

      final rawCodes =
          result['permission_codes'];

      if (rawCodes is List) {
        _selectedPermissionCodes =
            rawCodes
                .map(
                  (item) =>
                      _normalizePermissionCode(
                    item.toString(),
                  ),
                )
                .where((code) => code.isNotEmpty)
                .toSet()
                .toList();
      } else {
        _selectedPermissionCodes = [];
      }

      final rawModules =
          result['permissions_by_module'];

      if (rawModules is Map) {
        _permissionsByModule =
            Map<String, dynamic>.from(rawModules);
      } else {
        _permissionsByModule =
            _groupPermissionsByModule(
          _selectedUserPermissions,
        );
      }

      // Keep the public grouped catalogue in sync for the permission
      // dialog. Some backend versions return the grouped data directly;
      // the current permissions.php returns the flat permissions list,
      // so the fallback above is required.
      if (_permissionsGroupedByModule.isEmpty &&
          _permissions.isNotEmpty) {
        _permissionsGroupedByModule =
            _groupPermissionsByModule(_permissions);
      }

      _isSaving = false;

      notifyListeners();

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // CREATE USER
  // ============================================================

  Future<Map<String, dynamic>?>
      createUser(
    Map<String, dynamic> data,
  ) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final result =
          await ApiService.createUser(
        data,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: _currentPage,
        limit: _limit,
      );

      return result;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  Future<Map<String, dynamic>?>
      updateUser(
    Map<String, dynamic> data,
  ) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final result =
          await ApiService.updateUser(
        data,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: _currentPage,
        limit: _limit,
      );

      return result;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // ACTIVATE / DEACTIVATE
  // ============================================================

  Future<bool> toggleUserStatus({
    required int userId,
    required String status,
    String? reason,
  }) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await ApiService.toggleUserStatus(
        userId,
        status,
        reason: reason,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: _currentPage,
        limit: _limit,
      );

      if (_selectedUser != null &&
          _selectedUser!['id'] == userId) {
        await fetchUserDetails(
          userId,
        );
      }

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // SAFE DELETE / DEACTIVATE
  // ============================================================

  Future<bool> deleteUser(
    int userId, {
    String? reason,
  }) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await ApiService.deleteUser(
        userId,
        reason: reason,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: _currentPage,
        limit: _limit,
      );

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // LOAD ROLES + PERMISSIONS
  // ============================================================

  Future<bool> fetchRoles() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final result =
          await ApiService.getUserRoles();

      final rawRoles =
          result['roles'];

      if (rawRoles is List) {
        _roles =
            rawRoles
                .map<Map<String, dynamic>>(
                  (item) =>
                      Map<String, dynamic>.from(
                    item as Map,
                  ),
                )
                .toList();
      } else {
        _roles = [];
      }

      final rawPermissions =
          result['permissions'];

      if (rawPermissions is List) {
        _permissions = _deduplicatePermissions(
          rawPermissions
              .map<Map<String, dynamic>>(
                (item) =>
                    Map<String, dynamic>.from(
                  item as Map,
                ),
              )
              .toList(),
        );
      } else {
        _permissions = [];
      }

      final rawGrouped =
          result['permissions_by_module'];

      if (rawGrouped is Map) {
        // Do not trust a backend grouping that can contain duplicate
        // module names such as Dashboard / DASHBOARD. Always rebuild
        // the canonical grouping from the deduplicated catalogue.
        _permissionsGroupedByModule =
            _groupPermissionsByModule(_permissions);
      } else {
        _permissionsGroupedByModule = {};
      }

      _isLoading = false;

      notifyListeners();

      return true;
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // ASSIGN ROLE
  // ============================================================

  Future<bool> assignRole({
    required int userId,
    required String role,
    String? reason,
  }) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await ApiService.assignUserRole(
        userId: userId,
        role: role,
        reason: reason,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUsers(
        search: _search,
        status: _selectedStatus,
        role: _selectedRole,
        page: _currentPage,
        limit: _limit,
      );

      await fetchUserDetails(
        userId,
      );

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // USER PERMISSIONS
  // ============================================================

  Future<bool> fetchUserPermissions(
    int userId,
  ) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final result =
          await ApiService.getUserPermissions(
        userId,
      );

      final rawPermissions =
          result['permissions'];

      if (rawPermissions is List) {
        _selectedUserPermissions =
            rawPermissions
                .whereType<Map>()
                .map<Map<String, dynamic>>(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList();

        // IMPORTANT: permissions.php returns the full permission list.
        // Store that list in the provider so the dialog can display it.
        _permissions = _deduplicatePermissions(
          _selectedUserPermissions,
        );

        _selectedUserPermissions = List<Map<String, dynamic>>.from(
          _permissions,
        );

        _permissionsGroupedByModule =
            _groupPermissionsByModule(_permissions);
      } else {
        _selectedUserPermissions = [];
        _permissions = [];
        _permissionsGroupedByModule = {};
      }

      final rawCodes =
          result['permission_codes'];

      if (rawCodes is List) {
        _selectedPermissionCodes =
            rawCodes
                .map(
                  (item) =>
                      _normalizePermissionCode(
                    item.toString(),
                  ),
                )
                .where((code) => code.isNotEmpty)
                .toSet()
                .toList();
      } else {
        _selectedPermissionCodes = [];
      }

      final rawModules =
          result['permissions_by_module'];

      if (rawModules is Map) {
        _permissionsByModule =
            Map<String, dynamic>.from(rawModules);
      } else {
        _permissionsByModule =
            _groupPermissionsByModule(
          _selectedUserPermissions,
        );
      }

      // Keep the public grouped catalogue in sync for the permission
      // dialog. Some backend versions return the grouped data directly;
      // the current permissions.php returns the flat permissions list,
      // so the fallback above is required.
      if (_permissionsGroupedByModule.isEmpty &&
          _permissions.isNotEmpty) {
        _permissionsGroupedByModule =
            _groupPermissionsByModule(_permissions);
      }

      _isSaving = false;

      notifyListeners();

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // UPDATE USER PERMISSIONS
  // ============================================================

  Future<bool> updateUserPermissions({
    required int userId,
    required List<String> permissionCodes,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.updateUserPermissions(
        userId: userId,
        permissionCodes: permissionCodes,
      );

      // Re-fetch the updated user permission catalogue from backend
      await fetchUserPermissions(userId);

      _isSaving = false;
      notifyListeners();

      return true;
    } catch (e) {
      _isSaving = false;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // PERMISSION CHECK
  // ============================================================

  bool hasPermission(
    String permissionCode,
  ) {
    final normalized =
        _normalizePermissionCode(permissionCode);

    return _selectedPermissionCodes
        .map(_normalizePermissionCode)
        .contains(normalized);
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<bool> resetPassword({
    required int userId,
    required String newPassword,
    String? reason,
  }) async {
    _isSaving = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await ApiService.resetUserPassword(
        userId: userId,
        newPassword: newPassword,
        reason: reason,
      );

      _isSaving = false;

      notifyListeners();

      await fetchUserDetails(
        userId,
      );

      return true;
    } catch (e) {
      _isSaving = false;

      _errorMessage =
          _cleanError(e);

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // GROUP PERMISSIONS BY MODULE
  // ============================================================

  // ============================================================
  // PERMISSION NORMALIZATION / DEDUPLICATION
  // ============================================================

  String _normalizePermissionCode(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('.', '_')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String _normalizeModuleKey(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('.', '_')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String _displayModuleName(String value) {
    final key = _normalizeModuleKey(value);

    const knownNames = <String, String>{
      'DASHBOARD': 'Dashboard',
      'CUSTOMER': 'Customers',
      'CUSTOMERS': 'Customers',
      'GOLD': 'Gold Items',
      'GOLD_ITEM': 'Gold Items',
      'GOLD_ITEMS': 'Gold Items',
      'LOAN': 'Pawn Loans',
      'LOANS': 'Pawn Loans',
      'PAWN_LOAN': 'Pawn Loans',
      'PAWN_LOANS': 'Pawn Loans',
      'PAYMENT': 'Payments',
      'PAYMENTS': 'Payments',
      'RELEASE': 'Releases',
      'RELEASES': 'Releases',
      'RECEIPT': 'Receipts',
      'RECEIPTS': 'Receipts',
      'REPORT': 'Reports',
      'REPORTS': 'Reports',
      'SETTING': 'Settings',
      'SETTINGS': 'Settings',
      'USER': 'User Management',
      'USERS': 'User Management',
      'USER_MANAGEMENT': 'User Management',
    };

    return knownNames[key] ??
        (value.trim().isEmpty ? 'Other' : value.trim());
  }

  List<Map<String, dynamic>> _deduplicatePermissions(
    List<Map<String, dynamic>> permissions,
  ) {
    final byCode = <String, Map<String, dynamic>>{};

    for (final rawPermission in permissions) {
      final permission =
          Map<String, dynamic>.from(rawPermission);

      final rawCode =
          (permission['permission_code'] ??
                  permission['code'] ??
                  '')
              .toString();

      final code = _normalizePermissionCode(rawCode);
      if (code.isEmpty) {
        continue;
      }

      final existing = byCode[code];
      if (existing == null) {
        permission['permission_code'] = code;
        permission['module_name'] = _displayModuleName(
          (permission['module_name'] ??
                  permission['module'] ??
                  'Other')
              .toString(),
        );
        byCode[code] = permission;
        continue;
      }

      // If duplicate records exist (for example dashboard.view and
      // DASHBOARD_VIEW), keep one record and preserve an assigned=true
      // value if any duplicate says the permission is assigned.
      final existingAssigned =
          existing['assigned'] == true ||
          existing['is_assigned'] == true ||
          existing['selected'] == true;

      final currentAssigned =
          permission['assigned'] == true ||
          permission['is_assigned'] == true ||
          permission['selected'] == true;

      if (currentAssigned && !existingAssigned) {
        existing['assigned'] = true;
      }
    }

    return byCode.values.toList();
  }

  // ============================================================
  // GROUP PERMISSIONS BY MODULE
  // ============================================================

  Map<String, dynamic> _groupPermissionsByModule(
    List<Map<String, dynamic>> permissions,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final moduleNames = <String, String>{};

    for (final permission in permissions) {
      final rawModule =
          (permission['module_name'] ??
                  permission['module'] ??
                  'Other')
              .toString()
              .trim();

      final moduleKey = _normalizeModuleKey(
        rawModule.isEmpty ? 'Other' : rawModule,
      );

      final moduleName = _displayModuleName(
        rawModule.isEmpty ? 'Other' : rawModule,
      );

      moduleNames[moduleKey] = moduleName;
      grouped.putIfAbsent(
        moduleKey,
        () => <Map<String, dynamic>>[],
      );

      final permissionCode = _normalizePermissionCode(
        (permission['permission_code'] ??
                permission['code'] ??
                '')
            .toString(),
      );

      if (permissionCode.isEmpty) {
        continue;
      }

      final alreadyExists = grouped[moduleKey]!.any(
        (item) =>
            _normalizePermissionCode(
              (item['permission_code'] ??
                      item['code'] ??
                      '')
                  .toString(),
            ) ==
            permissionCode,
      );

      if (!alreadyExists) {
        final normalized =
            Map<String, dynamic>.from(permission);
        normalized['permission_code'] = permissionCode;
        normalized['module_name'] = moduleName;
        grouped[moduleKey]!.add(normalized);
      }
    }

    final result = <String, dynamic>{};

    for (final entry in grouped.entries) {
      result[moduleNames[entry.key] ?? entry.key] =
          entry.value;
    }

    return result;
  }

  // ============================================================
  // SELECT USER
  // ============================================================

  void clearSelectedUser() {
    _selectedUser = null;
    _selectedUserRoles = [];
    _selectedUserPermissions = [];
    _selectedPermissionCodes = [];
    _permissionsByModule = {};
    _permissions = [];
    _permissionsGroupedByModule = {};

    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }
}