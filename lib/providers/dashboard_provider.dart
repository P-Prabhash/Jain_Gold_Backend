// lib/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import '../models/dashboard_summary.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardSummary _summary = DashboardSummary();
  bool _isLoading = false;
  String? _errorMessage;

  DashboardSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await ApiService.getDashboard();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}
