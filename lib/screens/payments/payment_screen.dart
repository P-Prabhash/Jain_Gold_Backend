// lib/screens/payments/payment_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/loan.dart';

import '../../providers/payment_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';

class PaymentScreen extends StatefulWidget {
  final int? preselectedLoanId;

  const PaymentScreen({super.key, this.preselectedLoanId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedLoanId;
  final _paymentAmountCtrl = TextEditingController();
  final _manualInterestCtrl = TextEditingController(text: '0.00');
  final _remarksCtrl = TextEditingController();
  String _paymentMode = 'CASH';

  List<Loan> _activeLoans = [];
  List<Loan> _filteredLoans = [];
  Loan? _selectedLoan;

  final TextEditingController _loanSearchCtrl =
      TextEditingController();

  bool _showLoanResults = false;
  bool _isLoadingLoans = false;
  bool _isSubmitting = false;

  double _previousPaid = 0.0;
  double _currentPayment = 0.0;
  double _manualInterest = 0.0;
  double _totalAmountReceived = 0.0;
  double _newRemainingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedLoanId = widget.preselectedLoanId;
    _fetchActiveLoans();
  }

  Future<void> _fetchActiveLoans() async {
    setState(() => _isLoadingLoans = true);
    final loans = await ApiService.getLoans(status: 'ACTIVE');
    setState(() {
      _activeLoans = loans;
      _filteredLoans = loans;
      _isLoadingLoans = false;
      if (_selectedLoanId != null) {
        final match = _activeLoans.where((l) => l.id == _selectedLoanId).toList();
        if (match.isNotEmpty) {
          _selectedLoan = match.first;
          _onLoanSelected(_selectedLoan);
        }
      }
    });
  }


  void _searchLoan(String value) {

    setState(() {

      if(value.trim().isEmpty){

        _filteredLoans = _activeLoans;
        _showLoanResults = false;

        return;
      }


      final search =
          value.toLowerCase();


      _filteredLoans =
          _activeLoans.where((loan){

            return loan.loanNo
                .toString()
                .toLowerCase()
                .contains(search)
                ||
                loan.customerName
                .toString()
                .toLowerCase()
                .contains(search);

          }).toList();


      _showLoanResults = true;

    });

  }




  void _selectLoan(Loan loan){

    _loanSearchCtrl.text =
        "${loan.loanNo} - ${loan.customerName}";


    setState(() {

      _showLoanResults = false;

    });


    _onLoanSelected(loan);

  }



  @override
  void dispose() {
    _paymentAmountCtrl.dispose();
    _manualInterestCtrl.dispose();
    _remarksCtrl.dispose();
    _loanSearchCtrl.dispose();
    super.dispose();
  }

  void _onLoanSelected(Loan? loan) {
    setState(() {
      _selectedLoan = loan;
      _selectedLoanId = loan?.id;
      if (loan != null) {
        _previousPaid = loan.totalPaid;
        _recalculate();
      }
    });
  }

  void _recalculate() {
    if (_selectedLoan == null) return;
    final principalPay = double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0;
    final interest = double.tryParse(_manualInterestCtrl.text.trim()) ?? 0.0;

    _currentPayment = principalPay;
    _manualInterest = interest;
    _totalAmountReceived = principalPay + interest;

    _previousPaid = _selectedLoan!.totalPaid;
    _newRemainingBalance = max(0.0, _selectedLoan!.remainingBalance - principalPay);
  }

  void _setFullRemaining() {
    if (_selectedLoan == null) return;
    setState(() {
      _paymentAmountCtrl.text = _selectedLoan!.remainingBalance.toStringAsFixed(2);
      _recalculate();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLoanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an active loan')));
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<PaymentProvider>();
    final principalPay = double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0;
    final manualInterest = double.tryParse(_manualInterestCtrl.text.trim()) ?? 0.0;
    final totalReceived = principalPay + manualInterest;

    final res = await provider.processPayment({
      'loan_id': _selectedLoanId,
      'amount': principalPay,
      'principal_payment': principalPay,
      'principal_payment_amount': principalPay,
      'manual_interest': manualInterest,
      'manual_interest_amount': manualInterest,
      'total_received': totalReceived,
      'payment_mode': _paymentMode,
      'remarks': _remarksCtrl.text.trim(),
    });

    setState(() => _isSubmitting = false);

    if (res != null && res['success'] == true && mounted) {
      Navigator.of(context).pop(true);
      if (res['data']?['receipt'] != null) {
        showDialog(
          context: context,
          builder: (_) => A4ReceiptViewer(receiptData: res['data']['receipt']),
        );
      }
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.statusDanger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1200;

    final double maxWidth = isMobile
        ? double.infinity
        : isTablet
            ? 760
            : 980;

    return Center(
      child: Container(
        width: double.infinity,
        height: isMobile ? MediaQuery.of(context).size.height : null,
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.94,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 0 : 12,
          vertical: isMobile ? 0 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isMobile ? 0 : 16,
          ),
          boxShadow: isMobile
              ? const []
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPaymentHeader(isMobile),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isMobile
                      ? 14
                      : isTablet
                          ? 20
                          : 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _buildLoanSearchSection(isMobile),

                      if (_selectedLoan != null) ...[
                        const SizedBox(height: 14),
                        _buildLoanSummary(
                          isMobile,
                          isTablet,
                        ),
                      ],

                      const SizedBox(height: 14),

                      _buildPaymentAmountSection(
                        isMobile,
                      ),

                      const SizedBox(height: 14),

                      _buildPaymentDetailsSection(
                        isMobile,
                      ),

                      if (_selectedLoan != null) ...[
                        const SizedBox(height: 14),
                        _buildLivePreview(),
                      ],

                      const SizedBox(height: 18),

                      _buildActionButtons(
                        isMobile,
                        isTablet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT HEADER
  // ============================================================

  Widget _buildPaymentHeader(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 24,
        vertical: mobile ? 13 : 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            mobile ? 0 : 16,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: mobile ? 38 : 42,
            height: mobile ? 38 : 42,
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.payments,
              color: AppTheme.darkNavy,
              size: mobile ? 19 : 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Record Loan Payment / Partial Payment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
            onPressed: () =>
                Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOAN SEARCH
  // ============================================================

  Widget _buildLoanSearchSection(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _isLoadingLoans
            ? const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 24,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.goldPrimary,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _loanSearchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search Active Loan *',
                      hintText:
                          'Loan No / Customer Name',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.goldDark,
                      ),
                    ),
                    onChanged: _searchLoan,
                  ),

                  if (_showLoanResults)
                    Container(
                      margin: const EdgeInsets.only(
                        top: 5,
                      ),
                      constraints:
                          const BoxConstraints(
                        maxHeight: 180,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color:
                              AppTheme.silverBorder,
                        ),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            _filteredLoans.length,
                        itemBuilder:
                            (context, index) {
                          final loan =
                              _filteredLoans[index];

                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                              ),
                              title: Text(
                                loan.loanNo,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                              subtitle: Text(
                                '${loan.customerName}  |  '
                                '${AppConstants.formatCurrency(loan.remainingBalance)}',
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                              onTap: () =>
                                  _selectLoan(loan),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ],
    );
  }

  // ============================================================
  // LOAN SUMMARY
  // ============================================================

  Widget _buildLoanSummary(
    bool mobile,
    bool tablet,
  ) {
    final loan = _selectedLoan!;

    return Container(
      padding: EdgeInsets.all(
        mobile ? 11 : 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child: Column(
        children: [
          if (mobile)
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Borrower: ${loan.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Loan Type: '
                  '${loan.loanType.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.silverDark,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Borrower: ${loan.customerName}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loan Type: '
                  '${loan.loanType.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.silverDark,
                  ),
                ),
              ],
            ),

          const Divider(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact =
                  constraints.maxWidth < 430;

              if (compact) {
                return Column(
                  children: [
                    _loanSummaryValue(
                      'Principal Amount',
                      AppConstants.formatCurrency(
                        loan.principalAmount,
                      ),
                      CrossAxisAlignment.start,
                    ),
                    const SizedBox(height: 8),
                    _loanSummaryValue(
                      'Total Amount Due',
                      AppConstants.formatCurrency(
                        loan.totalDue,
                      ),
                      CrossAxisAlignment.start,
                    ),
                    const SizedBox(height: 8),
                    _loanSummaryValue(
                      'Current Remaining',
                      AppConstants.formatCurrency(
                        loan.remainingBalance,
                      ),
                      CrossAxisAlignment.start,
                      highlight: true,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _loanSummaryValue(
                      'Principal Amount',
                      AppConstants.formatCurrency(
                        loan.principalAmount,
                      ),
                      CrossAxisAlignment.start,
                    ),
                  ),
                  Expanded(
                    child: _loanSummaryValue(
                      'Total Amount Due',
                      AppConstants.formatCurrency(
                        loan.totalDue,
                      ),
                      CrossAxisAlignment.center,
                    ),
                  ),
                  Expanded(
                    child: _loanSummaryValue(
                      'Current Remaining',
                      AppConstants.formatCurrency(
                        loan.remainingBalance,
                      ),
                      CrossAxisAlignment.end,
                      highlight: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _loanSummaryValue(
    String title,
    String value,
    CrossAxisAlignment alignment, {
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.silverDark,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 13 : 12,
              color: highlight
                  ? AppTheme.goldDark
                  : AppTheme.darkNavy,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT AMOUNT
  // ============================================================

  Widget _buildPaymentAmountSection(bool mobile) {
    final amountField = TextFormField(
      controller: _paymentAmountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Principal Payment Amount (Rs) *',
        hintText: 'e.g. 5000',
        prefixIcon: Icon(
          Icons.payments_outlined,
          color: AppTheme.goldDark,
        ),
      ),
      onChanged: (_) {
        setState(() {
          _recalculate();
        });
      },
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Principal payment amount is required';
        }
        final d = double.tryParse(val.trim());
        if (d == null || d < 0) {
          return 'Enter valid amount';
        }
        if (_selectedLoan != null && d > _selectedLoan!.remainingBalance + 0.01) {
          return 'Cannot exceed remaining principal balance';
        }
        return null;
      },
    );

    final manualInterestField = TextFormField(
      controller: _manualInterestCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Manual Interest Amount (Rs)',
        hintText: 'e.g. 100',
        prefixIcon: Icon(
          Icons.percent_outlined,
          color: AppTheme.goldDark,
        ),
      ),
      onChanged: (_) {
        setState(() {
          _recalculate();
        });
      },
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        final d = double.tryParse(val.trim());
        if (d == null || d < 0) {
          return 'Enter valid interest amount';
        }
        return null;
      },
    );

    final fullDueButton = _selectedLoan == null
        ? null
        : ElevatedButton(
            onPressed: _setFullRemaining,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
            child: const Text(
              'FULL DUE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amountField,
          const SizedBox(height: 12),
          manualInterestField,
          if (fullDueButton != null) ...[
            const SizedBox(height: 9),
            SizedBox(
              height: 46,
              child: fullDueButton,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: amountField,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: manualInterestField,
        ),
        if (fullDueButton != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: fullDueButton,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PAYMENT MODE + REMARKS
  // ============================================================

  Widget _buildPaymentDetailsSection(
    bool mobile,
  ) {
    final modeField =
        DropdownButtonFormField<String>(
      initialValue: _paymentMode,
      decoration: const InputDecoration(
        labelText: 'Payment Mode *',
        prefixIcon: Icon(
          Icons.account_balance,
          color: AppTheme.silverDark,
        ),
      ),
      items: [
        'CASH',
        'BANK_TRANSFER',
        'UPI',
        'CHEQUE',
      ].map(
        (m) {
          return DropdownMenuItem(
            value: m,
            child: Text(
              m.replaceAll('_', ' '),
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          );
        },
      ).toList(),
      onChanged: (val) {
        setState(() {
          _paymentMode = val ?? 'CASH';
        });
      },
    );

    final remarksField =
        TextFormField(
      controller: _remarksCtrl,
      maxLines: mobile ? 2 : 1,
      decoration: const InputDecoration(
        labelText: 'Remarks (Optional)',
        prefixIcon: Icon(
          Icons.notes,
          color: AppTheme.silverDark,
        ),
      ),
    );

    if (mobile) {
      return Column(
        children: [
          modeField,
          const SizedBox(height: 12),
          remarksField,
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: modeField,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: remarksField,
        ),
      ],
    );
  }

  // ============================================================
  // LIVE PREVIEW
  // ============================================================

  Widget _buildLivePreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.goldPrimary,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          _previewRow(
            'Previously Paid Principal:',
            AppConstants.formatCurrency(_previousPaid),
          ),
          const SizedBox(height: 4),
          _previewRow(
            'Current Principal Payment:',
            AppConstants.formatCurrency(_currentPayment),
            valueColor: const Color(0xFF065F46),
            labelColor: const Color(0xFF065F46),
          ),
          const SizedBox(height: 4),
          _previewRow(
            'Additional Manual Interest:',
            AppConstants.formatCurrency(_manualInterest),
            valueColor: AppTheme.goldDark,
            labelColor: AppTheme.goldDark,
          ),
          const Divider(height: 12),
          _previewRow(
            'TOTAL AMOUNT RECEIVED:',
            AppConstants.formatCurrency(_totalAmountReceived),
            labelColor: AppTheme.darkNavy,
            valueColor: AppTheme.darkNavy,
            bold: true,
          ),
          const SizedBox(height: 4),
          _previewRow(
            'OUTSTANDING PRINCIPAL AFTER PAYMENT:',
            AppConstants.formatCurrency(_newRemainingBalance),
            labelColor: AppTheme.goldDark,
            valueColor: AppTheme.goldDark,
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _previewRow(
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
    bool bold = false,
    bool large = false,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.normal,
              color:
                  labelColor ??
                  AppTheme.silverDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 16 : 12,
                fontWeight: bold
                    ? FontWeight.w900
                    : FontWeight.bold,
                color:
                    valueColor ??
                    AppTheme.darkNavy,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons(
    bool mobile,
    bool tablet,
  ) {
    final cancelButton =
        OutlinedButton(
      onPressed: _isSubmitting
          ? null
          : () =>
              Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          mobile ? double.infinity : 120,
          46,
        ),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final processButton =
        ElevatedButton(
      onPressed:
          _isSubmitting
              ? null
              : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            AppTheme.goldPrimary,
        foregroundColor:
            AppTheme.darkNavy,
        minimumSize: Size(
          mobile ? double.infinity : 230,
          46,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child:
                  CircularProgressIndicator(
                color: AppTheme.darkNavy,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'PROCESS & PRINT RECEIPT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: processButton,
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 46,
            child: cancelButton,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 46,
          child: cancelButton,
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 46,
          child: processButton,
        ),
      ],
    );
  }
}
