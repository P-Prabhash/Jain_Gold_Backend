// lib/providers/gold_provider.dart

import 'package:flutter/material.dart';
import '../models/gold_item.dart';
import '../services/api_service.dart';

class GoldProvider extends ChangeNotifier {
  List<GoldItem> _goldItems = [];
  final Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<GoldItem> get goldItems => _goldItems;
  Map<String, dynamic> get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchGoldItems({int? customerId, String? status, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _goldItems = await ApiService.getGoldItems(
        customerId: customerId,
        status: status,
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

  Future<GoldItem?> addGoldItem(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final item = await ApiService.addGoldItem(data);
      await fetchGoldItems(customerId: data['customer_id']);
      _isLoading = false;
      notifyListeners();
      return item;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateGoldItem(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.updateGoldItem(data);
      await fetchGoldItems();
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
}
