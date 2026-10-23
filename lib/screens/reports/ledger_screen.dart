import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/transaction.dart';
import '../../providers/report_provider.dart';
import '../../widgets/gold_badge.dart';

import '../../services/ledger_print_service.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final TextEditingController _searchCtrl =
      TextEditingController();

  final ScrollController _horizontalController =
      ScrollController();

  final ScrollController _verticalController =
      ScrollController();

  String _selectedType = 'ALL';

  final List<String> _txTypes = [
    'ALL',
    'LOAN_CREATED',
    'EXISTING_LOAN_CREATED',
    'ADDITIONAL_LOAN',
    'PAYMENT',
    'PARTIAL_PAYMENT',
    'FULL_PAYMENT',
    'FINAL_MANUAL_INTEREST',
    'FINAL_SETTLEMENT',
    'PARTIAL_RELEASE',
    'FULL_RELEASE',
    'LOAN_CLOSED',
  ];

  // ============================================================
  // BREAKPOINTS
  // ============================================================

  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  bool _isMobile(double width) {
    return width < mobileBreakpoint;
  }

  bool _isTablet(double width) {
    return width >= mobileBreakpoint &&
        width < desktopBreakpoint;
  }

  bool _isDesktop(double width) {
    return width >= desktopBreakpoint;
  }

  // ============================================================
  // SAFE NUMBER
  // ============================================================

  num _toNum(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value;
    }

    return num.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context
          .read<ReportProvider>()
          .fetchLedger();
    });
  }

  @override
  void dispose() {

    _searchCtrl.dispose();

    _horizontalController.dispose();

    _verticalController.dispose();

    super.dispose();

  }


  // ============================================================
  // PRINT LEDGER REPORT
  // ============================================================

  Future<void> _printLedger() async {

    final provider =
        context.read<ReportProvider>();

    try {

      await LedgerPrintService.printLedger(

        transactions:
            provider.ledgerTransactions,

        search:
            _searchCtrl.text.trim(),

        transactionType:
            _selectedType,

      );

    } catch(e) {

      if(!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
          content:
              Text(e.toString()),
        ),

      );

    }

  }


  // ============================================================
  // FETCH
  // ============================================================

  void _fetchLedger() {
    context.read<ReportProvider>().fetchLedger(
          type: _selectedType == 'ALL'
              ? null
              : _selectedType,
          search: _searchCtrl.text.trim(),
        );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<ReportProvider>();

    final transactions =
        provider.ledgerTransactions;

    final width =
        MediaQuery.of(context).size.width;

    final mobile = _isMobile(width);
    final tablet = _isTablet(width);
    final desktop = _isDesktop(width);

    return Scaffold(
      backgroundColor:
          AppTheme.backgroundLight,

      appBar: AppBar(
        title: const Text(
          'Central Financial & Collateral Transaction Ledger',
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            mobile
                ? 10
                : tablet
                    ? 14
                    : 20,
          ),
          child: Column(
            children: [
              _buildControls(
                context,
                mobile: mobile,
                tablet: tablet,
              ),

              SizedBox(
                height: mobile
                    ? 10
                    : 16,
              ),

              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              AppTheme.goldPrimary,
                        ),
                      )
                    : transactions.isEmpty
                        ? _buildEmptyState()
                        : desktop
                            ? _buildDesktopTable(
                                transactions,
                              )
                            : _buildResponsiveCards(
                                transactions,
                                tablet: tablet,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTROLS
  // ============================================================

  Widget _buildControls(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    if (mobile) {
      return _buildMobileControls();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        tablet ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchField(),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: tablet ? 180 : 230,
            child: _buildTypeDropdown(),
          ),

          const SizedBox(width: 10),

          OutlinedButton.icon(

            onPressed: _printLedger,

            icon: const Icon(
              Icons.print,
              size: 18,
            ),

            label: const Text(
              'Print',
            ),

          ),
        ],
      ),
    );
  }

  Widget _buildMobileControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          _buildSearchField(),

          const SizedBox(height: 10),

          _buildTypeDropdown(
            fullWidth: true,
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(

              onPressed: _printLedger,

              icon: const Icon(
                Icons.print,
                size: 18,
              ),

              label: const Text(
                'Print Ledger',
              ),

            ),

          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      maxLines: 1,
      textInputAction:
          TextInputAction.search,

      decoration:
          const InputDecoration(
        hintText:
            'Search transaction, loan, customer...',
        prefixIcon: Icon(
          Icons.search,
          color:
              AppTheme.silverDark,
        ),
      ),

      onChanged: (_) {
        _fetchLedger();
      },
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _buildTypeDropdown({
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth
          ? double.infinity
          : null,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,

          isExpanded: true,

          icon: const Icon(
            Icons.keyboard_arrow_down,
            color:
                AppTheme.silverDark,
          ),

          items: _txTypes.map(
            (type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type
                      .replaceAll('_', ' '),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ).toList(),

          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedType = value;
            });

            _fetchLedger();
          },
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 45,
              color:
                  AppTheme.silverDark,
            ),
            SizedBox(height: 10),
            Text(
              'No ledger records found',
              style: TextStyle(
                color:
                    AppTheme.silverDark,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP TABLE
  // ============================================================

  Widget _buildDesktopTable(
    List<LoanTransaction> transactions,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(12),

        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,

          child: SingleChildScrollView(

            controller: _horizontalController,

            scrollDirection:
                Axis.horizontal,

            child: SingleChildScrollView(

              controller: _verticalController,

              scrollDirection:
                  Axis.vertical,

              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(
                  AppTheme.silverLight,
                ),

                dataRowMinHeight: 55,
                dataRowMaxHeight: 72,

                columnSpacing: 22,

                columns: const [
                  DataColumn(
                    label: Text(
                      'Tx Code',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Event Type',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Customer',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Loan No',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Amount',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Weight',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Date & Time',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Remarks',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                rows: transactions.map(
                  (t) {
                    final amount =
                        _toNum(t.amount);

                    final weight =
                        _toNum(t.weight);

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 155,
                            child: Text(
                              t.transactionCode,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    AppTheme.darkNavy,
                              ),
                            ),
                          ),
                        ),

                        DataCell(
                          GoldBadge(
                            status:
                                t.transactionType,
                            fontSize: 9,
                          ),
                        ),

                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              '${t.customerName ?? 'Customer'} (${t.customerCode ?? ''})',
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        ),

                        DataCell(
                          Text(
                            t.loanNo ?? '-',
                          ),
                        ),

                        DataCell(
                          Text(
                            amount > 0
                                ? AppConstants
                                    .formatCurrency(
                                    amount,
                                  )
                                : '-',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: amount > 0
                                  ? const Color(
                                      0xFF065F46,
                                    )
                                  : Colors.black,
                            ),
                          ),
                        ),

                        DataCell(
                          Text(
                            weight > 0
                                ? AppConstants
                                    .formatWeight(
                                    weight,
                                  )
                                : '-',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: weight > 0
                                  ? AppTheme
                                      .goldDark
                                  : Colors.black,
                            ),
                          ),
                        ),

                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Text(
                              '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}',
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                        ),

                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              _sanitizeRemark(t.remarks),
                              maxLines: 3,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    AppTheme.silverDark,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLET + MOBILE CARDS
  // ============================================================

  Widget _buildResponsiveCards(
    List<LoanTransaction> transactions, {
    required bool tablet,
  }) {
    return ListView.separated(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      itemCount:
          transactions.length,
      separatorBuilder:
          (_, __) =>
              const SizedBox(
        height: 10,
      ),
      itemBuilder:
          (context, index) {
        final t =
            transactions[index];

        return _buildTransactionCard(
          t,
          tablet: tablet,
        );
      },
    );
  }

  Widget _buildTransactionCard(
    LoanTransaction t, {
    required bool tablet,
  }) {
    final amount =
        _toNum(t.amount);

    final weight =
        _toNum(t.weight);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        tablet ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t.transactionCode,
                  maxLines: 2,
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

              const SizedBox(width: 8),

              Flexible(
                child: Align(
                  alignment:
                      Alignment.topRight,
                  child: GoldBadge(
                    status:
                        t.transactionType,
                    fontSize:
                        tablet ? 9 : 8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // CUSTOMER
          _infoRow(
            Icons.person_outline,
            'Customer',
            '${t.customerName ?? 'Customer'} (${t.customerCode ?? ''})',
          ),

          const SizedBox(height: 6),

          // LOAN
          _infoRow(
            Icons.account_balance_wallet_outlined,
            'Loan',
            t.loanNo ?? '-',
          ),

          const SizedBox(height: 6),

          // DATE
          _infoRow(
            Icons.calendar_today_outlined,
            'Date',
            '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}',
          ),

          const SizedBox(height: 10),

          const Divider(
            height: 1,
          ),

          const SizedBox(height: 10),

          // FINANCIAL VALUES
          Row(
            children: [
              Expanded(
                child:
                    _valueBox(
                  title: 'Amount',
                  value: amount > 0
                      ? AppConstants
                          .formatCurrency(
                          amount,
                        )
                      : '-',
                  valueColor:
                      amount > 0
                          ? const Color(
                              0xFF065F46,
                            )
                          : AppTheme
                              .darkNavy,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child:
                    _valueBox(
                  title: 'Weight',
                  value: weight > 0
                      ? AppConstants
                          .formatWeight(
                          weight,
                        )
                      : '-',
                  valueColor:
                      weight > 0
                          ? AppTheme
                              .goldDark
                          : AppTheme
                              .darkNavy,
                ),
              ),
            ],
          ),

          if (t.remarks != null &&
              t.remarks!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(9),
              decoration:
                  BoxDecoration(
                color:
                    AppTheme.silverLight,
                borderRadius:
                    BorderRadius.circular(
                  7,
                ),
              ),
              child: Text(
                _sanitizeRemark(t.remarks),
                maxLines: 4,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      AppTheme.silverDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sanitizeRemark(String? remark) {
    if (remark == null || remark.trim().isEmpty) return '-';
    return remark
        .replaceAll('₹', 'Rs ')
        .replaceAll('Rs. ', 'Rs ')
        .replaceAll('Rs.', 'Rs ')
        .replaceAll('\uFFFD', 'Rs ');
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color:
              AppTheme.silverDark,
        ),

        const SizedBox(width: 7),

        SizedBox(
          width: 55,
          child: Text(
            label,
            style:
                const TextStyle(
              fontSize: 10,
              color:
                  AppTheme.silverDark,
            ),
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            value,
            maxLines: 3,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppTheme.darkNavy,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VALUE BOX
  // ============================================================

  Widget _valueBox({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 9,
              color:
                  AppTheme.silverDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}