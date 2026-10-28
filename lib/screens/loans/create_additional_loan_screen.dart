import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/gold_item.dart';
import '../../models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/success_dialog.dart';

class CreateAdditionalLoanScreen extends StatefulWidget {
  final int? preselectedCustomerId;

  const CreateAdditionalLoanScreen({
    super.key,
    this.preselectedCustomerId,
  });

  @override
  State<CreateAdditionalLoanScreen> createState() =>
      _CreateAdditionalLoanScreenState();
}

class _CreateAdditionalLoanScreenState
    extends State<CreateAdditionalLoanScreen> {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // ADDITIONAL LOAN TYPES
  // ============================================================

  static const String goldAdded = 'GOLD_ITEM';
  static const String amountOnly = 'AMOUNT_ONLY';

  String _additionalType = goldAdded;

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  final TextEditingController _customerSearchCtrl =
      TextEditingController();

  Timer? _searchDebounce;

  bool _isSearchingCustomers = false;

  List<Map<String, dynamic>> _customerResults = [];

  Map<String, dynamic>? _selectedCustomer;

  // ============================================================
  // EXISTING LOANS
  // ============================================================

  int? _selectedLoanId;

  List<Loan> _existingLoans = [];

  // ============================================================
  // AVAILABLE GOLD
  // ============================================================

  List<GoldItem> _customerAvailableGold = [];

  final Set<int> _selectedGoldItemIds = {};

  double _totalPledgedWeight = 0.0;

  // ============================================================
  // FORM
  // ============================================================

  final TextEditingController _principalCtrl =
      TextEditingController();

  final TextEditingController _manualInterestCtrl =
      TextEditingController(text: '0.00');

  final TextEditingController _monthlyRateCtrl =
      TextEditingController(text: '2.00');

  final TextEditingController _remarksCtrl =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoadingCustomerData = false;
  bool _isSubmitting = false;

  Loan? get _selectedLoan {
    if (_selectedLoanId == null) {
      return null;
    }

    for (final loan in _existingLoans) {
      if (loan.id == _selectedLoanId) {
        return loan;
      }
    }

    return null;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (widget.preselectedCustomerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadCustomerById(
          widget.preselectedCustomerId!,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _customerSearchCtrl.dispose();
    _principalCtrl.dispose();
    _manualInterestCtrl.dispose();
    _monthlyRateCtrl.dispose();
    _remarksCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  void _onCustomerSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _customerResults = [];
        _isSearchingCustomers = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchCustomers(query),
    );
  }

  Future<void> _searchCustomers(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearchingCustomers = true;
    });

    try {
      final results =
          await ApiService.searchAdditionalLoanCustomers(
        query,
      );

      if (!mounted) return;

      setState(() {
        _customerResults = results;
        _isSearchingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _customerResults = [];
        _isSearchingCustomers = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer search failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  Future<void> _loadCustomerById(int customerId) async {
    try {
      final data = await ApiService.getCustomerDetails(customerId);
      if (data['customer'] is Map) {
        final cust = Map<String, dynamic>.from(data['customer'] as Map);
        await _selectCustomer(cust);
      }
    } catch (_) {}
  }

  // ============================================================
  // SELECT CUSTOMER
  // ============================================================

  Future<void> _selectCustomer(
    Map<String, dynamic> customer,
  ) async {
    final customerId = int.tryParse(
      '${customer['customer_id'] ?? customer['id'] ?? 0}',
    );

    if (customerId == null || customerId <= 0) {
      return;
    }

    FocusScope.of(context).unfocus();

    final cName = customer['name'] ?? customer['customer_name'] ?? '';
    final cCode = customer['customer_code'] ?? '';

    setState(() {
      _selectedCustomer = customer;

      _customerSearchCtrl.text =
          '$cName ($cCode)'.trim();

      _customerResults = [];

      _selectedLoanId = null;
      _existingLoans = [];

      _customerAvailableGold = [];

      _selectedGoldItemIds.clear();

      _totalPledgedWeight = 0;

      _isLoadingCustomerData = true;
    });

    try {
      final loans = await ApiService.getLoans(
        customerId: customerId,
      );

      final gold = await ApiService.getGoldItems(
        customerId: customerId,
        status: 'AVAILABLE',
      );

      final activeLoans = loans.where((loan) {
        final st = loan.status.toUpperCase();
        return st != 'CLOSED';
      }).toList();

      int? autoLoanId;
      if (activeLoans.length == 1) {
        autoLoanId = activeLoans.first.id;
      }

      if (!mounted) return;

      setState(() {
        _existingLoans = activeLoans;
        _selectedLoanId = autoLoanId;
        _customerAvailableGold = gold;
        _isLoadingCustomerData = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _existingLoans = [];
        _customerAvailableGold = [];
        _isLoadingCustomerData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load customer loan/gold data: $e',
          ),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  // ============================================================
  // CLEAR CUSTOMER
  // ============================================================

  void _clearCustomer() {
    if (_isSubmitting) return;

    setState(() {
      _selectedCustomer = null;

      _selectedLoanId = null;

      _existingLoans = [];

      _customerAvailableGold = [];

      _selectedGoldItemIds.clear();

      _totalPledgedWeight = 0;

      _customerSearchCtrl.clear();
    });
  }

  // ============================================================
  // SELECT LOAN
  // ============================================================

  void _selectLoan(int? loanId) {
    setState(() {
      _selectedLoanId = loanId;

      _selectedGoldItemIds.clear();

      _totalPledgedWeight = 0;
    });
  }

  // ============================================================
  // GOLD SELECTION
  // ============================================================

  void _toggleGoldSelection(
    GoldItem item,
  ) {
    if (_additionalType != goldAdded) {
      return;
    }

    setState(() {
      if (_selectedGoldItemIds.contains(item.id)) {
        _selectedGoldItemIds.remove(item.id);

        _totalPledgedWeight -= item.weight;

        if (_totalPledgedWeight < 0) {
          _totalPledgedWeight = 0;
        }
      } else {
        _selectedGoldItemIds.add(item.id);

        _totalPledgedWeight += item.weight;
      }
    });
  }

  // ============================================================
  // CHANGE ADDITIONAL TYPE
  // ============================================================

  void _changeAdditionalType(
    String type,
  ) {
    if (_isSubmitting) return;

    setState(() {
      _additionalType = type;

      if (type == amountOnly) {
        _selectedGoldItemIds.clear();
        _totalPledgedWeight = 0;
      }
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomer == null) {
      _showError(
        'Please search and select a customer.',
      );
      return;
    }

    if (_selectedLoanId == null) {
      _showError(
        'Please select an active pawn loan.',
      );
      return;
    }

    final principal = double.tryParse(_principalCtrl.text.trim()) ?? 0.0;
    if (principal <= 0) {
      _showError('Enter a valid additional loan amount.');
      return;
    }

    final manualInterest = double.tryParse(_manualInterestCtrl.text.trim()) ?? 0.0;
    if (manualInterest < 0) {
      _showError('Manual interest cannot be negative.');
      return;
    }

    final monthlyRate = double.tryParse(_monthlyRateCtrl.text.trim()) ?? 2.0;
    if (monthlyRate < 0) {
      _showError('Monthly rate cannot be negative.');
      return;
    }

    // Auto-detect type: if user selected new available gold items, set to goldAdded (GOLD_ITEM),
    // otherwise set to amountOnly (AMOUNT_ONLY - top-up against existing pledged collateral).
    final typeToSubmit = _selectedGoldItemIds.isNotEmpty ? goldAdded : amountOnly;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<LoanProvider>();

      final data = <String, dynamic>{
        'customer_id': int.tryParse(
          '${_selectedCustomer!['id'] ?? _selectedCustomer!['customer_id'] ?? 0}',
        ) ?? 0,
        'loan_id': _selectedLoanId,
        'parent_loan_id': _selectedLoanId,
        'additional_type': typeToSubmit,
        'gold_item_ids': typeToSubmit == goldAdded ? _selectedGoldItemIds.toList() : <int>[],
        'principal_amount': principal,
        'additional_amount': principal,
        'initial_interest': manualInterest,
        'manual_interest': manualInterest,
        'monthly_interest_rate': monthlyRate,
        'interest_type': 'MONTHLY_SIMPLE',
        'remarks': _remarksCtrl.text.trim(),
      };

      final res = await provider.createAdditionalLoan(
        data,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (res != null &&
          res['success'] == true) {
        final receipt = res['data']?['receipt'] ?? res['receipt'];

        SuccessDialog.show(
          context: context,
          title: 'Additional Loan Created Successfully',
          message: 'Additional pawn loan has been saved successfully.',
          onOk: () {
            Navigator.of(context).pop(true);
          },
          printLabel: 'Print Receipt',
          onPrint: () {
            Navigator.of(context).pop(true);
            if (receipt != null) {
              showDialog(
                context: context,
                builder: (_) => A4ReceiptViewer(
                  receiptData: receipt is Map<String, dynamic>
                      ? receipt
                      : Map<String, dynamic>.from(receipt as Map),
                ),
              );
            }
          },
        );
        return;
      }

      _showError(
        provider.errorMessage ??
            'Unable to update pawn loan.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showError(
        'Additional loan error: $e',
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            AppTheme.statusDanger,
      ),
    );
  }

  // ============================================================
  // LOAN CARD
  // ============================================================

  Widget _buildLoanCard(
    Loan loan,
  ) {
    final selected =
        _selectedLoanId == loan.id;

    return InkWell(
      onTap: () =>
          _selectLoan(loan.id),
      borderRadius:
          BorderRadius.circular(10),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 8,
        ),
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color: selected
              ? AppTheme.goldLight
              : Colors.white,
          borderRadius:
              BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : AppTheme.silverBorder,
            width:
                selected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: loan.id,
              activeColor:
                  AppTheme.goldDark,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.loanNo,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      color:
                          AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Opened: ${AppConstants.formatDate(loan.openedDate)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          AppTheme.silverDark,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                const Text(
                  'Principal',
                  style:
                      TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
                Text(
                  AppConstants.formatCurrency(
                    loan.principalAmount,
                  ),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Outstanding ${AppConstants.formatCurrency(loan.remainingBalance)}',
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.goldDark,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GoldBadge(
              status: loan.status,
              fontSize: 8,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GOLD CARD
  // ============================================================

  Widget _buildGoldCard(
    GoldItem item,
  ) {
    final selected =
        _selectedGoldItemIds
            .contains(item.id);

    return InkWell(
      onTap: _selectedLoanId == null
          ? null
          : () =>
              _toggleGoldSelection(item),
      borderRadius:
          BorderRadius.circular(10),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 8,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration:
            BoxDecoration(
          color: selected
              ? AppTheme.goldLight
              : Colors.white,
          borderRadius:
              BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : AppTheme.silverBorder,
            width:
                selected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor:
                  AppTheme.goldDark,
              onChanged:
                  _selectedLoanId == null
                      ? null
                      : (_) =>
                          _toggleGoldSelection(
                            item,
                          ),
            ),
            const Icon(
              Icons.diamond,
              color:
                  AppTheme.goldDark,
              size: 22,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.itemName} • ${item.purity}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Weight: ${AppConstants.formatWeight(item.weight)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          AppTheme.silverDark,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'AVAILABLE',
              style:
                  TextStyle(
                fontSize: 9,
                fontWeight:
                    FontWeight.bold,
                color:
                    AppTheme.statusActive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TYPE CARD
  // ============================================================

  Widget _buildTypeCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected =
        _additionalType == type;

    return InkWell(
      onTap: _isSubmitting
          ? null
          : () =>
              _changeAdditionalType(
                type,
              ),
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          color: selected
              ? AppTheme.goldLight
              : Colors.white,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : AppTheme.silverBorder,
            width:
                selected ? 1.6 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? AppTheme.goldDark
                  : AppTheme.silverDark,
            ),
            const SizedBox(
              width: 10,
            ),
            Container(
              padding:
                  const EdgeInsets.all(9),
              decoration:
                  BoxDecoration(
                color: selected
                    ? AppTheme.goldPrimary
                    : AppTheme.silverLight,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color:
                    AppTheme.darkNavy,
                size: 20,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      fontSize: 10,
                      color:
                          AppTheme.silverDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style:
                const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _submitButton() {
    if (_isSubmitting) {
      return const SizedBox(
        height: 20,
        width: 20,
        child:
            CircularProgressIndicator(
          color: AppTheme.darkNavy,
          strokeWidth: 2,
        ),
      );
    }

    return const Text(
      'UPDATE PAWN LOAN',
      style:
          TextStyle(
        fontWeight:
            FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final screenWidth =
            MediaQuery.of(context)
                .size
                .width;

        final isMobile =
            screenWidth < 600;

        final maxWidth =
            screenWidth >= 1200
                ? 850.0
                : screenWidth >= 600
                    ? 760.0
                    : screenWidth - 20;

        return Container(
          width: isMobile ? double.infinity : maxWidth,
          height: isMobile ? MediaQuery.of(context).size.height : null,
          constraints: BoxConstraints(
            maxHeight: isMobile
                ? double.infinity
                : MediaQuery.of(context).size.height * 0.94,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              isMobile ? 0 : 16,
            ),
            boxShadow: isMobile
                ? null
                : const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // HEADER
              Container(
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      isMobile ? 16 : 24,
                  vertical:
                      isMobile ? 13 : 16,
                ),
                decoration:
                    const BoxDecoration(
                  color:
                      AppTheme.darkNavy,
                  borderRadius:
                      BorderRadius.vertical(
                    top:
                        Radius.circular(
                      16,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_card,
                      color:
                          AppTheme.goldPrimary,
                      size: 22,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Additional Loan',
                        style:
                            GoogleFonts
                                .plusJakartaSans(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.bold,
                          fontSize:
                              isMobile
                                  ? 14
                                  : 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(
                        Icons.close,
                        color:
                            Colors.white70,
                      ),
                      onPressed:
                          _isSubmitting
                              ? null
                              : () =>
                                  Navigator.of(
                                    context,
                                  ).pop(),
                    ),
                  ],
                ),
              ),

              // BODY
              Flexible(
                child:
                    SingleChildScrollView(
                  padding:
                      EdgeInsets.all(
                    isMobile ? 14 : 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        // INFO
                        Container(
                          padding:
                              const EdgeInsets
                                  .all(12),
                          decoration:
                              BoxDecoration(
                            color:
                                AppTheme
                                    .silverLight,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                            border:
                                Border.all(
                              color:
                                  AppTheme
                                      .silverBorder,
                            ),
                          ),
                          child:
                              const Row(
                            children: [
                              Icon(
                                Icons
                                    .info_outline,
                                size: 18,
                                color:
                                    AppTheme
                                        .goldDark,
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              Expanded(
                                child:
                                    Text(
                                  'Additional loan is applied to the selected ACTIVE pawn loan. Choose either new available gold collateral or an additional amount against the existing collateral.',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        11,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // TYPE
                        Text(
                          'Additional Loan Type',
                          style:
                              GoogleFonts
                                  .plusJakartaSans(
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                AppTheme
                                    .darkNavy,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        LayoutBuilder(
                          builder:
                              (context,
                                  typeConstraints) {
                            final compact =
                                typeConstraints
                                        .maxWidth <
                                    520;

                            if (compact) {
                              return Column(
                                children: [
                                  _buildTypeCard(
                                    type:
                                        goldAdded,
                                    icon:
                                        Icons
                                            .diamond,
                                    title:
                                        'Add New Gold',
                                    subtitle:
                                        'Add available gold as new collateral',
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  _buildTypeCard(
                                    type:
                                        amountOnly,
                                    icon:
                                        Icons
                                            .currency_rupee,
                                    title:
                                        'Additional Amount Only',
                                    subtitle:
                                        'Give amount against existing gold',
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child:
                                      _buildTypeCard(
                                    type:
                                        goldAdded,
                                    icon:
                                        Icons
                                            .diamond,
                                    title:
                                        'Add New Gold',
                                    subtitle:
                                        'Add available gold as new collateral',
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child:
                                      _buildTypeCard(
                                    type:
                                        amountOnly,
                                    icon:
                                        Icons
                                            .currency_rupee,
                                    title:
                                        'Additional Amount Only',
                                    subtitle:
                                        'Give amount against existing gold',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        // CUSTOMER SEARCH
                        Text(
                          'Search Customer / Loan',
                          style:
                              GoogleFonts
                                  .plusJakartaSans(
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                AppTheme
                                    .darkNavy,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        TextField(
                          controller:
                              _customerSearchCtrl,
                          onChanged:
                              _onCustomerSearchChanged,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Name / Mobile / Aadhaar / Customer No / Loan No',
                            hintText:
                                'Type at least 2 characters...',
                            prefixIcon:
                                const Icon(
                              Icons.search,
                              color:
                                  AppTheme
                                      .goldDark,
                            ),
                            suffixIcon:
                                _isSearchingCustomers
                                    ? const Padding(
                                        padding:
                                            EdgeInsets
                                                .all(
                                          12,
                                        ),
                                        child:
                                            SizedBox(
                                          width:
                                              18,
                                          height:
                                              18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                AppTheme
                                                    .goldPrimary,
                                          ),
                                        ),
                                      )
                                    : null,
                          ),
                        ),

                        // RESULTS
                        if (_customerResults
                            .isNotEmpty)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              top: 6,
                            ),
                            constraints:
                                const BoxConstraints(
                              maxHeight:
                                  280,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppTheme
                                        .silverBorder,
                              ),
                              boxShadow:
                                  const [
                                BoxShadow(
                                  color:
                                      Colors
                                          .black12,
                                  blurRadius:
                                      10,
                                ),
                              ],
                            ),
                            child:
                                ListView
                                    .builder(
                              shrinkWrap:
                                  true,
                              itemCount:
                                  _customerResults
                                      .length,
                              itemBuilder:
                                  (context,
                                      index) {
                                final customer =
                                    _customerResults[
                                        index];

                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense:
                                        true,
                                    leading:
                                        const CircleAvatar(
                                      backgroundColor:
                                          AppTheme
                                              .goldLight,
                                      child:
                                          Icon(
                                        Icons
                                            .person,
                                        color:
                                            AppTheme
                                                .goldDark,
                                      ),
                                    ),
                                    title:
                                        Text(
                                      '${customer['name'] ?? customer['customer_name'] ?? '-'}',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                    subtitle:
                                        Text(
                                      'Customer: ${customer['customer_code'] ?? '-'}\n'
                                      'Mobile: ${customer['mobile'] ?? '-'}\n'
                                      'Aadhaar: ${customer['aadhaar_number'] ?? customer['aadhaar'] ?? '-'}\n'
                                      'Loans: ${customer['existing_loans_count'] ?? 1} active loan(s)',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            10,
                                      ),
                                    ),
                                    isThreeLine:
                                        true,
                                    trailing:
                                        const Icon(
                                      Icons
                                          .arrow_forward_ios,
                                      size:
                                          14,
                                      color:
                                          AppTheme
                                              .goldDark,
                                    ),
                                    onTap:
                                        () =>
                                            _selectCustomer(
                                      customer,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        // SELECTED CUSTOMER
                        if (_selectedCustomer !=
                            null)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              top: 10,
                            ),
                            padding:
                                const EdgeInsets
                                    .all(
                              12,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppTheme
                                      .goldLight,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppTheme
                                        .goldPrimary,
                              ),
                            ),
                            child:
                                Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor:
                                      AppTheme
                                          .goldPrimary,
                                  child:
                                      Icon(
                                    Icons
                                        .person,
                                    color:
                                        AppTheme
                                            .darkNavy,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        '${_selectedCustomer!['name'] ?? '-'}',
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      Text(
                                        '${_selectedCustomer!['customer_code'] ?? '-'} • ${_selectedCustomer!['mobile'] ?? '-'}',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              11,
                                          color:
                                              AppTheme
                                                  .silverDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      _clearCustomer,
                                  icon:
                                      const Icon(
                                    Icons.clear,
                                    color:
                                        AppTheme
                                            .statusDanger,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(
                          height: 20,
                        ),

                        // ACTIVE LOANS
                        Text(
                          '1. Select Existing Active Pawn Loan',
                          style:
                              GoogleFonts
                                  .plusJakartaSans(
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                AppTheme
                                    .darkNavy,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Container(
                          constraints:
                              const BoxConstraints(
                            maxHeight:
                                210,
                          ),
                          padding:
                              const EdgeInsets
                                  .all(8),
                          decoration:
                              BoxDecoration(
                            color:
                                AppTheme
                                    .silverLight,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                            border:
                                Border.all(
                              color:
                                  AppTheme
                                      .silverBorder,
                            ),
                          ),
                          child:
                              _isLoadingCustomerData
                                  ? const Center(
                                      child:
                                          CircularProgressIndicator(
                                        color:
                                            AppTheme
                                                .goldPrimary,
                                      ),
                                    )
                                  : _selectedCustomer ==
                                          null
                                      ? const Center(
                                          child:
                                              Text(
                                            'Search and select a customer first.',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  11,
                                              color:
                                                  AppTheme
                                                      .silverDark,
                                            ),
                                          ),
                                        )
                                      : _existingLoans
                                              .isEmpty
                                          ? const Center(
                                              child:
                                                  Text(
                                                'No ACTIVE pawn loan found.',
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      11,
                                                  color:
                                                      AppTheme
                                                          .silverDark,
                                                ),
                                              ),
                                            )
                                          : RadioGroup<int>(
                                              groupValue:
                                                  _selectedLoanId,
                                              onChanged:
                                                  _selectLoan,
                                              child:
                                                  ListView.builder(
                                                shrinkWrap:
                                                    true,
                                                itemCount:
                                                    _existingLoans
                                                        .length,
                                                itemBuilder:
                                                    (context,
                                                        index) {
                                                  return _buildLoanCard(
                                                    _existingLoans[
                                                        index],
                                                  );
                                                },
                                              ),
                                            ),
                        ),

                        // GOLD
                        if (_additionalType ==
                            goldAdded) ...[
                          const SizedBox(
                            height: 18,
                          ),
                          Text(
                            '2. Select Available Gold',
                            style:
                                GoogleFonts
                                    .plusJakartaSans(
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  AppTheme
                                      .darkNavy,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Container(
                            constraints:
                                const BoxConstraints(
                              maxHeight:
                                  230,
                            ),
                            padding:
                                const EdgeInsets
                                    .all(8),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppTheme
                                      .silverLight,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppTheme
                                        .silverBorder,
                              ),
                            ),
                            child:
                                _selectedLoanId ==
                                        null
                                    ? const Center(
                                        child:
                                            Text(
                                          'Select an active pawn loan first.',
                                          style:
                                              TextStyle(
                                            fontSize:
                                                11,
                                            color:
                                                AppTheme
                                                    .silverDark,
                                          ),
                                        ),
                                      )
                                    : _customerAvailableGold
                                            .isEmpty
                                        ? const Center(
                                            child:
                                                Text(
                                              'No AVAILABLE gold items for this customer.',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    AppTheme
                                                        .silverDark,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            shrinkWrap:
                                                true,
                                            itemCount:
                                                _customerAvailableGold
                                                    .length,
                                            itemBuilder:
                                                (context,
                                                    index) {
                                              return _buildGoldCard(
                                                _customerAvailableGold[
                                                    index],
                                              );
                                            },
                                          ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              Text(
                                'Selected: ${_selectedGoldItemIds.length} item(s)',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  color:
                                      AppTheme
                                          .silverDark,
                                ),
                              ),
                              Text(
                                'Collateral: ${AppConstants.formatWeight(_totalPledgedWeight)}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      AppTheme
                                          .goldDark,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // AMOUNT ONLY INFO
                        if (_additionalType ==
                            amountOnly)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              top: 18,
                            ),
                            padding:
                                const EdgeInsets
                                    .all(
                              12,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppTheme
                                      .silverLight,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppTheme
                                        .silverBorder,
                              ),
                            ),
                            child:
                                const Row(
                              children: [
                                Icon(
                                  Icons
                                      .account_balance_wallet,
                                  size:
                                      18,
                                  color:
                                      AppTheme
                                          .goldDark,
                                ),
                                SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child:
                                      Text(
                                    'No new gold will be added. The selected existing pawn loan collateral remains unchanged and the additional amount is added to that pawn loan.',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(
                          height: 18,
                        ),

                        // AMOUNT + MANUAL INTEREST FIELDS
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 500;

                            final amountField = TextFormField(
                              controller: _principalCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Additional Amount (₹) *',
                                hintText: 'e.g. 5000',
                                prefixIcon: Icon(
                                  Icons.currency_rupee,
                                  color: AppTheme.goldDark,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Additional amount is required';
                                }
                                final amount = double.tryParse(value.trim());
                                if (amount == null || amount <= 0) {
                                  return 'Enter valid amount';
                                }
                                return null;
                              },
                            );

                            final manualInterestField = TextFormField(
                              controller: _manualInterestCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Initial / Manual Interest (₹)',
                                hintText: 'e.g. 100',
                                prefixIcon: Icon(
                                  Icons.percent_outlined,
                                  color: AppTheme.goldDark,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return null;
                                final amount = double.tryParse(value.trim());
                                if (amount == null || amount < 0) {
                                  return 'Enter valid interest amount';
                                }
                                return null;
                              },
                            );

                            if (compact) {
                              return Column(
                                children: [
                                  amountField,
                                  const SizedBox(height: 14),
                                  manualInterestField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: amountField),
                                const SizedBox(width: 12),
                                Expanded(child: manualInterestField),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // RATE + REMARKS
                        LayoutBuilder(
                          builder: (context, fieldConstraints) {
                            final rateField = TextFormField(
                              controller: _monthlyRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Monthly Rate (%)',
                                suffixText: '% / mo',
                                prefixIcon: Icon(
                                  Icons.percent,
                                  color: AppTheme.goldDark,
                                ),
                              ),
                            );

                            final remarksField = TextFormField(
                              controller: _remarksCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Remarks (Optional)',
                                prefixIcon: Icon(
                                  Icons.notes,
                                  color: AppTheme.silverDark,
                                ),
                              ),
                            );

                            if (fieldConstraints.maxWidth < 500) {
                              return Column(
                                children: [
                                  rateField,
                                  const SizedBox(height: 14),
                                  remarksField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: rateField),
                                const SizedBox(width: 12),
                                Expanded(child: remarksField),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // SUMMARY
                        if (_selectedLoan != null)
                          Builder(
                            builder: (context) {
                              final additionalVal = double.tryParse(_principalCtrl.text.trim()) ?? 0.0;
                              final interestVal = double.tryParse(_manualInterestCtrl.text.trim()) ?? 0.0;
                              final newPrincipalVal = _selectedLoan!.principalAmount + additionalVal;
                              final newBalanceVal = _selectedLoan!.remainingBalance + additionalVal + interestVal;

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkNavy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ADDITIONAL LOAN SUMMARY',
                                      style: TextStyle(
                                        color: AppTheme.goldPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _summaryRow(
                                      'Pawn Loan No',
                                      _selectedLoan!.loanNo,
                                    ),
                                    _summaryRow(
                                      'Current Principal',
                                      AppConstants.formatCurrency(_selectedLoan!.principalAmount),
                                    ),
                                    _summaryRow(
                                      'Current Balance / Due',
                                      AppConstants.formatCurrency(_selectedLoan!.remainingBalance),
                                    ),
                                    _summaryRow(
                                      'New Additional Amount',
                                      AppConstants.formatCurrency(additionalVal),
                                    ),
                                    if (interestVal > 0)
                                      _summaryRow(
                                        'Initial Interest Charged',
                                        AppConstants.formatCurrency(interestVal),
                                      ),
                                    const Divider(color: Colors.white24, height: 16),
                                    _summaryRow(
                                      'NEW TOTAL PRINCIPAL',
                                      AppConstants.formatCurrency(newPrincipalVal),
                                    ),
                                    _summaryRow(
                                      'NEW REMAINING BALANCE / DUE',
                                      AppConstants.formatCurrency(newBalanceVal),
                                    ),
                                    _summaryRow(
                                      'New Gold Collateral',
                                      _selectedGoldItemIds.isNotEmpty
                                          ? AppConstants.formatWeight(_totalPledgedWeight)
                                          : '0.00g (Existing Collateral)',
                                    ),
                                    if (_selectedGoldItemIds.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Existing collateral unchanged',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(
                          height: 22,
                        ),

                        // BUTTONS
                        LayoutBuilder(
                          builder:
                              (context,
                                  buttonConstraints) {
                            if (buttonConstraints
                                    .maxWidth <
                                420) {
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .stretch,
                                children: [
                                  OutlinedButton(
                                    onPressed:
                                        _isSubmitting
                                            ? null
                                            : () =>
                                                Navigator.of(
                                                  context,
                                                ).pop(),
                                    child:
                                        const Text(
                                      'Cancel',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        _isSubmitting
                                            ? null
                                            : _handleSubmit,
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          AppTheme
                                              .goldPrimary,
                                      foregroundColor:
                                          AppTheme
                                              .darkNavy,
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        vertical:
                                            15,
                                      ),
                                    ),
                                    child:
                                        _submitButton(),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .end,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : () =>
                                              Navigator.of(
                                                context,
                                              ).pop(),
                                  child:
                                      const Text(
                                    'Cancel',
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                ElevatedButton(
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : _handleSubmit,
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        AppTheme
                                            .goldPrimary,
                                    foregroundColor:
                                        AppTheme
                                            .darkNavy,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          24,
                                      vertical:
                                          14,
                                    ),
                                  ),
                                  child:
                                      _submitButton(),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}