// lib/screens/gold/add_gold_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/gold_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/image_picker_widget.dart';
import '../../widgets/success_dialog.dart';
import '../customers/customer_profile_screen.dart';

class AddGoldScreen extends StatefulWidget {
  final int? customerId;

  const AddGoldScreen({
    super.key,
    this.customerId,
  });

  @override
  State<AddGoldScreen> createState() => _AddGoldScreenState();
}

class _AddGoldScreenState extends State<AddGoldScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedCustomerId;

  final TextEditingController _customerSearchCtrl =
      TextEditingController();

  List<dynamic> _filteredCustomers = [];

  bool _showCustomerResults = false;

  final TextEditingController _itemNameCtrl =
      TextEditingController();

  final FocusNode _itemNameFocusNode = FocusNode();

  final TextEditingController _weightCtrl =
      TextEditingController();

  final TextEditingController _remarksCtrl =
      TextEditingController();

  String _selectedPurity = '22K (91.6%)';

  String _uploadedPhotoUrl = '';

  bool _isSubmitting = false;

  static const List<String> _goldItemSuggestions = [
    'Ring',
    'Chain',
    'Necklace',
    'Bangle',
    'Bracelet',
    'Earrings',
    'Studs',
    'Pendant',
    'Coin',
    'Gold Bar',
    'Nose Ring',
    'Anklet',
  ];

  // ============================================================
  // TEMPORARY GOLD ITEMS
  // ============================================================

  final List<Map<String, dynamic>> _pendingGoldItems = [];

  final List<String> _purityOptions = [
    '24K (99.9%)',
    '22K (91.6%)',
    '18K (75.0%)',
    'Silver (92.5%)',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _selectedCustomerId = widget.customerId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final custProvider = context.read<CustomerProvider>();
        await custProvider.fetchCustomers();
        if (_selectedCustomerId != null && _selectedCustomerId! > 0) {
          final matches = custProvider.customers
              .where((c) => c.id == _selectedCustomerId)
              .toList();
          if (matches.isNotEmpty) {
            _selectCustomer(matches.first);
          } else {
            try {
              final res = await ApiService.getCustomerDetails(_selectedCustomerId!);
              if (res['customer'] != null) {
                final cust = Customer.fromJson(res['customer']);
                _selectCustomer(cust);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to load customer details: $e'),
                    backgroundColor: AppTheme.statusDanger,
                  ),
                );
              }
            }
          }
        }
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _itemNameCtrl.dispose();
    _weightCtrl.dispose();
    _remarksCtrl.dispose();
    _itemNameFocusNode.dispose();

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

      final search = value.toLowerCase().trim();

      _filteredCustomers = customers.where((customer) {
        return customer.name
                .toString()
                .toLowerCase()
                .contains(search) ||
            customer.customerCode
                .toString()
                .toLowerCase()
                .contains(search) ||
            customer.mobile
                .toString()
                .contains(search);
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
  }

  // ============================================================
  // CLEAR CURRENT GOLD FORM
  // ============================================================

  void _clearCurrentGoldForm() {
    _itemNameCtrl.clear();
    _weightCtrl.clear();
    _remarksCtrl.clear();

    setState(() {
      _selectedPurity = '22K (91.6%)';
      _uploadedPhotoUrl = '';
    });
  }

  // ============================================================
  // ADD GOLD TO TEMPORARY LIST
  // ============================================================

  void _showGoldAddedDialog(Map<String, dynamic> addedItem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF065F46),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gold Added Successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gold item added successfully. What would you like to do next?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.silverLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.silverBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: AppTheme.goldDark, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addedItem['item_name']?.toString() ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                          Text(
                            'Purity: ${addedItem['purity_display'] ?? addedItem['purity']} • Weight: ${addedItem['weight']} g',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _clearCurrentGoldForm();
                        _itemNameFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'ADD GOLD',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.darkNavy,
                        side: const BorderSide(color: AppTheme.goldPrimary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _handleCreateLoanNext();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        'NEXT',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD GOLD TO TEMPORARY LIST
  // ============================================================

  void _addGoldToList() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomerId == null ||
        _selectedCustomerId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
        ),
      );
      return;
    }

    final itemName = _itemNameCtrl.text.trim();

    final weight =
        double.tryParse(_weightCtrl.text.trim());

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid gold weight greater than zero'),
        ),
      );
      return;
    }

    final cleanPurity =
        _selectedPurity.split(' ')[0];

    final newItem = {
      'customer_id': _selectedCustomerId,
      'item_name': itemName,
      'purity': cleanPurity,
      'purity_display': _selectedPurity,
      'weight': weight,
      'remarks': _remarksCtrl.text.trim(),
      'photo_url': _uploadedPhotoUrl,
      'id': null,
    };

    setState(() {
      _pendingGoldItems.add(newItem);
    });

    _clearCurrentGoldForm();

    _showGoldAddedDialog(newItem);
  }

  // ============================================================
  // EDIT PENDING GOLD ITEM
  // ============================================================

  void _editPendingGoldItem(int index) {
    if (_isSubmitting) return;

    final item = _pendingGoldItems[index];

    setState(() {
      _itemNameCtrl.text = item['item_name']?.toString() ?? '';
      _weightCtrl.text = item['weight']?.toString() ?? '';
      _remarksCtrl.text = item['remarks']?.toString() ?? '';
      _uploadedPhotoUrl = item['photo_url']?.toString() ?? '';

      final purityStr = item['purity_display']?.toString() ?? item['purity']?.toString() ?? '';
      if (_purityOptions.contains(purityStr)) {
        _selectedPurity = purityStr;
      } else {
        final matched = _purityOptions.firstWhere(
          (p) => p.startsWith(purityStr),
          orElse: () => '22K (91.6%)',
        );
        _selectedPurity = matched;
      }

      _pendingGoldItems.removeAt(index);
    });

    _itemNameFocusNode.requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing "${item['item_name']}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // REMOVE PENDING GOLD ITEM
  // ============================================================

  void _removePendingGoldItem(int index) {
    if (_isSubmitting) {
      return;
    }

    final item = _pendingGoldItems[index];

    setState(() {
      _pendingGoldItems.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${item['item_name']}" removed',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // PERSIST PENDING GOLD ITEMS
  // ============================================================

  Future<List<int>> _persistPendingGoldItems() async {
    if (_itemNameCtrl.text.trim().isNotEmpty) {
      final weight = double.tryParse(_weightCtrl.text.trim());
      if (weight != null && weight > 0) {
        final cleanPurity = _selectedPurity.split(' ')[0];
        _pendingGoldItems.add({
          'customer_id': _selectedCustomerId,
          'item_name': _itemNameCtrl.text.trim(),
          'purity': cleanPurity,
          'purity_display': _selectedPurity,
          'weight': weight,
          'remarks': _remarksCtrl.text.trim(),
          'photo_url': _uploadedPhotoUrl,
          'id': null,
        });
        _clearCurrentGoldForm();
      }
    }

    if (_pendingGoldItems.isEmpty) {
      throw Exception('Please add at least one gold item first');
    }

    final provider = context.read<GoldProvider>();
    final List<int> savedGoldItemIds = [];

    for (int i = 0; i < _pendingGoldItems.length; i++) {
      final goldItem = _pendingGoldItems[i];

      if (goldItem['id'] != null && (goldItem['id'] as int) > 0) {
        savedGoldItemIds.add(goldItem['id'] as int);
        continue;
      }

      final item = await provider.addGoldItem({
        'customer_id': _selectedCustomerId,
        'item_name': goldItem['item_name'],
        'purity': goldItem['purity'],
        'weight': goldItem['weight'],
        'remarks': goldItem['remarks'],
        'photo_url': goldItem['photo_url'],
      });

      if (item != null) {
        goldItem['id'] = item.id;
        savedGoldItemIds.add(item.id);
      } else {
        throw Exception(
          provider.errorMessage ?? 'Failed to save gold item',
        );
      }
    }

    return savedGoldItemIds;
  }

  // ============================================================
  // SAVE ALL GOLD ITEMS (OPTION 1: SAVE FOR LATER)
  // ============================================================

  Future<void> _handleSaveAllGold() async {
    if (_isSubmitting) return;

    if (_selectedCustomerId == null || _selectedCustomerId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final savedIds = await _persistPendingGoldItems();

      if (!mounted) return;

      SuccessDialog.show(
        context: context,
        title: 'Gold Items Saved Successfully',
        message: 'Gold items saved successfully.',
        okLabel: 'OK',
        onOk: () {
          if (widget.customerId != null && widget.customerId! > 0) {
            Navigator.of(context).pop({
              'action': 'saved',
              'goldItemIds': savedIds,
              'customerId': _selectedCustomerId,
            });
          } else {
            Navigator.of(context).pop(true);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.statusDanger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // CREATE LOAN / NEXT (OPTION 2: CREATE LOAN IMMEDIATELY)
  // ============================================================

  Future<void> _handleCreateLoanNext() async {
    if (_isSubmitting) return;

    if (_selectedCustomerId == null || _selectedCustomerId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final savedIds = await _persistPendingGoldItems();

      if (!mounted) return;

      if (widget.customerId != null && widget.customerId! > 0) {
        Navigator.of(context).pop({
          'action': 'next',
          'goldItemIds': savedIds,
          'customerId': _selectedCustomerId,
        });
      } else if (_selectedCustomerId != null && _selectedCustomerId! > 0) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CustomerProfileScreen(
              customerId: _selectedCustomerId!,
              autoOpenNewLoanWithGoldIds: savedIds,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.statusDanger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // PENDING ITEMS SECTION
  // ============================================================

  Widget _buildPendingGoldItems() {
    if (_pendingGoldItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.silverLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.silverBorder,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: AppTheme.silverDark,
            ),
            SizedBox(height: 8),
            Text(
              'No gold items added yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.silverDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Enter a gold item above and tap ADD GOLD.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.silverDark,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.goldPrimary,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary
                  .withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2,
                  size: 19,
                  color: AppTheme.goldDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gold Items to Save',
                    style:
                        GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkNavy,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_pendingGoldItems.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ListView.separated(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: _pendingGoldItems.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1),
            itemBuilder: (context, index) {
              final item =
                  _pendingGoldItems[index];

              final weight =
                  item['weight'] as double;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.goldPrimary
                            .withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.diamond_outlined,
                        size: 20,
                        color: AppTheme.goldDark,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['item_name']
                                .toString(),
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  AppTheme.darkNavy,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _smallItemTag(
                                item['purity_display']
                                        ?.toString() ??
                                    item['purity']
                                        .toString(),
                              ),
                              _smallItemTag(
                                '${weight.toStringAsFixed(3)} g',
                              ),
                            ],
                          ),

                          if (item['remarks']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item['remarks']
                                  .toString(),
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color:
                                    AppTheme.silverDark,
                              ),
                            ),
                          ],

                          if (item['photo_url']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons
                                      .photo_camera_outlined,
                                  size: 13,
                                  color:
                                      AppTheme.goldDark,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Photo attached',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme
                                        .goldDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit item',
                          onPressed: _isSubmitting
                              ? null
                              : () => _editPendingGoldItem(index),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: _isSubmitting
                              ? null
                              : () => _removePendingGoldItem(index),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppTheme.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL TAG
  // ============================================================

  Widget _smallItemTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkNavy,
        ),
      ),
    );
  }

  // ============================================================
  // TOTAL WEIGHT
  // ============================================================

  double get _totalPendingWeight {
    double total = 0;

    for (final item in _pendingGoldItems) {
      final weight = item['weight'];

      if (weight is num) {
        total += weight.toDouble();
      }
    }

    return total;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1200;

    final double maxWidth = isMobile
        ? double.infinity
        : isTablet
            ? 760
            : 1050;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
        width: double.infinity,
        height: isMobile ? MediaQuery.of(context).size.height : null,
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.94,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 0 : 12,
          vertical: isMobile ? 0 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isMobile ? 0 : 16,
          ),
          boxShadow: isMobile
              ? const []
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResponsiveHeader(isMobile),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isMobile
                      ? 14
                      : isTablet
                          ? 20
                          : 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      if (widget.customerId == null)
                        _buildCustomerSearchResponsive(
                          isMobile,
                        ),

                      if (widget.customerId == null)
                        const SizedBox(height: 14),

                      if (_selectedCustomerId != null)
                        _buildSelectedCustomerResponsive(
                          isMobile,
                        ),

                      if (isMobile)
                        _buildMobileGoldForm()
                      else if (isTablet)
                        _buildTabletGoldForm()
                      else
                        _buildDesktopGoldForm(),

                      const SizedBox(height: 18),

                      _buildPendingGoldItems(),

                      if (_pendingGoldItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTotalSection(isMobile),
                      ],

                      const SizedBox(height: 20),

                      _buildFinalButtons(
                        isMobile,
                        isTablet,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Add all gold items first. They will be saved together when you tap SAVE ALL GOLD.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.silverDark,
                        ),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildResponsiveHeader(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 24,
        vertical: mobile ? 13 : 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            mobile ? 0 : 16,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: mobile ? 38 : 42,
            height: mobile ? 38 : 42,
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.diamond,
              color: AppTheme.darkNavy,
              size: mobile ? 19 : 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add Gold Collateral Items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.close,
              color: Colors.white70,
            ),
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  Widget _buildCustomerSearchResponsive(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customerSearchCtrl,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Search Customer *',
            hintText: 'Name / Customer Code / Mobile',
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.goldDark,
            ),
          ),
          onChanged: _searchCustomer,
        ),
        if (_showCustomerResults)
          Container(
            margin: const EdgeInsets.only(top: 5),
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppTheme.silverBorder,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filteredCustomers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No customers found',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer =
                          _filteredCustomers[index];

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          leading: const Icon(
                            Icons.person_outline,
                            color: AppTheme.goldDark,
                          ),
                          title: Text(
                            customer.name.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${customer.customerCode} • ${customer.mobile}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: _isSubmitting
                              ? null
                              : () => _selectCustomer(
                                    customer,
                                  ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  // ============================================================
  // SELECTED CUSTOMER
  // ============================================================

  Widget _buildSelectedCustomerResponsive(bool mobile) {
    String infoText = 'Customer selected';
    if (_customerSearchCtrl.text.trim().isNotEmpty) {
      infoText = _customerSearchCtrl.text.trim();
    } else if (_selectedCustomerId != null) {
      infoText = 'Customer ID: $_selectedCustomerId';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 12,
        vertical: 10,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.goldPrimary.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.goldPrimary.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_pin_rounded,
            size: 20,
            color: AppTheme.goldDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIRMED CUSTOMER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppTheme.goldDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  infoText,
                  maxLines: 2,
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
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle,
            size: 20,
            color: Color(0xFF065F46),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE FORM
  // ============================================================

  Widget _buildMobileGoldForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImagePickerWidget(
          uploadType: 'gold',
          label: 'Gold Item Photo (Camera / Gallery)',
          onImageUploaded: (url) {
            setState(() {
              _uploadedPhotoUrl = url;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildItemNameField(),
        const SizedBox(height: 14),
        _buildPurityField(),
        const SizedBox(height: 14),
        _buildWeightField(),
        const SizedBox(height: 14),
        _buildRemarksField(),
        const SizedBox(height: 14),
        _buildAddGoldButton(),
      ],
    );
  }

  // ============================================================
  // TABLET FORM
  // ============================================================

  Widget _buildTabletGoldForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImagePickerWidget(
          uploadType: 'gold',
          label: 'Gold Item Photo (Camera / Gallery)',
          onImageUploaded: (url) {
            setState(() {
              _uploadedPhotoUrl = url;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildItemNameField(),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPurityField(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildWeightField(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildRemarksField(),
        const SizedBox(height: 14),
        _buildAddGoldButton(),
      ],
    );
  }

  // ============================================================
  // DESKTOP FORM
  // ============================================================

  Widget _buildDesktopGoldForm() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: ImagePickerWidget(
            uploadType: 'gold',
            label: 'Gold Item Photo (Camera / Gallery)',
            onImageUploaded: (url) {
              setState(() {
                _uploadedPhotoUrl = url;
              });
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildItemNameField(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPurityField(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildWeightField(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildRemarksField(),
              const SizedBox(height: 14),
              _buildAddGoldButton(),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ITEM NAME
  // ============================================================

  Widget _buildItemNameField() {
    return RawAutocomplete<String>(
      textEditingController: _itemNameCtrl,
      focusNode: _itemNameFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _goldItemSuggestions.where((option) {
          return option.toLowerCase().contains(query);
        });
      },
      onSelected: (String selection) {
        _itemNameCtrl.text = selection;
        _itemNameCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.length),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Item Name / Description *',
            hintText: 'e.g. Ring, Chain, Necklace, Bangles',
            prefixIcon: Icon(
              Icons.shopping_bag_outlined,
              color: AppTheme.goldDark,
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Item name is required';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.silverBorder),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.silverBorder),
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      option,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PURITY
  // ============================================================

  Widget _buildPurityField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPurity,
      decoration: const InputDecoration(
        labelText: 'Purity *',
        prefixIcon: Icon(
          Icons.verified_outlined,
          color: AppTheme.goldDark,
        ),
      ),
      items: _purityOptions.map((purity) {
        return DropdownMenuItem<String>(
          value: purity,
          child: Text(
            purity,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
      onChanged: _isSubmitting
          ? null
          : (value) {
              setState(() {
                _selectedPurity =
                    value ?? '22K (91.6%)';
              });
            },
    );
  }

  // ============================================================
  // WEIGHT
  // ============================================================

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightCtrl,
      enabled: !_isSubmitting,
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: const InputDecoration(
        labelText: 'Gross Weight (Grams) *',
        hintText: 'e.g. 30.500',
        suffixText: 'g',
        prefixIcon: Icon(
          Icons.scale,
          color: AppTheme.goldDark,
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Weight is required';
        }

        final value =
            double.tryParse(val.trim());

        if (value == null || value <= 0) {
          return 'Enter valid weight';
        }

        return null;
      },
    );
  }

  // ============================================================
  // REMARKS
  // ============================================================

  Widget _buildRemarksField() {
    return TextFormField(
      controller: _remarksCtrl,
      enabled: !_isSubmitting,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText:
            'Remarks / Hallmark / Stone Details (Optional)',
        hintText:
            'e.g. 916 Hallmarked with CZ stone deduction 0.2g',
        prefixIcon: Icon(
          Icons.notes,
          color: AppTheme.silverDark,
        ),
      ),
    );
  }

  // ============================================================
  // ADD GOLD
  // ============================================================

  Widget _buildAddGoldButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting
            ? null
            : _addGoldToList,
        icon: const Icon(
          Icons.add_circle_outline,
          size: 20,
        ),
        label: const Text(
          'ADD GOLD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkNavy,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
      ),
    );
  }

  // ============================================================
  // TOTAL
  // ============================================================

  Widget _buildTotalSection(bool mobile) {
    if (mobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.goldPrimary.withValues(
            alpha: 0.10,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.goldPrimary.withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Column(
          children: [
            _totalRow(
              'Total Items',
              '${_pendingGoldItems.length}',
            ),
            const SizedBox(height: 8),
            _totalRow(
              'Total Weight',
              '${_totalPendingWeight.toStringAsFixed(3)} g',
              highlight: true,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.goldPrimary.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.goldPrimary.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _totalRow(
              'Total Items',
              '${_pendingGoldItems.length}',
            ),
          ),
          Expanded(
            child: _totalRow(
              'Total Weight',
              '${_totalPendingWeight.toStringAsFixed(3)} g',
              highlight: true,
              end: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    bool highlight = false,
    bool end = false,
  }) {
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight
                ? AppTheme.goldDark
                : AppTheme.darkNavy,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FINAL BUTTONS
  // ============================================================

  Widget _buildFinalButtons(
    bool mobile,
    bool tablet,
  ) {
    final bool hasItemsToProcess =
        _pendingGoldItems.isNotEmpty || _itemNameCtrl.text.trim().isNotEmpty;

    final cancelButton = OutlinedButton(
      onPressed: _isSubmitting
          ? null
          : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          mobile ? double.infinity : 100,
          46,
        ),
        side: const BorderSide(color: AppTheme.silverBorder),
      ),
      child: const Text(
        'CANCEL',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.darkNavy,
        ),
      ),
    );

    final saveOnlyButton = OutlinedButton.icon(
      onPressed: _isSubmitting || !hasItemsToProcess
          ? null
          : _handleSaveAllGold,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text(
        'SAVE ALL GOLD',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.goldDark,
        side: const BorderSide(color: AppTheme.goldPrimary, width: 1.5),
        minimumSize: Size(mobile ? double.infinity : 150, 46),
      ),
    );

    final createLoanNextButton = ElevatedButton.icon(
      onPressed: _isSubmitting || !hasItemsToProcess
          ? null
          : _handleCreateLoanNext,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.arrow_forward, size: 18),
      label: Text(
        _isSubmitting ? 'SAVING...' : 'CREATE LOAN / NEXT',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.goldDark,
        foregroundColor: Colors.white,
        minimumSize: Size(mobile ? double.infinity : 180, 46),
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 46, child: createLoanNextButton),
          const SizedBox(height: 9),
          SizedBox(height: 46, child: saveOnlyButton),
          const SizedBox(height: 9),
          SizedBox(height: 46, child: cancelButton),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(height: 46, child: cancelButton),
        const SizedBox(width: 10),
        SizedBox(height: 46, child: saveOnlyButton),
        const SizedBox(width: 10),
        SizedBox(height: 46, child: createLoanNextButton),
      ],
    );
  }
}
