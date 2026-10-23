import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/loan_provider.dart';
import '../../widgets/a4_receipt_viewer.dart';

class CloseLoanScreen extends StatefulWidget {
  final int loanId;

  const CloseLoanScreen({super.key, required this.loanId});

  @override
  State<CloseLoanScreen> createState() => _CloseLoanScreenState();
}

class _CloseLoanScreenState extends State<CloseLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _manualFinalInterestCtrl = TextEditingController(text: '0.00');
  final _paymentAmountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _paymentMode = 'CASH';

  double _currentOutstanding = 0.0;
  double _finalSettlementAmount = 0.0;
  double _remainingAfterPayment = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLoanDetails();
    });
  }

  Future<void> _loadLoanDetails() async {
    final provider = context.read<LoanProvider>();
    await provider.fetchLoanDetails(widget.loanId);
    final loan = provider.selectedLoan;
    if (loan != null) {
      setState(() {
        _currentOutstanding = loan.remainingBalance;
        _recalculate();
      });
    }
  }

  void _recalculate() {
    final manualInt = double.tryParse(_manualFinalInterestCtrl.text.trim()) ?? 0.0;
    _finalSettlementAmount = _currentOutstanding + manualInt;
    final pay = double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0;
    _remainingAfterPayment = max(0.0, _finalSettlementAmount - pay);
  }

  void _setFullPayment() {
    setState(() {
      _paymentAmountCtrl.text = _finalSettlementAmount.toStringAsFixed(2);
      _recalculate();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final pay = double.tryParse(_paymentAmountCtrl.text.trim()) ?? 0.0;
    final manualInt = double.tryParse(_manualFinalInterestCtrl.text.trim()) ?? 0.0;

    if (pay <= 0 && manualInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter manual final interest or a settlement payment amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<LoanProvider>();
    final res = await provider.closeOrSettleLoan({
      'loan_id': widget.loanId,
      'manual_final_interest': manualInt,
      'payment_amount': pay,
      'payment_mode': _paymentMode,
      'remarks': _remarksCtrl.text.trim(),
    });

    setState(() => _isSubmitting = false);

    if (res != null && res['success'] == true && mounted) {
      final isClosed = res['data']?['is_closed'] == true;
      Navigator.of(context).pop(true);

      if (res['data']?['receipt'] != null) {
        showDialog(
          context: context,
          builder: (_) => A4ReceiptViewer(receiptData: res['data']['receipt']),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isClosed ? 'Loan settled in full and CLOSED! Collateral discharged.' : 'Settlement payment recorded. Loan remains ACTIVE.'),
          backgroundColor: isClosed ? const Color(0xFF065F46) : AppTheme.goldDark,
        ),
      );
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppTheme.statusDanger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loan = provider.selectedLoan;
    final customer = provider.loanCustomer;

    if (provider.isLoadingDetails || loan == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.goldPrimary));
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.darkNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, color: AppTheme.goldPrimary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Final Settlement & Loan Closure: ${loan.loanNo}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Loan & Customer Meta Panel
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.silverLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.silverBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer: ${customer?.name ?? 'Customer'} (${customer?.customerCode ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Loan Type: ${loan.loanType.replaceAll('_', ' ')} • Opened: ${AppConstants.formatDate(loan.openedDate)}', style: const TextStyle(fontSize: 11, color: AppTheme.silverDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Original Principal: ${AppConstants.formatCurrency(loan.principalAmount)}', style: const TextStyle(fontSize: 11)),
                              Text('Total Paid To Date: ${AppConstants.formatCurrency(loan.totalPaid)}', style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // SECTION: Manual Final Interest & Live Calculation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Current Outstanding Box
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.silverBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Current Outstanding', style: TextStyle(fontSize: 11, color: AppTheme.silverDark, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  AppConstants.formatCurrency(_currentOutstanding),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkNavy),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Middle: Manual Final Interest Input
                        Expanded(
                          child: TextFormField(
                            controller: _manualFinalInterestCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Manual Final Interest (₹)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.edit_note, color: AppTheme.goldDark),
                            ),
                            onChanged: (_) => setState(() => _recalculate()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Final Settlement Amount Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.goldLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.goldPrimary, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FINAL SETTLEMENT AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.darkNavy)),
                              Text('(Current Outstanding + Manual Final Interest)', style: TextStyle(fontSize: 10, color: AppTheme.silverDark)),
                            ],
                          ),
                          Text(
                            AppConstants.formatCurrency(_finalSettlementAmount),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.goldDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Payment Amount Input & Quick Full Pay Button
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _paymentAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Payment Received Now (₹) *',
                              hintText: 'Enter partial or full amount',
                              prefixIcon: Icon(Icons.payments, color: AppTheme.goldDark),
                            ),
                            onChanged: (_) => setState(() => _recalculate()),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                              final d = double.tryParse(val.trim());
                              if (d == null || d <= 0) return 'Enter valid amount';
                              if (d > _finalSettlementAmount + 0.01) return 'Exceeds settlement amount';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _setFullPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.darkNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          ),
                          child: const Text('PAY FULL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode & Remarks
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _paymentMode,
                            decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.account_balance, color: AppTheme.silverDark)),
                            items: ['CASH', 'BANK_TRANSFER', 'UPI', 'CHEQUE'].map((m) {
                              return DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) => setState(() => _paymentMode = val ?? 'CASH'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _remarksCtrl,
                            decoration: const InputDecoration(labelText: 'Remarks (Optional)', prefixIcon: Icon(Icons.notes, color: AppTheme.silverDark)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Status Prediction Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _remainingAfterPayment <= 0.0 ? const Color(0xFFECFDF5) : AppTheme.silverLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _remainingAfterPayment <= 0.0 ? const Color(0xFFA7F3D0) : AppTheme.silverBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _remainingAfterPayment <= 0.0 ? 'RESULT: LOAN WILL BE CLOSED & ALL GOLD RELEASED' : 'RESULT: LOAN WILL REMAIN ACTIVE (PARTIAL PAYMENT)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _remainingAfterPayment <= 0.0 ? const Color(0xFF065F46) : AppTheme.darkNavy,
                                ),
                              ),
                              Text(
                                'Remaining after payment: ${AppConstants.formatCurrency(_remainingAfterPayment)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          Icon(
                            _remainingAfterPayment <= 0.0 ? Icons.check_circle : Icons.pending,
                            color: _remainingAfterPayment <= 0.0 ? const Color(0xFF065F46) : AppTheme.silverDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _remainingAfterPayment <= 0.0 ? const Color(0xFF065F46) : AppTheme.goldPrimary,
                            foregroundColor: _remainingAfterPayment <= 0.0 ? Colors.white : AppTheme.darkNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _remainingAfterPayment <= 0.0 ? 'CONFIRM FULL SETTLEMENT & CLOSE LOAN' : 'SAVE PARTIAL SETTLEMENT PAYMENT',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
