// lib/screens/customers/customer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/responsive_layout.dart';
import 'new_customer_screen.dart';
import 'customer_profile_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final Function(int tab, {Map<String, dynamic>? initialParams})?
      onNavigate;

  const CustomerListScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<CustomerListScreen> createState() =>
      _CustomerListScreenState();
}

class _CustomerListScreenState
    extends State<CustomerListScreen> {
  final TextEditingController _searchCtrl =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<CustomerProvider>()
            .fetchCustomers();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // CUSTOMER AVATAR
  // ============================================================

  Widget _buildCustomerAvatar(String? photoUrl, String name, {double radius = 16}) {
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
                    color: AppTheme.goldDark,
                    fontSize: radius * 0.8,
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
          color: AppTheme.goldDark,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  // ============================================================
  // NEW CUSTOMER
  // ============================================================

  void _openNewCustomerModal() async {
    final result = await showResponsiveDialog<bool>(
      context: context,
      child: const NewCustomerScreen(),
    );

    if (result == true && mounted) {
      context
          .read<CustomerProvider>()
          .fetchCustomers();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<CustomerProvider>();

    final customers = provider.customers;

    final width =
        MediaQuery.of(context).size.width;

    final isDesktop =
        width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor:
          AppTheme.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ====================================================
            // SEARCH / TOP BAR
            // ====================================================

            Container(
              padding: const EdgeInsets.all(16),
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
                  // SEARCH
                  Expanded(
                    child: TextField(
                      controller:
                          _searchCtrl,
                      decoration:
                          InputDecoration(
                        hintText:
                            'Search by Customer ID, Name, Mobile, Aadhaar...',
                        prefixIcon:
                            const Icon(
                          Icons.search,
                          color:
                              AppTheme.silverDark,
                        ),
                        suffixIcon:
                            _searchCtrl
                                    .text
                                    .isNotEmpty
                                ? IconButton(
                                    icon:
                                        const Icon(
                                      Icons.clear,
                                    ),
                                    onPressed:
                                        () {
                                      _searchCtrl
                                          .clear();

                                      setState(
                                        () {},
                                      );

                                      provider
                                          .fetchCustomers();
                                    },
                                  )
                                : null,
                      ),
                      onChanged: (val) {
                        setState(() {});

                        provider
                            .fetchCustomers(
                          val.trim(),
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  // NEW CUSTOMER
                  ElevatedButton.icon(
                    onPressed:
                        _openNewCustomerModal,
                    icon: const Icon(
                      Icons.person_add,
                      size: 18,
                    ),
                    label: Text(
                      isDesktop
                          ? 'New Customer'
                          : 'Add',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.goldPrimary,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ====================================================
            // CONTENT AREA
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
                  : customers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              const Icon(
                                Icons
                                    .person_search,
                                size: 54,
                                color:
                                    AppTheme
                                        .silverDark,
                              ),

                              const SizedBox(
                                height: 12,
                              ),

                              Text(
                                'No customers found',
                                style: GoogleFonts
                                    .plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              ElevatedButton(
                                onPressed:
                                    _openNewCustomerModal,
                                child: const Text(
                                  'Create First Customer',
                                ),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(
                              customers,
                            )
                          : _buildMobileCards(
                              customers,
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
    List<Customer> customers,
  ) {
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
          builder:
              (context, constraints) {
            // ==================================================
            // IMPORTANT:
            //
            // OUTER SCROLL = VERTICAL
            // INNER SCROLL = HORIZONTAL
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
                    constraints:
                        BoxConstraints(
                      minWidth:
                          constraints
                              .maxWidth,
                    ),
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty
                              .all(
                        AppTheme
                            .silverLight,
                      ),

                      dataRowMinHeight:
                          56,

                      dataRowMaxHeight:
                          64,

                      columnSpacing:
                          28,

                      horizontalMargin:
                          20,

                      // ========================================
                      // COLUMNS
                      // ========================================

                      columns: const [
                        DataColumn(
                          label: Text(
                            'Customer Code',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Customer Name',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Mobile',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Gold Items',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Gold Weight',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Active Loans',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        DataColumn(
                          label: Text(
                            'Outstanding',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
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
                            ),
                          ),
                        ),
                      ],

                      // ========================================
                      // ROWS
                      // ========================================

                      rows: customers.map(
                        (c) {
                          return DataRow(
                            cells: [
                              // ==================================
                              // CUSTOMER CODE
                              // ==================================

                              DataCell(
                                Text(
                                  c.customerCode,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        AppTheme
                                            .darkNavy,
                                  ),
                                ),
                              ),

                              // ==================================
                              // CUSTOMER NAME
                              // ==================================

                              DataCell(
                                Row(
                                  mainAxisSize:
                                      MainAxisSize
                                          .min,
                                  children: [
                                    _buildCustomerAvatar(
                                      c.photoUrl,
                                      c.name,
                                      radius: 16,
                                    ),

                                    const SizedBox(
                                      width: 10,
                                    ),

                                    Column(
                                      mainAxisSize:
                                          MainAxisSize
                                              .min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      children: [
                                        Text(
                                          c.name,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize:
                                                13,
                                          ),
                                        ),

                                        if (c.aadhaarNumber !=
                                                null &&
                                            c.aadhaarNumber!
                                                .isNotEmpty)
                                          Text(
                                            'Aadhaar: ${c.aadhaarNumber}',
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  10,
                                              color:
                                                  AppTheme.silverDark,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ==================================
                              // MOBILE
                              // ==================================

                              DataCell(
                                Text(
                                  c.mobile,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        13,
                                  ),
                                ),
                              ),

                              // ==================================
                              // GOLD ITEMS
                              // ==================================

                              DataCell(
                                Text(
                                  '${c.totalGoldItems} items',
                                ),
                              ),

                              // ==================================
                              // GOLD WEIGHT
                              // ==================================

                              DataCell(
                                Text(
                                  AppConstants
                                      .formatWeight(
                                    c.totalGoldWeight,
                                  ),
                                ),
                              ),

                              // ==================================
                              // ACTIVE LOANS
                              // ==================================

                              DataCell(
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        8,
                                    vertical: 2,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: c.activeLoans >
                                            0
                                        ? AppTheme
                                            .goldLight
                                            .withValues(alpha: 
                                            0.5,
                                          )
                                        : AppTheme
                                            .silverLight,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      4,
                                    ),
                                  ),
                                  child:
                                      Text(
                                    '${c.activeLoans} Active',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color: c.activeLoans >
                                              0
                                          ? AppTheme
                                              .goldDark
                                          : AppTheme
                                              .silverDark,
                                      fontSize:
                                          11,
                                    ),
                                  ),
                                ),
                              ),

                              // ==================================
                              // OUTSTANDING
                              // ==================================

                              DataCell(
                                Text(
                                  AppConstants
                                      .formatCurrency(
                                    c.totalOutstanding,
                                  ),
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color: c.totalOutstanding >
                                            0
                                        ? AppTheme
                                            .darkNavy
                                        : AppTheme
                                            .silverDark,
                                  ),
                                ),
                              ),

                              // ==================================
                              // STATUS
                              // ==================================

                              DataCell(
                                GoldBadge(
                                  status:
                                      c.status,
                                ),
                              ),

                              // ==================================
                              // ACTIONS
                              // ==================================

                              DataCell(
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                CustomerProfileScreen(
                                          customerId:
                                              c.id,
                                          onNavigate:
                                              widget
                                                  .onNavigate,
                                        ),
                                      ),
                                    );
                                  },
                                  style:
                                      OutlinedButton
                                          .styleFrom(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          10,
                                      vertical:
                                          4,
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    'View Profile',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          11,
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
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE / TABLET CARDS
  // ============================================================

  Widget _buildMobileCards(
    List<Customer> customers,
  ) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        primary: true,
        physics:
            const AlwaysScrollableScrollPhysics(),
        itemCount: customers.length,
        itemBuilder:
            (context, index) {
          final c =
              customers[index];

          return Card(
            margin:
                const EdgeInsets.only(
              bottom: 12,
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerProfileScreen(
                      customerId: c.id,
                      onNavigate:
                          widget.onNavigate,
                    ),
                  ),
                );
              },
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    // ==========================================
                    // CUSTOMER HEADER
                    // ==========================================

                    Row(
                      children: [
                        _buildCustomerAvatar(
                          c.photoUrl,
                          c.name,
                          radius: 20,
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                c.name,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize:
                                      14,
                                ),
                              ),

                              Text(
                                '${c.customerCode} • ${c.mobile}',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  color:
                                      AppTheme
                                          .silverDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        GoldBadge(
                          status:
                              c.status,
                        ),
                      ],
                    ),

                    const Divider(
                      height: 20,
                    ),

                    // ==========================================
                    // GOLD / OUTSTANDING
                    // ==========================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Gold Collateral',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,
                                color:
                                    AppTheme
                                        .silverDark,
                              ),
                            ),
                            Text(
                              '${c.totalGoldItems} items (${AppConstants.formatWeight(c.totalGoldWeight)})',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize:
                                    12,
                              ),
                            ),
                          ],
                        ),

                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .end,
                          children: [
                            const Text(
                              'Total Outstanding',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,
                                color:
                                    AppTheme
                                        .silverDark,
                              ),
                            ),
                            Text(
                              AppConstants
                                  .formatCurrency(
                                c.totalOutstanding,
                              ),
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w800,
                                fontSize:
                                    13,
                                color:
                                    AppTheme
                                        .darkNavy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}