// lib/providers/loan_provider.dart

import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/release.dart';
import '../models/transaction.dart';
import '../models/gold_item.dart';
import '../services/api_service.dart';

class LoanProvider extends ChangeNotifier {
  // ============================================================
  // LOANS
  // ============================================================

  List<Loan> _loans = [];

  bool _isLoading = false;
  String? _errorMessage;

  // ============================================================
  // SELECTED LOAN DETAILS
  // ============================================================

  Loan? _selectedLoan;
  Customer? _loanCustomer;

  List<LoanCollateralItem> _loanCollateral = [];
  Map<String, dynamic> _collateralWeights = {};

  List<Payment> _loanPayments = [];
  List<PartialRelease> _loanReleases = [];
  List<LoanTransaction> _loanTransactions = [];

  bool _isLoadingDetails = false;

  // ============================================================
  // ADDITIONAL LOAN DATA
  // ============================================================

  /// Customer belonging to the selected existing pawn loan.
  int? _additionalLoanCustomerId;

  /// Available/unpledged gold belonging to that customer.
  List<GoldItem> _additionalLoanAvailableGold = [];

  /// Active loans belonging to the customer.
  List<Loan> _additionalLoanActiveLoans = [];

  bool _isLoadingAdditionalLoanData = false;

  // ============================================================
  // GETTERS
  // ============================================================

  List<Loan> get loans => _loans;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Loan? get selectedLoan => _selectedLoan;

  Customer? get loanCustomer => _loanCustomer;

  List<LoanCollateralItem> get loanCollateral => _loanCollateral;

  Map<String, dynamic> get collateralWeights => _collateralWeights;

  List<Payment> get loanPayments => _loanPayments;

  List<PartialRelease> get loanReleases => _loanReleases;

  List<LoanTransaction> get loanTransactions => _loanTransactions;

  bool get isLoadingDetails => _isLoadingDetails;

  // Additional Loan getters

  int? get additionalLoanCustomerId => _additionalLoanCustomerId;

  List<GoldItem> get additionalLoanAvailableGold =>
      _additionalLoanAvailableGold;

  List<Loan> get additionalLoanActiveLoans =>
      _additionalLoanActiveLoans;

  bool get isLoadingAdditionalLoanData =>
      _isLoadingAdditionalLoanData;

  // ============================================================
  // FETCH LOANS
  // ============================================================

  Future<void> fetchLoans({
    int? customerId,
    String? status,
    String? loanType,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _loans = await ApiService.getLoans(
        customerId: customerId,
        status: status,
        loanType: loanType,
        search: search,
      );

      _isLoading = false;

      notifyListeners();
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();
    }
  }

  // ============================================================
  // CREATE NEW LOAN
  // ============================================================

