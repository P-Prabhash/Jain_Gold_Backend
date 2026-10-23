// lib/providers/payment_provider.dart

import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPayments({int? loanId, int? customerId, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _payments = await ApiService.getPayments(
        loanId: loanId,
        customerId: customerId,
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

  Future<Map<String, dynamic>?> processPayment(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.addPayment(data);
      await fetchPayments();
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
