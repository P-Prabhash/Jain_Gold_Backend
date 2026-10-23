// lib/providers/release_provider.dart

import 'package:flutter/material.dart';
import '../models/release.dart';
import '../services/api_service.dart';

class ReleaseProvider extends ChangeNotifier {
  List<PartialRelease> _releases = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PartialRelease> get releases => _releases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchReleases({int? loanId, int? customerId, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _releases = await ApiService.getReleases(loanId: loanId, customerId: customerId, search: search);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> processPartialRelease(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.addPartialRelease(data);
      await fetchReleases();
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
