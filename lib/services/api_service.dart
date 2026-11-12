// lib/services/api_service.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/customer.dart';
import '../models/gold_item.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/release.dart';
import '../models/transaction.dart';
import '../models/dashboard_summary.dart';
import '../models/receipt_data.dart';
import 'storage_service.dart';

class ApiService {
  static String baseUrl = AppConstants.defaultApiBaseUrl;
  static String? authToken;

  // Current authenticated user for role checks outside AuthProvider.
  static Map<String, dynamic>? currentUser;

  static void initSession() {
    try {
      final savedToken = StorageService.getToken();
      if (savedToken != null && savedToken.isNotEmpty) {
        authToken = savedToken;
      }

      final savedUserJson = StorageService.getUser();
      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        final decoded = jsonDecode(savedUserJson);
        if (decoded is Map) {
          currentUser = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
  }

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null &&
            authToken!.trim().isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

  // ============================================================
  // DATE NORMALIZATION
  // ============================================================

  static String _normalizeApiDate(String value) {
    final input = value.trim();

    if (input.isEmpty) {
      return '';
    }

    final isoPattern = RegExp(
      r'^\d{4}-\d{2}-\d{2}$',
    );

    if (isoPattern.hasMatch(input)) {
      return input;
    }

    final slashParts = input.split('/');

    if (slashParts.length == 3) {
      final day = slashParts[0].padLeft(2, '0');
      final month = slashParts[1].padLeft(2, '0');
      final year = slashParts[2];

      if (year.length == 4) {
        return '$year-$month-$day';
      }
    }

    final dashParts = input.split('-');

    if (dashParts.length == 3) {
      if (dashParts[0].length == 2 &&
          dashParts[1].length == 2 &&
          dashParts[2].length == 4) {
        return '${dashParts[2]}-${dashParts[1]}-${dashParts[0]}';
      }
    }

    return input;
  }

  // ============================================================
  // ENDPOINT CLEANER (NODE.JS REST ROUTE NORMALIZATION)
  // ============================================================

  static String _cleanEndpoint(String endpoint) {
    var e = endpoint.trim();
    if (e.endsWith('.php')) {
      e = e.substring(0, e.length - 4);
    }
    return e;
  }

  // ============================================================
  // GET REQUEST
  // ============================================================

  static Future<dynamic> _get(
    String endpoint, [
    Map<String, String>? queryParams,
  ]) async {
    final clean = _cleanEndpoint(endpoint);
    Uri uri;

    try {
      uri = Uri.parse('$baseUrl/$clean');

      if (queryParams != null &&
          queryParams.isNotEmpty) {
        final existingParams =
            Map<String, String>.from(
          uri.queryParameters,
        );

        existingParams.addAll(queryParams);

        uri = uri.replace(
          queryParameters: existingParams,
        );
      }
    } catch (e) {
      throw Exception(
        'Invalid API URL: $e',
      );
    }

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        if (authToken != null &&
            authToken!.trim().isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      final response = await http.get(
        uri,
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is Exception &&
          e.toString().startsWith('Exception:')) {
        rethrow;
      }

      throw Exception(
        'Network connection error: $e',
      );
    }
  }

  // ============================================================
  // POST REQUEST
  // ============================================================

  static Future<dynamic> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final clean = _cleanEndpoint(endpoint);
    Uri uri;

    try {
      uri = Uri.parse('$baseUrl/$clean');
    } catch (e) {
      throw Exception(
        'Invalid API URL: $e',
      );
    }

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is Exception &&
          e.toString().startsWith('Exception:')) {
        rethrow;
      }

      throw Exception(
        'Network connection error: $e',
      );
    }
  }

  // ============================================================
  // HANDLE RESPONSE
  // ============================================================

  static dynamic _handleResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      throw Exception(
        'Empty server response '
        '(HTTP ${response.statusCode})',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw Exception(
        'Invalid JSON response from server '
        '(HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decoded is Map<String, dynamic> &&
          decoded['success'] == false) {
        throw Exception(
          decoded['message']?.toString() ??
              'API operation failed.',
        );
      }

      return decoded;
    }

    String message =
        'Server error (${response.statusCode})';

    if (decoded is Map<String, dynamic>) {
      final serverMessage =
          decoded['message'];

      if (serverMessage != null &&
          serverMessage.toString().trim().isNotEmpty) {
        message = serverMessage.toString();
      }

      final errors = decoded['errors'];

      if (errors != null) {
        final details =
            _formatApiErrors(errors);

        if (details.isNotEmpty) {
          message =
              '$message\n$details';
        }
      }

      final detailsValue =
          decoded['details'];

      if (detailsValue != null) {
        final details =
            _formatApiErrors(detailsValue);

        if (details.isNotEmpty) {
          message =
              '$message\n$details';
        }
      }
    } else if (decoded != null) {
      message = decoded.toString();
    }

    throw Exception(message);
  }

  // ============================================================
  // FORMAT API ERRORS
  // ============================================================

  static String _formatApiErrors(
    dynamic errors,
  ) {
    if (errors == null) {
      return '';
    }

    if (errors is String) {
      return errors.trim();
    }

    if (errors is List) {
      return errors
          .map((e) => e.toString())
          .where(
            (e) => e.trim().isNotEmpty,
          )
          .join('\n');
    }

    if (errors is Map) {
      final lines = <String>[];

      errors.forEach((key, value) {
        if (value is Map) {
          final nested =
              _formatApiErrors(value);

          if (nested.isNotEmpty) {
            lines.add(
              '$key: $nested',
            );
          }
        } else {
          final text =
              value?.toString() ?? '';

          if (text.trim().isNotEmpty) {
            lines.add(
              '$key: $text',
            );
          }
        }
      });

      return lines.join('\n');
    }

    return errors.toString();
  }

  // ============================================================
  // AUTH
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final res = await _post(
      'api/auth/login',
      {
        'username': username,
        'password': password,
      },
    );

    if (res is Map<String, dynamic>) {
      final bool requiresOtp = res['otp_required'] == true ||
          res['requires_otp'] == true ||
          res['requiresOtp'] == true;

      // If Admin login without OTP (requires_otp == false), save tokens & user
      if (!requiresOtp) {
        final token = res['token'] ?? res['accessToken'] ?? res['data']?['token'];
        if (token != null && token.toString().trim().isNotEmpty) {
          authToken = token.toString();
          StorageService.saveToken(authToken!);
        }

        final user = res['user'] ?? res['data']?['user'];
        if (user is Map) {
          currentUser = Map<String, dynamic>.from(user);
          StorageService.saveUser(jsonEncode(currentUser));
        }
      }
    }

    return Map<String, dynamic>.from(res);
  }

  // ============================================================
  // OTP VERIFICATION
  // ============================================================

  static Future<Map<String, dynamic>> verifyAdminOtp(
    String loginSessionId,
    String otp,
  ) async {
    final res = await _post(
      'api/auth/verify-otp',
      {
        'login_session_id': loginSessionId,
        'challenge_id': loginSessionId,
        'challengeId': loginSessionId,
        'otp': otp,
      },
    );

    if (res is Map<String, dynamic>) {
      final token = res['token'] ?? res['accessToken'] ?? res['data']?['token'];
      if (token != null && token.toString().trim().isNotEmpty) {
        authToken = token.toString();
        StorageService.saveToken(authToken!);
      }

      final refreshToken = res['refreshToken'] ?? res['data']?['refreshToken'];
      if (refreshToken != null && refreshToken.toString().trim().isNotEmpty) {
        StorageService.saveRefreshToken(refreshToken.toString());
      }

      final user = res['user'] ?? res['data']?['user'];
      if (user is Map) {
        currentUser = Map<String, dynamic>.from(user);
        StorageService.saveUser(jsonEncode(currentUser));
      }
    }

    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String challengeId,
    String otp,
  ) {
    return verifyAdminOtp(challengeId, otp);
  }

  static Future<Map<String, dynamic>> resendAdminOtp(
    String loginSessionId,
  ) async {
    final res = await _post(
      'api/auth/resend-otp',
      {
        'login_session_id': loginSessionId,
        'challenge_id': loginSessionId,
        'challengeId': loginSessionId,
      },
    );
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> resendOtp(
    String challengeId,
  ) {
    return resendAdminOtp(challengeId);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _get('api/auth/me');
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> refreshToken(
    String refreshToken,
  ) async {
    final res = await _post(
      'api/auth/refresh-token',
      {
        'refreshToken': refreshToken,
        'refresh_token': refreshToken,
      },
    );
    if (res is Map<String, dynamic> && res['token'] != null) {
      authToken = res['token'].toString();
      StorageService.saveToken(authToken!);
    }
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> logoutApi() async {
    try {
      final res = await _post('api/auth/logout', {});
      return Map<String, dynamic>.from(res);
    } catch (_) {
      return {'success': true};
    }
  }

  // ============================================================
  // ADMIN CREDENTIALS
  // ============================================================

  static Future<Map<String, dynamic>> updateAdminCredentials({
    required String currentPassword,
    String? newUsername,
    String? newPassword,
  }) async {
    final data = <String, dynamic>{
      'current_password': currentPassword,
    };

    if (newUsername != null &&
        newUsername.trim().isNotEmpty) {
      data['new_username'] = newUsername.trim();
    }

    if (newPassword != null &&
        newPassword.isNotEmpty) {
      data['new_password'] = newPassword;
    }

    final res = await _post(
      'users/update_admin_credentials',
      data,
    );

    if (res is Map<String, dynamic>) {
      final token = res['token'];
      if (token != null &&
          token.toString().trim().isNotEmpty) {
        authToken = token.toString();
        StorageService.saveToken(authToken!);
      }

      final user = res['user'];
      if (user is Map) {
        currentUser = Map<String, dynamic>.from(user);
        StorageService.saveUser(jsonEncode(currentUser));
      }
    }

    return Map<String, dynamic>.from(res);
  }

  // ============================================================
  // INITIAL ADMIN SETUP
  // ============================================================

  static Future<Map<String, dynamic>>
      adminExists() async {
    final res = await _get(
      'auth/admin_status',
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  static Future<Map<String, dynamic>>
      sendAdminEmailOtp(
    String email,
  ) async {
    final res = await _post(
      'auth/admin_registration',
      {
        'action': 'send_otp',
        'email': email.trim(),
      },
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  static Future<Map<String, dynamic>>
      verifyAdminEmailOtp(
    String email,
    String otp,
  ) async {
    final res = await _post(
      'auth/admin_registration',
      {
        'action': 'verify_otp',
        'email': email.trim(),
        'otp': otp.trim(),
      },
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  static Future<Map<String, dynamic>>
      createInitialAdmin(
    Map<String, dynamic> data,
  ) async {
    final requestData =
        Map<String, dynamic>.from(data);

    requestData['action'] =
        'create_admin';

    final res = await _post(
      'auth/admin_registration',
      requestData,
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  static Future<DashboardSummary> getDashboard({
    String? fromDate,
    String? toDate,
    String? period,
  }) async {
    final params = <String, String>{};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      params['from_date'] = fromDate.trim();
      params['fromDate'] = fromDate.trim();
      params['start_date'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      params['to_date'] = toDate.trim();
      params['toDate'] = toDate.trim();
      params['end_date'] = toDate.trim();
    }
    if (period != null && period.trim().isNotEmpty) {
      params['period'] = period.trim();
    }

    final res = await _get(
      'dashboard/summary',
      params.isNotEmpty ? params : null,
    );

    return DashboardSummary.fromJson(
      res['data'],
    );
  }

  // ============================================================
  // CUSTOMERS
  // ============================================================

  static Future<List<Customer>>
      getCustomers([
    String? search,
  ]) async {
    final params =
        <String, String>{};

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    final res = await _get(
      'customers/list',
      params,
    );

    final list =
        res['data'] as List? ?? [];

    return list
        .map(
          (c) => Customer.fromJson(c),
        )
        .toList();
  }

  static Future<Customer> addCustomer(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'customers/create',
      data,
    );

    return Customer.fromJson(
      res['data'],
    );
  }

  static Future<Customer>
      updateCustomer(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'customers/update',
      data,
    );

    return Customer.fromJson(
      res['data'],
    );
  }

  static Future<Map<String, dynamic>>
      getCustomerDetails(
    int customerId,
  ) async {
    final res = await _get(
      'customers/get',
      {
        'id': customerId.toString(),
      },
    );

    return Map<String, dynamic>.from(
      res['data'],
    );
  }

  // ============================================================
  // GOLD ITEMS
  // ============================================================

  static Future<List<GoldItem>>
      getGoldItems({
    int? customerId,
    String? status,
    String? search,
  }) async {
    final params =
        <String, String>{};

    if (customerId != null &&
        customerId > 0) {
      params['customer_id'] =
          customerId.toString();
    }

    if (status != null &&
        status.trim().isNotEmpty) {
      params['status'] =
          status.trim();
    }

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    final res = await _get(
      'gold/list',
      params,
    );

    final list =
        res['data'] as List? ?? [];

    return list
        .map(
          (g) => GoldItem.fromJson(g),
        )
        .toList();
  }

  static Future<GoldItem> addGoldItem(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'gold/create',
      data,
    );

    return GoldItem.fromJson(
      res['data'],
    );
  }

  static Future<GoldItem>
      updateGoldItem(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'gold/update',
      data,
    );

    return GoldItem.fromJson(
      res['data'],
    );
  }

  // ============================================================
  // LOANS
  // ============================================================

  static Future<List<Loan>> getLoans({
    int? customerId,
    String? status,
    String? loanType,
    String? search,
  }) async {
    final params =
        <String, String>{};

    if (customerId != null &&
        customerId > 0) {
      params['customer_id'] =
          customerId.toString();
    }

    if (status != null &&
        status.trim().isNotEmpty) {
      params['status'] =
          status.trim();
    }

    if (loanType != null &&
        loanType.trim().isNotEmpty) {
      params['loan_type'] =
          loanType.trim();
    }

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    final res = await _get(
      'loans/list',
      params,
    );

    final list =
        res['data'] as List? ?? [];

    return list
        .map(
          (l) => Loan.fromJson(l),
        )
        .toList();
  }

  // ============================================================
  // CREATE NEW LOAN
  // ============================================================

  static Future<Map<String, dynamic>>
      createNewLoan(
    Map<String, dynamic> data,
  ) async {
    return await _post(
      'loans/create_new',
      data,
    );
  }

  // ============================================================
  // CREATE EXISTING LOAN
  // ============================================================

  static Future<Map<String, dynamic>>
      createExistingLoan(
    Map<String, dynamic> data,
  ) async {
    final payload =
        Map<String, dynamic>.from(data);

    if (payload.containsKey(
        'manual_opened_date')) {
      payload['manual_opened_date'] =
          _normalizeApiDate(
        payload['manual_opened_date']
                ?.toString() ??
            '',
      );
    }

    if (payload.containsKey(
        'manual_closed_date')) {
      final closedDate =
          payload['manual_closed_date']
                  ?.toString() ??
              '';

      payload['manual_closed_date'] =
          _normalizeApiDate(
        closedDate,
      );
    }

    if (payload['customer_id'] != null) {
      payload['customer_id'] =
          int.tryParse(
                payload['customer_id']
                    .toString(),
              ) ??
              0;
    }

    final rawGoldIds =
        payload['gold_item_ids'];

    if (rawGoldIds is List) {
      payload['gold_item_ids'] =
          rawGoldIds
              .map(
                (id) => int.tryParse(
                      id.toString(),
                    ) ??
                    0,
              )
              .where(
                (id) => id > 0,
              )
              .toList();
    } else {
      payload['gold_item_ids'] =
          <int>[];
    }

    final res = await _post(
      'loans/create_existing',
      payload,
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  // ============================================================
  // CREATE ADDITIONAL LOAN
  // ============================================================

  static Future<Map<String, dynamic>>
      createAdditionalLoan(
    Map<String, dynamic> data,
  ) async {
    final payload =
        Map<String, dynamic>.from(data);

    final rawGoldIds =
        payload['gold_item_ids'];

    if (rawGoldIds is List) {
      payload['gold_item_ids'] =
          rawGoldIds
              .map(
                (id) => int.tryParse(
                      id.toString(),
                    ) ??
                    0,
              )
              .where(
                (id) => id > 0,
              )
              .toList();
    }

    if (payload['customer_id'] != null) {
      payload['customer_id'] =
          int.tryParse(
                payload['customer_id']
                    .toString(),
              ) ??
              0;
    }

    return await _post(
      'loans/create_additional',
      payload,
    );
  }

  // ============================================================
  // LOAN DETAILS
  // ============================================================

  static Future<Map<String, dynamic>>
      getLoanDetails(
    int loanId,
  ) async {
    final res = await _get(
      'loans/get',
      {
        'id': loanId.toString(),
      },
    );

    return Map<String, dynamic>.from(
      res['data'],
    );
  }

  // ============================================================
  // CLOSE LOAN
  // ============================================================

  static Future<Map<String, dynamic>>
      closeLoan(
    Map<String, dynamic> data,
  ) async {
    return await _post(
      'loans/close',
      data,
    );
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  static Future<List<Payment>>
      getPayments({
    int? loanId,
    int? customerId,
    String? search,
  }) async {
    final params =
        <String, String>{};

    if (loanId != null &&
        loanId > 0) {
      params['loan_id'] =
          loanId.toString();
    }

    if (customerId != null &&
        customerId > 0) {
      params['customer_id'] =
          customerId.toString();
    }

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    final res = await _get(
      'payments/list',
      params,
    );

    final list =
        res['data'] as List? ?? [];

    return list
        .map(
          (p) => Payment.fromJson(p),
        )
        .toList();
  }

  static Future<Map<String, dynamic>>
      addPayment(
    Map<String, dynamic> data,
  ) async {
    return await _post(
      'payments/create',
      data,
    );
  }

  // ============================================================
  // PARTIAL RELEASES
  // ============================================================

  static Future<List<PartialRelease>> getReleases({
    int? loanId,
    int? customerId,
    String? search,
  }) async {
    final params = <String, String>{};

    if (loanId != null && loanId > 0) {
      params['loan_id'] = loanId.toString();
    }

    if (customerId != null && customerId > 0) {
      params['customer_id'] = customerId.toString();
    }

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final res = await _get('releases/list', params);
    final list = res['data'] as List? ?? [];
    return list.map((r) => PartialRelease.fromJson(r)).toList();
  }

  static Future<Map<String, dynamic>>
      addPartialRelease(
    Map<String, dynamic> data,
  ) async {
    return await _post(
      'releases/create_partial',
      data,
    );
  }

  // ============================================================
  // INTEREST CALCULATION
  // ============================================================

  static Future<Map<String, dynamic>>
      calculateInterest({
    required double principal,
    double monthlyRate = 2.0,
    String? startDate,
    String? endDate,
    double? months,
  }) async {
    final params =
        <String, String>{
      'principal':
          principal.toString(),
      'monthly_rate':
          monthlyRate.toString(),
    };

    if (startDate != null &&
        startDate.isNotEmpty) {
      params['start_date'] =
          _normalizeApiDate(
        startDate,
      );
    }

    if (endDate != null &&
        endDate.isNotEmpty) {
      params['end_date'] =
          _normalizeApiDate(
        endDate,
      );
    }

    if (months != null) {
      params['months'] =
          months.toString();
    }

    final res = await _get(
      'interest/calculate',
      params,
    );

    return Map<String, dynamic>.from(
      res['data'],
    );
  }

  // ============================================================
  // TRANSACTIONS LEDGER
  // ============================================================

  static Future<List<LoanTransaction>>
      getTransactions({
    int? customerId,
    int? loanId,
    String? type,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    final params =
        <String, String>{};

    if (customerId != null &&
        customerId > 0) {
      params['customer_id'] =
          customerId.toString();
    }

    if (loanId != null &&
        loanId > 0) {
      params['loan_id'] =
          loanId.toString();
    }

    if (type != null &&
        type.trim().isNotEmpty) {
      params['type'] =
          type.trim();
    }

    if (startDate != null &&
        startDate.trim().isNotEmpty) {
      params['start_date'] =
          _normalizeApiDate(
        startDate,
      );
    }

    if (endDate != null &&
        endDate.trim().isNotEmpty) {
      params['end_date'] =
          _normalizeApiDate(
        endDate,
      );
    }

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    final res = await _get(
      'transactions/ledger',
      params,
    );

    final list =
        res['data'] as List? ?? [];

    return list
        .map(
          (t) => LoanTransaction.fromJson(t),
        )
        .toList();
  }

  // ============================================================
  // RECEIPTS
  // ============================================================

  static Future<ReceiptModel>
      getReceipt({
    String? receiptNo,
    int? loanId,
    String? type,
  }) async {
    final params =
        <String, String>{};

    if (receiptNo != null &&
        receiptNo.trim().isNotEmpty) {
      params['receipt_no'] =
          receiptNo.trim();
    }

    if (loanId != null &&
        loanId > 0) {
      params['loan_id'] =
          loanId.toString();
    }

    if (type != null &&
        type.trim().isNotEmpty) {
      params['type'] =
          type.trim();
    }

    final res = await _get(
      'receipts/get',
      params,
    );

    return ReceiptModel.fromJson(
      res['data'],
    );
  }

  // ============================================================
  // UPDATE USER PERMISSIONS
  // ============================================================

  static Future<Map<String, dynamic>> updateUserPermissions({
  required int userId,
  required List<String> permissionCodes,
}) async {
  final current = currentUser;

  final adminId = int.tryParse(
    '${current?['id'] ?? ''}',
  );

  if (adminId == null || adminId <= 0) {
    throw Exception(
      'Authenticated ADMIN user not found.',
    );
  }

  final res = await _post(
    'users/update_permissions',
    {
      'user_id': userId,
      'permission_codes': permissionCodes,
      'admin_id': adminId,
    },
  );

  return Map<String, dynamic>.from(
    res['data'] ?? res,
  );
}

  // ============================================================
  // REPORTS
  // ============================================================

  static Future<Map<String, dynamic>>
      getReports({
    String? startDate,
    String? endDate,
  }) async {
    final params =
        <String, String>{};

    if (startDate != null &&
        startDate.trim().isNotEmpty) {
      params['start_date'] =
          _normalizeApiDate(
        startDate,
      );
    }

    if (endDate != null &&
        endDate.trim().isNotEmpty) {
      params['end_date'] =
          _normalizeApiDate(
        endDate,
      );
    }

    final res = await _get(
      'reports/summary',
      params,
    );

    return Map<String, dynamic>.from(
      res['data'],
    );
  }

  // ============================================================
  // IMAGE UPLOAD
  // ============================================================

  static Future<String>
      uploadImageBase64(
    String base64Image,
    String type,
  ) async {
    final res = await _post(
      'upload',
      {
        'image_base64': base64Image,
        'image': base64Image,
        'folder': type,
        'type': type,
      },
    );

    return res['photo_url']?.toString() ??
        res['url']?.toString() ??
        res['data']?['photo_url']?.toString() ??
        res['data']?['url']?.toString() ??
        '';
  }

  // ============================================================
  // ADDITIONAL LOAN CUSTOMER SEARCH
  // ============================================================

  static Future<
      List<Map<String, dynamic>>>
      searchAdditionalCustomers(
    String search,
  ) async {
    final query =
        search.trim();

    if (query.isEmpty) {
      return [];
    }

    final res = await _get(
      'loans/search_additional_customers',
      {
        'search': query,
      },
    );

    final data =
        res['data'];

    if (data is! List) {
      return [];
    }

    return data
        .map<Map<String, dynamic>>(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  // ============================================================
  // AVAILABLE GOLD FOR ADDITIONAL LOAN
  // ============================================================

  static Future<
      List<Map<String, dynamic>>>
      getAvailableGoldForAdditional(
    int customerId,
  ) async {
    final res = await _get(
      'gold/available_for_additional',
      {
        'customer_id':
            customerId.toString(),
      },
    );

    final data =
        res['data'];

    if (data is! List) {
      return [];
    }

    return data
        .map<Map<String, dynamic>>(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  // ============================================================
  // ADDITIONAL LOAN CUSTOMER SEARCH
  // ============================================================

  static Future<
      List<Map<String, dynamic>>>
      searchAdditionalLoanCustomers(
    String query,
  ) async {
    final search =
        query.trim();

    if (search.isEmpty) {
      return [];
    }

    final res = await _get(
      'customers/search_additional',
      {
        'search': search,
        'limit': '30',
      },
    );

    final list =
        res['data'];

    if (list is! List) {
      return [];
    }

    return list
        .map<Map<String, dynamic>>(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  // ============================================================
  // USER MANAGEMENT
  // ============================================================

  static Future<
      List<Map<String, dynamic>>>
      getUsers({
    String? search,
    String? status,
    String? role,
  }) async {
    final params =
        <String, String>{};

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    if (status != null &&
        status.trim().isNotEmpty &&
        status != 'ALL') {
      params['status'] =
          status.trim().toUpperCase();
    }

    if (role != null &&
        role.trim().isNotEmpty &&
        role != 'ALL') {
      params['role'] =
          role.trim().toUpperCase();
    }

    final query = Uri(
      queryParameters: params,
    ).query;

    final endpoint = query.isEmpty
        ? 'users/list'
        : 'users/list?$query';

    final res =
        await _get(endpoint);

    final data =
        res['data'];

    if (data is List) {
      return data
          .map<Map<String, dynamic>>(
            (e) =>
                Map<String, dynamic>.from(
              e as Map,
            ),
          )
          .toList();
    }

    return [];
  }

  static Future<
      Map<String, dynamic>>
      searchUsers({
    String? search,
    String? status,
    String? role,
    int page = 1,
    int limit = 25,
  }) async {
    final params =
        <String, String>{
      'page':
          page.toString(),
      'limit':
          limit.toString(),
    };

    if (search != null &&
        search.trim().isNotEmpty) {
      params['search'] =
          search.trim();
    }

    if (status != null &&
        status.trim().isNotEmpty &&
        status != 'ALL') {
      params['status'] =
          status.trim().toUpperCase();
    }

    if (role != null &&
        role.trim().isNotEmpty &&
        role != 'ALL') {
      params['role'] =
          role.trim().toUpperCase();
    }

    final query = Uri(
      queryParameters: params,
    ).query;

    final res = await _get(
      'users/search?$query',
    );

    return Map<String, dynamic>.from(
      res,
    );
  }

  static Future<
      Map<String, dynamic>>
      getUser(
    int userId,
  ) async {
    final res = await _get(
      'users/get?user_id=$userId',
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      createUser(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'users/create',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      updateUser(
    Map<String, dynamic> data,
  ) async {
    final res = await _post(
      'users/update',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      toggleUserStatus(
    int userId,
    String status, {
    String? reason,
  }) async {
    final data =
        <String, dynamic>{
      'user_id':
          userId,
      'status':
          status.toUpperCase(),
    };

    if (reason != null &&
        reason.trim().isNotEmpty) {
      data['reason'] =
          reason.trim();
    }

    final res = await _post(
      'users/toggle_status',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      deleteUser(
    int userId, {
    String? reason,
  }) async {
    final data =
        <String, dynamic>{
      'user_id':
          userId,
    };

    if (reason != null &&
        reason.trim().isNotEmpty) {
      data['reason'] =
          reason.trim();
    }

    final res = await _post(
      'users/delete',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      getUserRoles() async {
    final res = await _get(
      'users/roles',
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      assignUserRole({
    required int userId,
    required String role,
    String? reason,
  }) async {
    final data =
        <String, dynamic>{
      'user_id':
          userId,
      'role':
          role.toUpperCase(),
    };

    if (reason != null &&
        reason.trim().isNotEmpty) {
      data['reason'] =
          reason.trim();
    }

    final res = await _post(
      'users/assign_role',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      getUserPermissions(
    int userId,
  ) async {
    final res = await _get(
      'users/permissions?user_id=$userId',
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<
      Map<String, dynamic>>
      resetUserPassword({
    required int userId,
    required String newPassword,
    String? reason,
  }) async {
    final data =
        <String, dynamic>{
      'user_id':
          userId,
      'new_password':
          newPassword,
    };

    if (reason != null &&
        reason.trim().isNotEmpty) {
      data['reason'] =
          reason.trim();
    }

    final res = await _post(
      'users/reset_password',
      data,
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  // ============================================================
  // DATABASE BACKUP & RESTORE
  // ============================================================

  static Future<Map<String, dynamic>> createDatabaseBackup() async {
    final res = await _post(
      'backup/manual_backup',
      <String, dynamic>{},
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static Future<List<Map<String, dynamic>>> getDatabaseBackups() async {
    final res = await _get(
      'backup/list_backups',
    );

    final data = res['data'];
    final list = data is Map
        ? (data['backups'] as List? ?? [])
        : (data as List? ?? []);

    return list
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> restoreDatabaseBackup(
    String fileName,
  ) async {
    final res = await _post(
      'backup/restore_backup',
      <String, dynamic>{
        'file_name': fileName,
        'confirmation': 'restore',
      },
    );

    return Map<String, dynamic>.from(
      res['data'] ?? {},
    );
  }

  static String getDatabaseBackupDownloadUrl(
    String fileName,
  ) {
    return '$baseUrl/backup/download_backup?file_name=${Uri.encodeComponent(fileName)}';
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  static Future<Map<String, dynamic>> getSettings() async {
    final res = await _get('settings/get');
    return Map<String, dynamic>.from(res['data'] ?? res);
  }

  static Future<Map<String, dynamic>> saveSettings(
    Map<String, dynamic> data,
  ) async {
    final res = await _post('settings/save', data);
    return Map<String, dynamic>.from(res['data'] ?? res);
  }

  // ============================================================
  // PHOTO URL RESOLVER
  // ============================================================

  static String? resolvePhotoUrl(String? photoUrl) {
    if (photoUrl == null) return null;
    final trimmed = photoUrl.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image')) {
      return trimmed;
    }

    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    return '$cleanBase$cleanPath';
  }
}
