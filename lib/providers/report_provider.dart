// lib/providers/report_provider.dart

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class ReportProvider extends ChangeNotifier {
  Map<String, dynamic> _reportsData = {};
  List<LoanTransaction> _ledgerTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> get reportsData => _reportsData;
  List<LoanTransaction> get ledgerTransactions => _ledgerTransactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchReports({String? startDate, String? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reportsData = await ApiService.getReports(startDate: startDate, endDate: endDate);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> fetchLedger({
    int? customerId,
    int? loanId,
    String? type,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _ledgerTransactions = await ApiService.getTransactions(
        customerId: customerId,
        loanId: loanId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        search: search,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}
