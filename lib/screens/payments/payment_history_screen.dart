// lib/screens/payments/payment_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/payment.dart';
import '../../providers/payment_provider.dart';
import '../../services/api_service.dart';
import '../../services/pdf_receipt_service.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/responsive_layout.dart';
import 'payment_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Function(int tab, {Map<String, dynamic>? initialParams})?
      onNavigate;

  const PaymentHistoryScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState
    extends State<PaymentHistoryScreen> {
  final TextEditingController _searchCtrl =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PaymentProvider>().fetchPayments();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // NEW PAYMENT
  // ============================================================

  void _openNewPaymentModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      child: const PaymentScreen(),
    );

    if (result == true && mounted) {
      context.read<PaymentProvider>().fetchPayments();
    }
  }

  // ============================================================
  // PRINT RECEIPT
  // ============================================================

  Future<void> _printReceipt(Payment payment) async {
    try {
      final receipt = await ApiService.getReceipt(
        loanId: payment.loanId,
        receiptNo: payment.receiptNo,
        type: 'PAYMENT',
      );

      await PdfReceiptService.printReceipt(
        receipt.rawData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to print receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();
    final payments = provider.payments;

    final width = MediaQuery.of(context).size.width;
    final isDesktop =
        width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ====================================================
            // TOP CONTROLS BAR
            // ====================================================

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.silverBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText:
                            'Search Receipt No, Loan No, Customer...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color:
                              AppTheme.silverDark,
                        ),
                        suffixIcon:
                            _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();

                                      provider
                                          .fetchPayments(
                                        search: '',
                                      );

                                      setState(() {});
                                    },
                                  )
                                : null,
                      ),
                      onChanged: (val) {
                        provider.fetchPayments(
                          search: val.trim(),
                        );

                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  ElevatedButton.icon(
                    onPressed:
                        _openNewPaymentModal,
                    icon: const Icon(
                      Icons.payments,
                      size: 18,
                    ),
                    label: Text(
                      isDesktop
                          ? 'Record Payment'
                          : 'Pay',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.goldPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ====================================================
            // CONTENT
            // ====================================================

            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            AppTheme.goldPrimary,
                      ),
                    )
                  : payments.isEmpty
                      ? const Center(
                          child: Text(
                            'No payment records found',
                            style: TextStyle(
                              color:
                                  AppTheme.silverDark,
                            ),
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(
                              payments,
                            )
                          : _buildMobileCards(
                              payments,
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // DESKTOP TABLE
  // ================================================================

  Widget _buildDesktopTable(
      List<Payment> payments) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: AppTheme.darkNavy,
    );

    const cellStyle = TextStyle(
      fontSize: 11,
      color: AppTheme.darkNavy,
    );

    Widget header(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: headerStyle,
        ),
      );
    }

    Widget cell(
      Widget child, {
      Alignment alignment =
          Alignment.centerLeft,
    }) {
      return Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 10,
        ),
        child: child,
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ==================================================
            // VERTICAL + HORIZONTAL SCROLL
            // ==================================================

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                primary: true,
                physics:
                    const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth:
                          constraints.maxWidth,
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.45),
                        1: FlexColumnWidth(0.85),
                        2: FlexColumnWidth(1.35),
                        3: FlexColumnWidth(1.05),
                        4: FlexColumnWidth(1.00),
                        5: FlexColumnWidth(0.95),
                        6: FlexColumnWidth(0.95),
                        7: FlexColumnWidth(1.05),
                        8: FlexColumnWidth(0.65),
                        9: FixedColumnWidth(58),
                      },

                      border: const TableBorder(
                        horizontalInside:
                            BorderSide(
                          color:
                              AppTheme.silverBorder,
                          width: 0.7,
                        ),
                      ),

                      defaultVerticalAlignment:
                          TableCellVerticalAlignment
                              .middle,

                      children: [
                        // ==================================================
                        // HEADER
                        // ==================================================

                        TableRow(
                          decoration:
                              const BoxDecoration(
                            color:
                                AppTheme.silverLight,
                          ),
                          children: [
                            header('Receipt No'),
                            header('Loan No'),
                            header('Customer'),
                            header('Date & Time'),
                            header('Amount Paid'),
                            header('Previous Paid'),
                            header('Total Paid'),
                            header('Remaining'),
                            header('Mode'),
                            header('Actions'),
                          ],
                        ),

                        // ==================================================
                        // DATA ROWS
                        // ==================================================

                        ...payments.map(
                          (p) => TableRow(
                            children: [
                              // ==========================================
                              // RECEIPT NO
                              // ==========================================

                              cell(
                                Text(
                                  p.receiptNo,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 11,
                                    color:
                                        AppTheme
                                            .darkNavy,
                                  ),
                                ),
                              ),

                              // ==========================================
                              // LOAN NO
                              // ==========================================

                              cell(
                                Text(
                                  p.loanNo ?? '-',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style: cellStyle,
                                ),
                              ),

                              // ==========================================
                              // CUSTOMER
                              // ==========================================

                              cell(
                                Text(
                                  '${p.customerName ?? 'Customer'}'
                                  ' (${p.customerCode ?? ''})',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style: cellStyle,
                                ),
                              ),

                              // ==========================================
                              // DATE & TIME
                              // ==========================================

                              cell(
                                Text(
                                  '${AppConstants.formatDate(p.paymentDate)}\n'
                                  '${AppConstants.formatTime(p.paymentTime)}',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme
                                        .silverDark,
                                  ),
                                ),
                              ),

                              // ==========================================
                              // AMOUNT PAID
                              // ==========================================

                              cell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    p.amount,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 11,
                                    color:
                                        Color(
                                      0xFF065F46,
                                    ),
                                  ),
                                ),
                              ),

                              // ==========================================
                              // PREVIOUS PAID
                              // ==========================================

                              cell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    p.previousPaid,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style: cellStyle,
                                ),
                              ),

                              // ==========================================
                              // TOTAL PAID
                              // ==========================================

                              cell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    p.newTotalPaid,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 11,
                                    color:
                                        AppTheme
                                            .darkNavy,
                                  ),
                                ),
                              ),

                              // ==========================================
                              // REMAINING BALANCE
                              // ==========================================

                              cell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    p.remainingBalance,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 11,
                                    color:
                                        AppTheme
                                            .goldDark,
                                  ),
                                ),
                              ),

                              // ==========================================
                              // PAYMENT MODE
                              // ==========================================

                              cell(
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment:
                                      Alignment
                                          .centerLeft,
                                  child: GoldBadge(
                                    status:
                                        p.paymentMode,
                                  ),
                                ),
                              ),

                              // ==========================================
                              // ACTIONS
                              // ==========================================

                              cell(
                                IconButton(
                                  tooltip:
                                      'Print A4 Receipt',
                                  padding:
                                      EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  icon:
                                      const Icon(
                                    Icons.print,
                                    size: 18,
                                    color:
                                        AppTheme
                                            .darkNavy,
                                  ),
                                  onPressed: () =>
                                      _printReceipt(p),
                                ),
                                alignment:
                                    Alignment.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ================================================================
  // MOBILE CARDS
  // ================================================================

  Widget _buildMobileCards(
      List<Payment> payments) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        primary: true,
        physics:
            const AlwaysScrollableScrollPhysics(),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.receiptNo,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 13,
                            color:
                                AppTheme.darkNavy,
                          ),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.print,
                          size: 18,
                          color:
                              AppTheme.darkNavy,
                        ),
                        onPressed: () =>
                            _printReceipt(p),
                      ),
                    ],
                  ),

                  // ==================================================
                  // LOAN / CUSTOMER
                  // ==================================================

                  Text(
                    'Loan: ${p.loanNo} • ${p.customerName}',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 12,
                    ),
                  ),

                  Text(
                    '${AppConstants.formatDate(p.paymentDate)} '
                    '${AppConstants.formatTime(p.paymentTime)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          AppTheme.silverDark,
                    ),
                  ),

                  const Divider(height: 16),

                  // ==================================================
                  // FINANCIAL INFORMATION
                  // ==================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      // AMOUNT PAID
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'Amount Paid',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme
                                  .silverDark,
                            ),
                          ),
                          Text(
                            AppConstants
                                .formatCurrency(
                              p.amount,
                            ),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                              color:
                                  Color(
                                0xFF065F46,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // REMAINING BALANCE
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .end,
                        children: [
                          const Text(
                            'Remaining Balance',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme
                                  .silverDark,
                            ),
                          ),
                          Text(
                            AppConstants
                                .formatCurrency(
                              p.remainingBalance,
                            ),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 13,
                              color:
                                  AppTheme
                                      .goldDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}