  Future<Map<String, dynamic>?> createNewLoan(
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res = await ApiService.createNewLoan(data);

      await fetchLoans();

      _isLoading = false;

      notifyListeners();

      return res;
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // CREATE EXISTING LOAN
  // ============================================================

  Future<Map<String, dynamic>?> createExistingLoan(
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res = await ApiService.createExistingLoan(data);

      await fetchLoans();

      _isLoading = false;

      notifyListeners();

      return res;
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // ADDITIONAL LOAN
  //
  // IMPORTANT:
  // This does NOT create a new pawn loan.
  //
  // parent_loan_id = existing ACTIVE pawn loan.
  //
  // The backend must:
  //
  // existing principal
  //       +
  // additional amount
  //       =
  // updated principal
  //
  // and:
  //
  // AVAILABLE gold
  //       ->
  // PLEDGED gold
  //
  // on the SAME loan.
  // ============================================================

  Future<Map<String, dynamic>?> createAdditionalLoan(
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res =
          await ApiService.createAdditionalLoan(data);

      // Refresh main loan list.
      await fetchLoans();

      // If the request contains the parent loan,
      // refresh its complete details as well.
      final dynamic parentLoanId =
          data['parent_loan_id'] ?? data['loan_id'];

      if (parentLoanId != null) {
        final int? loanId =
            int.tryParse(parentLoanId.toString());

        if (loanId != null) {
          await fetchLoanDetails(loanId);
        }
      }

      _isLoading = false;

      notifyListeners();

      return res;
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // LOAD ADDITIONAL LOAN DATA FROM EXISTING LOAN
  //
  // This is the important new method.
  //
  // Pass the existing loan ID.
  //
  // Example:
  //
  // await provider.loadAdditionalLoanData(4);
  //
  // It obtains:
  //
  // Loan
  //   ↓
  // Customer
  //   ↓
  // Customer's AVAILABLE Gold
  // ============================================================

  Future<void> loadAdditionalLoanData(
    int loanId,
  ) async {
    _isLoadingAdditionalLoanData = true;
    _errorMessage = null;

    _additionalLoanAvailableGold = [];
    _additionalLoanActiveLoans = [];
    _additionalLoanCustomerId = null;

    notifyListeners();

    try {
      // --------------------------------------------------------
      // 1. Get complete existing loan
      // --------------------------------------------------------

      final res =
          await ApiService.getLoanDetails(loanId);

      if (res['loan'] == null) {
        throw Exception(
          'Existing pawn loan was not found.',
        );
      }

      final loan =
          Loan.fromJson(res['loan']);

      _selectedLoan = loan;

      // --------------------------------------------------------
      // 2. Get customer
      // --------------------------------------------------------

      if (res['customer'] != null) {
        _loanCustomer =
            Customer.fromJson(res['customer']);

        _additionalLoanCustomerId =
            _loanCustomer!.id;
      }

      // --------------------------------------------------------
      // 3. If customer wasn't returned by details endpoint,
      //    try getting customer_id directly from loan.
      // --------------------------------------------------------

      if (_additionalLoanCustomerId == null) {
        final dynamic customerId =
            _getCustomerIdFromLoan(loan);

        if (customerId != null) {
          _additionalLoanCustomerId = customerId;
        }
      }

      if (_additionalLoanCustomerId == null) {
        throw Exception(
          'Customer information is missing for loan ${loan.loanNo}.',
        );
      }

      // --------------------------------------------------------
      // 4. Load customer's ACTIVE loans
      // --------------------------------------------------------

      final customerLoans =
          await ApiService.getLoans(
        customerId: _additionalLoanCustomerId,
      );

      _additionalLoanActiveLoans =
          customerLoans.where((l) {
        return l.status.toUpperCase() == 'ACTIVE';
      }).toList();

      // --------------------------------------------------------
      // 5. Load customer's AVAILABLE gold
      //
      // AVAILABLE means:
      //
      // status = AVAILABLE
      //
      // These items are not currently pledged.
      // --------------------------------------------------------

      _additionalLoanAvailableGold =
          await ApiService.getGoldItems(
        customerId: _additionalLoanCustomerId,
        status: 'AVAILABLE',
      );

      // --------------------------------------------------------
      // 6. Load existing loan detail data
      // --------------------------------------------------------

      final rawCol =
          res['collateral'] as List? ?? [];

      _loanCollateral = rawCol
          .map(
            (c) => LoanCollateralItem.fromJson(c),
          )
          .toList();

      _collateralWeights =
          res['weights'] is Map
              ? Map<String, dynamic>.from(
                  res['weights'],
                )
              : {};

      final rawPay =
          res['payments'] as List? ?? [];

      _loanPayments = rawPay
          .map(
            (p) => Payment.fromJson(p),
          )
          .toList();

      final rawRel =
          res['releases'] as List? ?? [];

      _loanReleases = rawRel
          .map(
            (r) => PartialRelease.fromJson(r),
          )
          .toList();

      final rawTx =
          res['transactions'] as List? ?? [];

      _loanTransactions = rawTx
          .map(
            (t) => LoanTransaction.fromJson(t),
          )
          .toList();

      _isLoadingAdditionalLoanData = false;

      notifyListeners();
    } catch (e) {
      _isLoadingAdditionalLoanData = false;

      _additionalLoanAvailableGold = [];
      _additionalLoanActiveLoans = [];

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();
    }
  }

  // ============================================================
  // LOAD AVAILABLE GOLD FOR A LOAN
  //
  // Useful when the loan is already known and you only want
  // to refresh available gold.
  // ============================================================

  Future<List<GoldItem>> fetchAvailableGoldForLoan(
    int loanId,
  ) async {
    try {
      final res =
          await ApiService.getLoanDetails(loanId);

      int? customerId;

      // First preference: customer object returned by API.
      if (res['customer'] != null) {
        final customer =
            Customer.fromJson(res['customer']);

        customerId = customer.id;

        _loanCustomer = customer;
        _additionalLoanCustomerId = customer.id;
      }

      // Second preference: loan.customer_id.
      if (customerId == null &&
          res['loan'] != null) {
        final loan =
            Loan.fromJson(res['loan']);

        customerId =
            _getCustomerIdFromLoan(loan);

        if (customerId != null) {
          _additionalLoanCustomerId = customerId;
        }
      }

      if (customerId == null) {
        throw Exception(
          'Unable to determine customer for this pawn loan.',
        );
      }

      final gold =
          await ApiService.getGoldItems(
        customerId: customerId,
        status: 'AVAILABLE',
      );

      _additionalLoanAvailableGold = gold;

      notifyListeners();

      return gold;
    } catch (e) {
      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return [];
    }
  }

  // ============================================================
  // GET CUSTOMER ID FROM LOAN
  //
  // Your Loan model may expose customerId.
  // This helper keeps the provider tolerant of nullable values.
  // ============================================================

  int? _getCustomerIdFromLoan(Loan loan) {
    try {
      final dynamic value =
          loan.customerId;

      if (value == null) {
        return null;
      }

      if (value is int) {
        return value;
      }

      return int.tryParse(
        value.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // CLEAR ADDITIONAL LOAN STATE
  // ============================================================

  void clearAdditionalLoanData() {
    _additionalLoanCustomerId = null;

    _additionalLoanAvailableGold = [];

    _additionalLoanActiveLoans = [];

    notifyListeners();
  }

  // ============================================================
  // FETCH COMPLETE LOAN DETAILS
  // ============================================================

  Future<void> fetchLoanDetails(
    int loanId,
  ) async {
    _isLoadingDetails = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res =
          await ApiService.getLoanDetails(loanId);

      // --------------------------------------------------------
      // Loan
      // --------------------------------------------------------

      if (res['loan'] != null) {
        _selectedLoan =
            Loan.fromJson(res['loan']);
      } else {
        throw Exception(
          'Loan details not found.',
        );
      }

      // --------------------------------------------------------
      // Customer
      // --------------------------------------------------------

      if (res['customer'] != null) {
        _loanCustomer =
            Customer.fromJson(
          res['customer'],
        );
      } else {
        _loanCustomer = null;
      }

      // --------------------------------------------------------
      // Collateral
      // --------------------------------------------------------

      final rawCol =
          res['collateral'] as List? ?? [];

      _loanCollateral = rawCol
          .map(
            (c) => LoanCollateralItem.fromJson(c),
          )
          .toList();

      // --------------------------------------------------------
      // Collateral weights
      // --------------------------------------------------------

      _collateralWeights =
          res['weights'] is Map
              ? Map<String, dynamic>.from(
                  res['weights'],
                )
              : {};

      // --------------------------------------------------------
      // Payments
      // --------------------------------------------------------

      final rawPay =
          res['payments'] as List? ?? [];

      _loanPayments = rawPay
          .map(
            (p) => Payment.fromJson(p),
          )
          .toList();

      // --------------------------------------------------------
      // Releases
      // --------------------------------------------------------

      final rawRel =
          res['releases'] as List? ?? [];

      _loanReleases = rawRel
          .map(
            (r) => PartialRelease.fromJson(r),
          )
          .toList();

      // --------------------------------------------------------
      // Transactions
      // --------------------------------------------------------

      final rawTx =
          res['transactions'] as List? ?? [];

      _loanTransactions = rawTx
          .map(
            (t) => LoanTransaction.fromJson(t),
          )
          .toList();

      _isLoadingDetails = false;

      notifyListeners();
    } catch (e) {
      _isLoadingDetails = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();
    }
  }

  // ============================================================
  // CLOSE / SETTLE LOAN
  // ============================================================

  Future<Map<String, dynamic>?> closeOrSettleLoan(
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final res =
          await ApiService.closeLoan(data);

      final dynamic rawLoanId =
          data['loan_id'];

      final int? loanId =
          int.tryParse(
        rawLoanId?.toString() ?? '',
      );

      // Refresh currently selected loan.
      if (loanId != null) {
        if (_selectedLoan != null &&
            _selectedLoan!.id == loanId) {
          await fetchLoanDetails(loanId);
        }
      }

      // Refresh loan list.
      await fetchLoans();

      _isLoading = false;

      notifyListeners();

      return res;
    } catch (e) {
      _isLoading = false;

      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return null;
    }
  }
}