// lib/screens/loans/loan_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/responsive_layout.dart';

import 'create_new_loan_screen.dart';
import 'create_existing_loan_screen.dart';
import 'create_additional_loan_screen.dart';
import 'loan_details_screen.dart';
import 'close_loan_screen.dart';

import '../payments/payment_screen.dart';
import '../releases/partial_release_screen.dart';

class LoanListScreen extends StatefulWidget {
  final Function(
    int tab, {
    Map<String, dynamic>? initialParams,
  })? onNavigate;

  const LoanListScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<LoanListScreen> createState() =>
      _LoanListScreenState();
}

class _LoanListScreenState
    extends State<LoanListScreen> {
  final TextEditingController _searchCtrl =
      TextEditingController();

  String _selectedStatusFilter = 'ALL';
  String _selectedTypeFilter = 'ALL';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<LoanProvider>().fetchLoans();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAN TYPE
  // ============================================================

  String _getLoanTypeSymbol(String loanType) {
    final type = loanType.toUpperCase().trim();

    if (type == 'NEW_LOAN' ||
        type == 'NEW' ||
        type == '*') {
      return '*';
    }

    if (type == 'EXISTING_LOAN' ||
        type == 'EXISTING' ||
        type == '#') {
      return '#';
    }

    if (type == 'ADDITIONAL_LOAN' ||
        type == 'ADDITIONAL') {
      return 'ADDITIONAL';
    }

    return type.replaceAll('_', ' ');
  }

  String _getLoanTypeName(String loanType) {
    final type = loanType.toUpperCase().trim();

    if (type == 'NEW_LOAN' ||
        type == 'NEW' ||
        type == '*') {
      return 'NEW LOAN';
    }

    if (type == 'EXISTING_LOAN' ||
        type == 'EXISTING' ||
        type == '#') {
      return 'EXISTING LOAN';
    }

    if (type == 'ADDITIONAL_LOAN' ||
        type == 'ADDITIONAL') {
      return 'ADDITIONAL LOAN';
    }

    return type.replaceAll('_', ' ');
  }

  Widget _buildLoanTypeSymbol(
    String loanType, {
    double size = 30,
  }) {
    final type = loanType.toUpperCase().trim();

    final isNewLoan =
        type == 'NEW_LOAN' ||
        type == 'NEW' ||
        type == '*';

    final isExistingLoan =
        type == 'EXISTING_LOAN' ||
        type == 'EXISTING' ||
        type == '#';

    final symbol = _getLoanTypeSymbol(loanType);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNewLoan
            ? Colors.blue.withValues(alpha: 0.08)
            : isExistingLoan
                ? Colors.deepPurple.withValues(
                    alpha: 0.08,
                  )
                : AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNewLoan
              ? Colors.blue.withValues(alpha: 0.35)
              : isExistingLoan
                  ? Colors.deepPurple.withValues(
                      alpha: 0.35,
                    )
                  : AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Text(
        symbol,
        maxLines: 1,
        overflow: TextOverflow.clip,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize:
              isNewLoan || isExistingLoan
                  ? 18
                  : 7,
          fontWeight: FontWeight.w900,
          color: isNewLoan
              ? Colors.blue.shade800
              : isExistingLoan
                  ? Colors.deepPurple.shade800
                  : AppTheme.darkNavy,
        ),
      ),
    );
  }

  // ============================================================
  // FILTER FETCH
  // ============================================================

  void _fetchWithFilters({
    String? search,
    String? status,
    String? loanType,
  }) {
    final provider =
        context.read<LoanProvider>();

    provider.fetchLoans(
      status: status ??
          (_selectedStatusFilter == 'ALL'
              ? null
              : _selectedStatusFilter),
      loanType: loanType ??
          (_selectedTypeFilter == 'ALL'
              ? null
              : _selectedTypeFilter),
      search: search ??
          _searchCtrl.text.trim(),
    );
  }

  // ============================================================
  // NEW LOAN
  // ============================================================

  Future<void> _openNewLoanModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      child: const CreateNewLoanScreen(),
    );

    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoans();
    }
  }

  // ============================================================
  // EXISTING LOAN
  // ============================================================

  Future<void> _openExistingLoanModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      child: const CreateExistingLoanScreen(),
    );

    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoans();
    }
  }

  // ============================================================
  // ADDITIONAL LOAN
  // ============================================================

  Future<void> _openAdditionalLoanModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      child: const CreateAdditionalLoanScreen(),
    );

    if (result == true && mounted) {
      context.read<LoanProvider>().fetchLoans();
    }
  }

  // ============================================================
  // PRINT RECEIPT
  // ============================================================

  Future<void> _printReceipt(
    Loan loan,
  ) async {
    try {
      final receipt =
          await ApiService.getReceipt(
        loanId: loan.id,
        type: loan.status == 'CLOSED'
            ? 'CLOSURE'
            : 'LOAN',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            insetPadding:
                const EdgeInsets.all(10),
            child: A4ReceiptViewer(
              receiptData: receipt.rawData,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Receipt not found: $e'),
        ),
      );
    }
  }

  // ============================================================
  // VIEW DETAILS
  // ============================================================

  Future<void> _viewDetails(
    Loan loan,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoanDetailsScreen(
          loanId: loan.id,
          onNavigate: widget.onNavigate,
        ),
      ),
    );

    if (mounted) {
      context
          .read<LoanProvider>()
          .fetchLoans();
    }
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  Future<void> _openPayment(
    Loan loan,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding:
              const EdgeInsets.all(12),
          child: PaymentScreen(
            preselectedLoanId: loan.id,
          ),
        );
      },
    );

    if (result == true && mounted) {
      context
          .read<LoanProvider>()
          .fetchLoans();
    }
  }

  // ============================================================
  // PARTIAL RELEASE
  // ============================================================

  Future<void> _openPartialRelease(
    Loan loan,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding:
              const EdgeInsets.all(12),
          child:
              PartialReleaseScreen(
            preselectedLoanId: loan.id,
          ),
        );
      },
    );

    if (result == true && mounted) {
      context
          .read<LoanProvider>()
          .fetchLoans();
    }
  }

  // ============================================================
  // CLOSE LOAN
  // ============================================================

  Future<void> _closeLoan(
    Loan loan,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding:
              const EdgeInsets.all(12),
          child: CloseLoanScreen(
            loanId: loan.id,
          ),
        );
      },
    );

    if (result == true && mounted) {
      context
          .read<LoanProvider>()
          .fetchLoans();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<LoanProvider>();

    final loans = provider.loans;

    final width =
        MediaQuery.of(context).size.width;

    final isMobile = width < 600;

    final isTablet =
        width >= 600 && width < 1200;

    final isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor:
          AppTheme.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 10 : 16,
            isMobile ? 10 : 16,
            isMobile ? 10 : 16,
            10,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildResponsiveTopControls(
                isMobile: isMobile,
                isTablet: isTablet,
                isDesktop: isDesktop,
              ),

              SizedBox(
                height: isMobile ? 10 : 14,
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
                    : loans.isEmpty
                        ? _buildEmptyState()
                        : isMobile
                            ? _buildMobileCards(
                                loans,
                              )
                            : isTablet
                                ? _buildTabletCards(
                                    loans,
                                  )
                                : _buildDesktopTable(
                                    loans,
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESPONSIVE TOP CONTROLS
  // ============================================================

  Widget _buildResponsiveTopControls({
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: isDesktop
          ? _buildDesktopControls()
          : isTablet
              ? _buildTabletControls()
              : _buildMobileControls(),
    );
  }

  // ============================================================
  // DESKTOP CONTROLS
  // ============================================================

  Widget _buildDesktopControls() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchField(),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 145,
          child: _buildStatusDropdown(
            compact: true,
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 160,
          child: _buildTypeDropdown(
            compact: true,
          ),
        ),

        const SizedBox(width: 10),

        _buildNewLoanButton(),

        const SizedBox(width: 7),

        _buildAdditionalLoanButton(),

        const SizedBox(width: 7),

        _buildExistingLoanButton(),
      ],
    );
  }

  // ============================================================
  // TABLET CONTROLS
  // ============================================================

  Widget _buildTabletControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSearchField(),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 160,
              child: _buildStatusDropdown(
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 175,
              child: _buildTypeDropdown(
                compact: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildNewLoanButton(
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildExistingLoanButton(
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAdditionalLoanButton(
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE CONTROLS
  // ============================================================

  Widget _buildMobileControls() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSearchField(),

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: _buildStatusDropdown(
                compact: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypeDropdown(
                compact: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: _buildNewLoanButton(
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _buildExistingLoanButton(
                fullWidth: true,
                shortLabel: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        _buildAdditionalLoanButton(
          fullWidth: true,
        ),
      ],
    );
  }

  // ============================================================
  // NEW LOAN BUTTON
  // ============================================================

  Widget _buildNewLoanButton({
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _openNewLoanModal,
        icon: const Icon(
          Icons.add_circle_outline,
          size: 18,
        ),
        label: const Text(
          'New Loan',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              AppTheme.goldPrimary,
          foregroundColor:
              Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING LOAN BUTTON
  // ============================================================

  Widget _buildExistingLoanButton({
    bool fullWidth = false,
    bool shortLabel = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 46,
      child: OutlinedButton.icon(
        onPressed:
            _openExistingLoanModal,
        icon: const Icon(
          Icons.history_edu_outlined,
          size: 18,
        ),
        label: Text(
          shortLabel
              ? 'Existing'
              : 'Existing Loan',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              AppTheme.darkNavy,
          side: const BorderSide(
            color:
                AppTheme.silverBorder,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADDITIONAL LOAN BUTTON
  // ============================================================

  Widget _buildAdditionalLoanButton({
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 46,
      child: OutlinedButton.icon(
        onPressed:
            _openAdditionalLoanModal,
        icon: const Icon(
          Icons.add_card_outlined,
          size: 18,
        ),
        label: const Text(
          'Additional Loan',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              AppTheme.darkNavy,
          side: const BorderSide(
            color:
                AppTheme.silverBorder,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      textInputAction:
          TextInputAction.search,
      decoration: InputDecoration(
        hintText:
            'Search Loan No, Customer, Manual No...',
        prefixIcon: const Icon(
          Icons.search,
          color: AppTheme.silverDark,
        ),
        suffixIcon:
            _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();

                      _fetchWithFilters(
                        search: '',
                      );

                      setState(() {});
                    },
                  )
                : null,
        filled: true,
        fillColor:
            AppTheme.backgroundLight,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide: const BorderSide(
            color:
                AppTheme.silverBorder,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide: const BorderSide(
            color:
                AppTheme.goldPrimary,
            width: 1.2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
      ),
      onChanged: (value) {
        _fetchWithFilters(
          search: value.trim(),
        );

        setState(() {});
      },
    );
  }

  // ============================================================
  // STATUS DROPDOWN
  // ============================================================

  Widget _buildStatusDropdown({
    required bool compact,
  }) {
    return Container(
      height: compact ? 48 : 46,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color:
            AppTheme.backgroundLight,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:
              _selectedStatusFilter,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
          ),
          items: const [
            DropdownMenuItem(
              value: 'ALL',
              child: Text(
                'All Status',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'ACTIVE',
              child: Text(
                'Active',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'CLOSED',
              child: Text(
                'Closed',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedStatusFilter =
                  value;
            });

            _fetchWithFilters();
          },
        ),
      ),
    );
  }

  // ============================================================
  // TYPE DROPDOWN
  // ============================================================

  Widget _buildTypeDropdown({
    required bool compact,
  }) {
    return Container(
      height: compact ? 48 : 46,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color:
            AppTheme.backgroundLight,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:
              _selectedTypeFilter,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
          ),
          items: const [
            DropdownMenuItem(
              value: 'ALL',
              child: Text(
                'All Types',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'NEW_LOAN',
              child: Text(
                '*  New Loan',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'EXISTING_LOAN',
              child: Text(
                '#  Existing Loan',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'ADDITIONAL_LOAN',
              child: Text(
                'Additional',
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedTypeFilter =
                  value;
            });

            _fetchWithFilters();
          },
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color:
                    AppTheme.silverLight,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: const Icon(
                Icons.account_balance,
                size: 36,
                color:
                    AppTheme.silverDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pawn loans found',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try changing your search or filters.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:
                    AppTheme.silverDark,
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
    List<Loan> loans,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(14),
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              child:
                  SingleChildScrollView(
                primary: true,
                physics:
                    const AlwaysScrollableScrollPhysics(),
                child:
                    SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    width:
                        constraints.maxWidth <
                                1250
                            ? 1250
                            : constraints
                                .maxWidth,
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      dataRowMaxHeight: 70,
                      headingRowHeight: 54,
                      headingRowColor:
                          WidgetStateProperty
                              .all(
                        AppTheme
                            .silverLight,
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Loan No',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Customer',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Type',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Principal',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Interest',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total Due',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Total Paid',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Remaining',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Collateral',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      rows: loans.map(
                        (loan) {
                          return DataRow(
                            cells: [
                              // LOAN NO
                              DataCell(
                                SizedBox(
                                  width: 125,
                                  child:
                                      Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        loan.loanNo,
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                          fontSize:
                                              12,
                                          color:
                                              AppTheme
                                                  .darkNavy,
                                        ),
                                      ),
                                      if (loan.manualLoanNo !=
                                              null &&
                                          loan.manualLoanNo!
                                              .isNotEmpty)
                                        Text(
                                          'Manual: ${loan.manualLoanNo}',
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                9,
                                            color:
                                                AppTheme
                                                    .silverDark,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // CUSTOMER
                              DataCell(
                                SizedBox(
                                  width: 145,
                                  child:
                                      Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        loan.customerName ??
                                            'Customer',
                                        maxLines:
                                            2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w700,
                                          fontSize:
                                              12,
                                        ),
                                      ),
                                      if ((loan.customerCode ??
                                              '')
                                          .isNotEmpty)
                                        Text(
                                          loan.customerCode!,
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                9,
                                            color:
                                                AppTheme
                                                    .silverDark,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // TYPE
                              DataCell(
                                _buildLoanTypeSymbol(
                                  loan.loanType,
                                  size: 32,
                                ),
                              ),

                              // PRINCIPAL
                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    loan
                                        .principalAmount,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                  ),
                                ),
                              ),

                              // INTEREST
                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    loan.totalInterest +
                                        loan
                                            .manualFinalInterest,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                  ),
                                ),
                              ),

                              // TOTAL DUE
                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    loan.totalDue,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ),

                              // TOTAL PAID
                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    loan.totalPaid,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    color:
                                        Color(
                                      0xFF065F46,
                                    ),
                                  ),
                                ),
                              ),

                              // REMAINING
                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    loan
                                        .remainingBalance,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                    color: loan
                                                .remainingBalance >
                                            0
                                        ? AppTheme
                                            .goldDark
                                        : AppTheme
                                            .silverDark,
                                  ),
                                ),
                              ),

                              // COLLATERAL
                              DataCell(
                                Text(
                                  '${AppConstants.formatWeight(loan.totalPledgedWeight)} (${loan.totalItemsCount})',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 10,
                                  ),
                                ),
                              ),

                              // STATUS
                              DataCell(
                                GoldBadge(
                                  status:
                                      loan.status,
                                  fontSize: 9,
                                ),
                              ),

                              // ACTIONS
                              DataCell(
                                FittedBox(
                                  fit: BoxFit
                                      .scaleDown,
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,
                                    children: [
                                      _desktopAction(
                                        icon: Icons
                                            .visibility_outlined,
                                        color:
                                            AppTheme
                                                .darkNavy,
                                        tooltip:
                                            'View Details',
                                        onPressed:
                                            () =>
                                                _viewDetails(
                                          loan,
                                        ),
                                      ),

                                      if (loan
                                          .isActive)
                                        _desktopAction(
                                          icon: Icons
                                              .payments_outlined,
                                          color:
                                              const Color(
                                            0xFF065F46,
                                          ),
                                          tooltip:
                                              'Payment',
                                          onPressed:
                                              () =>
                                                  _openPayment(
                                            loan,
                                          ),
                                        ),

                                      if (loan
                                          .isActive)
                                        _desktopAction(
                                          icon: Icons
                                              .lock_open_outlined,
                                          color:
                                              AppTheme
                                                  .goldDark,
                                          tooltip:
                                              'Partial Release',
                                          onPressed:
                                              () =>
                                                  _openPartialRelease(
                                            loan,
                                          ),
                                        ),

                                      if (loan
                                          .isActive)
                                        _desktopAction(
                                          icon: Icons
                                              .lock_outline,
                                          color:
                                              AppTheme
                                                  .statusDanger,
                                          tooltip:
                                              'Close Loan',
                                          onPressed:
                                              () =>
                                                  _closeLoan(
                                            loan,
                                          ),
                                        ),

                                      _desktopAction(
                                        icon: Icons
                                            .print_outlined,
                                        color:
                                            AppTheme
                                                .silverDark,
                                        tooltip:
                                            'Print Receipt',
                                        onPressed:
                                            () =>
                                                _printReceipt(
                                          loan,
                                        ),
                                      ),
                                    ],
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
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP ACTION
  // ============================================================

  Widget _desktopAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints:
          const BoxConstraints(
        minWidth: 30,
        minHeight: 30,
      ),
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 17,
        color: color,
      ),
      onPressed: onPressed,
    );
  }

  // ============================================================
  // MOBILE LIST
  // ============================================================

  Widget _buildMobileCards(
    List<Loan> loans,
  ) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        primary: true,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(
          left: 1,
          right: 1,
          bottom: 24,
        ),
        itemCount: loans.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (context, index) {
          return _buildMobileLoanCard(
            loans[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // MOBILE LOAN CARD
  // ============================================================

  Widget _buildMobileLoanCard(
    Loan loan,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 7,
            offset:
                const Offset(0, 2),
            color: Colors.black
                .withValues(
              alpha: 0.05,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap: () =>
              _viewDetails(loan),
          child: Padding(
            padding:
                const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildMobileLoanHeader(
                  loan,
                ),

                const SizedBox(height: 12),

                const Divider(
                  height: 1,
                ),

                const SizedBox(height: 12),

                _buildMobileFinancialGrid(
                  loan,
                ),

                const SizedBox(height: 12),

                _buildMobileLoanMeta(
                  loan,
                ),

                const SizedBox(height: 12),

                _buildMobileActions(
                  loan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE HEADER
  // ============================================================

  Widget _buildMobileLoanHeader(
    Loan loan,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildLoanTypeSymbol(
          loan.loanType,
          size: 42,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                loan.loanNo,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      AppTheme.darkNavy,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                _getLoanTypeName(
                  loan.loanType,
                ),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      AppTheme.silverDark,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                loan.customerName ??
                    'Customer',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              if ((loan.customerCode ??
                      '')
                  .isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  loan.customerCode!,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
              ],

              if (loan.manualLoanNo !=
                      null &&
                  loan.manualLoanNo!
                      .isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Manual No: ${loan.manualLoanNo}',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 6),

        GoldBadge(
          status: loan.status,
          fontSize: 9,
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE FINANCIAL GRID
  // ============================================================

  Widget _buildMobileFinancialGrid(
    Loan loan,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _mobileInfoItem(
                label: 'Principal',
                value:
                    AppConstants
                        .formatCurrency(
                  loan.principalAmount,
                ),
                valueColor:
                    AppTheme.darkNavy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mobileInfoItem(
                label: 'Total Due',
                value:
                    AppConstants
                        .formatCurrency(
                  loan.totalDue,
                ),
                valueColor:
                    AppTheme.darkNavy,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _mobileInfoItem(
                label: 'Total Paid',
                value:
                    AppConstants
                        .formatCurrency(
                  loan.totalPaid,
                ),
                valueColor:
                    const Color(
                  0xFF065F46,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mobileInfoItem(
                label: 'Remaining',
                value:
                    AppConstants
                        .formatCurrency(
                  loan.remainingBalance,
                ),
                valueColor:
                    loan.remainingBalance >
                            0
                        ? AppTheme
                            .goldDark
                        : AppTheme
                            .silverDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _mobileInfoItem(
                label: 'Interest',
                value:
                    AppConstants
                        .formatCurrency(
                  loan.totalInterest +
                      loan
                          .manualFinalInterest,
                ),
                valueColor:
                    AppTheme.darkNavy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _mobileInfoItem(
                label: 'Collateral',
                value:
                    '${AppConstants.formatWeight(loan.totalPledgedWeight)} • ${loan.totalItemsCount} item${loan.totalItemsCount == 1 ? '' : 's'}',
                valueColor:
                    AppTheme.darkNavy,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE INFO ITEM
  // ============================================================

  Widget _mobileInfoItem({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 62,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            AppTheme.backgroundLight,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 9,
              color:
                  AppTheme.silverDark,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE META
  // ============================================================

  Widget _buildMobileLoanMeta(
    Loan loan,
  ) {
    return Row(
      children: [
        Expanded(
          child: _mobileMetaItem(
            icon:
                Icons.inventory_2_outlined,
            label: 'Collateral',
            value:
                '${AppConstants.formatWeight(loan.totalPledgedWeight)} • ${loan.totalItemsCount} item${loan.totalItemsCount == 1 ? '' : 's'}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _mobileMetaItem(
            icon:
                Icons.calendar_today_outlined,
            label: 'Opened',
            value:
                AppConstants.formatDate(
              loan.openedDate,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE META ITEM
  // ============================================================

  Widget _mobileMetaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.7,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
                AppTheme.silverDark,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        AppTheme.silverDark,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE ACTIONS
  // ============================================================

  Widget _buildMobileActions(
    Loan loan,
  ) {
    if (loan.isActive) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    _mobileActionButton(
                  icon:
                      Icons.visibility_outlined,
                  label: 'View',
                  onPressed: () =>
                      _viewDetails(
                    loan,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child:
                    _mobileActionButton(
                  icon:
                      Icons.print_outlined,
                  label: 'Print',
                  onPressed: () =>
                      _printReceipt(
                    loan,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Row(
            children: [
              Expanded(
                child:
                    _mobileActionButton(
                  icon:
                      Icons.payments_outlined,
                  label: 'Payment',
                  iconColor:
                      const Color(
                    0xFF065F46,
                  ),
                  onPressed: () =>
                      _openPayment(
                    loan,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child:
                    _mobileActionButton(
                  icon:
                      Icons.lock_open_outlined,
                  label: 'Release',
                  iconColor:
                      AppTheme.goldDark,
                  onPressed: () =>
                      _openPartialRelease(
                    loan,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          SizedBox(
            width: double.infinity,
            child:
                _mobileCloseButton(
              loan,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _mobileActionButton(
            icon:
                Icons.visibility_outlined,
            label: 'View',
            onPressed: () =>
                _viewDetails(loan),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _mobileActionButton(
            icon:
                Icons.print_outlined,
            label: 'Print',
            onPressed: () =>
                _printReceipt(loan),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE ACTION BUTTON
  // ============================================================

  Widget _mobileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(9),
        child: Container(
          height: 44,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color:
                AppTheme.backgroundLight,
            borderRadius:
                BorderRadius.circular(9),
            border: Border.all(
              color:
                  AppTheme.silverBorder,
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: iconColor ??
                    AppTheme.darkNavy,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE CLOSE BUTTON
  // ============================================================

  Widget _mobileCloseButton(
    Loan loan,
  ) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () =>
            _closeLoan(loan),
        icon: const Icon(
          Icons.lock_outline,
          size: 17,
        ),
        label: const Text(
          'Close Loan',
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              AppTheme.statusDanger,
          side: BorderSide(
            color:
                AppTheme.statusDanger
                    .withValues(
              alpha: 0.45,
            ),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLET GRID
  // ============================================================

  Widget _buildTabletCards(
    List<Loan> loans,
  ) {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final columns =
            constraints.maxWidth >= 850
                ? 2
                : 1;

        return Scrollbar(
          thumbVisibility: true,
          child: GridView.builder(
            primary: true,
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.only(
              left: 1,
              right: 1,
              bottom: 24,
            ),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent:
                  columns == 2
                      ? 390
                      : 375,
            ),
            itemCount: loans.length,
            itemBuilder:
                (context, index) {
              return _buildTabletLoanCard(
                loans[index],
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // TABLET CARD
  // ============================================================

  Widget _buildTabletLoanCard(
    Loan loan,
  ) {
    final type =
        loan.loanType.toUpperCase().trim();

    final isNew =
        type == 'NEW_LOAN' ||
        type == 'NEW' ||
        type == '*';

    final isExisting =
        type == 'EXISTING_LOAN' ||
        type == 'EXISTING' ||
        type == '#';

    final symbol = isNew
        ? '*'
        : isExisting
            ? '#'
            : 'ADDITIONAL';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset:
                const Offset(0, 2),
            color: Colors.black
                .withValues(
              alpha: 0.05,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap: () =>
              _viewDetails(loan),
          child: Padding(
            padding:
                const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment:
                          Alignment.center,
                      decoration:
                          BoxDecoration(
                        color: isNew
                            ? Colors.blue
                                .withValues(
                                alpha: 0.09,
                              )
                            : isExisting
                                ? Colors
                                    .deepPurple
                                    .withValues(
                                    alpha: 0.09,
                                  )
                                : AppTheme
                                    .silverLight,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        border:
                            Border.all(
                          color: isNew
                              ? Colors.blue
                                  .withValues(
                                  alpha:
                                      0.25,
                                )
                              : isExisting
                                  ? Colors
                                      .deepPurple
                                      .withValues(
                                      alpha:
                                          0.25,
                                    )
                                  : AppTheme
                                      .silverBorder,
                        ),
                      ),
                      child: Text(
                        symbol,
                        textAlign:
                            TextAlign.center,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .clip,
                        style:
                            TextStyle(
                          fontSize: isNew ||
                                  isExisting
                              ? 22
                              : 7,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            loan.loanNo,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              color: AppTheme
                                  .darkNavy,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            _getLoanTypeName(
                              loan.loanType,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color: AppTheme
                                  .silverDark,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            loan.customerName ??
                                'Customer',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    GoldBadge(
                      status:
                          loan.status,
                      fontSize: 9,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                if (loan.manualLoanNo !=
                        null &&
                    loan.manualLoanNo!
                        .isNotEmpty)
                  _tabletManualLoan(
                    loan.manualLoanNo!,
                  ),

                const SizedBox(
                  height: 10,
                ),

                // MONEY ROW 1
                Row(
                  children: [
                    Expanded(
                      child:
                          _tabletAmountBox(
                        'Principal',
                        AppConstants
                            .formatCurrency(
                          loan
                              .principalAmount,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          _tabletAmountBox(
                        'Total Due',
                        AppConstants
                            .formatCurrency(
                          loan.totalDue,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                // MONEY ROW 2
                Row(
                  children: [
                    Expanded(
                      child:
                          _tabletAmountBox(
                        'Total Paid',
                        AppConstants
                            .formatCurrency(
                          loan.totalPaid,
                        ),
                        valueColor:
                            const Color(
                          0xFF065F46,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          _tabletAmountBox(
                        'Remaining',
                        AppConstants
                            .formatCurrency(
                          loan
                              .remainingBalance,
                        ),
                        valueColor:
                            loan.remainingBalance >
                                    0
                                ? AppTheme
                                    .goldDark
                                : AppTheme
                                    .silverDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                // DETAILS
                Row(
                  children: [
                    Expanded(
                      child:
                          _tabletDetailBox(
                        Icons
                            .inventory_2_outlined,
                        'Collateral',
                        '${AppConstants.formatWeight(loan.totalPledgedWeight)} • ${loan.totalItemsCount} item${loan.totalItemsCount == 1 ? '' : 's'}',
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child:
                          _tabletDetailBox(
                        Icons
                            .calendar_today_outlined,
                        'Opened',
                        AppConstants
                            .formatDate(
                          loan.openedDate,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ACTIONS
                _buildTabletActions(
                  loan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLET MANUAL NUMBER
  // ============================================================

  Widget _tabletManualLoan(
    String manualLoanNo,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            AppTheme.backgroundLight,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tag,
            size: 14,
            color:
                AppTheme.silverDark,
          ),
          const SizedBox(width: 5),
          const Text(
            'Manual Loan No:',
            style:
                TextStyle(
              fontSize: 9,
              color:
                  AppTheme.silverDark,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              manualLoanNo,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLET AMOUNT BOX
  // ============================================================

  Widget _tabletAmountBox(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Container(
      height: 57,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color:
            AppTheme.backgroundLight,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  AppTheme.silverDark,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w900,
              color: valueColor ??
                  AppTheme.darkNavy,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLET DETAIL BOX
  // ============================================================

  Widget _tabletDetailBox(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      height: 57,
      padding:
          const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                AppTheme.silverDark,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 8,
                    color:
                        AppTheme.silverDark,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLET ACTIONS
  // ============================================================

  Widget _buildTabletActions(
    Loan loan,
  ) {
    if (loan.isActive) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _tabletAction(
                  Icons.visibility_outlined,
                  'View',
                  () =>
                      _viewDetails(
                    loan,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabletAction(
                  Icons.print_outlined,
                  'Print',
                  () =>
                      _printReceipt(
                    loan,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabletAction(
                  Icons.payments_outlined,
                  'Payment',
                  () =>
                      _openPayment(
                    loan,
                  ),
                  color:
                      const Color(
                    0xFF065F46,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _tabletAction(
                  Icons.lock_open_outlined,
                  'Release',
                  () =>
                      _openPartialRelease(
                    loan,
                  ),
                  color:
                      AppTheme.goldDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child:
                    _tabletCloseAction(
                  loan,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _tabletAction(
            Icons.visibility_outlined,
            'View',
            () =>
                _viewDetails(loan),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _tabletAction(
            Icons.print_outlined,
            'Print',
            () =>
                _printReceipt(loan),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TABLET ACTION BUTTON
  // ============================================================

  Widget _tabletAction(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 15,
          color: color ??
              AppTheme.darkNavy,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize: 9,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              color ??
                  AppTheme.darkNavy,
          side: BorderSide(
            color:
                AppTheme.silverBorder,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 5,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLET CLOSE ACTION
  // ============================================================

  Widget _tabletCloseAction(
    Loan loan,
  ) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: () =>
            _closeLoan(loan),
        icon: const Icon(
          Icons.lock_outline,
          size: 15,
        ),
        label: const Text(
          'Close Loan',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              AppTheme.statusDanger,
          side: BorderSide(
            color: AppTheme.statusDanger
                .withValues(
              alpha: 0.45,
            ),
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 5,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}