// lib/screens/customers/customer_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/gold_item.dart';
import '../../models/loan.dart';
import '../../models/payment.dart';
import '../../models/release.dart';
import '../../models/transaction.dart';
import '../../providers/customer_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/responsive_layout.dart';
import '../gold/add_gold_screen.dart';
import '../loans/create_new_loan_screen.dart';
import '../loans/loan_details_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final int customerId;
  final Function(int tab, {Map<String, dynamic>? initialParams})? onNavigate;
  final bool autoOpenAddGold;
  final List<int>? autoOpenNewLoanWithGoldIds;

  const CustomerProfileScreen({
    super.key,
    required this.customerId,
    this.onNavigate,
    this.autoOpenAddGold = false,
    this.autoOpenNewLoanWithGoldIds,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CustomerProvider>().fetchCustomerDetails(widget.customerId);
      if (!mounted) return;
      if (widget.autoOpenAddGold) {
        _openAddGoldModal();
      } else if (widget.autoOpenNewLoanWithGoldIds != null &&
          widget.autoOpenNewLoanWithGoldIds!.isNotEmpty) {
        _openNewLoanModal(preselectedGoldItemIds: widget.autoOpenNewLoanWithGoldIds);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddGoldModal() async {
    final result = await showResponsiveDialog<dynamic>(
      context: context,
      child: AddGoldScreen(customerId: widget.customerId),
    );

    if (!mounted) return;
    context.read<CustomerProvider>().fetchCustomerDetails(widget.customerId);

    if (result is Map && result['action'] == 'next') {
      final rawGoldIds = result['goldItemIds'];
      List<int> goldIds = [];
      if (rawGoldIds is List) {
        goldIds = rawGoldIds.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0).toList();
      }
      _openNewLoanModal(preselectedGoldItemIds: goldIds);
    }
  }

  void _openNewLoanModal({List<int>? preselectedGoldItemIds}) async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      child: CreateNewLoanScreen(
        preselectedCustomerId: widget.customerId,
        preselectedGoldItemIds: preselectedGoldItemIds,
      ),
    );

    if (result == true && mounted) {
      context.read<CustomerProvider>().fetchCustomerDetails(widget.customerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customer = provider.selectedCustomer;
    final summary = provider.customerSummary;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1200;
    final isDesktop = width >= 1200;

    if (provider.isLoadingDetails || customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Profile')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.goldPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          '${customer.name} (${customer.customerCode})',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!isMobile)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  provider.fetchCustomerDetails(widget.customerId),
            ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  provider.fetchCustomerDetails(widget.customerId),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : isTablet ? 16 : 20,
          vertical: isMobile ? 10 : 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerHeader(
                  customer,
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
                SizedBox(height: isMobile ? 10 : 18),
                _buildSummarySection(
                  summary,
                  isMobile: isMobile,
                  isTablet: isTablet,
                ),
                SizedBox(height: isMobile ? 10 : 20),
                _buildTabsSection(
                  provider,
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerAvatar(String? photoUrl, String name, {required double radius}) {
    final resolved = ApiService.resolvePhotoUrl(photoUrl);

    if (resolved != null && resolved.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: AppTheme.goldLight,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
                    color: AppTheme.goldDark,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.goldLight,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'C',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
          color: AppTheme.goldDark,
        ),
      ),
    );
  }

  Widget _buildCustomerHeader(
    dynamic customer, {
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final avatarRadius = isMobile ? 28.0 : isTablet ? 32.0 : 36.0;

    final customerInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              customer.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkNavy,
              ),
            ),
            GoldBadge(status: customer.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Customer ID: ${customer.customerCode} • Phone: ${customer.mobile}',
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            color: AppTheme.silverDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Address: ${customer.address}',
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            color: AppTheme.silverDark,
          ),
          maxLines: isMobile ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        if ((customer.aadhaarNumber != null &&
                customer.aadhaarNumber!.isNotEmpty) ||
            (customer.panNumber != null &&
                customer.panNumber!.isNotEmpty)) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 3,
            children: [
              if (customer.aadhaarNumber != null &&
                  customer.aadhaarNumber!.isNotEmpty)
                Text(
                  'Aadhaar: ${customer.aadhaarNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (customer.panNumber != null &&
                  customer.panNumber!.isNotEmpty)
                Text(
                  'PAN: ${customer.panNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _openAddGoldModal,
          icon: const Icon(Icons.add, size: 16),
          label: Text(isMobile ? 'Add Gold' : 'Add Gold'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkNavy,
            foregroundColor: Colors.white,
            minimumSize: Size(isMobile ? 0 : 110, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _openNewLoanModal,
          icon: const Icon(Icons.monetization_on, size: 16),
          label: const Text('Create Loan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.goldPrimary,
            foregroundColor: AppTheme.darkNavy,
            minimumSize: Size(isMobile ? 0 : 125, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerAvatar(
                      customer.photoUrl,
                      customer.name,
                      radius: avatarRadius,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: customerInfo),
                  ],
                ),
                const SizedBox(height: 12),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerAvatar(
                  customer.photoUrl,
                  customer.name,
                  radius: avatarRadius,
                ),
                const SizedBox(width: 18),
                Expanded(child: customerInfo),
                if (isTablet) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: 245, child: actions),
                ] else ...[
                  const SizedBox(width: 18),
                  actions,
                ],
              ],
            ),
    );
  }

  Widget _buildSummarySection(
    dynamic summary, {
    required bool isMobile,
    required bool isTablet,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.silverBorder, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INTERCONNECTED FINANCIAL & COLLATERAL SUMMARY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 10),
            // Row 1: Total Gold Items & Total Gold Weight
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Total Gold Items',
                    value: '${summary.totalGoldItems} items',
                    icon: Icons.diamond_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Total Gold Weight',
                    value: AppConstants.formatWeight(summary.totalGoldWeight),
                    icon: Icons.scale,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Pledged Weight & Released Weight
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Pledged Weight',
                    value: AppConstants.formatWeight(summary.pledgedGoldWeight),
                    icon: Icons.lock_outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Released Weight',
                    value: AppConstants.formatWeight(summary.releasedGoldWeight),
                    icon: Icons.lock_open_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: Total Loans & Total Loan Amount
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Total Loans',
                    value: '${summary.totalLoans} (${summary.activeLoans} Active)',
                    icon: Icons.account_balance,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Total Loan Amount',
                    value: AppConstants.formatCurrency(summary.totalLoanAmount),
                    icon: Icons.monetization_on,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 4: Total Paid & Total Interest
            Row(
              children: [
                Expanded(
                  child: _MetricChip(
                    label: 'Total Paid',
                    value: AppConstants.formatCurrency(summary.totalPaid),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricChip(
                    label: 'Total Interest',
                    value: AppConstants.formatCurrency(summary.totalInterest),
                    icon: Icons.percent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 5: Total Outstanding (Full Width)
            SizedBox(
              width: double.infinity,
              child: _MetricChip(
                label: 'Total Outstanding',
                value: AppConstants.formatCurrency(summary.totalOutstanding),
                icon: Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(height: 8),
            // Bottom: Closed Loans Summary (Full Width)
            SizedBox(
              width: double.infinity,
              child: _MetricChip(
                label: 'Closed Loans',
                value: '${summary.closedLoans} Closed Loans Settled',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
      );
    }

    final items = [
      _MetricChip(
        label: 'Total Gold Items',
        value: '${summary.totalGoldItems} items',
        icon: Icons.diamond_outlined,
      ),
      _MetricChip(
        label: 'Total Gold Weight',
        value: AppConstants.formatWeight(summary.totalGoldWeight),
        icon: Icons.scale,
      ),
      _MetricChip(
        label: 'Pledged Weight',
        value: AppConstants.formatWeight(summary.pledgedGoldWeight),
        icon: Icons.lock_outline,
      ),
      _MetricChip(
        label: 'Released Weight',
        value: AppConstants.formatWeight(summary.releasedGoldWeight),
        icon: Icons.lock_open_outlined,
      ),
      _MetricChip(
        label: 'Total Loans',
        value: '${summary.totalLoans} (${summary.activeLoans} Active)',
        icon: Icons.account_balance,
      ),
      _MetricChip(
        label: 'Total Loan Amount',
        value: AppConstants.formatCurrency(summary.totalLoanAmount),
        icon: Icons.monetization_on,
      ),
      _MetricChip(
        label: 'Total Paid',
        value: AppConstants.formatCurrency(summary.totalPaid),
        icon: Icons.payments_outlined,
      ),
      _MetricChip(
        label: 'Total Interest',
        value: AppConstants.formatCurrency(summary.totalInterest),
        icon: Icons.percent,
      ),
      _MetricChip(
        label: 'Total Outstanding',
        value: AppConstants.formatCurrency(summary.totalOutstanding),
        icon: Icons.warning_amber_rounded,
      ),
      _MetricChip(
        label: 'Closed Loans',
        value: '${summary.closedLoans} Closed',
        icon: Icons.check_circle_outline,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INTERCONNECTED FINANCIAL & COLLATERAL SUMMARY',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = 5;
              if (constraints.maxWidth < 650) {
                columns = 2;
              } else if (constraints.maxWidth < 1000) {
                columns = 3;
              } else if (constraints.maxWidth < 1350) {
                columns = 4;
              } else {
                columns = 5;
              }

              final itemWidth = (constraints.maxWidth - ((columns - 1) * 12)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((chip) {
                  return SizedBox(
                    width: itemWidth,
                    child: chip,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection(
    CustomerProvider provider, {
    required bool isMobile,
  }) {
    final tabs = [
      Tab(text: 'Gold (${provider.customerGoldItems.length})'),
      Tab(text: 'Loans (${provider.customerLoans.length})'),
      Tab(text: 'Payments (${provider.customerPayments.length})'),
      Tab(text: 'Releases (${provider.customerReleases.length})'),
      Tab(text: 'Transactions (${provider.customerTransactions.length})'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        children: [
          SizedBox(
            height: isMobile ? 48 : 52,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              labelColor: AppTheme.darkNavy,
              unselectedLabelColor: AppTheme.silverDark,
              indicatorColor: AppTheme.goldPrimary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: isMobile ? 11 : 13,
              ),
              tabs: tabs,
            ),
          ),
          const Divider(height: 1, color: AppTheme.silverBorder),
          SizedBox(
            height: isMobile ? 560 : isTabletSafeHeight(context),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGoldItemsTab(provider.customerGoldItems),
                _buildLoansTab(provider.customerLoans),
                _buildPaymentsTab(provider.customerPayments),
                _buildReleasesTab(provider.customerReleases),
                _buildTransactionsTab(provider.customerTransactions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double isTabletSafeHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 1200) return 520;
    return 480;
  }

  // TAB 1: Gold Items
  Widget _buildGoldItemsTab(List<GoldItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond_outlined, size: 48, color: AppTheme.silverDark),
            const SizedBox(height: 8),
            const Text('No gold items registered for this customer'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _openAddGoldModal, child: const Text('Add Gold Item')),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final g = items[index];
        return Material(
  color: Colors.transparent,
  child: ListTile(
    leading: const CircleAvatar(
      backgroundColor: AppTheme.goldLight,
      child:  Icon(
        Icons.diamond,
        size: 18,
        color: AppTheme.goldDark,
      ),
    ),
    title: Text(
      g.itemName,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Text(
      'Purity: ${g.purity} • Weight: ${AppConstants.formatWeight(g.weight)} ${g.remarks != null ? "• ${g.remarks}" : ""}',
    ),
    trailing: GoldBadge(status: g.status),
  ),
);
      },
    );
  }

  // TAB 2: Pawn Loans
  Widget _buildLoansTab(List<Loan> loans) {
    if (loans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on_outlined,
                size: 48,
                color: AppTheme.silverDark,
              ),
              const SizedBox(height: 8),
              const Text('No pawn loans created yet'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _openNewLoanModal,
                child: const Text('Create New Loan'),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1200;

    // Mobile: use a real card layout instead of ListTile's constrained
    // title/subtitle/trailing areas. This prevents the loan number and
    // collateral text from being squeezed into a very narrow column.
    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
        itemCount: loans.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final l = loans[index];

          final type = l.loanType.toString().toUpperCase();
          final typeSymbol = type == 'EXISTING_LOAN' ||
                  type == 'EXISTING' ||
                  type == '#'
              ? '#'
              : '*';

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoanDetailsScreen(
                      loanId: l.id,
                      onNavigate: widget.onNavigate,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.silverBorder,
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top row: loan type + loan number + amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppTheme.silverLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            size: 18,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.goldLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      typeSymbol,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.darkNavy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      l.loanNo.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.darkNavy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Opened: ${AppConstants.formatDate(l.openedDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.silverDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppConstants.formatCurrency(l.principalAmount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Bal: ${AppConstants.formatCurrency(l.remainingBalance)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(
                      height: 1,
                      color: AppTheme.silverBorder,
                    ),
                    const SizedBox(height: 9),

                    // Bottom row: collateral + status + navigation
                    Row(
                      children: [
                        const Icon(
                          Icons.diamond_outlined,
                          size: 15,
                          color: AppTheme.goldDark,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Collateral: ${AppConstants.formatWeight(l.totalPledgedWeight)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.silverDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GoldBadge(status: l.status),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: AppTheme.goldDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Tablet: retain a compact list row but give each logical area enough
    // horizontal space.
    if (isTablet) {
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: loans.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final l = loans[index];
          final type = l.loanType.toString().toUpperCase();
          final typeSymbol = type == 'EXISTING_LOAN' ||
                  type == 'EXISTING' ||
                  type == '#'
              ? '#'
              : '*';

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoanDetailsScreen(
                    loanId: l.id,
                    onNavigate: widget.onNavigate,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.silverLight,
                    child:  Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      typeSymbol,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.loanNo.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Opened: ${AppConstants.formatDate(l.openedDate)} • Collateral: ${AppConstants.formatWeight(l.totalPledgedWeight)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.silverDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppConstants.formatCurrency(l.principalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bal: ${AppConstants.formatCurrency(l.remainingBalance)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.goldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  GoldBadge(status: l.status),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.goldDark,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Desktop: full-width row with all important loan information visible.
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final l = loans[index];
        final type = l.loanType.toString().toUpperCase();
        final typeSymbol = type == 'EXISTING_LOAN' ||
                type == 'EXISTING' ||
                type == '#'
            ? '#'
            : '*';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LoanDetailsScreen(
                  loanId: l.id,
                  onNavigate: widget.onNavigate,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.silverLight,
                  child:  Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text(
                    typeSymbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.loanNo.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Opened: ${AppConstants.formatDate(l.openedDate)} • Collateral: ${AppConstants.formatWeight(l.totalPledgedWeight)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.silverDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppConstants.formatCurrency(l.principalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Bal: ${AppConstants.formatCurrency(l.remainingBalance)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.goldDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                GoldBadge(status: l.status),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.goldDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 3: Payments
  Widget _buildPaymentsTab(List<Payment> payments) {
    if (payments.isEmpty) {
      return const Center(child: Text('No payment records found', style: TextStyle(color: AppTheme.silverDark)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = payments[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFECFDF5),
              child: Icon(Icons.check, size: 18, color: Color(0xFF065F46)),
            ),
            title: Text('${p.receiptNo} - ${p.loanNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${AppConstants.formatDate(p.paymentDate)} ${AppConstants.formatTime(p.paymentTime)} • Mode: ${p.paymentMode}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppConstants.formatCurrency(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                Text('Rem: ${AppConstants.formatCurrency(p.remainingBalance)}', style: const TextStyle(fontSize: 10, color: AppTheme.silverDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 4: Releases
  Widget _buildReleasesTab(List<PartialRelease> releases) {
    if (releases.isEmpty) {
      return const Center(child: Text('No gold releases recorded', style: TextStyle(color: AppTheme.silverDark)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: releases.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final r = releases[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.silverLight,
              child: Icon(Icons.lock_open, size: 18, color: AppTheme.darkNavy),
            ),
            title: Text('${r.releaseNo} - ${r.loanNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${AppConstants.formatDate(r.releaseDate)} • Released: ${AppConstants.formatWeight(r.totalWeightReleased)}'),
            trailing: Text(AppConstants.formatWeight(r.totalWeightReleased), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // TAB 5: Transactions
  Widget _buildTransactionsTab(List<LoanTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions recorded', style: TextStyle(color: AppTheme.silverDark)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.silverLight,
              child: Icon(Icons.swap_horiz, size: 18, color: AppTheme.goldDark),
            ),
            title: Text(tx.humanReadableType, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${tx.transactionCode} • ${AppConstants.formatDate(tx.date)} ${AppConstants.formatTime(tx.time)} ${tx.remarks != null ? "• ${tx.remarks}" : ""}'),
            trailing: Text(
              tx.amount > 0 ? AppConstants.formatCurrency(tx.amount) : (tx.weight > 0 ? AppConstants.formatWeight(tx.weight) : '-'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}

class _MetricChip extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  State<_MetricChip> createState() => _MetricChipState();
}

class _MetricChipState extends State<_MetricChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered ? AppTheme.goldPrimary : AppTheme.silverBorder,
            width: _isHovered ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppTheme.goldPrimary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _isHovered ? 8 : 4,
              offset: Offset(0, _isHovered ? 2 : 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: _isHovered ? AppTheme.goldDark : AppTheme.darkNavy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: _isHovered ? AppTheme.goldDark : AppTheme.silverDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkNavy,
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
}
