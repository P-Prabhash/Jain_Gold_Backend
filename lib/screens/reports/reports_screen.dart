import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../widgets/gold_badge.dart';
import 'ledger_screen.dart';

class ReportsScreen extends StatefulWidget {
  final Function(
    int tab, {
    Map<String, dynamic>? initialParams,
  })? onNavigate;

  const ReportsScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState
    extends State<ReportsScreen> {
  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  bool _isMobile(double width) =>
      width < mobileBreakpoint;

  bool _isTablet(double width) =>
      width >= mobileBreakpoint &&
      width < desktopBreakpoint;

  bool _isDesktop(double width) =>
      width >= desktopBreakpoint;

  num _toNum(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value;
    }

    return num.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) return;

      context
          .read<ReportProvider>()
          .fetchReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<ReportProvider>();

    final data =
        provider.reportsData;

    final loansSummary =
        data['loans_summary'] as List? ??
            [];

    final paymentsSummary =
        data['payments_summary'] as List? ??
            [];

    final goldInventory =
        data['gold_inventory'] as List? ??
            [];

    final topOutstanding =
        data['top_outstanding_customers']
                as List? ??
            [];

    final width =
        MediaQuery.of(context).size.width;

    final mobile =
        _isMobile(width);

    final tablet =
        _isTablet(width);

    final desktop =
        _isDesktop(width);

