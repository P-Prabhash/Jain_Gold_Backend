// lib/screens/loans/create_existing_loan_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../models/gold_item.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';
import '../../widgets/success_dialog.dart';

class CreateExistingLoanScreen extends StatefulWidget {
  const CreateExistingLoanScreen({super.key});

  @override
  State<CreateExistingLoanScreen> createState() =>
      _CreateExistingLoanScreenState();
}

class _CreateExistingLoanScreenState
    extends State<CreateExistingLoanScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  // ============================================================
  // CUSTOMER
  // ============================================================

  final TextEditingController _customerNameCtrl =
      TextEditingController();

  final TextEditingController _mobileCtrl =
      TextEditingController();

  final TextEditingController _aadhaarCtrl =
      TextEditingController();

  final TextEditingController _panCtrl =
      TextEditingController();

  final TextEditingController _addressCtrl =
      TextEditingController();

  Customer? _selectedCustomer;

  bool _existingCustomerMode = true;
  bool _newCustomerMode = false;

  Timer? _customerSearchTimer;

  // ============================================================
  // LOAN
  // ============================================================

  final TextEditingController _manualLoanNoCtrl =
      TextEditingController();

  final TextEditingController _principalCtrl =
      TextEditingController();

  final TextEditingController _interestCtrl =
      TextEditingController();

  final TextEditingController _paidCtrl =
      TextEditingController();

  final TextEditingController _remarksCtrl =
      TextEditingController();

  DateTime? _openedDate;
  DateTime? _closedDate;

  String _status = 'ACTIVE';

  bool _saving = false;

  // ============================================================
  // GOLD
  // ============================================================

  List<GoldItem> _availableGoldItems = [];

  final Set<int> _selectedGoldIds =
      <int>{};

  bool _loadingGold = false;

  // ============================================================
  // ADD GOLD
  // ============================================================

  final List<Map<String, dynamic>> _newCustomerGoldItems = [];

  final TextEditingController _goldItemNameCtrl =
      TextEditingController();

  final TextEditingController _goldPurityCtrl =
      TextEditingController();

  final TextEditingController _goldWeightCtrl =
      TextEditingController();

  final TextEditingController _goldRemarksCtrl =
      TextEditingController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _principalCtrl.addListener(
      _refreshSummary,
    );

    _interestCtrl.addListener(
      _refreshSummary,
    );

    _paidCtrl.addListener(
      _refreshSummary,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _customerSearchTimer?.cancel();

    _customerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _addressCtrl.dispose();

    _manualLoanNoCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _paidCtrl.dispose();
    _remarksCtrl.dispose();

    _goldItemNameCtrl.dispose();
    _goldPurityCtrl.dispose();
    _goldWeightCtrl.dispose();
    _goldRemarksCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  void _refreshSummary() {
    if (!mounted) return;

    setState(() {});
  }

  double get _principal {
    return double.tryParse(
          _principalCtrl.text.trim(),
        ) ??
        0.0;
  }

  double get _interest {
    return double.tryParse(
          _interestCtrl.text.trim(),
        ) ??
        0.0;
  }

  double get _paid {
    return double.tryParse(
          _paidCtrl.text.trim(),
        ) ??
        0.0;
  }

  double get _totalDue {
    return _principal + _interest;
  }

  double get _remainingBalance {
    final value =
        _totalDue - _paid;

    return value < 0
        ? 0.0
        : value;
  }

  double get _selectedGoldWeight {
    double total = 0.0;

    for (final item
        in _availableGoldItems) {
      if (_selectedGoldIds
          .contains(item.id)) {
        total += item.weight;
      }
    }

    return total;
  }

  // ============================================================
  // DATE
  // ============================================================

  String _apiDate(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // OPENED DATE
  // ============================================================

  Future<void> _pickOpenedDate() async {
    final result =
        await showDatePicker(
      context: context,
      initialDate:
          _openedDate ??
              DateTime.now(),
      firstDate:
          DateTime(1950),
      lastDate:
          DateTime.now().add(
        const Duration(
          days: 3650,
        ),
      ),
      builder:
          (context, child) {
        return Theme(
          data:
              Theme.of(context)
                  .copyWith(
            colorScheme:
                Theme.of(context)
                    .colorScheme
                    .copyWith(
              primary:
                  AppTheme.goldDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _openedDate = result;

      if (_closedDate != null &&
          _closedDate!
              .isBefore(result)) {
        _closedDate = null;
        _status = 'ACTIVE';
      }
    });
  }

  // ============================================================
  // CLOSED DATE
  // ============================================================

  Future<void> _pickClosedDate() async {
    if (_openedDate == null) {
      _showError(
        'Select opened date first.',
      );
      return;
    }

    final result =
        await showDatePicker(
      context: context,
      initialDate:
          _closedDate ??
              _openedDate!,
      firstDate:
          _openedDate!,
      lastDate:
          DateTime.now().add(
        const Duration(
          days: 3650,
        ),
      ),
      builder:
          (context, child) {
        return Theme(
          data:
              Theme.of(context)
                  .copyWith(
            colorScheme:
                Theme.of(context)
                    .colorScheme
                    .copyWith(
              primary:
                  AppTheme.goldDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _closedDate = result;
      _status = 'CLOSED';
    });
  }

  // ============================================================
  // CUSTOMER MODE
  // ============================================================

  void _setExistingCustomerMode() {
    setState(() {
      _existingCustomerMode =
          true;

      _newCustomerMode =
          false;

      _selectedCustomer = null;

      _customerNameCtrl.clear();
      _mobileCtrl.clear();
      _aadhaarCtrl.clear();
      _panCtrl.clear();
      _addressCtrl.clear();

      _availableGoldItems = [];
      _selectedGoldIds.clear();
    });
  }

  void _setNewCustomerMode() {
    setState(() {
      _existingCustomerMode =
          false;

      _newCustomerMode =
          true;

      _selectedCustomer = null;

      _customerNameCtrl.clear();
      _mobileCtrl.clear();
      _aadhaarCtrl.clear();
      _panCtrl.clear();
      _addressCtrl.clear();

      _availableGoldItems = [];
      _selectedGoldIds.clear();
    });
  }

  // ============================================================
  // SELECT EXISTING CUSTOMER
  // ============================================================

  Future<void>
      _selectExistingCustomer() async {
    final provider =
        context.read<CustomerProvider>();

    await provider.fetchCustomers();

    if (!mounted) return;

    final customer =
        await showDialog<Customer>(
      context: context,
      builder: (
        dialogContext,
      ) {
        final searchController =
            TextEditingController();

        List<Customer> customers =
            List<Customer>.from(
          provider.customers,
        );

        bool loading = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            Future<void>
                searchCustomers(
              String value,
            ) async {
              final query =
                  value.trim();

              if (query.isEmpty) {
                setDialogState(() {
                  customers =
                      List<Customer>.from(
                    provider.customers,
                  );

                  loading = false;
                });

                return;
              }

              setDialogState(() {
                loading = true;
              });

              try {
                await provider
                    .fetchCustomers(
                  query,
                );

                if (!dialogContext
                    .mounted) {
                  return;
                }

                setDialogState(() {
                  customers =
                      List<Customer>.from(
                    provider.customers,
                  );

                  loading = false;
                });
              } catch (_) {
                if (!dialogContext
                    .mounted) {
                  return;
                }

                setDialogState(() {
                  loading = false;
                });
              }
            }

            final dialogWidth =
                MediaQuery.of(
              context,
            ).size.width;

            final isMobile =
                dialogWidth < 600;

            return AlertDialog(
              insetPadding:
                  EdgeInsets.all(
                isMobile ? 10 : 24,
              ),
              titlePadding:
                  EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 22,
                isMobile ? 16 : 24,
                10,
              ),
              contentPadding:
                  EdgeInsets.fromLTRB(
                isMobile ? 12 : 24,
                8,
                isMobile ? 12 : 24,
                12,
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(
                      color: AppTheme
                          .goldPrimary
                          .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        9,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .person_search,
                      color:
                          AppTheme
                              .goldDark,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  const Expanded(
                    child: Text(
                      'Select Existing Customer',
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  ),
                ],
              ),
              content:
                  SizedBox(
                width: isMobile
                    ? double.infinity
                    : 720,
                height:
                    isMobile
                        ? MediaQuery.of(
                              context,
                            ).size.height *
                            0.62
                        : 560,
                child: Column(
                  children: [
                    TextField(
                      controller:
                          searchController,
                      autofocus:
                          !isMobile,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Name / Mobile / Aadhaar / Customer No',
                        prefixIcon:
                            Icon(
                          Icons.search,
                        ),
                      ),
                      onChanged:
                          (value) {
                        _customerSearchTimer
                            ?.cancel();

                        _customerSearchTimer =
                            Timer(
                          const Duration(
                            milliseconds:
                                350,
                          ),
                          () {
                            searchCustomers(
                              value,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    if (loading)
                      const LinearProgressIndicator(
                        color: AppTheme
                            .goldPrimary,
                      ),

                    const SizedBox(
                      height: 8,
                    ),

                    Expanded(
                      child:
                          customers.isEmpty
                              ? _emptyCustomerState()
                              : ListView
                                  .separated(
                                  itemCount:
                                      customers
                                          .length,
                                  separatorBuilder:
                                      (
                                    _,
                                    __,
                                  ) =>
                                          const Divider(
                                    height:
                                        1,
                                  ),
                                  itemBuilder:
                                      (
                                    _,
                                    index,
                                  ) {
                                    final customer =
                                        customers[
                                            index];

                                    return _customerSearchTile(
                                      customer,
                                      dialogContext,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (customer == null ||
        !mounted) {
      return;
    }

    setState(() {
      _selectedCustomer =
          customer;

      _customerNameCtrl.text =
          customer.name;

      _mobileCtrl.text =
          customer.mobile;

      _aadhaarCtrl.text =
          customer.aadhaarNumber ?? '';


      _panCtrl.text =
          customer.panNumber ?? '';


      _addressCtrl.text =
          customer.address;
    });

    await _loadAvailableGold(
      customer.id,
    );
  }

  // ============================================================
  // CUSTOMER SEARCH TILE
  // ============================================================

  Widget _customerSearchTile(
    Customer customer,
    BuildContext dialogContext,
  ) {
    final initial =
        customer.name.isNotEmpty
            ? customer.name[0]
                .toUpperCase()
            : '?';

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        leading: CircleAvatar(
        radius: 22,
        backgroundColor:
            AppTheme.darkNavy,
        child: Text(
          initial,
          style:
              const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        customer.name,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w800,
          fontSize: 13,
        ),
      ),
      subtitle: Padding(
        padding:
            const EdgeInsets.only(
          top: 3,
        ),
        child: Text(
          'Customer No: ${customer.customerCode}\n'
          'Mobile: ${customer.mobile}\n'
          'Aadhaar: ${customer.aadhaarNumber ?? '-'}',
          maxLines: 3,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize: 10,
            height: 1.4,
            color:
                AppTheme.silverDark,
          ),
        ),
      ),
      isThreeLine: true,
      trailing:
          const Icon(
        Icons
            .arrow_forward_ios,
        size: 14,
      ),
      onTap: () {
        Navigator.pop(
          dialogContext,
          customer,
        );
      },
    ),
  );
}

  Widget _emptyCustomerState() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .person_off_outlined,
            size: 48,
            color:
                AppTheme.silverDark,
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'No customers found',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOAD GOLD
  // ============================================================

  Future<void>
      _loadAvailableGold(
    int customerId,
  ) async {
    if (!mounted) return;

    setState(() {
      _loadingGold = true;
      _availableGoldItems = [];
      _selectedGoldIds.clear();
    });

    try {
      List<GoldItem> items =
          await ApiService
              .getGoldItems(
        customerId:
            customerId,
        status: 'AVAILABLE',
      );

      if (items.isEmpty) {
        items =
            await ApiService
                .getGoldItems(
          customerId:
              customerId,
        );
      }

      if (!mounted) return;

      setState(() {
        _availableGoldItems =
            items;
        _loadingGold = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingGold = false;
      });

      _showError(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    }
  }

  // ============================================================
  // CREATE CUSTOMER
  // ============================================================

  Future<bool>
      _createCustomer() async {
    if (_customerNameCtrl
        .text
        .trim()
        .isEmpty) {
      _showError(
        'Customer name is required.',
      );
      return false;
    }

    if (_mobileCtrl
        .text
        .trim()
        .isEmpty) {
      _showError(
        'Mobile number is required.',
      );
      return false;
    }

    final provider =
        context.read<CustomerProvider>();

    final customer =
        await provider
            .createCustomer({
      'name':
          _customerNameCtrl.text
              .trim(),
      'mobile':
          _mobileCtrl.text
              .trim(),
      'aadhaar_number':
          _aadhaarCtrl.text
                  .trim()
                  .isEmpty
              ? null
              : _aadhaarCtrl.text
                  .trim(),
      'pan_number':
          _panCtrl.text
                  .trim()
                  .isEmpty
              ? null
              : _panCtrl.text
                  .trim(),
      'address':
          _addressCtrl.text
                  .trim()
                  .isEmpty
              ? null
              : _addressCtrl.text
                  .trim(),
    });

    if (customer == null) {
      _showError(
        provider.errorMessage ??
            'Failed to create customer.',
      );
      return false;
    }

    if (!mounted) {
      return false;
    }

    setState(() {
      _selectedCustomer =
          customer;
    });

    await _loadAvailableGold(
      customer.id,
    );

    return true;
  }

  // ============================================================
  // ADD GOLD
  // ============================================================

  Future<void> _addGoldItem() async {
    if (_selectedCustomer ==
        null) {
      _showError(
        'Select or create a customer first.',
      );
      return;
    }

    _goldItemNameCtrl.clear();
    _goldPurityCtrl.clear();
    _goldWeightCtrl.clear();
    _goldRemarksCtrl.clear();

    final formKey =
        GlobalKey<FormState>();

    bool saving = false;

    final result =
        await showDialog<bool>(
      context: context,
      barrierDismissible:
          false,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final width =
                MediaQuery.of(
              context,
            ).size.width;

            final mobile =
                width < 600;

            return AlertDialog(
              insetPadding:
                  EdgeInsets.all(
                mobile ? 10 : 24,
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(
                      color: AppTheme
                          .goldPrimary
                          .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        9,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons.diamond,
                      color:
                          AppTheme
                              .goldDark,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  const Expanded(
                    child: Text(
                      'Add Gold Item',
                    ),
                  ),
                ],
              ),
              content:
                  SizedBox(
                width: mobile
                    ? double.infinity
                    : 560,
                child: Form(
                  key: formKey,
                  child:
                      SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            10,
                          ),
                          decoration:
                              BoxDecoration(
                            color: AppTheme
                                .goldLight,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child:
                              Text(
                            'Customer: ${_selectedCustomer!.name}',
                            style:
                                const TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  AppTheme
                                      .darkNavy,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        _dialogField(
                          controller:
                              _goldItemNameCtrl,
                          label:
                              'Item Name *',
                          icon:
                              Icons
                                  .diamond_outlined,
                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Item name is required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        _dialogField(
                          controller:
                              _goldPurityCtrl,
                          label:
                              'Purity *',
                          hint:
                              'Example: 22K / 916',
                          icon:
                              Icons
                                  .verified_outlined,
                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Purity is required';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        _dialogField(
                          controller:
                              _goldWeightCtrl,
                          label:
                              'Weight (g) *',
                          icon:
                              Icons
                                  .scale_outlined,
                          suffix:
                              'g',
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal:
                                true,
                          ),
                          validator:
                              (value) {
                            final weight =
                                double.tryParse(
                              value
                                      ?.trim() ??
                                  '',
                            );

                            if (weight ==
                                    null ||
                                weight <=
                                    0) {
                              return 'Enter valid weight';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        _dialogField(
                          controller:
                              _goldRemarksCtrl,
                          label:
                              'Remarks',
                          icon:
                              Icons
                                  .notes_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      saving
                          ? null
                          : () async {
                              if (!formKey
                                  .currentState!
                                  .validate()) {
                                return;
                              }

                              setDialogState(
                                () {
                                  saving =
                                      true;
                                },
                              );

                              try {
                                final weight =
                                    double.parse(
                                  _goldWeightCtrl
                                      .text
                                      .trim(),
                                );

                                await ApiService
                                    .addGoldItem({
                                  'customer_id':
                                      _selectedCustomer!
                                          .id,
                                  'item_name':
                                      _goldItemNameCtrl
                                          .text
                                          .trim(),
                                  'purity':
                                      _goldPurityCtrl
                                          .text
                                          .trim(),
                                  'weight':
                                      weight,
                                  'remarks':
                                      _goldRemarksCtrl
                                          .text
                                          .trim(),
                                });

                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                Navigator.pop(
                                  dialogContext,
                                  true,
                                );
                              } catch (e) {
                                setDialogState(
                                  () {
                                    saving =
                                        false;
                                  },
                                );

                                if (!context
                                    .mounted) {
                                  return;
                                }

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(
                                      e.toString()
                                          .replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    ),
                                    backgroundColor:
                                        AppTheme
                                            .statusDanger,
                                  ),
                                );
                              }
                            },
                  icon: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.add,
                        ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : 'Add Gold Item',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true &&
        mounted) {
      await _loadAvailableGold(
        _selectedCustomer!.id,
      );

      _showSuccess(
        'Gold item added successfully.',
      );
    }
  }

  // ============================================================
  // GOLD DIALOG FIELD
  // ============================================================

  Widget _dialogField({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    TextInputType? keyboardType,
    String? Function(String?)?
        validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType:
          keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration:
          InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(
          icon,
          color:
              AppTheme.goldDark,
        ),
      ),
    );
  }

  // ============================================================
  // SAVE EXISTING LOAN
  // ============================================================

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _openedDate ??= DateTime.now();

    if (_existingCustomerMode && _selectedCustomer == null) {
      _showError('Please search and select an existing customer.');
      return;
    }

    if (_principal <= 0) {
      _showError('Principal amount must be greater than 0.');
      return;
    }

    if (_paid < 0) {
      _showError('Paid amount cannot be negative.');
      return;
    }

    if (_paid > _totalDue) {
      _showError('Paid amount cannot exceed total due.');
      return;
    }

    if (_status == 'CLOSED' && _closedDate == null) {
      _showError('Closed date is required for a closed loan.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_newCustomerMode) {
        if (_customerNameCtrl.text.trim().isEmpty || _mobileCtrl.text.trim().isEmpty) {
          _showError('Customer Name and Mobile Number are required.');
          return;
        }
        if (_newCustomerGoldItems.isEmpty) {
          _showError('Please add at least one gold collateral item.');
          return;
        }

        final created = await _createCustomer();
        if (!created || _selectedCustomer == null) {
          return;
        }

        // Automatically create and select gold collateral items for new customer
        for (final Map<String, dynamic> item in _newCustomerGoldItems) {
          try {
            final res = await ApiService.addGoldItem({
              'customer_id': _selectedCustomer!.id,
              'item_name': item['item_name'],
              'purity': item['purity'],
              'weight': item['weight'],
              'remarks': item['remarks'],
            });
            if (res.id > 0) {
              _selectedGoldIds.add(res.id);
            }
          } catch (_) {}
        }
      }

      if (_selectedCustomer == null) {
        _showError('Customer is required.');
        return;
      }

      if (_selectedGoldIds.isEmpty) {
        _showError('Select or add at least one gold item.');
        return;
      }

      final data = {
        'customer_id': _selectedCustomer!.id,
        'manual_loan_no': _manualLoanNoCtrl.text.trim(),
        'manual_opened_date': _apiDate(_openedDate!),
        'manual_closed_date': _closedDate == null ? null : _apiDate(_closedDate!),
        'principal_amount': _principal,
        'monthly_interest_rate': 2.0,
        'total_interest': _interest,
        'total_paid': _paid,
        'remaining_balance': _remainingBalance,
        'gold_item_ids': _selectedGoldIds.toList(),
        'status': _status,
        'remarks': _remarksCtrl.text.trim(),
      };

      if (!mounted) return;

      final loanProvider = context.read<LoanProvider>();
      final result = await loanProvider.createExistingLoan(data);

      if (result == null) {
        throw Exception(
          loanProvider.errorMessage ?? 'Failed to create existing loan.',
        );
      }

      if (!mounted) return;

      final receipt = result['data']?['receipt'] ?? result['receipt'];

      SuccessDialog.show(
        context: context,
        title: 'Pawn Loan Created Successfully',
        message: 'The pawn loan has been saved successfully.',
        onOk: () {
          Navigator.of(context).pop(true);
        },
        printLabel: 'Print Receipt',
        onPrint: () {
          Navigator.of(context).pop(true);
          if (receipt != null) {
            showDialog(
              context: context,
              builder: (_) {
                return Dialog(
                  insetPadding: const EdgeInsets.all(10),
                  child: A4ReceiptViewer(
                    receiptData: receipt is Map<String, dynamic>
                        ? receipt
                        : Map<String, dynamic>.from(receipt as Map),
                  ),
                );
              },
            );
          }
        },
      );

    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final width = MediaQuery.of(context).size.width;

    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1200;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.darkNavy,
        foregroundColor: Colors.white,
        title: Text(
          'Existing Pawn Loan',
          style: TextStyle(
            fontSize: isMobile ? 15 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 10
                  : isTablet
                      ? 18
                      : 28,
              vertical: isMobile
                  ? 10
                  : isTablet
                      ? 18
                      : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(isMobile),

                    SizedBox(
                      height: isMobile ? 10 : 14,
                    ),

                    if (isMobile)
                      _buildMobileLayout()
                    else if (isTablet)
                      _buildTabletLayout()
                    else
                      _buildDesktopLayout(),

                    SizedBox(
                      height: isMobile ? 14 : 18,
                    ),

                    _buttons(isMobile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE LAYOUT
  // ============================================================

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        _customerSection(
          true,
          false,
        ),

        const SizedBox(
          height: 10,
        ),

        _goldSection(
          true,
          false,
        ),

        const SizedBox(
          height: 10,
        ),

        _loanSection(
          true,
          false,
        ),

        const SizedBox(
          height: 10,
        ),

        _summarySection(
          true,
        ),
      ],
    );
  }

  // ============================================================
  // TABLET LAYOUT
  // ============================================================

  Widget _buildTabletLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _customerSection(
          false,
          true,
        ),

        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _goldSection(
                false,
                true,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              flex: 3,
              child: _summarySection(
                false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _loanSection(
          false,
          true,
        ),
      ],
    );
  }

  // ============================================================
  // DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _customerSection(
                false,
                false,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: _loanSection(
                false,
                false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _goldSection(
          false,
          false,
        ),

        const SizedBox(height: 18),

        _summarySection(
          false,
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(
    bool mobile,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        mobile ? 14 : 20,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.darkNavy,
        borderRadius:
            BorderRadius.circular(
          mobile ? 12 : 16,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:
                mobile ? 42 : 48,
            height:
                mobile ? 42 : 48,
            decoration:
                BoxDecoration(
              color:
                  AppTheme.goldPrimary,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child:
                Icon(
              Icons.history_edu,
              color:
                  AppTheme.darkNavy,
              size:
                  mobile ? 22 : 26,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Existing Pawn Loan',
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        mobile
                            ? 16
                            : 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  mobile
                      ? 'Register historical loan details'
                      : 'Register an already existing historical pawn loan',
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize:
                        mobile
                            ? 9
                            : 11,
                  ),
                ),
              ],
            ),
          ),

          if (!mobile)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '# EXISTING',
                style: TextStyle(
                  color: AppTheme.goldPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER SECTION
  // ============================================================

  Widget _customerSection(
    bool mobile,
    bool tablet,
  ) {
    return _card(
      title:
          '1. CUSTOMER',
      icon:
          Icons.person_outline,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          _modeSelector(
            mobile,
          ),

          const SizedBox(
            height: 14,
          ),

          if (_existingCustomerMode)
            SizedBox(
              width:
                  double.infinity,
              height:
                  mobile ? 48 : 44,
              child:
                  OutlinedButton.icon(
                onPressed:
                    _selectExistingCustomer,
                icon:
                    const Icon(
                  Icons
                      .person_search,
                  size: 19,
                ),
                label:
                    Text(
                  _selectedCustomer ==
                          null
                      ? 'Search Existing Customer'
                      : 'Change Customer',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),

          if (_newCustomerMode)
            _newCustomerFields(
              mobile,
              tablet,
            ),

          if (_selectedCustomer !=
              null)
            _selectedCustomerCard(),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER MODE SELECTOR
  // ============================================================

  Widget _modeSelector(
    bool mobile,
  ) {
    if (mobile) {
      return Column(
        children: [
          SizedBox(
            width:
                double.infinity,
            height: 45,
            child:
                _modeButton(
              title:
                  'Existing Customer',
              icon:
                  Icons.person_search,
              selected:
                  _existingCustomerMode,
              onTap:
                  _setExistingCustomerMode,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 45,
            child:
                _modeButton(
              title:
                  'Create New Customer',
              icon:
                  Icons.person_add_alt_1,
              selected:
                  _newCustomerMode,
              onTap:
                  _setNewCustomerMode,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _modeButton(
            title: 'Existing Customer',
            icon: Icons.person_search,
            selected: _existingCustomerMode,
            onTap: _setExistingCustomerMode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _modeButton(
            title: 'Create New Customer',
            icon: Icons.person_add_alt_1,
            selected: _newCustomerMode,
            onTap: _setNewCustomerMode,
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.goldPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.goldDark : AppTheme.silverBorder,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppTheme.darkNavy : AppTheme.silverDark,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.darkNavy : AppTheme.silverDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NEW CUSTOMER FIELDS
  // ============================================================

  Widget _newCustomerFields(
    bool mobile,
    bool tablet,
  ) {
    return Column(
      children: [
        _responsiveFields(
          mobile,
          [
            _field(
              _customerNameCtrl,
              'Customer Name *',
              Icons.person_outline,
              required: true,
            ),
            _field(
              _mobileCtrl,
              'Mobile Number *',
              Icons.phone_outlined,
              keyboardType:
                  TextInputType.phone,
              required: true,
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        _responsiveFields(
          mobile,
          [
            _field(
              _aadhaarCtrl,
              'Aadhaar Number',
              Icons.badge_outlined,
            ),
            _field(
              _panCtrl,
              'PAN Number',
              Icons.credit_card_outlined,
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        _field(
          _addressCtrl,
          'Address',
          Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  // ============================================================
  // SELECTED CUSTOMER
  // ============================================================

  Widget _selectedCustomerCard() {
    final customer =
        _selectedCustomer!;

    final initial =
        customer.name.isNotEmpty
            ? customer.name[0]
                .toUpperCase()
            : '?';

    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        top: 12,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.goldLight,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppTheme.goldPrimary,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                AppTheme.darkNavy,
            child: Text(
              initial,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontWeight:
                    FontWeight.w800,
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
                  customer.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight
                            .w800,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'Customer No: ${customer.customerCode}',
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
                Text(
                  'Mobile: ${customer.mobile}',
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

          const Icon(
            Icons.check_circle,
            color:
                Color(0xFF065F46),
            size: 21,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GOLD SECTION
  // ============================================================

  Widget _goldSection(
    bool mobile,
    bool tablet,
  ) {
    return _card(
      title: '2. GOLD COLLATERAL',
      icon: Icons.diamond_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_newCustomerMode) ...[
            _newCustomerGoldSection(mobile, tablet),
          ] else if (_selectedCustomer == null) ...[
            ElevatedButton.icon(
              onPressed: _selectExistingCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldPrimary,
                foregroundColor: AppTheme.darkNavy,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
              icon: const Icon(Icons.person_search, size: 20),
              label: const Text(
                'Search & Select Existing Customer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ] else ...[
            _goldCustomerHeader(mobile),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_availableGoldItems.length} gold item(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                ),
                _smallCountBadge('Selected ${_selectedGoldIds.length}'),
              ],
            ),
            const SizedBox(height: 9),
            _goldList(mobile),
            if (_selectedGoldIds.isNotEmpty) _selectedGoldSummary(mobile),
          ],
        ],
      ),
    );
  }

  Widget _newCustomerGoldSection(bool mobile, bool tablet) {
    double totalWeight = 0.0;
    for (final item in _newCustomerGoldItems) {
      totalWeight += double.tryParse('${item['weight'] ?? 0}') ?? 0.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.silverLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.silverBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Gold Collateral for New Customer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.darkNavy),
              ),
              const SizedBox(height: 10),
              _responsiveFields(
                mobile,
                [
                  _field(_goldItemNameCtrl, 'Item Name (e.g. Gold Chain) *', Icons.diamond_outlined),
                  _field(_goldPurityCtrl, 'Purity (e.g. 22K)', Icons.verified_outlined),
                ],
              ),
              const SizedBox(height: 10),
              _responsiveFields(
                mobile,
                [
                  _field(_goldWeightCtrl, 'Weight in Grams (e.g. 20.00) *', Icons.scale, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  _field(_goldRemarksCtrl, 'Remarks (Optional)', Icons.notes),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final name = _goldItemNameCtrl.text.trim();
                    final weight = double.tryParse(_goldWeightCtrl.text.trim()) ?? 0.0;
                    if (name.isEmpty || weight <= 0) {
                      _showError('Item name and valid weight are required.');
                      return;
                    }
                    setState(() {
                      _newCustomerGoldItems.add({
                        'item_name': name,
                        'purity': _goldPurityCtrl.text.trim().isEmpty ? '22K' : _goldPurityCtrl.text.trim(),
                        'weight': weight,
                        'remarks': _goldRemarksCtrl.text.trim(),
                      });
                      _goldItemNameCtrl.clear();
                      _goldPurityCtrl.clear();
                      _goldWeightCtrl.clear();
                      _goldRemarksCtrl.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Gold Item', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (_newCustomerGoldItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No gold items added yet. Fill out the fields above and click Add Gold Item.',
              style: TextStyle(fontSize: 11, color: AppTheme.silverDark),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _newCustomerGoldItems.length,
            itemBuilder: (context, index) {
              final item = _newCustomerGoldItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.goldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.goldPrimary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond, color: AppTheme.goldDark, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['item_name']} • ${item['purity']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'Weight: ${AppConstants.formatWeight(double.tryParse('${item['weight']}') ?? 0.0)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.silverDark),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _newCustomerGoldItems.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Added: ${_newCustomerGoldItems.length}', style: const TextStyle(fontSize: 12, color: AppTheme.silverDark)),
              Text('Total Weight: ${AppConstants.formatWeight(totalWeight)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
            ],
          ),
        ],
      ],
    );
  }

  // ============================================================
  // GOLD CUSTOMER HEADER
  // ============================================================

  Widget _goldCustomerHeader(
    bool mobile,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        11,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 19,
                      backgroundColor:
                          AppTheme
                              .darkNavy,
                      child:
                          Icon(
                        Icons.person,
                        size: 18,
                        color:
                            AppTheme
                                .goldPrimary,
                      ),
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            _selectedCustomer!
                                .name,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                          Text(
                            '${_selectedCustomer!.customerCode} • ${_selectedCustomer!.mobile}',
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  8,
                              color:
                                  AppTheme
                                      .silverDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 9,
                ),

                SizedBox(
                  height: 42,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _addGoldItem,
                    icon:
                        const Icon(
                      Icons.add,
                      size: 17,
                    ),
                    label:
                        const Text(
                      'Add Gold Item',
                      style:
                          TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      AppTheme
                          .darkNavy,
                  child:
                      Icon(
                    Icons.person,
                    size: 18,
                    color:
                        AppTheme
                            .goldPrimary,
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
                        _selectedCustomer!
                            .name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize:
                              12,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        '${_selectedCustomer!.customerCode} • ${_selectedCustomer!.mobile}',
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
                ElevatedButton.icon(
                  onPressed:
                      _addGoldItem,
                  icon:
                      const Icon(
                    Icons.add,
                    size: 17,
                  ),
                  label:
                      const Text(
                    'Add Gold Item',
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // GOLD LIST
  // ============================================================

  Widget _goldList(
    bool mobile,
  ) {
    if (_loadingGold) {
      return Container(
        height:
            mobile ? 180 : 220,
        decoration:
            BoxDecoration(
          color:
              AppTheme.silverLight,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child:
            const Center(
          child:
              CircularProgressIndicator(
            color:
                AppTheme.goldPrimary,
          ),
        ),
      );
    }

    if (_availableGoldItems
        .isEmpty) {
      return _noGoldState();
    }

    final height =
        mobile ? 320.0 : 350.0;

    return Container(
      height: height,
      decoration:
          BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: ListView.separated(
        padding:
            const EdgeInsets.all(
          7,
        ),
        itemCount:
            _availableGoldItems
                .length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          height: 6,
        ),
        itemBuilder:
            (context, index) {
          return _goldItemTile(
            _availableGoldItems[
                index],
          );
        },
      ),
    );
  }

  // ============================================================
  // NO GOLD
  // ============================================================

  Widget _noGoldState() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        24,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .inventory_2_outlined,
            size: 42,
            color:
                AppTheme.silverDark,
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'No gold items available',
            style:
                TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppTheme.darkNavy,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'Add one or more gold items for this customer.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 9,
              color:
                  AppTheme.silverDark,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            height: 42,
            child:
                ElevatedButton.icon(
              onPressed:
                  _addGoldItem,
              icon:
                  const Icon(
                Icons.add,
                size: 17,
              ),
              label:
                  const Text(
                'Add First Gold Item',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GOLD ITEM TILE
  // ============================================================

  Widget _goldItemTile(
    GoldItem item,
  ) {
    final selected =
        _selectedGoldIds
            .contains(item.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedGoldIds
                .remove(item.id);
          } else {
            _selectedGoldIds
                .add(item.id);
          }
        });
      },
      borderRadius:
          BorderRadius.circular(
        9,
      ),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? AppTheme.goldLight
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            9,
          ),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : AppTheme.silverBorder,
            width:
                selected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor:
                  AppTheme.goldDark,
              onChanged:
                  (_) {
                setState(() {
                  if (selected) {
                    _selectedGoldIds
                        .remove(
                      item.id,
                    );
                  } else {
                    _selectedGoldIds
                        .add(
                      item.id,
                    );
                  }
                });
              },
            ),

            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    AppTheme.silverLight,
                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .diamond_outlined,
                color:
                    AppTheme.goldDark,
                size: 21,
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    item.itemName,
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
                          AppTheme
                              .darkNavy,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      Text(
                        'Purity: ${item.purity}',
                        style:
                            const TextStyle(
                          fontSize:
                              8,
                          color:
                              AppTheme
                                  .silverDark,
                        ),
                      ),
                      Text(
                        'Weight: ${AppConstants.formatWeight(item.weight)}',
                        style:
                            const TextStyle(
                          fontSize:
                              8,
                          color:
                              AppTheme
                                  .silverDark,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                      Text(
                        'Status: ${item.status}',
                        style:
                            const TextStyle(
                          fontSize:
                              8,
                          color:
                              AppTheme
                                  .silverDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (selected)
              const Icon(
                Icons
                    .check_circle,
                color:
                    AppTheme.goldDark,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED GOLD SUMMARY
  // ============================================================

  Widget _selectedGoldSummary(
    bool mobile,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 10,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.goldLight,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppTheme.goldPrimary,
        ),
      ),
      child: mobile
          ? Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons
                          .check_circle,
                      color:
                          AppTheme
                              .goldDark,
                      size: 19,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Expanded(
                      child: Text(
                        '${_selectedGoldIds.length} gold item(s) selected',
                        style:
                            const TextStyle(
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                _weightValue(),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons
                      .check_circle,
                  color:
                      AppTheme.goldDark,
                  size: 19,
                ),
                const SizedBox(
                  width: 7,
                ),
                Expanded(
                  child: Text(
                    '${_selectedGoldIds.length} gold item(s) selected',
                    style:
                        const TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
                _weightValue(),
              ],
            ),
    );
  }

  Widget _weightValue() {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        const Icon(
          Icons.scale_outlined,
          size: 17,
          color:
              AppTheme.goldDark,
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          AppConstants
              .formatWeight(
            _selectedGoldWeight,
          ),
          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w900,
            color:
                AppTheme.goldDark,
          ),
        ),
      ],
    );
  }

  Widget _smallCountBadge(
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            AppTheme.goldLight,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Text(
        text,
        style:
            const TextStyle(
          fontSize: 8,
          fontWeight:
              FontWeight.w800,
          color:
              AppTheme.goldDark,
        ),
      ),
    );
  }

  // ============================================================
  // LOAN SECTION
  // ============================================================

  Widget _loanSection(
    bool mobile,
    bool tablet,
  ) {
    return _card(
      title:
          '3. EXISTING PAWN LOAN DETAILS',
      icon:
          Icons.account_balance_outlined,
      child: Column(
        children: [
          _responsiveFields(
            mobile,
            [
              _field(
                _manualLoanNoCtrl,
                'Manual Loan Number *',
                Icons
                    .confirmation_number_outlined,
                required: true,
              ),
              _field(
                _principalCtrl,
                'Principal Amount *',
                Icons
                    .account_balance_wallet_outlined,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                required: true,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          _responsiveFields(
            mobile,
            [
              _field(
                _interestCtrl,
                'Total Interest',
                Icons.percent,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
              ),
              _field(
                _paidCtrl,
                'Total Paid',
                Icons
                    .payments_outlined,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          _responsiveFields(
            mobile,
            [
              _dateField(
                'Manual Opened Date *',
                _displayDate(
                  _openedDate,
                ),
                _pickOpenedDate,
              ),
              _dateField(
                'Manual Closed Date',
                _displayDate(
                  _closedDate,
                ),
                _pickClosedDate,
                clear:
                    _closedDate !=
                        null,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          _responsiveFields(
            mobile,
            [
              _statusField(),
              _field(
                _remarksCtrl,
                'Remarks',
                Icons.notes_outlined,
                maxLines: mobile
                    ? 2
                    : 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusField() {
    return DropdownButtonFormField<
        String>(
      initialValue: _status,
      decoration:
          const InputDecoration(
        labelText:
            'Loan Status',
        prefixIcon:
            Icon(
          Icons.flag_outlined,
          color:
              AppTheme.goldDark,
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'ACTIVE',
          child:
              Text('ACTIVE'),
        ),
        DropdownMenuItem(
          value: 'CLOSED',
          child:
              Text('CLOSED'),
        ),
      ],
      onChanged:
          (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _status = value;

          if (value ==
              'ACTIVE') {
            _closedDate = null;
          }
        });
      },
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _summarySection(
    bool mobile,
  ) {
    return _card(
      title:
          '4. LOAN SUMMARY',
      icon:
          Icons.summarize_outlined,
      child:
          LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          int columns;

          if (constraints
                  .maxWidth >=
              700) {
            columns = 4;
          } else if (constraints
                  .maxWidth >=
              300) {
            columns = 2;
          } else {
            columns = 1;
          }

          return GridView.count(
            crossAxisCount:
                columns,
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio:
                columns == 1
                    ? 4.2
                    : 1.75,
            children: [
              _summaryCard(
                'Principal',
                AppConstants
                    .formatCurrency(
                  _principal,
                ),
                Icons
                    .account_balance_wallet_outlined,
              ),
              _summaryCard(
                'Interest',
                AppConstants
                    .formatCurrency(
                  _interest,
                ),
                Icons.percent,
              ),
              _summaryCard(
                'Total Due',
                AppConstants
                    .formatCurrency(
                  _totalDue,
                ),
                Icons
                    .account_balance_outlined,
              ),
              _summaryCard(
                'Remaining',
                AppConstants
                    .formatCurrency(
                  _remainingBalance,
                ),
                Icons
                    .payments_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          9,
        ),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration:
                BoxDecoration(
              color:
                  AppTheme.goldLight,
              borderRadius:
                  BorderRadius.circular(
                7,
              ),
            ),
            child:
                Icon(
              icon,
              size: 16,
              color:
                  AppTheme.goldDark,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 8,
                    color:
                        AppTheme
                            .silverDark,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                FittedBox(
                  fit: BoxFit
                      .scaleDown,
                  alignment:
                      Alignment
                          .centerLeft,
                  child: Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight
                              .w900,
                      color:
                          AppTheme
                              .darkNavy,
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
  // BUTTONS
  // ============================================================

  Widget _buttons(
    bool mobile,
  ) {
    if (mobile) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          SizedBox(
            height: 50,
            child:
                ElevatedButton.icon(
              onPressed:
                  _saving
                      ? null
                      : _saveLoan,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save,
                      size: 19,
                    ),
              label: Text(
                _saving
                    ? 'Saving Existing Loan...'
                    : 'SAVE EXISTING LOAN',
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          SizedBox(
            height: 46,
            child:
                OutlinedButton(
              onPressed:
                  _saving
                      ? null
                      : () =>
                          Navigator.pop(
                        context,
                      ),
              child:
                  const Text(
                'CANCEL',
                style:
                    TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
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
        OutlinedButton(
          onPressed:
              _saving
                  ? null
                  : () =>
                      Navigator.pop(
                    context,
                  ),
          style:
              OutlinedButton.styleFrom(
            minimumSize:
                const Size(
              120,
              46,
            ),
          ),
          child:
              const Text(
            'CANCEL',
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        ElevatedButton.icon(
          onPressed:
              _saving
                  ? null
                  : _saveLoan,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.save,
                  size: 18,
                ),
          label: Text(
            _saving
                ? 'Saving...'
                : 'SAVE EXISTING LOAN',
            style:
                const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          style:
              ElevatedButton.styleFrom(
            minimumSize:
                const Size(
              210,
              46,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.025,
            ),
            blurRadius: 8,
            offset:
                const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration:
                    BoxDecoration(
                  color: AppTheme
                      .goldPrimary
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    8,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  size: 17,
                  color:
                      AppTheme.goldDark,
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // RESPONSIVE FIELDS
  // ============================================================

  Widget _responsiveFields(
    bool mobile,
    List<Widget> children,
  ) {
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(
            child: children[i],
          ),
          if (i < children.length - 1)
            const SizedBox(width: 16),
        ],
      ],
    );
  }

  // ============================================================
  // FIELD
  // ============================================================

  Widget _field(
    TextEditingController
        controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller:
          controller,
      keyboardType:
          keyboardType,
      maxLines:
          maxLines,
      validator:
          (value) {
        if (required &&
            (value == null ||
                value
                    .trim()
                    .isEmpty)) {
          return 'Required';
        }

        return null;
      },
      decoration:
          InputDecoration(
        labelText:
            label,
        prefixIcon:
            Icon(
          icon,
          color:
              AppTheme.goldDark,
        ),
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _dateField(
    String label,
    String value,
    VoidCallback onTap, {
    bool clear = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        8,
      ),
      child:
          InputDecorator(
        decoration:
            InputDecoration(
          labelText:
              label,
          prefixIcon:
              const Icon(
            Icons
                .calendar_month_outlined,
            color:
                AppTheme.goldDark,
          ),
          suffixIcon:
              clear
                  ? IconButton(
                      tooltip:
                          'Clear date',
                      onPressed:
                          () {
                        setState(
                          () {
                            _closedDate =
                                null;
                            _status =
                                'ACTIVE';
                          },
                        );
                      },
                      icon:
                          const Icon(
                        Icons.clear,
                        size: 18,
                      ),
                    )
                  : null,
        ),
        child: Text(
          value,
          style:
              TextStyle(
            fontSize: 12,
            color: value ==
                    'Select date'
                ? AppTheme
                    .silverDark
                : AppTheme
                    .darkNavy,
            fontWeight:
                value ==
                        'Select date'
                    ? FontWeight
                        .w400
                    : FontWeight
                        .w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            const Color(
          0xFF065F46,
        ),
        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            AppTheme.statusDanger,
        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }
}

// ==================================================================
// INFO BOX
// ==================================================================

class _InfoBox
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
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
      child: Row(
        children: [
          Icon(
            icon,
            color:
                AppTheme.silverDark,
            size: 19,
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    AppTheme.silverDark,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}