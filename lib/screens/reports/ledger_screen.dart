// lib/screens/reports/ledger_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/transaction.dart';
import '../../providers/report_provider.dart';
import '../../services/api_service.dart';
import '../../services/ledger_print_service.dart';
import '../../widgets/gold_badge.dart';
import '../../widgets/module_header.dart';

class LedgerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const LedgerScreen({
    super.key,
    this.onBack,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  String _selectedType = 'ALL';
  String _selectedStaffId = 'ALL';
  DateTime? _fromDate;
  DateTime? _toDate;

  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic> _kpiSummary = {};
  bool _isLoadingKpi = false;

  int _currentPage = 1;
  int _rowsPerPage = 25;

  num _toNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString().trim()) ?? 0;
  }

  final List<Map<String, String>> _txTypes = [
    {'code': 'ALL', 'label': 'All Event Types'},
    {'code': 'CUSTOMER_CREATED', 'label': 'Customer Created'},
    {'code': 'GOLD_ITEM_ADDED', 'label': 'Gold Item Added'},
    {'code': 'SILVER_ITEM_ADDED', 'label': 'Silver Item Added'},
    {'code': 'LOAN_CREATED', 'label': 'Loan Created'},
    {'code': 'LOAN_UPDATED', 'label': 'Loan Updated'},
    {'code': 'LOAN_CLOSED', 'label': 'Loan Closed'},
    {'code': 'PARTIAL_PAYMENT', 'label': 'Partial Payment'},
    {'code': 'INTEREST_PAYMENT', 'label': 'Interest Payment'},
    {'code': 'FULL_PAYMENT', 'label': 'Full Payment'},
    {'code': 'FINAL_SETTLEMENT', 'label': 'Final Settlement'},
    {'code': 'GOLD_RELEASED', 'label': 'Gold Released'},
    {'code': 'MANUAL_LEDGER_ENTRY', 'label': 'Manual Ledger Entry'},
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchStaffList();
      _fetchLedger();
      _fetchKpiSummary();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _fetchStaffList() async {
    try {
      final staff = await ApiService.getCentralLedgerStaff();
      if (staff.isNotEmpty && mounted) {
        setState(() {
          _staffList = staff;
        });
      } else {
        final users = await ApiService.getUsers();
        if (mounted) {
          setState(() {
            _staffList = users;
          });
        }
      }
    } catch (_) {}
  }

  void _fetchLedger() {
    final fromStr = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
    final toStr = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;

    context.read<ReportProvider>().fetchLedger(
          type: _selectedType == 'ALL' ? null : _selectedType,
          startDate: fromStr,
          endDate: toStr,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );

    _fetchKpiSummary();
  }

  Future<void> _fetchKpiSummary() async {
    if (_isLoadingKpi) return;
    setState(() => _isLoadingKpi = true);

    try {
      final fromStr = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;

      final summaryRes = await ApiService.getCentralLedgerStaffSummary(
        staffId: _selectedStaffId == 'ALL' ? null : _selectedStaffId,
        fromDate: fromStr,
        toDate: toStr,
      );

      if (mounted) {
        setState(() {
          _kpiSummary = summaryRes['summary'] ?? {};
          _isLoadingKpi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKpi = false);
    }
  }

  // ============================================================
  // STAFF ATTRIBUTION HELPERS
  // ============================================================

  String _getStaffName(LoanTransaction t) {
    if (t.staffName != null && t.staffName!.trim().isNotEmpty && t.staffName != 'Historical / Not Recorded') {
      return t.staffName!.trim();
    }
    if (t.createdBy != null && t.createdBy!.trim().isNotEmpty && t.createdBy != 'STAFF') {
      return t.createdBy!.trim();
    }
    return 'Historical / Not Recorded';
  }

  String _getStaffId(LoanTransaction t) {
    if (t.staffId != null && t.staffId!.trim().isNotEmpty && t.staffId != 'null') {
      final sId = t.staffId!.trim();
      if (sId.startsWith('STF-')) return sId;
      if (RegExp(r'^\d+$').hasMatch(sId)) {
        return 'STF-${sId.padLeft(3, '0')}';
      }
      return sId;
    }
    final name = _getStaffName(t).toLowerCase();
    for (int i = 0; i < _staffList.length; i++) {
      final u = _staffList[i];
      final uName = (u['full_name'] ?? u['name'] ?? u['username'] ?? '').toString().toLowerCase();
      if (uName.isNotEmpty && (uName.contains(name) || name.contains(uName))) {
        final idNum = u['id'] ?? u['staff_id'] ?? (i + 1);
        return 'STF-${idNum.toString().padLeft(3, '0')}';
      }
    }
    return 'STF-001';
  }

  String _getStaffRole(LoanTransaction t) {
    if (t.staffRole != null && t.staffRole!.trim().isNotEmpty && t.staffRole != 'N/A') {
      return t.staffRole!.trim().toUpperCase();
    }
    final name = _getStaffName(t).toLowerCase();
    for (final u in _staffList) {
      final uName = (u['full_name'] ?? u['name'] ?? u['username'] ?? '').toString().toLowerCase();
      if (uName.isNotEmpty && (uName.contains(name) || name.contains(uName))) {
        return (u['role'] ?? u['staff_role'] ?? 'STAFF').toString().toUpperCase();
      }
    }
    return 'STAFF';
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty || name.contains('Historical')) return 'ST';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // ============================================================
  // FILTERING TRANSACTIONS
  // ============================================================

  List<LoanTransaction> _getFilteredTransactions(List<LoanTransaction> rawList) {
    return rawList.where((t) {
      // 1. Search Query
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final code = t.transactionCode.toLowerCase();
        final loanNo = (t.loanNo ?? '').toLowerCase();
        final cust = (t.customerName ?? '').toLowerCase();
        final custCode = (t.customerCode ?? '').toLowerCase();
        final sName = _getStaffName(t).toLowerCase();
        final sId = _getStaffId(t).toLowerCase();
        final remarks = (t.remarks ?? '').toLowerCase();

        if (!code.contains(q) &&
            !loanNo.contains(q) &&
            !cust.contains(q) &&
            !custCode.contains(q) &&
            !sName.contains(q) &&
            !sId.contains(q) &&
            !remarks.contains(q)) {
          return false;
        }
      }

      // 2. Staff Filter
      if (_selectedStaffId != 'ALL') {
        final staffId = _getStaffId(t);
        final staffName = _getStaffName(t);

        bool matches = false;
        if (staffId == _selectedStaffId || staffName == _selectedStaffId) {
          matches = true;
        } else {
          for (final u in _staffList) {
            final uIdStr = u['id']?.toString() ?? u['staff_id']?.toString() ?? '';
            final uName = (u['full_name'] ?? u['name'] ?? '').toString();
            if (uIdStr == _selectedStaffId || uName == _selectedStaffId) {
              if (staffName.toLowerCase() == uName.toLowerCase() || staffId.contains(uIdStr)) {
                matches = true;
                break;
              }
            }
          }
        }
        if (!matches) return false;
      }

      // 3. Event Type Filter
      if (_selectedType != 'ALL') {
        final typeUpper = t.transactionType.toUpperCase();
        final selUpper = _selectedType.toUpperCase();
        if (typeUpper != selUpper && !typeUpper.contains(selUpper) && !selUpper.contains(typeUpper)) {
          return false;
        }
      }

      // 4. Date Range Filter
      if (_fromDate != null || _toDate != null) {
        final txDate = DateTime.tryParse(t.date);
        if (txDate != null) {
          if (_fromDate != null && txDate.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
            return false;
          }
          if (_toDate != null && txDate.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59))) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
      });
      _fetchLedger();
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
      _fetchLedger();
    }
  }

  // ============================================================
  // EXPORT & PRINT
  // ============================================================

  Future<void> _printLedger() async {
    final provider = context.read<ReportProvider>();
    final txs = _getFilteredTransactions(provider.ledgerTransactions);

    try {
      await LedgerPrintService.printLedger(
        transactions: txs,
        search: _searchCtrl.text.trim(),
        transactionType: _selectedType,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _exportCsv(List<LoanTransaction> txs) {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Tx Code,Event Type,Staff Name,Staff ID,Customer,Loan No,Amount (INR),Weight (g),Date & Time,Remarks');

      for (final t in txs) {
        final amount = t.amount > 0 ? t.amount.toStringAsFixed(2) : '0.00';
        final weight = t.weight > 0 ? t.weight.toStringAsFixed(3) : '0.000';
        final staffName = _getStaffName(t).replaceAll(',', ' ');
        final staffId = _getStaffId(t).replaceAll(',', ' ');
        final customer = '${t.customerName ?? 'Customer'} (${t.customerCode ?? ''})'.replaceAll(',', ' ');
        final loanNo = (t.loanNo ?? '-').replaceAll(',', ' ');
        final remarks = (t.remarks ?? '-').replaceAll('\n', ' ').replaceAll(',', ' ');
        final dt = '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}';

        buffer.writeln('${t.transactionCode},${t.transactionType},$staffName,$staffId,"$customer",$loanNo,$amount,$weight,"$dt","$remarks"');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ledger exported successfully (${txs.length} records)'),
          backgroundColor: const Color(0xFF065F46),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ============================================================
  // TRANSACTION DETAILS DIALOG
  // ============================================================

  Future<void> _showTransactionDetailsDialog(LoanTransaction t) async {
    Map<String, dynamic>? detailedRes;
    try {
      detailedRes = await ApiService.getCentralLedgerTransactionDetails(t.transactionCode);
    } catch (_) {}

    final txData = detailedRes?['transaction'] ?? {};
    final staffAttr = detailedRes?['staff_attribution'] ?? {};

    final staffName = staffAttr['staff_name'] ?? _getStaffName(t);
    final staffId = staffAttr['staff_id'] != null ? 'STF-${staffAttr['staff_id'].toString().padLeft(3, '0')}' : _getStaffId(t);
    final staffRole = staffAttr['staff_role'] ?? _getStaffRole(t);

    final creatorName = staffAttr['creator_name'] ?? txData['created_by_name'] ?? 'Historical / Not Recorded';
    final updaterName = staffAttr['updater_name'] ?? txData['updated_by_name'];
    final collectorName = staffAttr['collector_name'] ?? txData['collected_by_name'];
    final closerName = staffAttr['closer_name'] ?? txData['closed_by_name'];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 680,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppTheme.darkNavy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: AppTheme.goldPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.transactionCode,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Central Ledger Transaction & Staff Audit Details',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      GoldBadge(status: t.transactionType, fontSize: 10),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),

                // Body Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Staff Responsible Banner
                      Text('STAFF ATTRIBUTION', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.silverLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.silverBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.goldPrimary,
                                  child: Text(
                                    _getInitials(staffName),
                                    style: const TextStyle(color: AppTheme.darkNavy, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(staffName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkNavy)),
                                      const SizedBox(height: 2),
                                      Text('Role: $staffRole', style: const TextStyle(fontSize: 11, color: AppTheme.silverDark)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkNavy,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    staffId,
                                    style: const TextStyle(color: AppTheme.goldPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),

                            // Sub-attribution details if updated/closed/collected by another staff
                            if (creatorName != null || updaterName != null || collectorName != null || closerName != null) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  if (creatorName != null) _staffMiniChip('Original Creator', creatorName),
                                  if (updaterName != null) _staffMiniChip('Last Updater', updaterName),
                                  if (collectorName != null) _staffMiniChip('Collector', collectorName),
                                  if (closerName != null) _staffMiniChip('Closer', closerName),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Details Grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailItem('Customer Name', t.customerName ?? 'N/A'),
                                const SizedBox(height: 10),
                                _detailItem('Customer Code', t.customerCode ?? 'N/A'),
                                const SizedBox(height: 10),
                                _detailItem('Loan Number', t.loanNo ?? 'N/A'),
                                const SizedBox(height: 10),
                                _detailItem('Payment Mode', t.paymentMode ?? txData['payment_mode'] ?? 'CASH'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailItem('Amount', t.amount > 0 ? AppConstants.formatCurrency(t.amount) : 'N/A', isBold: true, color: const Color(0xFF065F46)),
                                const SizedBox(height: 10),
                                _detailItem('Gold Weight', t.weight > 0 ? AppConstants.formatWeight(t.weight) : 'N/A', isBold: true, color: AppTheme.goldDark),
                                const SizedBox(height: 10),
                                _detailItem('Date & Time', '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}'),
                                const SizedBox(height: 10),
                                _detailItem('Status', txData['transaction_status'] ?? 'SUCCESS', isBold: true, color: const Color(0xFF16A34A)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (t.remarks != null && t.remarks!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('REMARKS & NOTES', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.silverDark)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.silverLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.silverBorder),
                          ),
                          child: Text(
                            _sanitizeRemark(t.remarks),
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkNavy),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.silverLight,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldPrimary, foregroundColor: AppTheme.darkNavy),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _staffMiniChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 10, color: AppTheme.silverDark, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 10.5, color: AppTheme.darkNavy, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _detailItem(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.silverDark, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppTheme.darkNavy,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final rawTransactions = provider.ledgerTransactions;
    final filteredTxs = _getFilteredTransactions(rawTransactions);

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < mobileBreakpoint;
    final isTablet = width >= mobileBreakpoint && width < desktopBreakpoint;
    final isDesktop = width >= desktopBreakpoint;

    // Pagination calculations
    final totalRecords = filteredTxs.length;
    final totalPages = (totalRecords / _rowsPerPage).ceil().clamp(1, 9999);
    if (_currentPage > totalPages) _currentPage = totalPages;

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage < totalRecords) ? startIndex + _rowsPerPage : totalRecords;
    final paginatedTxs = (startIndex < totalRecords) ? filteredTxs.sublist(startIndex, endIndex) : <LoanTransaction>[];

    return Material(
      color: AppTheme.backgroundLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuleHeader(
            title: 'Central Financial & Collateral Transaction Ledger',
            subtitle: 'Complete audit trail of all financial disbursements, payments, collateral releases and staff activities.',
            icon: Icons.receipt_long,
            onBack: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 10 : isTablet ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SEARCH & FILTERS SECTION
                  _buildFilterControls(isMobile: isMobile, isTablet: isTablet),

                  const SizedBox(height: 14),

                  // 2. STAFF MONITORING KPI SUMMARY CARDS
                  _buildStaffKpiCards(filteredTxs, isMobile: isMobile, isTablet: isTablet),

                  const SizedBox(height: 16),

                  // 3. MAIN TRANSACTION TABLE OR CARDS
                  provider.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.goldPrimary),
                          ),
                        )
                      : paginatedTxs.isEmpty
                          ? _buildEmptyState()
                          : isDesktop || isTablet
                              ? _buildDesktopTable(paginatedTxs)
                              : _buildMobileCards(paginatedTxs),

                  if (totalRecords > 0) ...[
                    const SizedBox(height: 14),
                    _buildPaginationBar(totalRecords, totalPages, startIndex, endIndex, isMobile: isMobile),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CONTROLS SECTION
  // ============================================================

  Widget _buildFilterControls({required bool isMobile, required bool isTablet}) {
    // Unique staff options loaded dynamically
    final Map<String, String> staffOptions = {'ALL': 'All Staff'};
    for (final u in _staffList) {
      final name = (u['full_name'] ?? u['name'] ?? u['username'] ?? '').toString().trim();
      final idVal = u['id'] ?? u['staff_id'];
      final code = (idVal != null && idVal.toString().isNotEmpty) ? (idVal.toString().startsWith('STF-') ? idVal.toString() : 'STF-${idVal.toString().padLeft(3, '0')}') : 'STF-001';
      if (name.isNotEmpty) {
        staffOptions[idVal?.toString() ?? name] = '$name ($code)';
      }
    }

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.silverBorder, width: 0.8),
        ),
        child: Column(
          children: [
            _buildSearchInput(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildStaffDropdown(staffOptions)),
                const SizedBox(width: 8),
                Expanded(child: _buildEventTypeDropdown()),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDatePickerBtn('From Date', _fromDate, _selectFromDate, () { setState(() => _fromDate = null); _fetchLedger(); })),
                const SizedBox(width: 8),
                Expanded(child: _buildDatePickerBtn('To Date', _toDate, _selectToDate, () { setState(() => _toDate = null); _fetchLedger(); })),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printLedger,
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<String>(
                    onSelected: (val) {
                      final provider = context.read<ReportProvider>();
                      final txs = _getFilteredTransactions(provider.ledgerTransactions);
                      if (val == 'csv') _exportCsv(txs);
                      if (val == 'print') _printLedger();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.description, size: 16), SizedBox(width: 8), Text('Export CSV')])),
                      const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, size: 16), SizedBox(width: 8), Text('Print PDF')])),
                    ],
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.goldPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download, size: 16, color: AppTheme.darkNavy),
                          SizedBox(width: 4),
                          Text('Export', style: TextStyle(color: AppTheme.darkNavy, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: _buildSearchInput()),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildStaffDropdown(staffOptions)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildEventTypeDropdown()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDatePickerBtn('From Date', _fromDate, _selectFromDate, () { setState(() => _fromDate = null); _fetchLedger(); })),
              const SizedBox(width: 10),
              Expanded(child: _buildDatePickerBtn('To Date', _toDate, _selectToDate, () { setState(() => _toDate = null); _fetchLedger(); })),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _printLedger,
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (val) {
                  final provider = context.read<ReportProvider>();
                  final txs = _getFilteredTransactions(provider.ledgerTransactions);
                  if (val == 'csv') _exportCsv(txs);
                  if (val == 'print') _printLedger();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.description, size: 16), SizedBox(width: 8), Text('Export CSV')])),
                  const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, size: 16), SizedBox(width: 8), Text('Print PDF')])),
                ],
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.download, size: 16, color: AppTheme.darkNavy),
                      SizedBox(width: 6),
                      Text('Export', style: TextStyle(color: AppTheme.darkNavy, fontWeight: FontWeight.bold, fontSize: 12)),
                      Icon(Icons.arrow_drop_down, color: AppTheme.darkNavy),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchCtrl,
      maxLines: 1,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Search transaction, loan, customer or staff...',
        hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.silverDark),
        prefixIcon: const Icon(Icons.search, color: AppTheme.silverDark, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                  _fetchLedger();
                },
              )
            : null,
      ),
      onChanged: (_) {
        setState(() {});
        _fetchLedger();
      },
    );
  }

  Widget _buildStaffDropdown(Map<String, String> staffOptions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.silverBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: staffOptions.containsKey(_selectedStaffId) ? _selectedStaffId : 'ALL',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.silverDark),
          items: staffOptions.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedStaffId = val;
            });
            _fetchLedger();
          },
        ),
      ),
    );
  }

  Widget _buildEventTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.silverBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.silverDark),
          items: _txTypes.map((item) {
            return DropdownMenuItem<String>(
              value: item['code'],
              child: Text(
                item['label']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedType = val;
            });
            _fetchLedger();
          },
        ),
      ),
    );
  }

  Widget _buildDatePickerBtn(String label, DateTime? value, VoidCallback onTap, VoidCallback onClear) {
    final text = value != null ? DateFormat('dd/MM/yyyy').format(value) : label;
    final hasValue = value != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: hasValue ? AppTheme.goldPrimary : AppTheme.silverBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 15, color: hasValue ? AppTheme.goldDark : AppTheme.silverDark),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.w500,
                  color: hasValue ? AppTheme.darkNavy : AppTheme.silverDark,
                ),
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: AppTheme.silverDark),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STAFF MONITORING KPI CARDS
  // ============================================================

  Widget _buildStaffKpiCards(List<LoanTransaction> txs, {required bool isMobile, required bool isTablet}) {
    final activeStaffSet = <String>{};
    int customersAdded = _toNum(_kpiSummary['customers_added']).toInt();
    int goldAdded = _toNum(_kpiSummary['gold_items_added']).toInt();
    int loansCreated = _toNum(_kpiSummary['loans_created']).toInt();
    int loansClosed = _toNum(_kpiSummary['loans_closed']).toInt();
    double amountDisbursed = _toNum(_kpiSummary['total_loan_amount_disbursed']).toDouble();
    double totalCollection = _toNum(_kpiSummary['total_payments_collected']).toDouble();

    // Local fallback computation if KPI summary from backend is still loading
    if (_kpiSummary.isEmpty) {
      for (final t in txs) {
        activeStaffSet.add(_getStaffName(t));

        final type = t.transactionType.toUpperCase();
        if (type == 'CUSTOMER_CREATED' || type == 'LOAN_CREATED' || type == 'EXISTING_LOAN_CREATED') {
          customersAdded++;
        }
        if (type == 'GOLD_ITEM_ADDED' || t.weight > 0) {
          goldAdded++;
        }
        if (type == 'LOAN_CREATED' || type == 'EXISTING_LOAN_CREATED' || type == 'ADDITIONAL_LOAN') {
          loansCreated++;
          amountDisbursed += t.amount;
        }
        if (type == 'LOAN_CLOSED') {
          loansClosed++;
        }
        if (type.contains('PAYMENT') || type.contains('SETTLEMENT') || type.contains('INTEREST') || type.contains('RELEASE')) {
          totalCollection += t.amount;
        }
      }
    } else {
      for (final t in txs) {
        activeStaffSet.add(_getStaffName(t));
      }
    }

    final activeStaffCount = _selectedStaffId == 'ALL' ? (activeStaffSet.isEmpty ? 1 : activeStaffSet.length) : 1;

    final cards = [
      _kpiBox('Active Staff', activeStaffCount.toString(), Icons.badge_outlined, AppTheme.goldDark),
      _kpiBox('Customers Added', customersAdded.toString(), Icons.person_add_alt_1_outlined, const Color(0xFF2563EB)),
      _kpiBox('Gold Items Added', goldAdded.toString(), Icons.diamond_outlined, const Color(0xFFD97706)),
      _kpiBox('Loans Created', loansCreated.toString(), Icons.add_card_outlined, const Color(0xFF059669)),
      _kpiBox('Loans Closed', loansClosed.toString(), Icons.lock_clock_outlined, const Color(0xFF64748B)),
      _kpiBox('Disbursed', AppConstants.formatCurrency(amountDisbursed), Icons.arrow_upward_rounded, const Color(0xFFDC2626)),
      _kpiBox('Collection', AppConstants.formatCurrency(totalCollection), Icons.arrow_downward_rounded, const Color(0xFF16A34A)),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: cards.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 130, child: c))).toList(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cardWidth = (constraints.maxWidth - (6 * 10)) / 7;
        if (cardWidth < 120) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards.map((c) => Padding(padding: const EdgeInsets.only(right: 10), child: SizedBox(width: 140, child: c))).toList(),
            ),
          );
        }
        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: c))).toList(),
        );
      },
    );
  }

  Widget _kpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.silverDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.silverBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.silverDark),
            const SizedBox(height: 12),
            Text(
              'No ledger records found',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.darkNavy, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search query, staff filter, event type, or date range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.silverDark, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP TABLE
  // ============================================================

  Widget _buildDesktopTable(List<LoanTransaction> transactions) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.silverBorder, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.silverLight),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 68,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Tx Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Event Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Staff ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Loan No', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: transactions.map((t) {
                  final amount = _toNum(t.amount);
                  final weight = _toNum(t.weight);
                  final staffName = _getStaffName(t);
                  final staffId = _getStaffId(t);

                  return DataRow(
                    cells: [
                      // 1. Tx Code
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            t.transactionCode,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy, fontSize: 12),
                          ),
                        ),
                      ),

                      // 2. Event Type
                      DataCell(GoldBadge(status: t.transactionType, fontSize: 9)),

                      // 3. Staff Name
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.goldLight,
                              child: Text(
                                _getInitials(staffName),
                                style: const TextStyle(color: AppTheme.goldDark, fontWeight: FontWeight.bold, fontSize: 9),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 110,
                              child: Text(
                                staffName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.darkNavy),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Staff ID
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.darkNavyLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            staffId,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldPrimary),
                          ),
                        ),
                      ),

                      // 5. Customer
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            '${t.customerName ?? 'Customer'} (${t.customerCode ?? ''})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),

                      // 6. Loan No
                      DataCell(Text(t.loanNo ?? '-', style: const TextStyle(fontSize: 12))),

                      // 7. Amount
                      DataCell(
                        Text(
                          amount > 0 ? AppConstants.formatCurrency(amount) : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: amount > 0 ? const Color(0xFF065F46) : Colors.black,
                          ),
                        ),
                      ),

                      // 8. Weight
                      DataCell(
                        Text(
                          weight > 0 ? AppConstants.formatWeight(weight) : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: weight > 0 ? AppTheme.goldDark : Colors.black,
                          ),
                        ),
                      ),

                      // 9. Date & Time
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),

                      // 10. Remarks
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(
                            _sanitizeRemark(t.remarks),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.silverDark, fontSize: 11),
                          ),
                        ),
                      ),

                      // 11. Action (View Button)
                      DataCell(
                        InkWell(
                          onTap: () => _showTransactionDetailsDialog(t),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.goldPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.goldPrimary, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_red_eye_outlined, size: 14, color: AppTheme.darkNavy),
                                SizedBox(width: 4),
                                Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.darkNavy)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE CARDS VIEW
  // ============================================================

  Widget _buildMobileCards(List<LoanTransaction> transactions) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final t = transactions[index];
        final amount = _toNum(t.amount);
        final weight = _toNum(t.weight);
        final staffName = _getStaffName(t);
        final staffId = _getStaffId(t);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.silverBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.transactionCode,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkNavy),
                    ),
                  ),
                  GoldBadge(status: t.transactionType, fontSize: 8),
                ],
              ),
              const SizedBox(height: 8),

              // Staff Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.goldPrimary,
                    child: Text(_getInitials(staffName), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.darkNavy)),
                  ),
                  const SizedBox(width: 6),
                  Text('Staff: $staffName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.darkNavy)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.darkNavy, borderRadius: BorderRadius.circular(4)),
                    child: Text(staffId, style: const TextStyle(color: AppTheme.goldPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              _infoRow(Icons.person_outline, 'Customer', '${t.customerName ?? 'Customer'} (${t.customerCode ?? ''})'),
              const SizedBox(height: 4),
              _infoRow(Icons.account_balance_wallet_outlined, 'Loan', t.loanNo ?? '-'),
              const SizedBox(height: 4),
              _infoRow(Icons.calendar_today_outlined, 'Date', '${AppConstants.formatDate(t.date)} ${AppConstants.formatTime(t.time)}'),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _valueBox(
                      title: 'Amount',
                      value: amount > 0 ? AppConstants.formatCurrency(amount) : '-',
                      valueColor: amount > 0 ? const Color(0xFF065F46) : AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _valueBox(
                      title: 'Weight',
                      value: weight > 0 ? AppConstants.formatWeight(weight) : '-',
                      valueColor: weight > 0 ? AppTheme.goldDark : AppTheme.darkNavy,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showTransactionDetailsDialog(t),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                  label: const Text('View Detailed Log', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppTheme.goldPrimary),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PAGINATION BAR
  // ============================================================

  Widget _buildPaginationBar(int totalRecords, int totalPages, int startIndex, int endIndex, {required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.silverBorder),
      ),
      child: isMobile
          ? Column(
              children: [
                Text(
                  'Showing ${startIndex + 1} - $endIndex of $totalRecords',
                  style: const TextStyle(fontSize: 11, color: AppTheme.silverDark, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageBtn('|<', _currentPage > 1 ? () => setState(() => _currentPage = 1) : null),
                    _pageBtn('<', _currentPage > 1 ? () => setState(() => _currentPage--) : null),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Page $_currentPage of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    _pageBtn('>', _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
                    _pageBtn('>|', _currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows per page: ', style: TextStyle(fontSize: 12, color: AppTheme.silverDark)),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      items: [10, 25, 50, 100].map((r) => DropdownMenuItem<int>(value: r, child: Text('$r'))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _rowsPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Showing ${startIndex + 1} - $endIndex of $totalRecords records',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkNavy),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _pageBtn('|<', _currentPage > 1 ? () => setState(() => _currentPage = 1) : null),
                    const SizedBox(width: 4),
                    _pageBtn('Previous', _currentPage > 1 ? () => setState(() => _currentPage--) : null),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.goldPrimary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('Page $_currentPage of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.darkNavy)),
                    ),
                    const SizedBox(width: 8),
                    _pageBtn('Next', _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
                    const SizedBox(width: 4),
                    _pageBtn('>|', _currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _pageBtn(String label, VoidCallback? onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(36, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.silverDark),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.silverDark)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.darkNavy),
          ),
        ),
      ],
    );
  }

  Widget _valueBox({required String title, required String value, required Color valueColor}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: AppTheme.silverDark)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