    return Scaffold(
      backgroundColor:
          AppTheme.backgroundLight,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            mobile
                ? 10
                : tablet
                    ? 14
                    : 20,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildTopBanner(
                context,
                mobile: mobile,
                tablet: tablet,
              ),

              SizedBox(
                height: mobile
                    ? 12
                    : 18,
              ),

              if (provider.isLoading)
                const Padding(
                  padding:
                      EdgeInsets.all(40),
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppTheme.goldPrimary,
                    ),
                  ),
                )
              else if (desktop)
                _buildDesktopGrid(
                  loansSummary,
                  paymentsSummary,
                  goldInventory,
                  topOutstanding,
                )
              else if (tablet)
                _buildTabletGrid(
                  loansSummary,
                  paymentsSummary,
                  goldInventory,
                  topOutstanding,
                )
              else
                _buildMobileLayout(
                  loansSummary,
                  paymentsSummary,
                  goldInventory,
                  topOutstanding,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BANNER
  // ============================================================

  Widget _buildTopBanner(
    BuildContext context, {
    required bool mobile,
    required bool tablet,
  }) {
    if (mobile) {
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
                const Icon(
                  Icons.bar_chart,
                  color:
                      AppTheme.goldDark,
                  size: 22,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Financial Reports & Business Intelligence',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        GoogleFonts
                            .plusJakartaSans(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            const Text(
              'Live aggregated metrics directly calculated by MySQL engine',
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color:
                    AppTheme.silverDark,
              ),
            ),

            const SizedBox(height: 11),

            SizedBox(
              width: double.infinity,
              child: Column(
                children: [

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(

                      onPressed: () {

                        Navigator.push(

                          context,

                          MaterialPageRoute(

                            builder: (_) =>
                                const LedgerScreen(),

                          ),

                        );

                      },

                      icon: const Icon(
                        Icons.menu_book,
                        size: 18,
                      ),

                      label: const Text(
                        'View Central Ledger',
                      ),

                    ),
                  ),


                  const SizedBox(height:10),


                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(

                      onPressed: _printReport,

                      icon: const Icon(
                        Icons.print,
                        size:18,
                      ),

                      label: const Text(
                        'Print Report',
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

    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.all(
        tablet ? 13 : 16,
      ),
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
          const Icon(
            Icons.bar_chart,
            color:
                AppTheme.goldDark,
            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Reports & Business Intelligence',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        tablet ? 14 : 15,
                  ),
                ),

                const SizedBox(height: 2),

                const Text(
                  'Live aggregated metrics directly calculated by MySQL engine',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const LedgerScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.menu_book,
              size: 18,
            ),
            label: const Text(
              'View Central Ledger',
            ),

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.darkNavy,
              foregroundColor:
                  Colors.white,
            ),

          ),

          const SizedBox(width:10),

          OutlinedButton.icon(

            onPressed: _printReport,

            icon: const Icon(
              Icons.print,
              size:18,
            ),

            label: const Text(
              'Print Report',
            ),

          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRINT REPORT
  // ============================================================

  Future<void> _printReport() async {
    final provider = context.read<ReportProvider>();
    final data = provider.reportsData;

    final loans = data['loans_summary'] is List
        ? List<dynamic>.from(data['loans_summary'])
        : <dynamic>[];

    final payments = data['payments_summary'] is List
        ? List<dynamic>.from(data['payments_summary'])
        : <dynamic>[];

    final gold = data['gold_inventory'] is List
        ? List<dynamic>.from(data['gold_inventory'])
        : <dynamic>[];

    final outstanding = data['top_outstanding_customers'] is List
        ? List<dynamic>.from(data['top_outstanding_customers'])
        : <dynamic>[];

    try {
      await Printing.layoutPdf(
        name: 'Gold_Silver_Pawn_Financial_Report.pdf',
        format: PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();

          final generatedAt = DateTime.now();
          final generatedDate =
              '${generatedAt.day.toString().padLeft(2, '0')}/'
              '${generatedAt.month.toString().padLeft(2, '0')}/'
              '${generatedAt.year}';
          final generatedTime =
              '${generatedAt.hour.toString().padLeft(2, '0')}:'
              '${generatedAt.minute.toString().padLeft(2, '0')}:'
              '${generatedAt.second.toString().padLeft(2, '0')}';

          String currency(dynamic value) {
            return AppConstants.formatCurrency(_toNum(value));
          }

          String weight(dynamic value) {
            return AppConstants.formatWeight(_toNum(value));
          }

          pw.Widget pdfSectionTitle(String title) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              color: const PdfColor.fromInt(0xFF0F172A),
              child: pw.Text(
                title,
                style: const pw.TextStyle(
                  color:  PdfColor.fromInt(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }

          pw.Widget pdfRow(
            String label,
            String subLabel,
            String value,
          ) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFFE5E7EB),
                    width: 0.5,
                  ),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      label,
                      maxLines: 2,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      subLabel,
                      maxLines: 2,
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColor.fromInt(0xFF64748B),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      value,
                      textAlign: pw.TextAlign.right,
                      maxLines: 2,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color:  PdfColor.fromInt(0xFFAA7C11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          pw.Widget pdfCard(String title, List<pw.Widget> children) {
            return pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFCBD5E1),
                  width: 0.6,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfSectionTitle(title),
                  ...children,
                ],
              ),
            );
          }

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
              header: (_) => pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0F172A),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'GOLD & SILVER PAWN LOAN MANAGEMENT ERP',
                          style: const pw.TextStyle(
                            color:  PdfColor.fromInt(0xFFD4AF37),
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'FINANCIAL REPORT & BUSINESS INTELLIGENCE',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'OFFICIAL REPORT',
                      style: const pw.TextStyle(
                        color:  PdfColor.fromInt(0xFFD4AF37),
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              footer: (context) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated: $generatedDate  $generatedTime',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
              build: (context) => [
                pw.SizedBox(height: 12),
                pw.Text(
                  'Financial Reports & Business Intelligence',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color:  PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Live aggregated metrics calculated from the current MySQL report data.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF64748B),
                  ),
                ),
                pw.SizedBox(height: 12),

                pdfCard(
                  'LOAN DISBURSEMENT BREAKDOWN',
                  loans.isEmpty
                      ? [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'No loan data in current period.',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ]
                      : loans.map((raw) {
                          final item = raw is Map
                              ? Map<String, dynamic>.from(raw)
                              : <String, dynamic>{};
                          final type = (item['loan_type'] ?? 'Loan')
                              .toString()
                              .replaceAll('_', ' ');
                          final count = item['loan_count'] ?? 0;
                          return pdfRow(
                            type,
                            '$count loans',
                            currency(item['total_principal']),
                          );
                        }).toList(),
                ),

                pdfCard(
                  'COLLECTIONS BY PAYMENT MODE',
                  payments.isEmpty
                      ? [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'No collection data in current period.',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ]
                      : payments.map((raw) {
                          final item = raw is Map
                              ? Map<String, dynamic>.from(raw)
                              : <String, dynamic>{};
                          final mode =
                              item['payment_mode']?.toString() ?? '-';
                          final type =
                              item['payment_type']?.toString() ?? '-';
                          return pdfRow(
                            mode,
                            type.replaceAll('_', ' '),
                            currency(item['total_amount']),
                          );
                        }).toList(),
                ),

                pdfCard(
                  'GOLD COLLATERAL INVENTORY STATUS',
                  gold.isEmpty
                      ? [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'No gold items.',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ]
                      : gold.map((raw) {
                          final item = raw is Map
                              ? Map<String, dynamic>.from(raw)
                              : <String, dynamic>{};
                          final status =
                              item['status']?.toString() ?? 'AVAILABLE';
                          final count = item['count'] ?? 0;
                          return pdfRow(
                            status,
                            '$count items',
                            weight(item['total_weight']),
                          );
                        }).toList(),
                ),

                pdfCard(
                  'TOP OUTSTANDING BORROWERS',
                  outstanding.isEmpty
                      ? [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              'No outstanding balances.',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ]
                      : outstanding.map((raw) {
                          final item = raw is Map
                              ? Map<String, dynamic>.from(raw)
                              : <String, dynamic>{};
                          final name =
                              item['name']?.toString() ?? 'Customer';
                          final code =
                              item['customer_code']?.toString() ?? '-';
                          return pdfRow(
                            name,
                            code,
                            currency(item['total_outstanding']),
                          );
                        }).toList(),
                ),
              ],
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to print report: $e',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }



  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _buildDesktopGrid(
    List loans,
    List payments,
    List gold,
    List outstanding,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildLoansSummaryCard(
                loans,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child:
                  _buildPaymentsSummaryCard(
                payments,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildGoldInventoryCard(
                gold,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child:
                  _buildTopOutstandingCard(
                outstanding,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // TABLET
  // ============================================================

  Widget _buildTabletGrid(
    List loans,
    List payments,
    List gold,
    List outstanding,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildLoansSummaryCard(
                loans,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child:
                  _buildPaymentsSummaryCard(
                payments,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  _buildGoldInventoryCard(
                gold,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child:
                  _buildTopOutstandingCard(
                outstanding,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _buildMobileLayout(
    List loans,
    List payments,
    List gold,
    List outstanding,
  ) {
    return Column(
      children: [
        _buildLoansSummaryCard(
          loans,
          mobile: true,
        ),

        const SizedBox(height: 10),

        _buildPaymentsSummaryCard(
          payments,
          mobile: true,
        ),

        const SizedBox(height: 10),

        _buildGoldInventoryCard(
          gold,
          mobile: true,
        ),

        const SizedBox(height: 10),

        _buildTopOutstandingCard(
          outstanding,
          mobile: true,
        ),
      ],
    );
  }

  // ============================================================
  // LOANS
  // ============================================================

  Widget _buildLoansSummaryCard(
    List loans, {
    bool mobile = false,
  }) {
    return _reportCard(
      title:
          'LOAN DISBURSEMENT BREAKDOWN',
      icon:
          Icons.account_balance_wallet,
      mobile: mobile,
      child: loans.isEmpty
          ? _emptyText(
              'No loan data in current period',
            )
          : Column(
              children: loans.map(
                (item) {
                  final type =
                      (item['loan_type'] ??
                              '')
                          .toString()
                          .replaceAll(
                            '_',
                            ' ',
                          );

                  final count =
                      item['loan_count'] ??
                          0;

                  final amount =
                      _toNum(
                    item[
                        'total_principal'],
                  );

                  return _summaryRow(
                    label:
                        type.isEmpty
                            ? 'Loan'
                            : type,
                    subLabel:
                        '$count loans',
                    value:
                        AppConstants
                            .formatCurrency(
                      amount,
                    ),
                    valueColor:
                        AppTheme.goldDark,
                    mobile:
                        mobile,
                  );
                },
              ).toList(),
            ),
    );
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Widget _buildPaymentsSummaryCard(
    List payments, {
    bool mobile = false,
  }) {
    return _reportCard(
      title:
          'COLLECTIONS BY PAYMENT MODE',
      icon:
          Icons.payments_outlined,
      mobile: mobile,
      child: payments.isEmpty
          ? _emptyText(
              'No collection data in current period',
            )
          : Column(
              children: payments.map(
                (item) {
                  final mode =
                      item['payment_mode']
                              ?.toString() ??
                          '-';

                  final type =
                      item['payment_type']
                              ?.toString() ??
                          '-';

                  final amount =
                      _toNum(
                    item['total_amount'],
                  );

                  return _summaryRow(
                    label:
                        mode,
                    subLabel:
                        type.replaceAll(
                          '_',
                          ' ',
                        ),
                    value:
                        AppConstants
                            .formatCurrency(
                      amount,
                    ),
                    valueColor:
                        const Color(
                      0xFF065F46,
                    ),
                    mobile:
                        mobile,
                  );
                },
              ).toList(),
            ),
    );
  }

  // ============================================================
  // GOLD
  // ============================================================

  Widget _buildGoldInventoryCard(
    List goldInventory, {
    bool mobile = false,
  }) {
    return _reportCard(
      title:
          'GOLD COLLATERAL INVENTORY STATUS',
      icon:
          Icons.diamond_outlined,
      mobile: mobile,
      child: goldInventory.isEmpty
          ? _emptyText(
              'No gold items',
            )
          : Column(
              children:
                  goldInventory.map(
                (item) {
                  final status =
                      item['status']
                              ?.toString() ??
                          'AVAILABLE';

                  final count =
                      item['count'] ??
                          0;

                  final weight =
                      _toNum(
                    item['total_weight'],
                  );

                  return _summaryRow(
                    label:
                        status,
                    subLabel:
                        '$count items',
                    value:
                        AppConstants
                            .formatWeight(
                      weight,
                    ),
                    badge:
                        true,
                    mobile:
                        mobile,
                  );
                },
              ).toList(),
            ),
    );
  }

  // ============================================================
  // OUTSTANDING
  // ============================================================

  Widget _buildTopOutstandingCard(
    List topOutstanding, {
    bool mobile = false,
  }) {
    return _reportCard(
      title:
          'TOP OUTSTANDING BORROWERS',
      icon:
          Icons.people_outline,
      mobile: mobile,
      child: topOutstanding.isEmpty
          ? _emptyText(
              'No outstanding balances',
            )
          : Column(
              children:
                  topOutstanding.map(
                (customer) {
                  final name =
                      customer['name']
                              ?.toString() ??
                          'Customer';

                  final code =
                      customer[
                              'customer_code']
                          ?.toString() ??
                          '-';

                  final amount =
                      _toNum(
                    customer[
                        'total_outstanding'],
                  );

                  return _summaryRow(
                    label:
                        name,
                    subLabel:
                        code,
                    value:
                        AppConstants
                            .formatCurrency(
                      amount,
                    ),
                    valueColor:
                        AppTheme.goldDark,
                    mobile:
                        mobile,
                  );
                },
              ).toList(),
            ),
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _reportCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool mobile = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? 12 : 16,
      ),
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(
                  color:
                      AppTheme.silverLight,
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color:
                      AppTheme.goldDark,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontWeight:
                        FontWeight.w800,
                    fontSize:
                        mobile ? 12 : 13,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Divider(
            height: 1,
          ),

          const SizedBox(height: 6),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow({
    required String label,
    required String subLabel,
    required String value,
    Color valueColor =
        AppTheme.darkNavy,
    bool badge = false,
    bool mobile = false,
  }) {
    if (mobile) {
      return Container(
        width: double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 6,
        ),
        padding:
            const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color:
              AppTheme.silverLight,
          borderRadius:
              BorderRadius.circular(
            7,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (badge)
                  Flexible(
                    child: GoldBadge(
                      status: label,
                      fontSize: 8,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),

                if (badge)
                  const Spacer(),

                const SizedBox(width: 6),

                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 12,
                    color: valueColor,
                  ),
                ),
              ],
            ),

            if (subLabel
                .trim()
                .isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 3,
                ),
                child: Text(
                  subLabel,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 9.5,
                    color:
                        AppTheme.silverDark,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (badge)
            Flexible(
              flex: 3,
              child: GoldBadge(
                status: label,
                fontSize: 9,
              ),
            )
          else
            Expanded(
              flex: 4,
              child: Text(
                label,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(width: 8),

          Expanded(
            flex: 2,
            child: Text(
              subLabel,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    AppTheme.silverDark,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY TEXT
  // ============================================================

  Widget _emptyText(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow:
            TextOverflow.ellipsis,
        style: const TextStyle(
          color:
              AppTheme.silverDark,
          fontSize: 11,
        ),
      ),
    );
  }
}