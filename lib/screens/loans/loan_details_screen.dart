import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../models/loan.dart';
import '../../models/payment.dart';
import '../../models/release.dart';
import '../../models/transaction.dart';
import '../../providers/loan_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';
import '../../widgets/gold_badge.dart';
import '../payments/payment_screen.dart';
import '../releases/partial_release_screen.dart';
import 'close_loan_screen.dart';
import 'create_additional_loan_screen.dart';

class LoanDetailsScreen extends StatefulWidget {
  final int loanId;
  final Function(int tab, {Map<String, dynamic>? initialParams})? onNavigate;

  const LoanDetailsScreen({super.key, required this.loanId, this.onNavigate});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanProvider>().fetchLoanDetails(widget.loanId);
    });
  }

  void _openPaymentModal() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PaymentScreen(preselectedLoanId: widget.loanId),
      ),
    );
    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoanDetails(widget.loanId);
    }
  }

  void _openPartialReleaseModal() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PartialReleaseScreen(preselectedLoanId: widget.loanId),
      ),
    );
    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoanDetails(widget.loanId);
    }
  }

  void _openCloseLoanModal() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: CloseLoanScreen(loanId: widget.loanId),
      ),
    );
    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoanDetails(widget.loanId);
    }
  }

  void _openAdditionalLoanModal() async {
    final loan = context.read<LoanProvider>().selectedLoan;
    if (loan == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: CreateAdditionalLoanScreen(preselectedCustomerId: loan.customerId),
      ),
    );
    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoanDetails(widget.loanId);
    }
  }

  void _printLoanReceipt() async {
    try {
      final receipt = await ApiService.getReceipt(loanId: widget.loanId, type: 'LOAN');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => A4ReceiptViewer(receiptData: receipt.rawData),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load receipt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loan = provider.selectedLoan;
    final customer = provider.loanCustomer;
    final collateral = provider.loanCollateral;
    final weights = provider.collateralWeights;
    final payments = provider.loanPayments;
    final releases = provider.loanReleases;
    final transactions = provider.loanTransactions;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.desktopBreakpoint;
    final isTablet = width >= AppConstants.mobileBreakpoint && !isDesktop;

    if (provider.isLoadingDetails || loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan Details')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.goldPrimary)),
      );
    }

    final double totalPledgedWeight = double.tryParse(weights['total_pledged_weight']?.toString() ?? '0') ?? 0.0;
    final double remainingPledgedWeight = double.tryParse(weights['remaining_pledged_weight']?.toString() ?? '0') ?? 0.0;
    final double progress = loan.totalDue > 0 ? (loan.totalPaid / loan.totalDue).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('${loan.loanNo} • ${loan.loanType.replaceAll('_', ' ')}'),
        actions: [
          IconButton(
            tooltip: 'Print A4 Loan Receipt',
            icon: const Icon(Icons.print, color: AppTheme.goldPrimary),
            onPressed: _printLoanReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchLoanDetails(widget.loanId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.silverBorder, width: 0.8),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (loan.isActive) ...[
                    ElevatedButton.icon(
                      onPressed: _openPaymentModal,
                      icon: const Icon(Icons.payments, size: 16),
                      label: const Text('Make Payment'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldPrimary),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openPartialReleaseModal,
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: const Text('Partial Release'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkNavy, foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openCloseLoanModal,
                      icon: const Icon(Icons.lock_clock, size: 16),
                      label: const Text('Close / Settle Loan'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), foregroundColor: Colors.white),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _openAdditionalLoanModal,
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Additional Loan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printLoanReceipt,
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Print Receipt'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3-PANEL RESPONSIVE CARDS (Customer | Financial | Collateral)
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCustomerCard(customer)),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildFinancialSummaryCard(loan, progress)),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _buildCollateralSummaryCard(collateral, totalPledgedWeight, remainingPledgedWeight)),
                ],
              ),
            ] else if (isTablet) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCustomerCard(customer)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFinancialSummaryCard(loan, progress)),
                ],
              ),
              const SizedBox(height: 16),
              _buildCollateralSummaryCard(collateral, totalPledgedWeight, remainingPledgedWeight),
            ] else ...[
              _buildFinancialSummaryCard(loan, progress),
              const SizedBox(height: 14),
              _buildCustomerCard(customer),
              const SizedBox(height: 14),
              _buildCollateralSummaryCard(collateral, totalPledgedWeight, remainingPledgedWeight),
            ],
            const SizedBox(height: 24),

            // COLLATERAL DETAILED GRID
            _buildCollateralTableSection(collateral),
            const SizedBox(height: 24),

            // PAYMENT & RELEASE & TRANSACTION LEDGER TABS
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.silverBorder, width: 0.8),
              ),
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppTheme.darkNavy,
                      indicatorColor: AppTheme.goldPrimary,
                      indicatorWeight: 3,
                      labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: [
                        Tab(text: 'Payment History (${payments.length})'),
                        Tab(text: 'Release Records (${releases.length})'),
                        Tab(text: 'Loan Transaction Ledger (${transactions.length})'),
                      ],
                    ),
                    const Divider(height: 1, color: AppTheme.silverBorder),
                    SizedBox(
                      height: 380,
                      child: TabBarView(
                        children: [
                          _buildPaymentHistoryTable(payments),
                          _buildReleaseHistoryTable(releases),
                          _buildLedgerTable(transactions),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Panel 1: Customer Card
  Widget _buildCustomerCard(Customer? customer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppTheme.goldDark, size: 18),
              const SizedBox(width: 6),
              Text('BORROWER DETAILS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.darkNavy)),
            ],
          ),
          const Divider(height: 16),
          if (customer != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerPhoto(customer.photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('ID: ${customer.customerCode}', style: const TextStyle(fontSize: 12, color: AppTheme.silverDark)),
                      const SizedBox(height: 4),
                      Text('Phone: ${customer.mobile}', style: const TextStyle(fontSize: 12)),
                      Text('Address: ${customer.address}', style: const TextStyle(fontSize: 12, color: AppTheme.silverDark)),
                      if (customer.aadhaarNumber != null && customer.aadhaarNumber!.isNotEmpty)
                        Text('Aadhaar: ${customer.aadhaarNumber}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text('No borrower details available', style: TextStyle(color: AppTheme.silverDark, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerPhoto(String? photoUrl) {
    final fullUrl = ApiService.resolvePhotoUrl(photoUrl);

    if (fullUrl != null && fullUrl.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.goldPrimary, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultCustomerAvatar(),
          ),
        ),
      );
    }

    return _defaultCustomerAvatar();
  }

  Widget _defaultCustomerAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.goldLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.goldPrimary, width: 1.5),
      ),
      child: const Icon(Icons.person, color: AppTheme.goldDark, size: 30),
    );
  }

  // Panel 2: Financial Card
  Widget _buildFinancialSummaryCard(Loan loan, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldPrimary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.goldDark, size: 18),
                  const SizedBox(width: 6),
                  Text('FINANCIAL SUMMARY', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.darkNavy)),
                ],
              ),
              GoldBadge(status: loan.status),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Principal Loan Amount:', style: TextStyle(fontSize: 12, color: AppTheme.silverDark)),
              Text(AppConstants.formatCurrency(loan.principalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Interest (${loan.monthlyInterestRate}% / mo):', style: const TextStyle(fontSize: 12, color: AppTheme.silverDark)),
              Text(AppConstants.formatCurrency(loan.totalInterest + loan.manualFinalInterest), style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount Due:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(AppConstants.formatCurrency(loan.totalDue), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
              Text(AppConstants.formatCurrency(loan.totalPaid), style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.silverLight,
            color: progress >= 1.0 ? const Color(0xFF065F46) : AppTheme.goldDark,
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('REMAINING BALANCE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.darkNavy)),
              Text(
                AppConstants.formatCurrency(loan.remainingBalance),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.goldDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Panel 3: Collateral Summary Card
  Widget _buildCollateralSummaryCard(List<LoanCollateralItem> collateral, double totalWeight, double remWeight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.diamond, color: AppTheme.goldDark, size: 18),
              const SizedBox(width: 6),
              Text('COLLATERAL STATUS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.darkNavy)),
            ],
          ),
          const Divider(height: 16),
          Text('Total Items: ${collateral.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Original Pledged Weight: ${AppConstants.formatWeight(totalWeight)}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text('Remaining Pledged Weight: ${AppConstants.formatWeight(remWeight)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
        ],
      ),
    );
  }

  // Collateral Details Table
  Widget _buildCollateralTableSection(List<LoanCollateralItem> collateral) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLEDGED GOLD COLLATERAL ITEMS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.darkNavy)),
          const Divider(height: 16),
          if (collateral.isEmpty)
            const Text('No collateral items attached to this loan', style: TextStyle(color: AppTheme.silverDark, fontSize: 12))
          else
            Table(
              columnWidths: const {
                0: FixedColumnWidth(56),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              border: TableBorder.all(color: AppTheme.silverBorder, width: 0.5),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: AppTheme.silverLight),
                  children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Purity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Pledged Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                ...collateral.map((c) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: _buildItemThumbnail(c.photoUrl),
                    ),
                    Padding(padding: const EdgeInsets.all(8), child: Text(c.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(c.purity, style: const TextStyle(fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(AppConstants.formatWeight(c.pledgedWeight), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    Padding(padding: const EdgeInsets.all(8), child: GoldBadge(status: c.collateralStatus, fontSize: 9)),
                  ],
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildItemThumbnail(String? photoUrl) {
    final fullUrl = ApiService.resolvePhotoUrl(photoUrl);
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          fullUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultGoldIcon(),
        ),
      );
    }
    return _defaultGoldIcon();
  }

  Widget _defaultGoldIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.goldLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.diamond, color: AppTheme.goldDark, size: 20),
    );
  }

  Widget _buildPaymentHistoryTable(List<Payment> payments) {
    if (payments.isEmpty) {
      return const Center(child: Text('No payments recorded for this loan', style: TextStyle(color: AppTheme.silverDark)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = payments[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            leading: const CircleAvatar(backgroundColor: Color(0xFFECFDF5), child: Icon(Icons.check, size: 16, color: Color(0xFF065F46))),
            title: Text('${p.receiptNo} • ${AppConstants.formatCurrency(p.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${AppConstants.formatDate(p.paymentDate)} ${AppConstants.formatTime(p.paymentTime)} • Mode: ${p.paymentMode}'),
            trailing: Text('Remaining: ${AppConstants.formatCurrency(p.remainingBalance)}', style: const TextStyle(fontSize: 11, color: AppTheme.silverDark)),
          ),
        );
      },
    );
  }

  Widget _buildReleaseHistoryTable(List<PartialRelease> releases) {
    if (releases.isEmpty) {
      return const Center(child: Text('No releases recorded for this loan', style: TextStyle(color: AppTheme.silverDark)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: releases.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = releases[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            leading: const CircleAvatar(backgroundColor: AppTheme.silverLight, child: Icon(Icons.lock_open, size: 16, color: AppTheme.goldDark)),
            title: Text('${r.releaseNo} • Released: ${AppConstants.formatWeight(r.totalWeightReleased)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${AppConstants.formatDate(r.releaseDate)} ${AppConstants.formatTime(r.releaseTime)} ${r.remarks != null ? "• ${r.remarks}" : ""}'),
          ),
        );
      },
    );
  }

  Widget _buildLedgerTable(List<LoanTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions recorded', style: TextStyle(color: AppTheme.silverDark)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            onTap: () => _showTransactionDetailsDialog(context, tx),
            leading: const CircleAvatar(backgroundColor: AppTheme.silverLight, child: Icon(Icons.swap_horiz, size: 16, color: AppTheme.darkNavy)),
            title: Text(tx.humanReadableType, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${tx.transactionCode} • ${AppConstants.formatDate(tx.date)} ${AppConstants.formatTime(tx.time)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tx.amount > 0 ? AppConstants.formatCurrency(tx.amount) : (tx.weight > 0 ? AppConstants.formatWeight(tx.weight) : '-'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 18, color: AppTheme.silverDark),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetailsDialog(BuildContext context, LoanTransaction tx) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppTheme.goldDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.humanReadableType,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                    ),
                    Text(
                      tx.transactionCode,
                      style: const TextStyle(fontSize: 11, color: AppTheme.silverDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                _txDetailRow('Transaction Code', tx.transactionCode),
                _txDetailRow('Transaction Type', tx.humanReadableType),
                _txDetailRow('Date & Time', '${AppConstants.formatDate(tx.date)} at ${AppConstants.formatTime(tx.time)}'),
                if (tx.amount > 0)
                  _txDetailRow('Amount', AppConstants.formatCurrency(tx.amount), isHighlight: true),
                if (tx.weight > 0)
                  _txDetailRow('Collateral Weight Impact', AppConstants.formatWeight(tx.weight)),
                if (tx.referenceId != null && tx.referenceId!.isNotEmpty)
                  _txDetailRow('Reference / Loan No', tx.referenceId!),
                if (tx.createdBy != null && tx.createdBy!.isNotEmpty)
                  _txDetailRow('Recorded By', tx.createdBy!),
                if (tx.remarks != null && tx.remarks!.isNotEmpty)
                  _txDetailRow('Remarks / Notes', tx.remarks!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _txDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.silverDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
                color: isHighlight ? AppTheme.goldDark : AppTheme.darkNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
