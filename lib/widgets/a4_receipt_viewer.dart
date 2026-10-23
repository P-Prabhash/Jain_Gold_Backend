// lib/widgets/a4_receipt_viewer.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/pdf_receipt_service.dart';

class A4ReceiptViewer extends StatelessWidget {
  final Map<String, dynamic> receiptData;
  final VoidCallback? onClose;

  const A4ReceiptViewer({
    super.key,
    required this.receiptData,
    this.onClose,
  });

  // ============================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1000;

  bool _isMobile(double width) {
    return width < mobileBreakpoint;
  }

  bool _isTablet(double width) {
    return width >= mobileBreakpoint &&
        width < tabletBreakpoint;
  }

  bool _isDesktop(double width) {
    return width >= tabletBreakpoint;
  }

  // ============================================================
  // SAFE NUMBER CONVERSION
  // ============================================================

  num _toNum(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  String _currency(dynamic value) {
    return AppConstants.formatCurrency(
      _toNum(value),
    );
  }

  String _weight(dynamic value) {
    return AppConstants.formatWeight(
      _toNum(value),
    );
  }

  // ============================================================
  // SAFE MAP / LIST HELPERS
  // ============================================================

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List _asList(dynamic value) {
    if (value is List) {
      return value;
    }

    return <dynamic>[];
  }

  // ============================================================
  // IMAGE HELPERS
  // ============================================================

  String? _getImageValue(dynamic item) {
    if (item is! Map) {
      return null;
    }

    final candidates = <dynamic>[
      item['photo_url'],
      item['photoUrl'],
      item['customer_photo_url'],
      item['customerPhotoUrl'],
      item['photo'],
      item['image_url'],
      item['imageUrl'],
      item['image'],
      item['customer_photo'],
      item['customerPhoto'],
    ];

    for (final value in candidates) {
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null' &&
          text.toLowerCase() != 'undefined') {
        return text;
      }
    }

    return null;
  }

  String? _resolveImageUrl(dynamic item) {
    final rawValue = _getImageValue(item);

    if (rawValue == null) {
      return null;
    }

    final raw = rawValue.trim();

    if (raw.isEmpty) {
      return null;
    }

    // Data image is not handled by Image.network.
    // Receipt images should normally be served by PHP
    // using an HTTP/HTTPS URL.
    if (raw.startsWith('data:image/')) {
      return null;
    }

    // Absolute URL.
    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      return raw;
    }

    final base = ApiService.baseUrl
        .trim()
        .replaceFirst(
          RegExp(r'/+$'),
          '',
        );

    if (base.isEmpty) {
      return raw;
    }

    // Root-relative path. PHP upload.php returns values such as
    // /uploads/customers/....jpg. They are relative to the PHP
    // backend, not the web server root.
    if (raw.startsWith('/')) {
      final parsedBase = Uri.tryParse(base);
      if (parsedBase != null && parsedBase.hasScheme && parsedBase.host.isNotEmpty) {
        final origin = '${parsedBase.scheme}://${parsedBase.authority}';
        final basePath = parsedBase.path.replaceFirst(RegExp(r'/+$'), '');
        if (basePath.isNotEmpty &&
            (raw == basePath || raw.startsWith('$basePath/'))) {
          return '$origin$raw';
        }
        return '$base$raw';
      }
      return '$base$raw';
    }

