import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/loan.dart';
import '../../providers/release_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';

class PartialReleaseScreen extends StatefulWidget {
  final int? preselectedLoanId;

  const PartialReleaseScreen({
    super.key,
    this.preselectedLoanId,
  });

  @override
  State<PartialReleaseScreen> createState() =>
      _PartialReleaseScreenState();
}

class _PartialReleaseScreenState
    extends State<PartialReleaseScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedLoanId;

  final _paymentAmountCtrl =
      TextEditingController(text: '0.00');

  final _remarksCtrl =
      TextEditingController();

  String _paymentMode = 'CASH';

  List<Loan> _activeLoans = [];

  List<Loan> _filteredLoans = [];

  final TextEditingController _loanSearchCtrl =
      TextEditingController();

  bool _showLoanResults = false;


  List<LoanCollateralItem> _pledgedItems = [];

  final Set<int> _selectedItemIdsToRelease = {};

  double _releasedWeightSum = 0.0;

  bool _isLoading = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _selectedLoanId = widget.preselectedLoanId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchActiveLoans();
    });
  }

  @override
  void dispose() {
    _paymentAmountCtrl.dispose();
    _remarksCtrl.dispose();
    _loanSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveLoans() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final loans =
          await ApiService.getLoans(status: 'ACTIVE');

      if (!mounted) return;

      setState(() {
        _activeLoans = loans;
        _filteredLoans = loans;
        _isLoading = false;
      });

      if (_selectedLoanId != null) {
        final match = _activeLoans
            .where((l) => l.id == _selectedLoanId)
            .toList();

        if (match.isNotEmpty) {
          setState(() {
          });

          await _loadCollateralForLoan(
            _selectedLoanId!,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load active loans: $e',
          ),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
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

    setState(() {

      _selectedLoanId = loan.id;


      _loanSearchCtrl.text =
          "${loan.loanNo} - ${loan.customerName}";

      _showLoanResults = false;

    });


    _loadCollateralForLoan(loan.id);

  }



  Future<void> _loadCollateralForLoan(
      int loanId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedItemIdsToRelease.clear();
      _releasedWeightSum = 0.0;
      _pledgedItems = [];
    });

    try {
      final res =
          await ApiService.getLoanDetails(loanId);

      final rawCol =
          res['collateral'] as List? ?? [];

      final allItems = rawCol
          .map(
            (c) => LoanCollateralItem.fromJson(c),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _pledgedItems = allItems
            .where(
              (i) =>
                  i.collateralStatus == 'PLEDGED',
            )
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load collateral: $e',
          ),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  void _toggleItemSelection(
      LoanCollateralItem item) {
    setState(() {
      if (_selectedItemIdsToRelease
          .contains(item.goldItemId)) {
        _selectedItemIdsToRelease
            .remove(item.goldItemId);

        _releasedWeightSum -=
            item.pledgedWeight;
      } else {
        _selectedItemIdsToRelease
            .add(item.goldItemId);

        _releasedWeightSum +=
            item.pledgedWeight;
      }

      if (_releasedWeightSum < 0) {
        _releasedWeightSum = 0;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLoanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a loan'),
        ),
      );
      return;
    }

    if (_selectedItemIdsToRelease.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select at least one gold item to release',
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
          context.read<ReleaseProvider>();

      final payment =
          double.tryParse(
                _paymentAmountCtrl.text.trim(),
              ) ??
              0.0;

      final res =
          await provider.processPartialRelease({
        'loan_id': _selectedLoanId,
        'gold_item_ids':
            _selectedItemIdsToRelease.toList(),
        'payment_amount': payment,
        'payment_mode': _paymentMode,
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
            builder: (_) =>
                A4ReceiptViewer(
              receiptData: receipt,
            ),
          );
        }
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage!,
            ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Release failed: $e',
          ),
          backgroundColor:
              AppTheme.statusDanger,
        ),
      );
    }
  }


  Widget _buildLoanDropdown() {

    if (_isLoading && _activeLoans.isEmpty) {

      return const Center(

        child: Padding(

          padding: EdgeInsets.all(16),

          child: CircularProgressIndicator(

            color: AppTheme.goldPrimary,

          ),

        ),

      );

    }


    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [


        TextField(

          controller:
              _loanSearchCtrl,


          decoration:
              const InputDecoration(

                labelText:
                    'Search Loan Account *',

                hintText:
                    'Loan Number / Customer Name',

                prefixIcon:
                    Icon(

                      Icons.search,

                      color:
                          AppTheme.goldDark,

                    ),

              ),


          onChanged:
              _searchLoan,


        ),



        if(_showLoanResults)

        Container(

          margin:
              const EdgeInsets.only(top:5),


          constraints:
              const BoxConstraints(
                maxHeight:180,
              ),


          decoration:
              BoxDecoration(

                color:
                    Colors.white,

                border:
                    Border.all(
                      color:
                          AppTheme.silverBorder,
                    ),

                borderRadius:
                    BorderRadius.circular(8),

              ),



          child:

          ListView.builder(

            itemCount:
                _filteredLoans.length,


            itemBuilder:
                (context,index){

              final loan =
                  _filteredLoans[index];


              return Material(
                color: Colors.transparent,
                child: ListTile(

                  dense:true,


                  title:
                      Text(loan.loanNo),


                  subtitle:
                      Text(
                        "${loan.customerName} | ${AppConstants.formatCurrency(loan.remainingBalance)}",
                      ),


                  onTap:
                      () => _selectLoan(loan),


                ),
              );


            },

          ),

        ),


      ],

    );

  }



  Widget _buildCollateralList() {
    return Container(
      constraints:
          const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child: _pledgedItems.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No pledged collateral items found '
                  'under this loan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.silverDark,
                  ),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _pledgedItems.length,
              itemBuilder: (
                context,
                index,
              ) {
                final item =
                    _pledgedItems[index];

                final isSelected =
                    _selectedItemIdsToRelease
                        .contains(
                  item.goldItemId,
                );

                return CheckboxListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  title: Text(
                    '${item.itemName} '
                    '(${item.purity})',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Weight: '
                    '${AppConstants.formatWeight(item.pledgedWeight)}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                  value: isSelected,
                  activeColor:
                      AppTheme.goldDark,
                  onChanged: (_) =>
                      _toggleItemSelection(
                    item,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPaymentAndRemarks(
      bool isMobile) {
    final paymentField =
        TextFormField(
      controller: _paymentAmountCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: const InputDecoration(
        labelText:
            'Payment Received For Release (₹)',
        hintText:
            'e.g. 20000 (0.00 if no payment)',
        prefixIcon: Icon(
          Icons.currency_rupee,
          color: AppTheme.goldDark,
        ),
      ),
    );

    final paymentModeField =
        DropdownButtonFormField<String>(
      initialValue: _paymentMode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Payment Mode',
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
      ].map((mode) {
        return DropdownMenuItem<String>(
          value: mode,
          child: Text(
            mode.replaceAll('_', ' '),
            overflow:
                TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _paymentMode =
              val ?? 'CASH';
        });
      },
    );

    final remarksField =
        TextFormField(
      controller: _remarksCtrl,
      maxLines: isMobile ? 3 : 1,
      decoration:
          const InputDecoration(
        labelText:
            'Release Remarks (Optional)',
        prefixIcon: Icon(
          Icons.notes,
          color: AppTheme.silverDark,
        ),
      ),
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        paymentField,
        const SizedBox(height: 16),
        if (isMobile) ...[
          paymentModeField,
          const SizedBox(height: 16),
          remarksField,
        ] else
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: paymentModeField,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: remarksField,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons(
      bool isMobile) {
    final cancelButton =
        OutlinedButton(
      onPressed: _isSubmitting
          ? null
          : () =>
              Navigator.of(context).pop(),
      child: const Text('Cancel'),
    );

    final confirmButton =
        ElevatedButton(
      onPressed:
          _isSubmitting
              ? null
              : _handleSubmit,
      style:
          ElevatedButton.styleFrom(
        backgroundColor:
            AppTheme.goldPrimary,
        foregroundColor:
            AppTheme.darkNavy,
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
                color:
                    AppTheme.darkNavy,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'CONFIRM RELEASE & PRINT',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          confirmButton,
          const SizedBox(height: 10),
          cancelButton,
        ],
      );
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.end,
      children: [
        cancelButton,
        const SizedBox(width: 12),
        confirmButton,
      ],
    );
  }

  @override
  Widget build(
      BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final isMobile =
        screenWidth < 600;

    final horizontalPadding =
        isMobile ? 14.0 : 24.0;

    final dialogWidth =
        screenWidth < 700
            ? screenWidth - 20
            : 680.0;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: isMobile ? double.infinity : dialogWidth,
          height: isMobile ? MediaQuery.of(context).size.height : null,
          constraints: BoxConstraints(
            maxHeight: isMobile
                ? double.infinity
                : MediaQuery.of(context).size.height - 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 0 : 16),
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
                      isMobile ? 14 : 24,
                  vertical: 14,
                ),
                decoration:
                    const BoxDecoration(
                  color:
                      AppTheme.darkNavy,
                  borderRadius:
                      BorderRadius.vertical(
                    top: Radius.circular(
                      16,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_open,
                      color:
                          AppTheme.goldPrimary,
                      size: 22,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Process Partial '
                        'Gold Release',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
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
                      padding:
                          EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
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
                    horizontalPadding,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        const SizedBox(
                          height: 4,
                        ),

                        // LOAN
                        _buildLoanDropdown(),

                        const SizedBox(
                          height: 18,
                        ),

                        // TITLE
                        Text(
                          'Select Pledged Gold '
                          'Items to Release *',
                          style: GoogleFonts
                              .plusJakartaSans(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                AppTheme.darkNavy,
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        // COLLATERAL
                        _buildCollateralList(),

                        const SizedBox(
                          height: 7,
                        ),

                        // SUMMARY
                        Wrap(
                          alignment:
                              WrapAlignment
                                  .spaceBetween,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Selected for Release: '
                              '${_selectedItemIdsToRelease.length} items',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color:
                                    AppTheme
                                        .silverDark,
                              ),
                            ),
                            Text(
                              'Weight to Release: '
                              '${AppConstants.formatWeight(_releasedWeightSum)}',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    AppTheme
                                        .goldDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // PAYMENT + REMARKS
                        _buildPaymentAndRemarks(
                          isMobile,
                        ),

                        SizedBox(
                          height:
                              isMobile
                                  ? 18
                                  : 24,
                        ),

                        // BUTTONS
                        _buildActionButtons(
                          isMobile,
                        ),

                        SizedBox(
                          height:
                              isMobile
                                  ? 8
                                  : 4,
                        ),
                      ],
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
}