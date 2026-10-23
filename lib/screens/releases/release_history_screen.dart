// lib/screens/releases/release_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/release.dart';
import '../../providers/release_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/a4_receipt_viewer.dart';
import 'partial_release_screen.dart';

class ReleaseHistoryScreen extends StatefulWidget {
  final Function(int tab, {Map<String, dynamic>? initialParams})?
      onNavigate;

  const ReleaseHistoryScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<ReleaseHistoryScreen> createState() =>
      _ReleaseHistoryScreenState();
}

class _ReleaseHistoryScreenState
    extends State<ReleaseHistoryScreen> {
  final ScrollController _tableScrollCtrl = ScrollController();
  final ScrollController _mobileScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReleaseProvider>().fetchReleases();
      }
    });
  }

  @override
  void dispose() {
    _tableScrollCtrl.dispose();
    _mobileScrollCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // NEW PARTIAL RELEASE
  // ============================================================

  Future<void> _openPartialReleaseModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(12),
        child: PartialReleaseScreen(),
      ),
    );

    if (result == true && mounted) {
      context.read<ReleaseProvider>().fetchReleases();
    }
  }

  // ============================================================
  // PRINT RECEIPT
  // ============================================================

  Future<void> _printReceipt(
    PartialRelease release,
  ) async {
    try {
      final receipt = await ApiService.getReceipt(
        receiptNo: release.releaseNo,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => A4ReceiptViewer(
          receiptData: receipt.rawData,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Receipt error: $e',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
  }

  // ============================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================

  bool _isMobile(double width) {
    return width < 700;
  }

  bool _isTablet(double width) {
    return width >= 700 && width < 1100;
  }

  bool _isDesktop(double width) {
    return width >= 1100;
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReleaseProvider>();
    final releases = provider.releases;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final mobile = _isMobile(width);
            final tablet = _isTablet(width);
            final desktop = _isDesktop(width);

            final horizontalPadding = mobile
                ? 12.0
                : tablet
                    ? 16.0
                    : 20.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: mobile ? 12 : 16,
              ),
              child: Column(
                children: [
                  _buildTopBar(
                    mobile: mobile,
                    tablet: tablet,
                    desktop: desktop,
                  ),

                  SizedBox(
                    height: mobile ? 12 : 16,
                  ),

                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.goldPrimary,
                            ),
                          )
                        : releases.isEmpty
                            ? _buildEmptyState()
                            : mobile
                                ? _buildMobileCards(releases)
                                : _buildResponsiveTable(
                                    releases,
                                    tablet: tablet,
                                    desktop: desktop,
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar({
    required bool mobile,
    required bool tablet,
    required bool desktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 18,
        vertical: mobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          mobile ? 12 : 14,
        ),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                     Icon(
                      Icons.lock_open,
                      color: AppTheme.goldDark,
                      size: 22,
                    ),
                     SizedBox(width: 10),
                     Expanded(
                      child: Text(
                        'Gold Release Records',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed:
                        _openPartialReleaseModal,
                    icon: const Icon(
                      Icons.lock_open,
                      size: 18,
                    ),
                    label: const Text(
                      'New Partial Release',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.goldPrimary,
                      foregroundColor:
                          AppTheme.darkNavy,
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.lock_open,
                  color: AppTheme.goldDark,
                  size: 24,
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Gold Release Records',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed:
                        _openPartialReleaseModal,
                    icon: const Icon(
                      Icons.lock_open,
                      size: 18,
                    ),
                    label: Text(
                      tablet
                          ? 'New Release'
                          : 'New Partial Release',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.goldPrimary,
                      foregroundColor:
                          AppTheme.darkNavy,
                      padding:
                          EdgeInsets.symmetric(
                        horizontal:
                            tablet ? 14 : 18,
                      ),
                    ),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
      ),
      child: const Center(
        child: Text(
          'No gold releases on record',
          style: TextStyle(
            color: AppTheme.silverDark,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESPONSIVE TABLE
  // ============================================================

  Widget _buildResponsiveTable(
    List<PartialRelease> releases, {
    required bool tablet,
    required bool desktop,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            _buildTableHeader(
              tablet: tablet,
              desktop: desktop,
            ),

            Expanded(
              child: Scrollbar(
                controller: _tableScrollCtrl,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _tableScrollCtrl,
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: releases.length,
                  itemBuilder: (context, index) {
                    return _buildTableRow(
                      releases[index],
                      tablet: tablet,
                      desktop: desktop,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader({
    required bool tablet,
    required bool desktop,
  }) {
    final fontSize = tablet ? 12.0 : 13.0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 58,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 10 : 12,
        vertical: 10,
      ),
      color: AppTheme.silverLight,
      child: Row(
        children: [
          _headerCell(
            'Release No',
            flex: 15,
            fontSize: fontSize,
          ),

          _headerCell(
            'Loan No',
            flex: 11,
            fontSize: fontSize,
          ),

          _headerCell(
            'Customer',
            flex: 15,
            fontSize: fontSize,
          ),

          _headerCell(
            'Release Date & Time',
            flex: 16,
            fontSize: fontSize,
          ),

          _headerCell(
            'Weight Released',
            flex: 12,
            fontSize: fontSize,
          ),

          _headerCell(
            'Payment Attached',
            flex: 12,
            fontSize: fontSize,
          ),

          _headerCell(
            'Release Type',
            flex: 11,
            fontSize: fontSize,
          ),

          _headerCell(
            'Remarks',
            flex: 8,
            fontSize: fontSize,
          ),

          _headerCell(
            'Actions',
            flex: 7,
            fontSize: fontSize,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER CELL
  // ============================================================

  Widget _headerCell(
    String text, {
    required int flex,
    required double fontSize,
    Alignment alignment =
        Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign:
                alignment == Alignment.center
                    ? TextAlign.center
                    : TextAlign.left,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              color: AppTheme.darkNavy,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLE ROW
  // ============================================================

  Widget _buildTableRow(
    PartialRelease release, {
    required bool tablet,
    required bool desktop,
  }) {
    final fontSize = tablet ? 11.5 : 12.5;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 72,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 10 : 12,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.black,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          // RELEASE NO
          _dataCell(
            Text(
              release.releaseNo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                color: AppTheme.darkNavy,
              ),
            ),
            flex: 17,
          ),

          // LOAN NO
          _dataCell(
            Text(
              release.loanNo ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
              ),
            ),
            flex: 11,
          ),

          // CUSTOMER
          _dataCell(
            Text(
              '${release.customerName ?? 'Customer'}\n'
              '(${release.customerCode ?? ''})',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.25,
              ),
            ),
            flex: 16,
          ),

          // DATE
          _dataCell(
            Text(
              '${AppConstants.formatDate(release.releaseDate)}\n'
              '${AppConstants.formatTime(release.releaseTime)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.25,
              ),
            ),
            flex: 18,
          ),

          // WEIGHT
          _dataCell(
            Text(
              AppConstants.formatWeight(
                release.totalWeightReleased,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                color: AppTheme.goldDark,
              ),
            ),
            flex: 13,
          ),

          // PAYMENT
          _dataCell(
            Text(
              release.paymentAmount != null
                  ? AppConstants.formatCurrency(
                      release.paymentAmount,
                    )
                  : 'None',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
              ),
            ),
            flex: 12,
          ),

          // RELEASE TYPE
          _dataCell(
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: release.releaseType == 'FULL RELEASE'
                    ? const Color(0xFFECFDF5)
                    : AppTheme.silverLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: release.releaseType == 'FULL RELEASE'
                      ? const Color(0xFF059669)
                      : AppTheme.silverBorder,
                ),
              ),
              child: Text(
                release.releaseType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.bold,
                  color: release.releaseType == 'FULL RELEASE'
                      ? const Color(0xFF065F46)
                      : AppTheme.darkNavy,
                ),
              ),
            ),
            flex: 11,
          ),

          // REMARKS
          _dataCell(
            Text(
              release.remarks ?? '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: AppTheme.silverDark,
              ),
            ),
            flex: 8,
          ),

          // ACTION
          Expanded(
            flex: 7,
            child: Center(
              child: IconButton(
                tooltip: 'Print Release Receipt',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                icon: Icon(
                  Icons.print,
                  size: tablet ? 17 : 19,
                  color: AppTheme.darkNavy,
                ),
                onPressed: () =>
                    _printReceipt(release),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA CELL
  // ============================================================

  Widget _dataCell(
    Widget child, {
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
        ),
        child: child,
      ),
    );
  }

  // ============================================================
  // MOBILE CARDS
  // ============================================================

  Widget _buildMobileCards(
    List<PartialRelease> releases,
  ) {
    return Scrollbar(
      controller: _mobileScrollCtrl,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _mobileScrollCtrl,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: 12,
        ),
        itemCount: releases.length,
        itemBuilder: (context, index) {
          final r = releases[index];

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.silverBorder,
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // TOP
                  // ------------------------------------------------

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.releaseNo,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 14,
                            color:
                                AppTheme.darkNavy,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        tooltip:
                            'Print Release Receipt',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(
                          Icons.print,
                          size: 20,
                          color:
                              AppTheme.darkNavy,
                        ),
                        onPressed: () =>
                            _printReceipt(r),
                      ),
                    ],
                  ),

                  const Divider(height: 12),

                  // ------------------------------------------------
                  // LOAN
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Loan No',
                    value: r.loanNo ?? '-',
                  ),

                  const SizedBox(height: 8),

                  // ------------------------------------------------
                  // CUSTOMER
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Customer',
                    value:
                        '${r.customerName ?? 'Customer'} '
                        '(${r.customerCode ?? ''})',
                  ),

                  const SizedBox(height: 8),

                  // ------------------------------------------------
                  // DATE
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Release Date',
                    value:
                        '${AppConstants.formatDate(r.releaseDate)} '
                        '${AppConstants.formatTime(r.releaseTime)}',
                  ),

                  const SizedBox(height: 8),

                  // ------------------------------------------------
                  // WEIGHT
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Weight Released',
                    value:
                        AppConstants.formatWeight(
                      r.totalWeightReleased,
                    ),
                    valueStyle:
                        const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldDark,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ------------------------------------------------
                  // PAYMENT
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Payment Attached',
                    value:
                        r.paymentAmount != null
                            ? AppConstants
                                .formatCurrency(
                                r.paymentAmount,
                              )
                            : 'None',
                  ),

                  const SizedBox(height: 8),

                  // ------------------------------------------------
                  // REMARKS
                  // ------------------------------------------------

                  _mobileInfoRow(
                    label: 'Remarks',
                    value: r.remarks ?? '-',
                    valueStyle:
                        const TextStyle(
                      color: AppTheme.silverDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // MOBILE INFO ROW
  // ============================================================

  Widget _mobileInfoRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.silverDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkNavy,
                ),
          ),
        ),
      ],
    );
  }
}