    // Relative path.
    return '$base/$raw';
  }

  Widget _imagePlaceholder({
    required double width,
    required double height,
    required bool broken,
    BorderRadius borderRadius =
        const BorderRadius.all(
      Radius.circular(5),
    ),
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        border: Border.all(
          color: AppTheme.silverBorder,
        ),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          broken
              ? Icons.broken_image_outlined
              : Icons.image_not_supported_outlined,
          color: AppTheme.silverDark,
          size: 22,
        ),
      ),
    );
  }

  Widget _receiptImage({
    required String? imageUrl,
    required double width,
    required double height,
    BorderRadius borderRadius =
        const BorderRadius.all(
      Radius.circular(5),
    ),
  }) {
    if (imageUrl == null ||
        imageUrl.trim().isEmpty) {
      return _imagePlaceholder(
        width: width,
        height: height,
        broken: false,
        borderRadius: borderRadius,
      );
    }

    final resolved = _resolveImageUrl({
      'photo_url': imageUrl,
    });

    if (resolved == null ||
        resolved.trim().isEmpty) {
      return _imagePlaceholder(
        width: width,
        height: height,
        broken: false,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppTheme.silverLight,
              border: Border.all(
                color: AppTheme.silverBorder,
              ),
              borderRadius: borderRadius,
            ),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value:
                      loadingProgress
                                  .expectedTotalBytes !=
                              null
                          ? loadingProgress
                                  .cumulativeBytesLoaded /
                              loadingProgress
                                  .expectedTotalBytes!
                          : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return _imagePlaceholder(
            width: width,
            height: height,
            broken: true,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  // ============================================================
  // MAIN VIEW
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final width = media.size.width;
    final height = media.size.height;

    final mobile = _isMobile(width);
    final tablet = _isTablet(width);
    final desktop = _isDesktop(width);

    if (mobile) {
      return _buildMobileViewer(
        context,
        width,
        height,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: tablet ? 14 : 24,
        vertical: tablet ? 14 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop
              ? 920
              : width - 28,
          maxHeight: height - 28,
        ),
        child: _buildViewerContainer(
          context,
          mobile: false,
          tablet: tablet,
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE FULL SCREEN
  // ============================================================

  Widget _buildMobileViewer(
    BuildContext context,
    double width,
    double height,
  ) {
    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: _buildViewerContainer(
          context,
          mobile: true,
          tablet: false,
        ),
      ),
    );
  }

  // ============================================================
  // VIEWER CONTAINER
  // ============================================================

  Widget _buildViewerContainer(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: mobile
            ? BorderRadius.zero
            : BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildToolbar(
            context,
            mobile: mobile,
            tablet: tablet,
          ),

          Expanded(
            child: Container(
              color: AppTheme.backgroundLight,
              child: Scrollbar(
                thumbVisibility: !mobile,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile
                        ? 8
                        : tablet
                            ? 16
                            : 24,
                    vertical: mobile
                        ? 8
                        : tablet
                            ? 16
                            : 24,
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: mobile
                            ? double.infinity
                            : tablet
                                ? 720
                                : 780,
                      ),
                      padding: EdgeInsets.all(
                        mobile
                            ? 10
                            : tablet
                                ? 18
                                : 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: AppTheme.silverBorder,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          mobile ? 6 : 8,
                        ),
                        boxShadow: mobile
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.07),
                                  blurRadius: 12,
                                  offset:
                                      const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: _buildA4Content(
                        context,
                        mobile: mobile,
                        tablet: tablet,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildToolbar(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 16,
        vertical: mobile ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: mobile
            ? BorderRadius.zero
            : const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long,
            color: AppTheme.goldPrimary,
            size: 20,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              'A4 Official Receipt Preview',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: mobile ? 13 : 15,
              ),
            ),
          ),

          const SizedBox(width: 4),

          if (mobile)
            IconButton(
              tooltip: 'Print Receipt',
              onPressed: () {
                PdfReceiptService.printReceipt(
                  receiptData,
                );
              },
              icon: const Icon(
                Icons.print,
                color: AppTheme.goldPrimary,
                size: 21,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                PdfReceiptService.printReceipt(
                  receiptData,
                );
              },
              icon: const Icon(
                Icons.print,
                size: 16,
                color: AppTheme.darkNavy,
              ),
              label: const Text(
                'Print Receipt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme.goldPrimary,
                foregroundColor:
                    AppTheme.darkNavy,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
              ),
            ),

          IconButton(
            tooltip: 'Close',
            onPressed: onClose ??
                () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // A4 CONTENT
  // ============================================================

  Widget _buildA4Content(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    final receiptType =
        (receiptData['receipt_type'] ??
                'PAYMENT')
            .toString()
            .toUpperCase();

    final customer = _asMap(
      receiptData['customer'],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildShopHeader(
          context,
          mobile: mobile,
          tablet: tablet,
        ),

        const SizedBox(height: 12),

        _buildReceiptBanner(
          mobile: mobile,
        ),

        const SizedBox(height: 12),

        _buildCustomerLoanSection(
          context,
          customer,
          mobile: mobile,
          tablet: tablet,
        ),

        const SizedBox(height: 16),

        if (receiptType == 'PAWN_LOAN' ||
            receiptType == 'LOAN' ||
            receiptType == 'ADDITIONAL_LOAN')
          _buildPawnLoanBody(
            mobile: mobile,
          )
        else if (receiptType == 'PAYMENT')
          _buildPaymentBody(
            mobile: mobile,
          )
        else if (receiptType == 'PARTIAL_RELEASE')
          _buildReleaseBody(
            mobile: mobile,
          )
        else if (receiptType == 'CLOSURE')
          _buildClosureBody(
            mobile: mobile,
          )
        else
          _buildGenericReceiptBody(
            mobile: mobile,
          ),

        const SizedBox(height: 22),

        _buildSignatures(
          mobile: mobile,
        ),
      ],
    );
  }

  // ============================================================
  // SHOP HEADER
  // ============================================================

  Widget _buildShopHeader(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    final shop = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'JAIN GOLD & PAWN SHOP',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cinzel(
            color: AppTheme.goldPrimary,
            fontSize: mobile ? 14 : 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 3),

        const Text(
          'Licensed Government Pawn Broker & Gold Financing ERP',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
          ),
        ),

        const SizedBox(height: 2),

        const Text(
          'Main Market Road, Commercial Complex | Ph: +91 98765 43210',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 8.5,
          ),
        ),
      ],
    );

    final date = Column(
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        const Text(
          'OFFICIAL RECEIPT',
          style: TextStyle(
            color: AppTheme.goldPrimary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),

        Text(
          'Date: ${receiptData['date'] ?? receiptData['opened_date'] ?? AppConstants.formatDate(DateTime.now().toIso8601String())}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
          ),
        ),

        Text(
          'Time: ${receiptData['time'] ?? '-'}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                shop,
                const SizedBox(height: 10),
                date,
              ],
            )
          : Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: shop,
                ),
                const SizedBox(width: 15),
                date,
              ],
            ),
    );
  }

  // ============================================================
  // RECEIPT BANNER
  // ============================================================

  Widget _buildReceiptBanner({
    required bool mobile,
  }) {
    final type =
        (receiptData['receipt_type'] ??
                'PAYMENT')
            .toString()
            .replaceAll('_', ' ');

    final receiptNo =
        receiptData['receipt_no'] ??
            '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(5),
        border: Border.all(
          color: AppTheme.goldPrimary,
        ),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Receipt No: $receiptNo',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 11,
                    color:
                        AppTheme.goldDark,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    type,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                      color:
                          AppTheme.darkNavy,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Flexible(
                  child: Text(
                    'Receipt No: $receiptNo',
                    textAlign:
                        TextAlign.right,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                      color:
                          AppTheme.goldDark,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // CUSTOMER + LOAN
  // ============================================================

  Widget _buildCustomerLoanSection(
    BuildContext context,
    Map<String, dynamic> customer, {
    required bool mobile,
    required bool tablet,
  }) {
    final customerPhoto =
        _resolveImageUrl(customer);

    final loan =
        _asMap(receiptData['loan']);

    final rawLoanType =
        (receiptData['loan_type'] ??
                loan['loan_type'] ??
                'NEW_LOAN')
            .toString()
            .toUpperCase();

    String loanType = '*';

    if (rawLoanType == 'EXISTING_LOAN') {
      loanType = '#';
    } else if (rawLoanType == 'ADDITIONAL_LOAN') {
      loanType = 'ADDITIONAL';
    }

    final customerSection = Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _receiptImage(
          imageUrl: customerPhoto,
          width: mobile ? 64 : 70,
          height: mobile ? 76 : 82,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'CUSTOMER DETAILS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      AppTheme.silverDark,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Name: ${customer['name'] ?? customer['full_name'] ?? '-'}',
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(
                'ID: ${customer['customer_code'] ?? customer['customerCode'] ?? customer['id'] ?? '-'}',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),

              Text(
                'Mobile: ${customer['mobile'] ?? customer['phone'] ?? '-'}',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),

              Text(
                'Address: ${customer['address'] ?? '-'}',
                maxLines: mobile ? 3 : 4,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final loanSection = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'LOAN DETAILS',
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                FontWeight.bold,
            color:
                AppTheme.silverDark,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'Loan No: ${receiptData['loan_no'] ?? loan['loan_no'] ?? '-'}',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.bold,
            color:
                AppTheme.darkNavy,
          ),
        ),

        const SizedBox(height: 4),

        Row(
          children: [
            const Text(
              'Type: ',
              style: TextStyle(
                fontSize: 11,
              ),
            ),

            Container(
              width: loanType == 'ADDITIONAL'
                  ? 72
                  : 30,
              height: 30,
              alignment:
                  Alignment.center,
              decoration: BoxDecoration(
                color:
                    AppTheme.silverLight,
                border: Border.all(
                  color:
                      AppTheme.goldPrimary,
                ),
                borderRadius:
                    BorderRadius.circular(5),
              ),
              child: Text(
                loanType,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      AppTheme.darkNavy,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Text(
          'Opened Date: ${receiptData['opened_date'] ?? receiptData['date'] ?? loan['opened_date'] ?? '-'}',
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
        borderRadius:
            BorderRadius.circular(5),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                customerSection,
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                loanSection,
              ],
            )
          : Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: customerSection,
                ),

                Container(
                  width: 1,
                  height:
                      tablet ? 100 : 92,
                  color:
                      AppTheme.silverBorder,
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: loanSection,
                ),
              ],
            ),
    );
  }

  // ============================================================
  // PAWN LOAN BODY
  // ============================================================

  Widget _buildPawnLoanBody({
    required bool mobile,
  }) {
    final loan = _asMap(receiptData['loan']);
    final financial = _asMap(receiptData['financial'] ?? receiptData['loan_financial']);

    List collateral = _asList(receiptData['collateral']);
    if (collateral.isEmpty) {
      collateral = _asList(receiptData['gold_items']);
    }

    double totalWeight = _toNum(receiptData['total_pledged_weight'] ?? financial['total_pledged_weight']).toDouble();
    if (totalWeight <= 0) {
      for (final item in collateral) {
        final itemMap = _asMap(item);
        totalWeight += _toNum(itemMap['pledged_weight'] ?? itemMap['weight'] ?? itemMap['gross_weight']).toDouble();
      }
    }

    final origPrincipal = _toNum(loan['original_principal'] ?? financial['original_principal']);
    final addAmount = _toNum(loan['additional_amount'] ?? financial['additional_amount']);
    final principal = _toNum(loan['principal_amount'] ?? financial['principal_amount'] ?? receiptData['principal_amount']);
    final totalInterest = _toNum(loan['total_interest'] ?? financial['total_interest'] ?? financial['initial_interest']);
    final totalDue = _toNum(loan['total_due'] ?? financial['total_due'] ?? (principal + totalInterest));
    final totalPaid = _toNum(loan['total_paid'] ?? financial['total_paid']);
    final remaining = _toNum(loan['remaining_balance'] ?? financial['remaining_balance'] ?? (totalDue - totalPaid));

    final financialRows = <List<String>>[];
    if (addAmount > 0) {
      financialRows.add(['Original Principal Amount', _currency(origPrincipal)]);
      financialRows.add(['Additional Top-up Amount', _currency(addAmount)]);
      financialRows.add(['Combined Principal Loan Amount', _currency(principal)]);
    } else {
      financialRows.add(['Principal Loan Amount', _currency(principal)]);
    }

    if (totalInterest > 0) {
      financialRows.add(['Interest Amount', _currency(totalInterest)]);
    }
    financialRows.add(['Total Due Amount', _currency(totalDue)]);
    if (totalPaid > 0) {
      financialRows.add(['Total Paid Amount', _currency(totalPaid)]);
    }
    financialRows.add(['REMAINING BALANCE', _currency(remaining)]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('PLEDGED GOLD ITEMS'),
        const SizedBox(height: 7),
        if (mobile) _buildItemCards(collateral) else _buildItemTable(collateral),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total Pledged Weight: ${_weight(totalWeight)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppTheme.darkNavy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _renderFinancialSummary(financialRows),
      ],
    );
  }

  // ============================================================
  // PAYMENT BODY
  // ============================================================

  Widget _buildPaymentBody({
    required bool mobile,
  }) {
    final payment = _asMap(receiptData['payment']);
    final financial = _asMap(
      receiptData['loan_financial'] ??
          receiptData['financial'] ??
          receiptData['payment'],
    );

    final principal = _toNum(
      financial['principal_amount'] ??
          receiptData['principal_amount'] ??
          receiptData['principal'],
    );

    final principalPayment = _toNum(
      financial['principal_payment_amount'] ??
          financial['principal_payment'] ??
          payment['principal_payment'] ??
          payment['amount'] ??
          receiptData['amount'] ??
          receiptData['current_payment'],
    );

    final manualInterest = _toNum(
      financial['manual_interest_collected'] ??
          financial['manual_interest'] ??
          payment['manual_interest'] ??
          receiptData['manual_interest'],
    );

    final totalReceived = _toNum(
      financial['total_amount_received'] ??
          payment['total_received'] ??
          receiptData['total_received'] ??
          (principalPayment + manualInterest),
    );

    final previousPaid = _toNum(
      financial['previous_paid_principal'] ??
          financial['previous_paid'] ??
          payment['previous_paid'] ??
          receiptData['previous_paid'],
    );

    final remaining = _toNum(
      financial['outstanding_principal_after'] ??
          financial['remaining_balance'] ??
          payment['remaining_balance'] ??
          receiptData['remaining_balance'],
    );

    return Column(
      children: [
        _renderFinancialSummary(
          [
            [
              'Principal Loan Amount',
              _currency(principal),
            ],
            [
              'Previously Paid Principal',
              _currency(previousPaid),
            ],
            [
              'Current Principal Payment',
              _currency(principalPayment),
            ],
            [
              'Additional Manual Interest',
              _currency(manualInterest),
            ],
            [
              'TOTAL AMOUNT RECEIVED',
              _currency(totalReceived),
            ],
            [
              'OUTSTANDING PRINCIPAL AFTER PAYMENT',
              _currency(remaining),
            ],
          ],
        ),

        const SizedBox(height: 12),

        _buildOutstandingBalance(
          remaining,
          mobile: mobile,
        ),
      ],
    );
  }

  // ============================================================
  // OUTSTANDING BALANCE
  // ============================================================

  Widget _buildOutstandingBalance(
    num remaining, {
    required bool mobile,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        border: Border.all(
          color: AppTheme.goldPrimary,
          width: 1.3,
        ),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'OUTSTANDING REMAINING BALANCE',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 11,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _currency(remaining),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 16,
                    color:
                        AppTheme.goldDark,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(
                  child: Text(
                    'OUTSTANDING REMAINING BALANCE',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                      color:
                          AppTheme.darkNavy,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  _currency(remaining),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 16,
                    color:
                        AppTheme.goldDark,
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // PARTIAL RELEASE
  // ============================================================

  Widget _buildReleaseBody({
    required bool mobile,
  }) {
    final released = _asList(
      receiptData['released_gold'],
    );

    final remaining = _asList(
      receiptData[
          'remaining_pledged_gold'],
    );

    final financial = _asMap(
      receiptData['financial'],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'ITEMS RELEASED THIS TRANSACTION',
          color: AppTheme.goldDark,
        ),

        const SizedBox(height: 7),

        if (mobile)
          _buildItemCards(
            released,
          )
        else
          _buildItemTable(
            released,
          ),

        const SizedBox(height: 12),

        _sectionTitle(
          'REMAINING PLEDGED COLLATERAL',
        ),

        const SizedBox(height: 7),

        if (mobile)
          _buildItemCards(
            remaining,
          )
        else
          _buildItemTable(
            remaining,
          ),

        const SizedBox(height: 12),

        _renderFinancialSummary(
          [
            [
              'Previous Total Paid',
              _currency(
                financial[
                    'previous_paid'],
              ),
            ],
            [
              'Payment Received For Release',
              _currency(
                financial[
                    'current_payment'],
              ),
            ],
            [
              'New Total Paid',
              _currency(
                financial[
                    'total_paid'],
              ),
            ],
            [
              'REMAINING BALANCE',
              _currency(
                financial[
                    'remaining_balance'],
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ============================================================
  // CLOSURE
  // ============================================================

  Widget _buildClosureBody({
    required bool mobile,
  }) {
    final financial = _asMap(
      receiptData['financial'],
    );

    final gold =
        _asMap(receiptData['gold']);

    List releasedItems = _asList(
      gold['released_items'],
    );

    if (releasedItems.isEmpty) {
      releasedItems = _asList(
        receiptData['collateral'],
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _renderFinancialSummary(
          [
            [
              'Original Principal Amount',
              _currency(
                financial[
                    'principal_amount'],
              ),
            ],
            [
              'Previous Monthly Interest',
              _currency(
                financial[
                    'previous_interest'],
              ),
            ],
            [
              'Manual Final Interest Applied',
              _currency(
                financial[
                    'manual_final_interest'],
              ),
            ],
            [
              'Final Settlement Total',
              _currency(
                financial[
                    'final_settlement_amount'],
              ),
            ],
            [
              'Total Amount Paid',
              _currency(
                financial[
                    'total_paid'],
              ),
            ],
            [
              'Final Payment Received',
              _currency(
                financial[
                    'final_payment'],
              ),
            ],
            [
              'REMAINING BALANCE',
              '₹0.00 (PAID IN FULL)',
            ],
          ],
        ),

        const SizedBox(height: 12),

        _sectionTitle(
          'COLLATERAL RELEASED AT CLOSURE',
        ),

        const SizedBox(height: 7),

        if (mobile)
          _buildItemCards(
            releasedItems,
          )
        else
          _buildItemTable(
            releasedItems,
          ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Gold Released at Closure: ${_weight(gold['gold_released_at_closure'])}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 10),

            const Flexible(
              child: Text(
                'Remaining Pledged Gold: 0.000g',
                textAlign:
                    TextAlign.right,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      AppTheme.darkNavy,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.darkNavy,
            borderRadius:
                BorderRadius.circular(6),
          ),
          child: const Text(
            'LOAN CLOSED | ALL GOLD COLLATERAL RELEASED IN FULL',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppTheme.goldPrimary,
              fontWeight:
                  FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GENERIC RECEIPT
  // ============================================================

  Widget _buildGenericReceiptBody({
    required bool mobile,
  }) {
    final collateral = _asList(
      receiptData['collateral'],
    );

    if (collateral.isEmpty) {
      return _renderFinancialSummary(
        [
          [
            'Amount',
            _currency(
              receiptData['amount'],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'GOLD ITEMS',
        ),

        const SizedBox(height: 7),

        if (mobile)
          _buildItemCards(
            collateral,
          )
        else
          _buildItemTable(
            collateral,
          ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title, {
    Color color = AppTheme.darkNavy,
  }) {
    return Text(
      title,
      maxLines: 2,
      overflow:
          TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight:
            FontWeight.bold,
        color: color,
      ),
    );
  }

  // ============================================================
  // DESKTOP / TABLET ITEM TABLE
  // ============================================================

  Widget _buildItemTable(
    List items,
  ) {
    if (items.isEmpty) {
      return _emptyItems();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
        borderRadius:
            BorderRadius.circular(4),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(62),
          1: FlexColumnWidth(3.2),
          2: FlexColumnWidth(1.3),
        },
        border:
            const TableBorder.symmetric(
          inside: BorderSide(
            color:
                AppTheme.silverBorder,
          ),
        ),
        children: [
          const TableRow(
            decoration: BoxDecoration(
              color:
                  AppTheme.silverLight,
            ),
            children: [
              Padding(
                padding:
                    EdgeInsets.all(6),
                child: Text(
                  'Photo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.all(6),
                child: Text(
                  'Item Name',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.all(6),
                child: Text(
                  'Weight',
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          ...items.map(
            (item) {
              final imageUrl =
                  _resolveImageUrl(
                item,
              );

              final itemName =
                  item['item_name']
                          ?.toString() ??
                      item['itemName']
                          ?.toString() ??
                      item['name']
                          ?.toString() ??
                      '-';

              final weight =
                  _weight(
                item['weight'] ??
                    item['pledged_weight'] ??
                    item['pledgedWeight'],
              );

              return TableRow(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.all(
                      5,
                    ),
                    child: _receiptImage(
                      imageUrl:
                          imageUrl,
                      width: 48,
                      height: 48,
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.all(
                      6,
                    ),
                    child: Text(
                      itemName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.all(
                      6,
                    ),
                    child: Text(
                      weight,
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE GOLD ITEM CARDS
  // ============================================================

  Widget _buildItemCards(
    List items,
  ) {
    if (items.isEmpty) {
      return _emptyItems();
    }

    return Column(
      children: items.map(
        (item) {
          final imageUrl =
              _resolveImageUrl(
            item,
          );

          final itemName =
              item['item_name']
                      ?.toString() ??
                  item['itemName']
                      ?.toString() ??
                  item['name']
                      ?.toString() ??
                  '-';

          final weight =
              _weight(
            item['weight'] ??
                item['pledged_weight'] ??
                item['pledgedWeight'],
          );

          return Container(
            width: double.infinity,
            margin:
                const EdgeInsets.only(
              bottom: 7,
            ),
            padding:
                const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color:
                    AppTheme.silverBorder,
              ),
              borderRadius:
                  BorderRadius.circular(5),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _receiptImage(
                  imageUrl: imageUrl,
                  width: 72,
                  height: 72,
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      _mobileItemValue(
                        'Weight',
                        weight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _emptyItems() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(5),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: const Text(
        'No items',
        style: TextStyle(
          fontSize: 11,
          color:
              AppTheme.silverDark,
        ),
      ),
    );
  }

  Widget _mobileItemValue(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color:
                AppTheme.silverDark,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FINANCIAL SUMMARY
  // ============================================================

  Widget _renderFinancialSummary(
    List<List<String>> pairs,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color:
            AppTheme.silverLight,
        borderRadius:
            BorderRadius.circular(5),
        border: Border.all(
          color:
              AppTheme.silverBorder,
        ),
      ),
      child: Column(
        children: pairs.map(
          (pair) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 3,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      pair.isNotEmpty
                          ? pair[0]
                          : '',
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 10.5,
                        color:
                            AppTheme.darkNavy,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    flex: 4,
                    child: Text(
                      pair.length > 1
                          ? pair[1]
                          : '',
                      textAlign:
                          TextAlign.right,
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            AppTheme.darkNavy,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // SIGNATURES + GENERATED FOOTER
  // ============================================================

  Widget _buildSignatures({
    required bool mobile,
  }) {
    final customer =
        _signatureBlock(
      'Customer Signature / Thumb',
    );

    final cashier =
        _signatureBlock(
      'Authorized Cashier',
    );

    final generatedDate =
        receiptData[
                    'generated_date']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? receiptData[
                'generated_date']
            .toString()
        : AppConstants.formatDate(
            DateTime.now()
                .toIso8601String(),
          );

    final generatedTime =
        receiptData[
                    'generated_time']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? receiptData[
                'generated_time']
            .toString()
        : _currentTime();

    return Column(
      children: [
        if (mobile)
          Column(
            children: [
              customer,
              const SizedBox(
                height: 24,
              ),
              cashier,
            ],
          )
        else
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              customer,
              cashier,
            ],
          ),

        const SizedBox(
          height: 14,
        ),

        const Divider(
          color:
              AppTheme.silverBorder,
        ),

        const SizedBox(height: 6),

        Wrap(
          alignment:
              WrapAlignment.center,
          spacing: 18,
          runSpacing: 4,
          children: [
            Text(
              'Generated Date: $generatedDate',
              style:
                  const TextStyle(
                fontSize: 8,
                color:
                    AppTheme.silverDark,
              ),
            ),

            Text(
              'Generated Time: $generatedTime',
              style:
                  const TextStyle(
                fontSize: 8,
                color:
                    AppTheme.silverDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        const Text(
          'Computer generated authoritative ERP receipt. Subject to terms & conditions.',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            fontSize: 7.5,
            color:
                AppTheme.silverDark,
          ),
        ),
      ],
    );
  }

  String _currentTime() {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Widget _signatureBlock(
    String label,
  ) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 1,
          color: Colors.black54,
        ),

        const SizedBox(height: 4),

        Text(
          label,
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            fontSize: 9.5,
            color:
                AppTheme.silverDark,
          ),
        ),
      ],
    );
  }
}