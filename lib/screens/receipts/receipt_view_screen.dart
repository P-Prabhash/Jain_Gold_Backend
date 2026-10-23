// lib/screens/receipts/receipt_view_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/loan.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';

class ReceiptViewScreen extends StatefulWidget {
  const ReceiptViewScreen({super.key});

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  final TextEditingController _receiptNoCtrl = TextEditingController();
  List<Loan> _loans = [];
  int? _selectedLoanId;
  String _selectedType = 'LOAN';
  bool _isLoading = false;
  Map<String, dynamic>? _loadedReceiptData;

  @override
  void initState() {
    super.initState();
    _fetchLoans();
  }

  @override
  void dispose() {
    _receiptNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLoans() async {
    final loans = await ApiService.getLoans();
    if (!mounted) return;
    setState(() => _loans = loans);
  }

  Future<void> _searchByReceiptNo() async {
    final no = _receiptNoCtrl.text.trim();
    if (no.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final receipt = await ApiService.getReceipt(receiptNo: no);
      if (!mounted) return;
      setState(() {
        _loadedReceiptData = receipt.rawData;
        _isLoading = false;
      });
      _openReceiptViewer(_loadedReceiptData!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt not found: $e')),
      );
    }
  }

  Future<void> _searchByLoanAndType() async {
    if (_selectedLoanId == null) return;

    // Find the selected loan so the UI never requests a CLOSURE
    // receipt for an ACTIVE loan.
    Loan? selectedLoan;
    for (final loan in _loans) {
      if (loan.id == _selectedLoanId) {
        selectedLoan = loan;
        break;
      }
    }

    final status = selectedLoan?.status.trim().toUpperCase() ?? '';

    if (_selectedType == 'CLOSURE' && status != 'CLOSED') {
      if (!mounted) return;

      setState(() {
        _selectedType = 'PAYMENT';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'ACTIVE'
                ? 'This loan is ACTIVE. Closure receipt is available only after full settlement. Payment Receipt selected.'
                : 'Closure receipt is available only for a CLOSED/SETTLED loan. Payment Receipt selected.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final receipt = await ApiService.getReceipt(
        loanId: _selectedLoanId,
        type: _selectedType,
      );

      if (!mounted) return;

      setState(() {
        _loadedReceiptData = receipt.rawData;
        _isLoading = false;
      });

      _openReceiptViewer(_loadedReceiptData!);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt retrieval failed: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _openReceiptViewer(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => A4ReceiptViewer(receiptData: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1200;

        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isMobile ? 10 : isTablet ? 16 : 20,
                isMobile ? 10 : 16,
                isMobile ? 10 : isTablet ? 16 : 20,
                isMobile ? 18 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isMobile),
                      SizedBox(height: isMobile ? 10 : 20),
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildReceiptSearchCard(isMobile),
                            const SizedBox(height: 10),
                            _buildLoanSearchCard(isMobile),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildReceiptSearchCard(isMobile),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLoanSearchCard(isMobile),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 38 : 44,
            height: isMobile ? 38 : 44,
            decoration: BoxDecoration(
              color: AppTheme.goldLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long,
              color: AppTheme.goldDark,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A4 Official Receipts Center',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Search, preview, and print official A4 government compliant receipts for Pawn Loans, Payments, Partial Releases, and Loan Closures.',
                  style: TextStyle(
                    color: AppTheme.silverDark,
                    fontSize: isMobile ? 10.5 : 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: child,
    );
  }

  Widget _buildReceiptSearchCard(bool isMobile) {
    return _card(
      isMobile: isMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Option 1: Search by Exact Receipt Number',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 13,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Enter the exact receipt number to retrieve the official receipt.',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: AppTheme.silverDark,
              height: 1.35,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 14),
          TextField(
            controller: _receiptNoCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (!_isLoading) {
                _searchByReceiptNo();
              }
            },
            decoration: const InputDecoration(
              labelText: 'Receipt Number',
              hintText: 'e.g. RCP-LN-..., RCP-PAY-..., REL-...',
              prefixIcon: Icon(
                Icons.pin,
                color: AppTheme.goldDark,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          SizedBox(
            width: double.infinity,
            height: isMobile ? 46 : 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _searchByReceiptNo,
              icon: _isLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.darkNavy,
                      ),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(
                _isLoading ? 'Retrieving...' : 'Retrieve Receipt',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldPrimary,
                foregroundColor: AppTheme.darkNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSearchCard(bool isMobile) {
    return _card(
      isMobile: isMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Option 2: Generate by Loan Account & Type',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 13,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Select a loan account and the receipt type you want to preview.',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: AppTheme.silverDark,
              height: 1.35,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 14),
          DropdownButtonFormField<int>(
            initialValue: _selectedLoanId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Loan Account',
              prefixIcon: Icon(
                Icons.monetization_on,
                color: AppTheme.goldDark,
              ),
            ),
            items: _loans.map((l) {
              return DropdownMenuItem<int>(
                value: l.id,
                child: Text(
                  '${l.loanNo} - ${l.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              Loan? selectedLoan;

              for (final loan in _loans) {
                if (loan.id == val) {
                  selectedLoan = loan;
                  break;
                }
              }

              final status =
                  selectedLoan?.status.trim().toUpperCase() ?? '';

              setState(() {
                _selectedLoanId = val;

                if (status == 'CLOSED') {
                  _selectedType = 'CLOSURE';
                } else if (_selectedType == 'CLOSURE') {
                  _selectedType = 'PAYMENT';
                }
              });
            },
          ),
          SizedBox(height: isMobile ? 10 : 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Receipt Type',
              prefixIcon: Icon(
                Icons.category,
                color: AppTheme.silverDark,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'LOAN',
                child: Text(
                  'Pawn Loan Pledge Receipt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'PAYMENT',
                child: Text(
                  'Payment Receipt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'PARTIAL_RELEASE',
                child: Text(
                  'Partial Release Receipt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'CLOSURE',
                child: Text(
                  'Loan Closure & Settlement Receipt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedType = val ?? 'LOAN');
            },
          ),
          SizedBox(height: isMobile ? 12 : 16),
          SizedBox(
            width: double.infinity,
            height: isMobile ? 46 : 44,
            child: ElevatedButton.icon(
              onPressed: (_isLoading || _selectedLoanId == null)
                  ? null
                  : _searchByLoanAndType,
              icon: _isLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.preview, size: 18),
              label: Text(
                _isLoading ? 'Loading...' : 'Open A4 Preview',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.darkNavy.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
