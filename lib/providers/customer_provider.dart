// lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/gold_item.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/release.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Selected Customer Details
  Customer? _selectedCustomer;
  CustomerSummary _customerSummary = CustomerSummary();
  List<GoldItem> _customerGoldItems = [];
  List<Loan> _customerLoans = [];
  List<Payment> _customerPayments = [];
  List<PartialRelease> _customerReleases = [];
  List<LoanTransaction> _customerTransactions = [];
  bool _isLoadingDetails = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Customer? get selectedCustomer => _selectedCustomer;
  CustomerSummary get customerSummary => _customerSummary;
  List<GoldItem> get customerGoldItems => _customerGoldItems;
  List<Loan> get customerLoans => _customerLoans;
  List<Payment> get customerPayments => _customerPayments;
  List<PartialRelease> get customerReleases => _customerReleases;
  List<LoanTransaction> get customerTransactions => _customerTransactions;
  bool get isLoadingDetails => _isLoadingDetails;

  Future<void> fetchCustomers([String? search]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _customers = await ApiService.getCustomers(search);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<Customer?> createCustomer(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newCust = await ApiService.addCustomer(data);
      await fetchCustomers();
      _isLoading = false;
      notifyListeners();
      return newCust;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCustomer(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await ApiService.updateCustomer(data);
      if (_selectedCustomer != null && _selectedCustomer!.id == updated.id) {
        _selectedCustomer = updated;
      }
      await fetchCustomers();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCustomerDetails(int customerId) async {
    _isLoadingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.getCustomerDetails(customerId);
      _selectedCustomer = Customer.fromJson(res['customer']);
      _customerSummary = CustomerSummary.fromJson(res['summary']);
      
      final rawGold = res['gold_items'] as List? ?? [];
      _customerGoldItems = rawGold.map((g) => GoldItem.fromJson(g)).toList();

      final rawLoans = res['loans'] as List? ?? [];
      _customerLoans = rawLoans.map((l) => Loan.fromJson(l)).toList();

      final rawPay = res['payments'] as List? ?? [];
      _customerPayments = rawPay.map((p) => Payment.fromJson(p)).toList();

      final rawRel = res['releases'] as List? ?? [];
      _customerReleases = rawRel.map((r) => PartialRelease.fromJson(r)).toList();

      final rawTx = res['transactions'] as List? ?? [];
      _customerTransactions = rawTx.map((t) => LoanTransaction.fromJson(t)).toList();

      _isLoadingDetails = false;
      notifyListeners();
    } catch (e) {
      _isLoadingDetails = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}
