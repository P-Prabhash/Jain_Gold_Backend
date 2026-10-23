// lib/screens/loans/create_new_loan_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/gold_item.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';

class CreateNewLoanScreen extends StatefulWidget {
  final int? preselectedCustomerId;

  const CreateNewLoanScreen({
    super.key,
    this.preselectedCustomerId,
  });

  @override
  State<CreateNewLoanScreen> createState() =>
      _CreateNewLoanScreenState();
}

class _CreateNewLoanScreenState
    extends State<CreateNewLoanScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedCustomerId;

  final TextEditingController _customerSearchCtrl =
      TextEditingController();

  final TextEditingController _principalCtrl =
      TextEditingController();

  final TextEditingController _monthlyRateCtrl =
      TextEditingController(text: '2.00');

  final TextEditingController _initialInterestCtrl =
      TextEditingController(text: '0.00');

  final TextEditingController _remarksCtrl =
      TextEditingController();

  List<dynamic> _filteredCustomers = [];

  bool _showCustomerResults = false;
  bool _isLoadingGold = false;
  bool _isSubmitting = false;

  List<GoldItem> _customerAvailableGold = [];

  final Set<int> _selectedGoldItemIds = {};

  double _totalPledgedWeight = 0.0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _selectedCustomerId =
        widget.preselectedCustomerId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context
          .read<CustomerProvider>()
          .fetchCustomers();

      if (_selectedCustomerId != null) {
        _fetchCustomerAvailableGold(
          _selectedCustomerId!,
        );
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _principalCtrl.dispose();
    _monthlyRateCtrl.dispose();
    _initialInterestCtrl.dispose();
    _remarksCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  void _searchCustomer(String value) {
    final customers =
        context.read<CustomerProvider>().customers;

    setState(() {
      if (value.trim().isEmpty) {
        _filteredCustomers = [];
        _showCustomerResults = false;
        return;
      }

      final search =
          value.toLowerCase().trim();

      _filteredCustomers =
          customers.where((customer) {
        final name = customer.name
            .toString()
            .toLowerCase();

        final code = customer.customerCode
            .toString()
            .toLowerCase();

        final mobile = customer.mobile
            .toString()
            .toLowerCase();

        return name.contains(search) ||
            code.contains(search) ||
            mobile.contains(search);
      }).toList();

      _showCustomerResults = true;
    });
  }

  // ============================================================
  // SELECT CUSTOMER
  // ============================================================

  void _selectCustomer(dynamic customer) {
    setState(() {
      _selectedCustomerId = customer.id;

      _customerSearchCtrl.text =
          '${customer.name} (${customer.customerCode})';

      _showCustomerResults = false;
    });

    _fetchCustomerAvailableGold(
      customer.id,
    );
  }

  // ============================================================
  // FETCH CUSTOMER GOLD
  // ============================================================

  Future<void> _fetchCustomerAvailableGold(
    int customerId,
  ) async {
    setState(() {
      _isLoadingGold = true;
      _selectedGoldItemIds.clear();
      _totalPledgedWeight = 0.0;
      _customerAvailableGold = [];
    });

    try {
      final items =
          await ApiService.getGoldItems(
        customerId: customerId,
        status: 'AVAILABLE',
      );

      if (!mounted) return;

      setState(() {
        _customerAvailableGold = items;
        _isLoadingGold = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingGold = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load gold items: $e',
          ),
          backgroundColor:
              AppTheme.statusDanger,
        ),
      );
    }
  }

  // ============================================================
  // SELECT / UNSELECT GOLD
  // ============================================================

  void _toggleGoldSelection(
    GoldItem item,
  ) {
    setState(() {
      if (_selectedGoldItemIds.contains(item.id)) {
        _selectedGoldItemIds.remove(item.id);

        _totalPledgedWeight -= item.weight;
      } else {
        _selectedGoldItemIds.add(item.id);

        _totalPledgedWeight += item.weight;
      }

      if (_totalPledgedWeight < 0) {
        _totalPledgedWeight = 0;
      }
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a customer'),
        ),
      );
      return;
    }

    if (_selectedGoldItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one gold item to pledge as collateral',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider =
          context.read<LoanProvider>();

      final principal =
          double.tryParse(
                _principalCtrl.text.trim(),
              ) ??
              0.0;

      final rate =
          double.tryParse(
                _monthlyRateCtrl.text.trim(),
              ) ??
              2.0;

      final initialInterest =
          double.tryParse(
                _initialInterestCtrl.text.trim(),
              ) ??
              0.0;

      final res =
          await provider.createNewLoan({
        'customer_id':
            _selectedCustomerId,

        'gold_item_ids':
            _selectedGoldItemIds.toList(),

        'principal_amount':
            principal,

        'monthly_interest_rate':
            rate,

        'initial_interest':
            initialInterest,

        'remarks':
            _remarksCtrl.text.trim(),
      });

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (res != null &&
          res['success'] == true) {
        final receipt =
            res['data']?['receipt'];

        Navigator.of(context).pop(true);

        if (receipt != null) {
          showDialog(
            context: context,
            builder: (_) {
              return Dialog(
                insetPadding:
                    const EdgeInsets.all(10),
                child:
                    A4ReceiptViewer(
                  receiptData:
                      receipt,
                ),
              );
            },
          );
        }
      } else {
        final message =
            provider.errorMessage ??
                'Unable to create loan';

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                AppTheme.statusDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Error: $e'),
          backgroundColor:
              AppTheme.statusDanger,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width;

    final isMobile = width < 600;

    final isTablet =
        width >= 600 && width < 1200;

    final isDesktop =
        width >= 1200;

    final customers =
        context
            .watch<CustomerProvider>()
            .customers;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: isDesktop
              ? 1050
              : isTablet
                  ? 850
                  : double.infinity,
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.94,
          ),
          margin: EdgeInsets.symmetric(
            horizontal:
                isMobile ? 8 : 20,
            vertical:
                isMobile ? 8 : 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              isMobile ? 12 : 18,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 25,
                offset:
                    Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(
                isMobile,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.all(
                    isMobile
                        ? 14
                        : isTablet
                            ? 20
                            : 26,
                  ),
                  child: Form(
                    key: _formKey,
                    child: isDesktop
                        ? _buildDesktopForm(
                            customers,
                          )
                        : isTablet
                            ? _buildTabletForm(
                                customers,
                              )
                            : _buildMobileForm(
                                customers,
                              ),
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
  // HEADER
  // ============================================================

  Widget _buildHeader(
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal:
            isMobile ? 14 : 22,
        vertical:
            isMobile ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 38 : 42,
            height: isMobile ? 38 : 42,
            decoration: BoxDecoration(
              color:
                  AppTheme.goldPrimary
                      .withValues(
                alpha: 0.14,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color:
                  AppTheme.goldPrimary,
              size: 23,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Pawn Loan',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts
                          .plusJakartaSans(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w800,
                    fontSize:
                        isMobile ? 14 : 17,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'New Loan • System number auto-generated',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts
                          .plusJakartaSans(
                    color:
                        Colors.white70,
                    fontSize:
                        isMobile ? 9 : 10,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Close',
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
            onPressed: () =>
                Navigator.of(context)
                    .pop(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE FORM
  // ============================================================

  Widget _buildMobileForm(
    List<dynamic> customers,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSystemNumberBanner(
          compact: true,
        ),

        const SizedBox(height: 14),

        _buildCustomerSection(
          compact: true,
        ),

        const SizedBox(height: 14),

        _buildCollateralSection(
          compact: true,
        ),

        const SizedBox(height: 14),

        _buildLoanAmountSection(
          compact: true,
        ),

        const SizedBox(height: 14),

        _buildInterestSection(
          compact: true,
        ),

        const SizedBox(height: 14),

        _buildRemarksSection(),

        const SizedBox(height: 20),

        _buildActionButtons(
          mobile: true,
        ),
      ],
    );
  }

  // ============================================================
  // TABLET FORM
  // ============================================================

  Widget _buildTabletForm(
    List<dynamic> customers,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSystemNumberBanner(),

        const SizedBox(height: 18),

        _buildCustomerSection(),

        const SizedBox(height: 18),

        _buildCollateralSection(),

        const SizedBox(height: 18),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildLoanAmountSection(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child:
                  _buildInterestSection(),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _buildRemarksSection(),

        const SizedBox(height: 24),

        _buildActionButtons(),
      ],
    );
  }

  // ============================================================
  // DESKTOP FORM
  // ============================================================

  Widget _buildDesktopForm(
    List<dynamic> customers,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildSystemNumberBanner(),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child:
                  _buildCustomerSection(),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 4,
              child:
                  _buildLoanAmountSection(),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildCollateralSection(),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildInterestSection(),
            ),
            const SizedBox(width: 18),
            Expanded(
              child:
                  _buildRemarksSection(),
            ),
          ],
        ),

        const SizedBox(height: 26),

        _buildActionButtons(),
      ],
    );
  }

  // ============================================================
  // SYSTEM NUMBER BANNER
  // ============================================================

  Widget _buildSystemNumberBanner({
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color:
                  AppTheme.goldPrimary
                      .withValues(
                alpha: 0.13,
              ),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: const Icon(
              Icons.tag,
              size: 16,
              color:
                  AppTheme.goldDark,
            ),
          ),

          const SizedBox(width: 9),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                 Text(
                  'Automatic Loan Number',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),
                 SizedBox(height: 2),
                Text(
                  'System will generate the New Loan number automatically.',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                       TextStyle(
                    fontSize: 9,
                    color:
                        AppTheme.silverDark,
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
  // CUSTOMER SECTION
  // ============================================================

  Widget _buildCustomerSection({
    bool compact = false,
  }) {
    return _sectionContainer(
      title: 'Customer',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller:
                _customerSearchCtrl,
            decoration:
                const InputDecoration(
              labelText:
                  'Search Customer *',
              hintText:
                  'Name / Customer Code / Mobile',
              prefixIcon: Icon(
                Icons.search,
                color:
                    AppTheme.goldDark,
              ),
              suffixIcon: Icon(
                Icons.person_search_outlined,
                color:
                    AppTheme.silverDark,
              ),
            ),
            onChanged:
                _searchCustomer,
          ),

          if (_showCustomerResults)
            _buildCustomerResults(),

          if (_selectedCustomerId !=
              null)
            Container(
              margin:
                  const EdgeInsets.only(
                top: 9,
              ),
              padding:
                  const EdgeInsets.all(
                10,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.green
                    .withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
                border: Border.all(
                  color: Colors.green
                      .withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .check_circle_outline,
                    size: 18,
                    color: Colors.green,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Customer selected',
                      style:
                          TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            Colors.green,
                      ),
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
  // CUSTOMER RESULTS
  // ============================================================

  Widget _buildCustomerResults() {
    if (_filteredCustomers.isEmpty) {
      return Container(
        margin:
            const EdgeInsets.only(
          top: 5,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(9),
          border: Border.all(
            color:
                AppTheme.silverBorder,
          ),
        ),
        child: const Text(
          'No matching customers found.',
          style: TextStyle(
            fontSize: 11,
            color:
                AppTheme.silverDark,
          ),
        ),
      );
    }

    return Container(
      margin:
          const EdgeInsets.only(
        top: 5,
      ),
      constraints:
          const BoxConstraints(
        maxHeight: 210,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black
                .withValues(
              alpha: 0.07,
            ),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount:
            _filteredCustomers.length,
        separatorBuilder:
            (_, __) =>
                const Divider(
          height: 1,
        ),
        itemBuilder:
            (context, index) {
          final customer =
              _filteredCustomers[index];

          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme
                      .goldPrimary
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color:
                      AppTheme.goldDark,
                ),
              ),
              title: Text(
                customer.name
                    .toString(),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${customer.customerCode} • ${customer.mobile}',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 9,
                  color:
                      AppTheme.silverDark,
                ),
              ),
              onTap: () =>
                  _selectCustomer(
                customer,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // COLLATERAL SECTION
  // ============================================================

  Widget _buildCollateralSection({
    bool compact = false,
  }) {
    return _sectionContainer(
      title:
          'Select Gold Collateral Items *',
      icon:
          Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            height:
                compact ? 245 : 265,
            padding:
                const EdgeInsets.all(7),
            decoration:
                BoxDecoration(
              color:
                  AppTheme.silverLight,
              borderRadius:
                  BorderRadius.circular(
                9,
              ),
              border: Border.all(
                color:
                    AppTheme.silverBorder,
              ),
            ),
            child: _isLoadingGold
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color: AppTheme
                          .goldPrimary,
                    ),
                  )
                : _customerAvailableGold
                        .isEmpty
                    ? _buildNoGoldMessage()
                    : ListView.separated(
                        itemCount:
                            _customerAvailableGold
                                .length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(
                          height: 1,
                        ),
                        itemBuilder:
                            (context,
                                index) {
                          final item =
                              _customerAvailableGold[
                                  index];

                          final selected =
                              _selectedGoldItemIds
                                  .contains(
                            item.id,
                          );

                          return _buildGoldSelectionTile(
                            item,
                            selected,
                          );
                        },
                      ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Expanded(
                child: _summaryChip(
                  icon:
                      Icons.check_circle_outline,
                  label:
                      'Selected',
                  value:
                      '${_selectedGoldItemIds.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _summaryChip(
                  icon:
                      Icons.scale_outlined,
                  label:
                      'Total Pledged Weight',
                  value:
                      AppConstants
                          .formatWeight(
                    _totalPledgedWeight,
                  ),
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO GOLD
  // ============================================================

  Widget _buildNoGoldMessage() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              _selectedCustomerId == null
                  ? Icons.person_search_outlined
                  : Icons.inventory_2_outlined,
              size: 35,
              color:
                  AppTheme.silverDark,
            ),
            const SizedBox(height: 9),
            Text(
              _selectedCustomerId == null
                  ? 'Select a customer first'
                  : 'No available gold items found',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppTheme.silverDark,
              ),
            ),
            if (_selectedCustomerId !=
                null) ...[
              const SizedBox(height: 4),
              const Text(
                'Please add gold items for this customer first.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color:
                      AppTheme.silverDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GOLD TILE
  // ============================================================

  Widget _buildGoldSelectionTile(
    GoldItem item,
    bool selected,
  ) {
    return InkWell(
      onTap: () =>
          _toggleGoldSelection(
        item,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.goldPrimary
                  .withValues(
                  alpha: 0.08,
                )
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor:
                  AppTheme.goldDark,
              onChanged: (_) =>
                  _toggleGoldSelection(
                item,
              ),
            ),

            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(
                color:
                    AppTheme.silverLight,
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
              ),
              child: const Icon(
                Icons.diamond_outlined,
                size: 19,
                color:
                    AppTheme.goldDark,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    '${item.itemName} (${item.purity})',
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Weight: ${AppConstants.formatWeight(item.weight)}',
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 9,
                      color:
                          AppTheme
                              .silverDark,
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              const Icon(
                Icons.check_circle,
                size: 19,
                color:
                    AppTheme.goldDark,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOAN AMOUNT
  // ============================================================

  Widget _buildLoanAmountSection({
    bool compact = false,
  }) {
    return _sectionContainer(
      title: 'Loan Amount',
      icon:
          Icons.account_balance_wallet_outlined,
      child: TextFormField(
        controller: _principalCtrl,
        keyboardType:
            const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration:
            const InputDecoration(
          labelText:
              'Principal Loan Amount (Rs) *',
          hintText:
              'e.g. 100000',
          prefixIcon: Icon(
            Icons.payments_outlined,
            color:
                AppTheme.goldDark,
          ),
        ),
        validator: (value) {
          if (value == null ||
              value.trim().isEmpty) {
            return 'Principal amount is required';
          }

          final amount =
              double.tryParse(
            value.trim(),
          );

          if (amount == null ||
              amount <= 0) {
            return 'Enter valid amount';
          }

          return null;
        },
      ),
    );
  }

  // ============================================================
  // INTEREST
  // ============================================================

  Widget _buildInterestSection({
    bool compact = false,
  }) {
    return _sectionContainer(
      title: 'Monthly Interest',
      icon: Icons.percent,
      child: compact
          ? Column(
              children: [
                _monthlyRateField(),
                const SizedBox(height: 12),
                _initialInterestField(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child:
                      _monthlyRateField(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _initialInterestField(),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // MONTHLY RATE
  // ============================================================

  Widget _monthlyRateField() {
    return TextFormField(
      controller: _monthlyRateCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration:
          const InputDecoration(
        labelText:
            'Monthly Rate (%) *',
        suffixText:
            '% / mo',
        prefixIcon: Icon(
          Icons.percent,
          color:
              AppTheme.goldDark,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Monthly rate is required';
        }

        final rate =
            double.tryParse(
          value.trim(),
        );

        if (rate == null ||
            rate < 0) {
          return 'Enter valid rate';
        }

        return null;
      },
    );
  }

  // ============================================================
  // INITIAL INTEREST
  // ============================================================

  Widget _initialInterestField() {
    return TextFormField(
      controller:
          _initialInterestCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration:
          const InputDecoration(
        labelText:
            'Initial Interest (Rs)',
        hintText: '0.00',
        prefixIcon: Icon(
          Icons.calculate_outlined,
          color:
              AppTheme.silverDark,
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return null;
        }

        final amount =
            double.tryParse(
          value.trim(),
        );

        if (amount == null ||
            amount < 0) {
          return 'Enter valid interest';
        }

        return null;
      },
    );
  }

  // ============================================================
  // REMARKS
  // ============================================================

  Widget _buildRemarksSection() {
    return _sectionContainer(
      title: 'Remarks',
      icon: Icons.notes_outlined,
      child: TextFormField(
        controller: _remarksCtrl,
        maxLines: 3,
        decoration:
            const InputDecoration(
          labelText:
              'Loan Remarks (Optional)',
          hintText:
              'Enter loan remarks...',
          prefixIcon: Padding(
            padding:
                EdgeInsets.only(
              bottom: 42,
            ),
            child: Icon(
              Icons.notes,
              color:
                  AppTheme.silverDark,
            ),
          ),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  // ============================================================
  // SECTION CONTAINER
  // ============================================================

  Widget _sectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
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
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(
                  color:
                      AppTheme.goldPrimary
                          .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color:
                      AppTheme.goldDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts
                          .plusJakartaSans(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CHIP
  // ============================================================

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.goldPrimary
                .withValues(
                alpha: 0.08,
              )
            : AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(9),
        border: Border.all(
          color: highlight
              ? AppTheme.goldPrimary
                  .withValues(
                  alpha: 0.25,
                )
              : AppTheme.silverBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? AppTheme.goldDark
                : AppTheme.silverDark,
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
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
          ),

          const SizedBox(width: 5),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
              color: highlight
                  ? AppTheme.goldDark
                  : AppTheme.darkNavy,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons({
    bool mobile = false,
  }) {
    if (mobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child:
                ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : _handleSubmit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme
                            .darkNavy,
                      ),
                    )
                  : const Icon(
                      Icons
                          .receipt_long_outlined,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Processing...'
                    : 'DISBURSE & PRINT RECEIPT',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme
                        .goldPrimary,
                foregroundColor:
                    AppTheme.darkNavy,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 45,
            child:
                OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () =>
                      Navigator.of(
                        context,
                      ).pop(),
              child:
                  const Text(
                'CANCEL',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
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
          child:
              OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () =>
                    Navigator.of(
                      context,
                    ).pop(),
            style:
                OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 22,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
              ),
            ),
            child:
                const Text(
              'CANCEL',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          height: 46,
          child:
              ElevatedButton.icon(
            onPressed: _isSubmitting
                ? null
                : _handleSubmit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          AppTheme.darkNavy,
                    ),
                  )
                : const Icon(
                    Icons
                        .receipt_long_outlined,
                    size: 18,
                  ),
            label: Text(
              _isSubmitting
                  ? 'Processing...'
                  : 'DISBURSE & PRINT RECEIPT',
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.goldPrimary,
              foregroundColor:
                  AppTheme.darkNavy,
              elevation: 0,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 20,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}