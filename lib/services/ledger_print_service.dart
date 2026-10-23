import 'dart:typed_data';

// lib/services/ledger_print_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/constants.dart';
import '../models/transaction.dart';

class LedgerPrintService {
  // ==========================================================================
  // PUBLIC PRINT METHOD
  // ==========================================================================

  static Future<void> printLedger({
    required List<LoanTransaction> transactions,
    String search = '',
    String transactionType = 'ALL',
  }) async {
    if (transactions.isEmpty) {
      throw Exception(
        'No ledger records available to print.',
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async {
        return _buildPdf(
          transactions: transactions,
          search: search,
          transactionType: transactionType,
        );
      },
      name:
          'Central_Ledger_${_fileDate()}',
    );
  }

  // ==========================================================================
  // PDF
  // ==========================================================================

  static Future<Uint8List> _buildPdf({
    required List<LoanTransaction> transactions,
    required String search,
    required String transactionType,
  }) async {
    final pdf = pw.Document();

    final totalAmount = transactions.fold<double>(
      0,
      (sum, item) =>
          sum + _toDouble(item.amount),
    );

    final totalWeight = transactions.fold<double>(
      0,
      (sum, item) =>
          sum + _toDouble(item.weight),
    );

    final generatedDate =
        DateTime.now();

    // ========================================================================
    // A4 MULTI PAGE
    // ========================================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),

        header: (context) {
          return _buildHeader(
            generatedDate,
            search,
            transactionType,
          );
        },

        footer: (context) {
          return _buildFooter(
            context,
          );
        },

        build: (context) {
          return [
            // ================================================================
            // SUMMARY
            // ================================================================

            _buildSummary(
              transactions.length,
              totalAmount,
              totalWeight,
            ),

            pw.SizedBox(
              height: 18,
            ),

            // ================================================================
            // TABLE
            // ================================================================

            _buildTransactionTable(
              transactions,
            ),

            pw.SizedBox(
              height: 18,
            ),

            // ================================================================
            // TOTALS
            // ================================================================

            _buildTotals(
              totalAmount,
              totalWeight,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  static pw.Widget _buildHeader(
    DateTime generatedDate,
    String search,
    String transactionType,
  ) {
    return pw.Container(
      margin:
          const pw.EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const pw.EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color:
                PdfColors.grey400,
            width: 0.8,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GOLD & SILVER PAWN MANAGEMENT ERP',
            style:
                const pw.TextStyle(
              fontSize: 15,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
            height: 4,
          ),

          pw.Text(
            'CENTRAL FINANCIAL & COLLATERAL TRANSACTION LEDGER',
            style:
                const pw.TextStyle(
              fontSize: 11,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(
            height: 7,
          ),

          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment
                    .spaceBetween,
            children: [
              pw.Text(
                'Transaction Type: ${_displayType(transactionType)}',
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
              ),
              pw.Text(
                search.trim().isEmpty
                    ? 'Search: ALL'
                    : 'Search: ${search.trim()}',
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
              ),
              pw.Text(
                'Generated: ${_dateTime(generatedDate)}',
                style:
                    const pw.TextStyle(
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  static pw.Widget _buildFooter(
    pw.Context context,
  ) {
    return pw.Container(
      margin:
          const pw.EdgeInsets.only(
        top: 10,
      ),
      padding:
          const pw.EdgeInsets.only(
        top: 8,
      ),
      decoration:
          const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color:
                PdfColors.grey400,
            width: 0.6,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment
                .spaceBetween,
        children: [
          pw.Text(
            'Central Ledger',
            style:
                const pw.TextStyle(
              fontSize: 7,
              color:
                  PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style:
                const pw.TextStyle(
              fontSize: 7,
              color:
                  PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUMMARY
  // ==========================================================================

  static pw.Widget _buildSummary(
    int count,
    double amount,
    double weight,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.all(
        12,
      ),
      decoration:
          pw.BoxDecoration(
        color:
            PdfColors.grey100,
        borderRadius:
            pw.BorderRadius.circular(
          6,
        ),
        border:
            pw.Border.all(
          color:
              PdfColors.grey400,
          width: 0.6,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _summaryBox(
              'TOTAL TRANSACTIONS',
              count.toString(),
            ),
          ),
          pw.SizedBox(
            width: 10,
          ),
          pw.Expanded(
            child: _summaryBox(
              'TOTAL AMOUNT',
              _currency(amount),
            ),
          ),
          pw.SizedBox(
            width: 10,
          ),
          pw.Expanded(
            child: _summaryBox(
              'TOTAL WEIGHT',
              '${weight.toStringAsFixed(3)} g',
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryBox(
    String title,
    String value,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style:
              const pw.TextStyle(
            fontSize: 7,
            fontWeight:
                pw.FontWeight.bold,
            color:
                PdfColors.grey700,
          ),
        ),
        pw.SizedBox(
          height: 4,
        ),
        pw.Text(
          value,
          style:
              const  pw.TextStyle(
            fontSize: 11,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TRANSACTION TABLE
  // ==========================================================================

  static pw.Widget _buildTransactionTable(
    List<LoanTransaction> transactions,
  ) {
    return pw.TableHelper.fromTextArray(
      border:
          pw.TableBorder.all(
        color:
            PdfColors.grey400,
        width: 0.5,
      ),

      headerDecoration:
          const pw.BoxDecoration(
        color:
            PdfColors.grey200,
      ),

      headerStyle:
          const pw.TextStyle(
        fontSize: 7,
        fontWeight:
            pw.FontWeight.bold,
      ),

      cellStyle:
          const pw.TextStyle(
        fontSize: 6.5,
      ),

      cellPadding:
          const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),

      columnWidths: {
        0: const pw.FlexColumnWidth(
          1.5,
        ),
        1: const pw.FlexColumnWidth(
          1.3,
        ),
        2: const pw.FlexColumnWidth(
          1.5,
        ),
        3: const pw.FlexColumnWidth(
          1.0,
        ),
        4: const pw.FlexColumnWidth(
          1.0,
        ),
        5: const pw.FlexColumnWidth(
          0.9,
        ),
        6: const pw.FlexColumnWidth(
          1.3,
        ),
        7: const pw.FlexColumnWidth(
          2.0,
        ),
      },

      headers: [
        'TX CODE',
        'EVENT TYPE',
        'CUSTOMER',
        'LOAN NO',
        'AMOUNT',
        'WEIGHT',
        'DATE & TIME',
        'REMARKS',
      ],

      data: transactions.map(
        (t) {
          final amount =
              _toDouble(
            t.amount,
          );

          final weight =
              _toDouble(
            t.weight,
          );

          return [
            t.transactionCode,

            _displayType(
              t.transactionType,
            ),

            '${t.customerName ?? 'Customer'}\n'
                '${t.customerCode ?? ''}',

            t.loanNo ?? '-',

            amount > 0
                ? _currency(
                    amount,
                  )
                : '-',

            weight > 0
                ? '${weight.toStringAsFixed(3)} g'
                : '-',

            '${AppConstants.formatDate(t.date)} '
                '${AppConstants.formatTime(t.time)}',

            t.remarks ?? '-',
          ];
        },
      ).toList(),
    );
  }

  // ==========================================================================
  // TOTALS
  // ==========================================================================

  static pw.Widget _buildTotals(
    double totalAmount,
    double totalWeight,
  ) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.all(
        10,
      ),
      decoration:
          pw.BoxDecoration(
        border:
            pw.Border.all(
          color:
              PdfColors.grey500,
          width: 0.7,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
            pw.MainAxisAlignment
                .end,
        children: [
          pw.Text(
            'TOTAL AMOUNT: ',
            style:
                const pw.TextStyle(
              fontSize: 8,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            _currency(
              totalAmount,
            ),
            style:
               const pw.TextStyle(
              fontSize: 9,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(
            width: 25,
          ),
          pw.Text(
            'TOTAL WEIGHT: ',
            style:
                const pw.TextStyle(
              fontSize: 8,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${totalWeight.toStringAsFixed(3)} g',
            style:
               const pw.TextStyle(
              fontSize: 9,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  static double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  static String _currency(
    double amount,
  ) {
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  static String _displayType(
    String value,
  ) {
    if (value.trim().isEmpty) {
      return '-';
    }

    return value
        .replaceAll('_', ' ')
        .toUpperCase();
  }

  static String _dateTime(
    DateTime date,
  ) {
    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    final year =
        date.year.toString();

    final hour =
        date.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final second =
        date.second
            .toString()
            .padLeft(2, '0');

    return '$day/$month/$year $hour:$minute:$second';
  }

  static String _fileDate() {
    final now =
        DateTime.now();

    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}