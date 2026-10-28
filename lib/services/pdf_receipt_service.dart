// lib/services/pdf_receipt_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/constants.dart';
import '../services/api_service.dart';

class PdfReceiptService {
  // ============================================================
  // PDF THEME
  // ============================================================

  static const PdfColor pdfGold =
      PdfColor.fromInt(0xFFD4AF37);

  static const PdfColor pdfDarkGold =
      PdfColor.fromInt(0xFFAA7C11);

  static const PdfColor pdfCharcoal =
      PdfColor.fromInt(0xFF1F2937);

  static const PdfColor pdfNavy =
      PdfColor.fromInt(0xFF0F172A);

  static const PdfColor pdfLightGray =
      PdfColor.fromInt(0xFFF8FAFC);

  static const PdfColor pdfMediumGray =
      PdfColor.fromInt(0xFFE5E7EB);

  static const PdfColor pdfBorderColor =
      PdfColor.fromInt(0xFFCBD5E1);

  // ============================================================
  // MAIN PDF GENERATOR
  // ============================================================

  static Future<Uint8List> generateReceiptPdf(
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();

    final receiptType = _stringValue(
      data['receipt_type'],
    ).toUpperCase();

    // IMPORTANT:
    // Download customer photo + every gold-item photo
    // BEFORE constructing the PDF.
    final imageCache = await _loadReceiptImages(data);

    final pageContent = _buildPageContent(
      data,
      receiptType.isEmpty ? 'PAYMENT' : receiptType,
      imageCache,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.SizedBox(
            width: PdfPageFormat.a4.width - 48,
            height: PdfPageFormat.a4.height - 48,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: pageContent,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // COMPLETE PAGE
  // ============================================================

  static pw.Widget _buildPageContent(
    Map<String, dynamic> data,
    String receiptType,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    return pw.Container(
      width: 545,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(data),

          pw.SizedBox(height: 8),

          _buildReceiptTitleBanner(
            receiptType,
            _stringValue(data['receipt_no']),
          ),

          pw.SizedBox(height: 8),

          _buildCustomerAndLoanMeta(
            data,
            imageCache,
          ),

          pw.SizedBox(height: 8),

          if (receiptType == 'PAWN_LOAN' ||
              receiptType == 'LOAN' ||
              receiptType == 'NEW_LOAN' ||
              receiptType == 'ADDITIONAL_LOAN')
            _buildLoanReceiptBody(
              data,
              imageCache,
            )
          else if (receiptType == 'PAYMENT')
            _buildPaymentReceiptBody(
              data,
              imageCache,
            )
          else if (receiptType == 'PARTIAL_RELEASE')
            _buildReleaseReceiptBody(
              data,
              imageCache,
            )
          else if (receiptType == 'CLOSURE')
            _buildClosureReceiptBody(
              data,
              imageCache,
            )
          else
            _buildGenericReceiptBody(data),

          pw.SizedBox(height: 8),

          _buildTermsAndConditions(),

          pw.SizedBox(height: 8),

          _buildFooter(data),
        ],
      ),
    );
  }

  // ============================================================
  // TERMS AND CONDITIONS
  // ============================================================

  static pw.Widget _buildTermsAndConditions() {
    final conditions = [
      'Interest: Interest will be calculated according to the agreed loan terms and applicable business rules.',
      'Repayment: The customer must repay the outstanding principal and applicable interest according to the agreed repayment terms.',
      'Pledged Gold: The pledged gold items will remain as collateral until the outstanding loan and applicable dues are settled.',
      'Release of Gold: Pledged gold items will be released only after the required settlement and verification are completed.',
      'Receipt and Records: The customer should retain this receipt for future reference and present it when requesting repayment confirmation or release of pledged items.',
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: pdfLightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: pdfBorderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERMS AND CONDITIONS',
            style: const pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: pdfNavy,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(height: 1, thickness: 0.5, color: pdfBorderColor),
          pw.SizedBox(height: 4),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(conditions.length, (index) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${index + 1}. ',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfDarkGold,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        conditions[index],
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: pdfCharcoal,
                          lineSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  static pw.Widget _buildHeader(
    Map<String, dynamic> data,
  ) {
    final date = _displayDate(
      data['date'] ??
          data['receipt_date'] ??
          data['created_at'],
    );

    final suppliedTime = _stringValue(
      data['time'],
    );

    final time = suppliedTime.isNotEmpty
        ? suppliedTime
        : _currentTime();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: pw.BoxDecoration(
        color: pdfCharcoal,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        crossAxisAlignment:
            pw.CrossAxisAlignment.center,
        mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'JAIN GOLD & PAWN SHOP',
                  style: const pw.TextStyle(
                    color: pdfGold,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Licensed Pawn Broker & Gold Financing ERP',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Main Market Road, Commercial Complex',
                  style: const pw.TextStyle(
                    color: PdfColors.grey300,
                    fontSize: 6.5,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 12),

          pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'OFFICIAL RECEIPT',
                style: const pw.TextStyle(
                  color: pdfGold,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Date: $date',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 7,
                ),
              ),
              pw.Text(
                'Time: $time',
                style: const pw.TextStyle(
                  color: PdfColors.grey300,
                  fontSize: 6.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECEIPT TITLE
  // ============================================================

  static pw.Widget _buildReceiptTitleBanner(
    String type,
    String receiptNo,
  ) {
    String title = 'TRANSACTION RECEIPT';

    switch (type) {
      case 'PAWN_LOAN':
      case 'LOAN':
      case 'NEW_LOAN':
        title = 'PAWN LOAN PLEDGE RECEIPT';
        break;

      case 'ADDITIONAL_LOAN':
        title = 'ADDITIONAL PAWN LOAN RECEIPT';
        break;

      case 'PAYMENT':
        title = 'LOAN PAYMENT RECEIPT';
        break;

      case 'PARTIAL_RELEASE':
        title = 'PARTIAL GOLD RELEASE RECEIPT';
        break;

      case 'CLOSURE':
        title =
            'LOAN CLOSURE & FINAL SETTLEMENT RECEIPT';
        break;
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: pw.BoxDecoration(
        color: pdfLightGray,
        border: pw.Border.all(
          color: pdfGold,
          width: 1,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: const pw.TextStyle(
                color: pdfNavy,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            'Receipt No: '
            '${receiptNo.isEmpty ? '-' : receiptNo}',
            style: const pw.TextStyle(
              color: pdfDarkGold,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER + LOAN DETAILS
  // ============================================================

  static pw.Widget _buildCustomerAndLoanMeta(
    Map<String, dynamic> data,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    final customer = _mapValue(
      data['customer'],
    );

    final loan = _mapValue(
      data['loan'],
    );

    final directLoanNo = _stringValue(
      data['loan_no'],
    );

    final loanNo = directLoanNo.isNotEmpty
        ? directLoanNo
        : _stringValue(
            loan['loan_no'],
          );

    final loanType = _loanTypeSymbol(
      data['loan_type'] ??
          loan['loan_type'],
    );

    final openedDate = _displayDate(
      data['opened_date'] ??
          loan['opened_date'] ??
          data['date'],
    );

    final customerImage = _imageForItem(
      customer,
      imageCache,
    );

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: pdfBorderColor,
          width: 0.7,
        ),
        borderRadius:
            pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          // ======================================================
          // CUSTOMER PHOTO
          // ======================================================

          pw.Container(
            width: 55,
            height: 62,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: pdfBorderColor,
              ),
              borderRadius:
                  pw.BorderRadius.circular(4),
            ),
            child: customerImage != null
                ? pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(
                      customerImage,
                      width: 55,
                      height: 62,
                      fit: pw.BoxFit.cover,
                    ),
                  )
                : pw.Center(
                    child: pw.Text(
                      'PHOTO',
                      style:
                          const pw.TextStyle(
                        color:
                            PdfColors.grey600,
                        fontSize: 6,
                      ),
                    ),
                  ),
          ),

          pw.SizedBox(width: 9),

          // ======================================================
          // CUSTOMER DETAILS
          // ======================================================

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  'CUSTOMER DETAILS',
                ),
                pw.SizedBox(height: 3),

                _metaLine(
                  'Name',
                  customer['name'] ??
                      customer['full_name'],
                  boldValue: true,
                ),

                _metaLine(
                  'Customer ID',
                  customer['customer_code'] ??
                      customer['customer_id'] ??
                      customer['id'],
                ),

                _metaLine(
                  'Mobile',
                  customer['mobile'] ??
                      customer['phone'],
                ),

                _metaLine(
                  'Address',
                  customer['address'],
                  maxValueLines: 2,
                ),
              ],
            ),
          ),

          pw.Container(
            width: 0.7,
            height: 64,
            color: pdfBorderColor,
          ),

          pw.SizedBox(width: 10),

          // ======================================================
          // LOAN DETAILS
          // ======================================================

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  'LOAN DETAILS',
                ),
                pw.SizedBox(height: 3),

                _metaLine(
                  'Loan Number',
                  loanNo,
                  boldValue: true,
                ),

                _metaLine(
                  'Type',
                  loanType,
                  boldValue: true,
                ),

                _metaLine(
                  'Opened Date',
                  openedDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAWN LOAN
  // ============================================================

  static pw.Widget _buildLoanReceiptBody(
    Map<String, dynamic> data,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    final loan = _mapValue(
      data['loan'],
    );

    var collateral = _listValue(
      data['collateral'],
    );

    if (collateral.isEmpty) {
      collateral = _listValue(
        loan['collateral'],
      );
    }

    if (collateral.isEmpty) {
      collateral = _listValue(
        data['gold_items'],
      );
    }

    final principal = _number(
      loan['principal_amount'] ??
          data['principal_amount'],
    );

    final totalDue = _number(
      loan['total_due'] ??
          data['total_due'] ??
          principal,
    );

    final remaining = _number(
      loan['remaining_balance'] ??
          data['remaining_balance'] ??
          principal,
    );

    double totalWeight = _number(data['total_pledged_weight'] ?? data['financial']?['total_pledged_weight']);
    if (totalWeight <= 0) {
      totalWeight = _calculateWeight(collateral);
    }

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'PLEDGED GOLD COLLATERAL',
          color: pdfNavy,
        ),

        pw.SizedBox(height: 4),

        _buildCollateralTable(
          collateral,
          imageCache,
        ),

        pw.SizedBox(height: 5),

        pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total Pledged Weight: ',
              style: const pw.TextStyle(
                fontSize: 8,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              AppConstants.formatWeight(
                totalWeight,
              ),
              style: const pw.TextStyle(
                fontSize: 8,
                color: pdfNavy,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 7),

        _buildFinancialSummaryBox(
          [
            if (_number(loan['additional_amount'] ?? data['financial']?['additional_amount']) > 0) ...[
              [
                'Original Principal Amount',
                AppConstants.formatCurrency(_number(loan['original_principal'] ?? data['financial']?['original_principal'])),
              ],
              [
                'Additional Top-up Amount',
                AppConstants.formatCurrency(_number(loan['additional_amount'] ?? data['financial']?['additional_amount'])),
              ],
              [
                'Combined Principal Amount',
                AppConstants.formatCurrency(principal),
              ],
            ] else ...[
              [
                'Principal Loan Amount',
                AppConstants.formatCurrency(principal),
              ],
            ],
            if (_number(loan['total_interest'] ?? data['financial']?['total_interest'] ?? data['financial']?['initial_interest']) > 0)
              [
                'Total Interest Amount',
                AppConstants.formatCurrency(_number(loan['total_interest'] ?? data['financial']?['total_interest'] ?? data['financial']?['initial_interest'])),
              ],
            [
              'Total Due Amount',
              AppConstants.formatCurrency(totalDue),
            ],
            [
              'REMAINING BALANCE',
              AppConstants.formatCurrency(remaining),
            ],
          ],
          highlightLast: true,
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  static pw.Widget _buildPaymentReceiptBody(
    Map<String, dynamic> data,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    final payment = _mapValue(
      data['payment'],
    );

    final financial = _mapValue(
      data['loan_financial'] ??
          data['financial'] ??
          data['payment'] ??
          data,
    );

    final principal = _number(
      financial['principal_amount'] ??
          data['principal_amount'],
    );

    final totalDue = _number(
      financial['total_due'] ??
          data['total_due'],
    );

    final previousPaid = _number(
      financial['previous_paid'] ??
          payment['previous_paid'] ??
          data['previous_paid'],
    );

    final currentPayment = _number(
      financial['current_payment'] ??
          financial['payment_amount'] ??
          payment['amount'] ??
          data['amount'],
    );

    final totalPaid = _number(
      financial['total_paid'] ??
          payment['new_total_paid'] ??
          payment['total_paid'] ??
          data['total_paid'],
    );

    final remaining = _number(
      financial['remaining_balance'] ??
          payment['remaining_balance'] ??
          data['remaining_balance'],
    );

    var collateral = _listValue(
      data['collateral'],
    );

    if (collateral.isEmpty) {
      collateral = _listValue(
        _mapValue(
          data['loan'],
        )['collateral'],
      );
    }

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _buildFinancialSummaryBox(
          [
            [
              'Original Principal Amount',
              AppConstants.formatCurrency(
                principal,
              ),
            ],
            [
              'Total Amount Due',
              AppConstants.formatCurrency(
                totalDue,
              ),
            ],
            [
              'Previously Paid Amount',
              AppConstants.formatCurrency(
                previousPaid,
              ),
            ],
            [
              'CURRENT PAYMENT RECEIVED',
              AppConstants.formatCurrency(
                currentPayment,
              ),
            ],
            [
              'Cumulative Total Paid',
              AppConstants.formatCurrency(
                totalPaid,
              ),
            ],
            [
              'REMAINING BALANCE',
              AppConstants.formatCurrency(
                remaining,
              ),
            ],
          ],
          highlightLast: true,
        ),

        if (collateral.isNotEmpty) ...[
          pw.SizedBox(height: 7),

          _sectionHeading(
            'PLEDGED GOLD',
            color: pdfNavy,
          ),

          pw.SizedBox(height: 4),

          _buildCollateralTable(
            collateral,
            imageCache,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PARTIAL RELEASE
  // ============================================================

  static pw.Widget _buildReleaseReceiptBody(
    Map<String, dynamic> data,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    var releasedGold = _listValue(
      data['released_gold'],
    );

    var remainingGold = _listValue(
      data['remaining_pledged_gold'],
    );

    final financial = _mapValue(
      data['financial'],
    );

    if (releasedGold.isEmpty) {
      releasedGold = _listValue(
        data['released_items'],
      );
    }

    if (remainingGold.isEmpty) {
      remainingGold = _listValue(
        data['remaining_gold'],
      );
    }

    final releasedWeight = _number(
      data['total_released_weight'] ??
          _calculateWeight(releasedGold),
    );

    final remainingWeight = _number(
      data['remaining_pledged_weight'] ??
          _calculateWeight(remainingGold),
    );

    final remainingBalance = _number(
      financial['remaining_balance'] ??
          data['remaining_balance'],
    );

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'ITEMS RELEASED THIS TRANSACTION',
          color: pdfDarkGold,
        ),

        pw.SizedBox(height: 4),

        _buildCollateralTable(
          releasedGold,
          imageCache,
        ),

        pw.SizedBox(height: 4),

        pw.Text(
          'Total Weight Released: '
          '${AppConstants.formatWeight(releasedWeight)}',
          style: const pw.TextStyle(
            fontSize: 7.5,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.SizedBox(height: 6),

        _sectionHeading(
          'REMAINING PLEDGED COLLATERAL',
          color: pdfNavy,
        ),

        pw.SizedBox(height: 4),

        _buildCollateralTable(
          remainingGold,
          imageCache,
        ),

        pw.SizedBox(height: 4),

        pw.Text(
          'Remaining Pledged Weight: '
          '${AppConstants.formatWeight(remainingWeight)}',
          style: const pw.TextStyle(
            fontSize: 7.5,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.SizedBox(height: 6),

        _buildFinancialSummaryBox(
          [
            [
              'Previous Total Paid',
              AppConstants.formatCurrency(
                financial['previous_paid'],
              ),
            ],
            [
              'Payment Received For Release',
              AppConstants.formatCurrency(
                financial['current_payment'],
              ),
            ],
            [
              'New Total Paid',
              AppConstants.formatCurrency(
                financial['total_paid'],
              ),
            ],
            [
              'REMAINING BALANCE',
              AppConstants.formatCurrency(
                remainingBalance,
              ),
            ],
          ],
          highlightLast: true,
        ),
      ],
    );
  }

  // ============================================================
  // CLOSURE
  // ============================================================

  static pw.Widget _buildClosureReceiptBody(
    Map<String, dynamic> data,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    final financial = _mapValue(
      data['financial'],
    );

    final gold = _mapValue(
      data['gold'],
    );

    var releasedItems = _listValue(
      gold['released_items'],
    );

    if (releasedItems.isEmpty) {
      releasedItems = _listValue(
        data['released_items'],
      );
    }

    if (releasedItems.isEmpty) {
      releasedItems = _listValue(
        data['collateral'],
      );
    }

    final goldReleased = _number(
      gold['gold_released_at_closure'] ??
          data['gold_released_at_closure'] ??
          _calculateWeight(releasedItems),
    );

    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        _buildFinancialSummaryBox(
          [
            [
              'Original Principal Loan Amount',
              AppConstants.formatCurrency(
                financial['principal_amount'],
              ),
            ],
            [
              'Accumulated Monthly Interest',
              AppConstants.formatCurrency(
                financial['previous_interest'],
              ),
            ],
            [
              'Manual Final Interest Applied',
              AppConstants.formatCurrency(
                financial['manual_final_interest'],
              ),
            ],
            [
              'Final Settlement Amount',
              AppConstants.formatCurrency(
                financial['final_settlement_amount'],
              ),
            ],
            [
              'Total Amount Paid',
              AppConstants.formatCurrency(
                financial['total_paid'],
              ),
            ],
            [
              'FINAL PAYMENT RECEIVED',
              AppConstants.formatCurrency(
                financial['final_payment'],
              ),
            ],
            [
              'REMAINING OUTSTANDING BALANCE',
              AppConstants.formatCurrency(0),
            ],
          ],
          highlightLast: true,
        ),

        pw.SizedBox(height: 7),

        _sectionHeading(
          'COLLATERAL RELEASED AT CLOSURE',
          color: pdfNavy,
        ),

        pw.SizedBox(height: 4),

        _buildCollateralTable(
          releasedItems,
          imageCache,
        ),

        pw.SizedBox(height: 4),

        pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gold Released at Closure: '
              '${AppConstants.formatWeight(goldReleased)}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Remaining Pledged Gold: 0.000g',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: pdfNavy,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 5),

        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: pdfNavy,
            borderRadius:
                pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'LOAN CLOSED | ALL GOLD COLLATERAL RELEASED IN FULL',
            textAlign:
                pw.TextAlign.center,
            style: const   pw.TextStyle(
              color: pdfGold,
              fontSize: 8,
              fontWeight:
                  pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GENERIC
  // ============================================================

  static pw.Widget _buildGenericReceiptBody(
    Map<String, dynamic> data,
  ) {
    final amount = _number(
      data['amount'] ??
          data['total_amount'],
    );

    return _buildFinancialSummaryBox(
      [
        [
          'Amount',
          AppConstants.formatCurrency(
            amount,
          ),
        ],
      ],
      highlightLast: true,
    );
  }

  // ============================================================
  // GOLD COLLATERAL TABLE
  //
  // LOCKED:
  // Photo | Item Name | Weight
  //
  // NO:
  // Purity
  // Gross Weight
  // Stone
  // Status
  // ============================================================

  static pw.Widget _buildCollateralTable(
    List items,
    Map<String, pw.MemoryImage> imageCache,
  ) {
    if (items.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: pdfBorderColor,
            width: 0.6,
          ),
        ),
        child: pw.Center(
          child: pw.Text(
            'No gold items available',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: pdfBorderColor,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(48),
        1: pw.FlexColumnWidth(1),
        2: pw.FixedColumnWidth(75),
      },
      children: [
        // --------------------------------------------------------
        // HEADER
        // --------------------------------------------------------

        pw.TableRow(
          decoration:
              const pw.BoxDecoration(
            color: pdfLightGray,
          ),
          children: [
            _tableCell(
              'Photo',
              isHeader: true,
              alignCenter: true,
            ),
            _tableCell(
              'Item Name',
              isHeader: true,
            ),
            _tableCell(
              'Weight (g)',
              isHeader: true,
              alignRight: true,
            ),
          ],
        ),

        // --------------------------------------------------------
        // ALL GOLD ITEMS
        // --------------------------------------------------------

        ...items.map(
          (rawItem) {
            final item = _mapValue(
              rawItem,
            );

            final name = _stringValue(
              item['item_name'] ??
                  item['itemName'] ??
                  item['name'],
            );

            final weight = _number(
              item['weight'] ??
                  item['pledged_weight'] ??
                  item['pledgedWeight'] ??
                  item['gold_weight'],
            );

            final image = _imageForItem(
              item,
              imageCache,
            );

            return pw.TableRow(
              children: [
                // ------------------------------------------------
                // GOLD ITEM PHOTO
                // ------------------------------------------------

                pw.Container(
                  height: 40,
                  alignment:
                      pw.Alignment.center,
                  padding:
                      const pw.EdgeInsets.all(2),
                  child: image != null
                      ? pw.ClipRRect(
                          horizontalRadius: 3,
                          verticalRadius: 3,
                          child: pw.Image(
                            image,
                            width: 36,
                            height: 36,
                            fit: pw.BoxFit.cover,
                          ),
                        )
                      : pw.Container(
                          width: 36,
                          height: 36,
                          alignment:
                              pw.Alignment.center,
                          decoration:
                              pw.BoxDecoration(
                            color:
                                pdfLightGray,
                            border:
                                pw.Border.all(
                              color:
                                  pdfBorderColor,
                            ),
                            borderRadius:
                                pw.BorderRadius
                                    .circular(3),
                          ),
                          child: pw.Text(
                            '—',
                            style:
                                const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors
                                  .grey600,
                            ),
                          ),
                        ),
                ),

                // ------------------------------------------------
                // ITEM NAME
                // ------------------------------------------------

                _tableCell(
                  name.isEmpty ? '-' : name,
                ),

                // ------------------------------------------------
                // WEIGHT
                // ------------------------------------------------

                _tableCell(
                  AppConstants.formatWeight(
                    weight,
                  ),
                  alignRight: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // FINANCIAL SUMMARY
  // ============================================================

  static pw.Widget _buildFinancialSummaryBox(
    List<List<String>> rows, {
    bool highlightLast = false,
  }) {
    return pw.Container(
      width: double.infinity,
      padding:
          const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: pw.BoxDecoration(
        color: pdfLightGray,
        border: pw.Border.all(
          color: pdfBorderColor,
          width: 0.7,
        ),
        borderRadius:
            pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: rows
            .asMap()
            .entries
            .map(
          (entry) {
            final isLast =
                highlightLast &&
                    entry.key ==
                        rows.length - 1;

            final label =
                entry.value.isNotEmpty
                    ? entry.value[0]
                    : '';

            final value =
                entry.value.length > 1
                    ? entry.value[1]
                    : '';

            return pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(
                vertical: 2,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize:
                            isLast ? 8 : 7.2,
                        fontWeight: isLast
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                        color: isLast
                            ? pdfNavy
                            : PdfColors.grey800,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    value,
                    textAlign:
                        pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize:
                          isLast ? 9 : 7.2,
                      fontWeight: isLast
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: isLast
                          ? pdfDarkGold
                          : PdfColors.black,
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
  // FOOTER
  // ============================================================

  static pw.Widget _buildFooter(
    Map<String, dynamic> data,
  ) {
    final now = DateTime.now();

    final generatedDate =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    final generatedTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    return pw.Column(
      children: [
        pw.Divider(
          color: pdfBorderColor,
          thickness: 0.7,
        ),

        pw.SizedBox(height: 5),

        pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBlock(
              'Customer Signature / Thumb',
            ),
            _signatureBlock(
              'Authorized Officer / Cashier',
            ),
          ],
        ),

        pw.SizedBox(height: 5),

        pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Generated Date: $generatedDate',
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey700,
              ),
            ),

            pw.SizedBox(width: 12),

            pw.Text(
              'Generated Time: $generatedTime',
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 2),

        pw.Text(
          'Computer generated ERP receipt. '
          'Please retain this receipt for your records.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 5.8,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock(
    String label,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 120,
          height: 0.7,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 6.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADING
  // ============================================================

  static pw.Widget _sectionHeading(
    String text, {
    PdfColor color = pdfNavy,
  }) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // META LINE
  // ============================================================

  static pw.Widget _metaLine(
    String label,
    dynamic value, {
    bool boldValue = false,
    int maxValueLines = 1,
  }) {
    final text =
        _stringValue(value).isEmpty
            ? '-'
            : _stringValue(value);

    return pw.Padding(
      padding:
          const pw.EdgeInsets.only(
        bottom: 1.5,
      ),
      child: pw.Row(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 58,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey700,
              ),
            ),
          ),

          pw.Text(
            ': ',
            style: const pw.TextStyle(
              fontSize: 6.5,
              color: PdfColors.grey700,
            ),
          ),

          pw.Expanded(
            child: pw.Text(
              text,
              maxLines: maxValueLines,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: boldValue
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE CELL
  // ============================================================

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
    bool alignCenter = false,
  }) {
    pw.TextAlign alignment =
        pw.TextAlign.left;

    if (alignRight) {
      alignment = pw.TextAlign.right;
    } else if (alignCenter) {
      alignment = pw.TextAlign.center;
    }

    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 5,
      ),
      child: pw.Text(
        text,
        textAlign: alignment,
        style: pw.TextStyle(
          fontSize: 6.8,
          fontWeight: isHeader
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader
              ? pdfNavy
              : PdfColors.black,
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE COLLECTION
  // ============================================================

  static Future<Map<String, pw.MemoryImage>>
      _loadReceiptImages(
    Map<String, dynamic> data,
  ) async {
    final cache =
        <String, pw.MemoryImage>{};

    final urls = <String>{};

    // ==========================================================
    // CUSTOMER PHOTO
    // ==========================================================

    final customer = _mapValue(
      data['customer'],
    );

    _addImageUrl(
      customer,
      urls,
    );

    _addDirectImageValue(
      data['customer_photo_url'],
      urls,
    );

    _addDirectImageValue(
      data['customer_photo'],
      urls,
    );

    _addDirectImageValue(
      data['customerPhotoUrl'],
      urls,
    );

    _addDirectImageValue(
      data['customerPhoto'],
      urls,
    );

    // ==========================================================
    // MAIN COLLATERAL
    // ==========================================================

    _collectImageUrls(
      data['collateral'],
      urls,
    );

    // ==========================================================
    // GOLD ITEMS
    // ==========================================================

    _collectImageUrls(
      data['gold_items'],
      urls,
    );

    // ==========================================================
    // LOAN COLLATERAL
    // ==========================================================

    final loan = _mapValue(
      data['loan'],
    );

    _collectImageUrls(
      loan['collateral'],
      urls,
    );

    _collectImageUrls(
      loan['gold_items'],
      urls,
    );

    // ==========================================================
    // RELEASED GOLD
    // ==========================================================

    _collectImageUrls(
      data['released_gold'],
      urls,
    );

    _collectImageUrls(
      data['released_items'],
      urls,
    );

    // ==========================================================
    // REMAINING GOLD
    // ==========================================================

    _collectImageUrls(
      data['remaining_pledged_gold'],
      urls,
    );

    _collectImageUrls(
      data['remaining_gold'],
      urls,
    );

    // ==========================================================
    // CLOSURE
    // ==========================================================

    final gold = _mapValue(
      data['gold'],
    );

    _collectImageUrls(
      gold['released_items'],
      urls,
    );

    _collectImageUrls(
      gold['collateral'],
      urls,
    );

    // ==========================================================
    // OTHER POSSIBLE LISTS
    // ==========================================================

    _collectImageUrls(
      data['items'],
      urls,
    );

    // ==========================================================
    // DOWNLOAD EVERY UNIQUE IMAGE
    // ==========================================================

    for (final rawUrl in urls) {
      try {
        final image =
            await _downloadImage(rawUrl);

        if (image != null) {
          cache[rawUrl] = image;
        }
      } catch (_) {
        // One failed image must never prevent
        // the receipt from being generated.
      }
    }

    return cache;
  }

  // ============================================================
  // COLLECT IMAGE URLS
  // ============================================================

  static void _collectImageUrls(
    dynamic value,
    Set<String> output,
  ) {
    if (value is List) {
      for (final item in value) {
        final map = _mapValue(item);

        _addImageUrl(
          map,
          output,
        );
      }

      return;
    }

    if (value is Map) {
      final map = _mapValue(value);

      _addImageUrl(
        map,
        output,
      );
    }
  }

  // ============================================================
  // ADD IMAGE URL
  // ============================================================

  static void _addImageUrl(
    Map<String, dynamic> item,
    Set<String> output,
  ) {
    final url = _extractImageUrl(item);

    if (url != null) {
      output.add(url);
    }
  }

  // ============================================================
  // DIRECT IMAGE VALUE
  // ============================================================

  static void _addDirectImageValue(
    dynamic value,
    Set<String> output,
  ) {
    if (value == null) {
      return;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return;
    }

    final lower = text.toLowerCase();

    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'none') {
      return;
    }

    output.add(text);
  }

  // ============================================================
  // GET IMAGE FROM CACHE
  // ============================================================

  static pw.MemoryImage? _imageForItem(
    Map<String, dynamic> item,
    Map<String, pw.MemoryImage> cache,
  ) {
    final url = _extractImageUrl(item);

    if (url == null) {
      return null;
    }

    return cache[url];
  }

  // ============================================================
  // IMAGE URL EXTRACTION
  // ============================================================

  static String? _extractImageUrl(
    Map<String, dynamic> item,
  ) {
    final candidates = <dynamic>[
      // Standard database field.
      item['photo_url'],

      // Flutter naming.
      item['photoUrl'],

      // Generic photo.
      item['photo'],

      // Image fields.
      item['image_url'],
      item['imageUrl'],
      item['image'],

      // Path fields.
      item['photo_path'],
      item['photoPath'],
      item['image_path'],
      item['imagePath'],

      // Customer photo fields.
      item['customer_photo_url'],
      item['customerPhotoUrl'],
      item['customer_photo'],
      item['customerPhoto'],

      // Gold item photo fields.
      item['item_photo'],
      item['itemPhoto'],
      item['item_photo_url'],
      item['itemPhotoUrl'],
      item['gold_photo'],
      item['goldPhoto'],
      item['gold_photo_url'],
      item['goldPhotoUrl'],
    ];

    for (final value in candidates) {
      if (value == null) {
        continue;
      }

      final url =
          value.toString().trim();

      if (url.isEmpty) {
        continue;
      }

      final lower =
          url.toLowerCase();

      if (lower == 'null' ||
          lower == 'undefined' ||
          lower == 'none') {
        continue;
      }

      return url;
    }

    return null;
  }

  // ============================================================
  // IMAGE URL RESOLUTION
  //
  // CRITICAL FIX
  //
  // ApiService.baseUrl:
  //
  // https://backedn-node.onrender.com
  //
  // PHP:
  //
  // /uploads/customers/customer_xxx.jpg
  //
  // MUST become:
  //
  // https://backedn-node.onrender.com/
  // uploads/customers/customer_xxx.jpg
  //
  // NOT:
  //
  // http://localhost/uploads/...
  // ============================================================

  static String _resolveImageUrl(
    String raw,
  ) {
    final value = raw.trim();

    if (value.isEmpty) {
      return value;
    }

    // ==========================================================
    // ALREADY ABSOLUTE
    // ==========================================================

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }

    // ==========================================================
    // BASE64 IMAGE
    // ==========================================================

    if (value.startsWith('data:image/')) {
      return value;
    }

    // ==========================================================
    // API BASE URL
    // ==========================================================

    final base = ApiService.baseUrl
        .trim()
        .replaceFirst(
          RegExp(r'/+$'),
          '',
        );

    if (base.isEmpty) {
      return value;
    }

    final baseUri =
        Uri.tryParse(base);

    if (baseUri == null ||
        !baseUri.hasScheme ||
        baseUri.host.isEmpty) {
      return value.startsWith('/')
          ? value
          : '$base/$value';
    }

    final origin =
        '${baseUri.scheme}://${baseUri.authority}';

    final basePath =
        baseUri.path.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    // ==========================================================
    // ROOT-RELATIVE URL
    //
    // /uploads/gold/a.jpg
    //
    // becomes
    //
    // https://backedn-node.onrender.com/
    // uploads/gold/a.jpg
    // ==========================================================

    if (value.startsWith('/')) {
      // If it already contains the complete
      // application/backend path:
      //
      // /gold_pawn_erp/backend/uploads/a.jpg
      //
      if (basePath.isNotEmpty &&
          (value == basePath ||
              value.startsWith('$basePath/'))) {
        return '$origin$value';
      }

      // Normal PHP response:
      //
      // /uploads/...
      //
      return '$base$value';
    }

    // ==========================================================
    // VALUE ALREADY STARTS WITH BACKEND PATH
    // ==========================================================

    if (basePath.isNotEmpty &&
        value.startsWith('$basePath/')) {
      return '$origin/$value';
    }

    // ==========================================================
    // NORMAL RELATIVE URL
    // ==========================================================

    return '$base/$value';
  }

  // ============================================================
  // DOWNLOAD IMAGE
  // ============================================================

  static Future<pw.MemoryImage?>
      _downloadImage(
    String rawUrl,
  ) async {
    final value = rawUrl.trim();

    if (value.isEmpty) {
      return null;
    }

    // ==========================================================
    // BASE64 IMAGE
    // ==========================================================

    if (value.startsWith('data:image/')) {
      final commaIndex =
          value.indexOf(',');

      if (commaIndex < 0) {
        return null;
      }

      try {
        final header =
            value.substring(
          0,
          commaIndex,
        );

        final encoded =
            value.substring(
          commaIndex + 1,
        );

        Uint8List bytes;

        if (header.contains(';base64')) {
          bytes = base64Decode(
            encoded,
          );
        } else {
          bytes =
              Uint8List.fromList(
            utf8.encode(encoded),
          );
        }

        if (bytes.isEmpty) {
          return null;
        }

        return pw.MemoryImage(
          bytes,
        );
      } catch (_) {
        return null;
      }
    }

    // ==========================================================
    // HTTP IMAGE
    // ==========================================================

    final url =
        _resolveImageUrl(value);

    try {
      final uri =
          Uri.tryParse(url);

      if (uri == null ||
          !uri.hasScheme ||
          uri.host.isEmpty) {
        return null;
      }

      final response =
          await http.get(
        uri,
        headers: const {
          'Accept':
              'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        },
      ).timeout(
        const Duration(
          seconds: 15,
        ),
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(
          response.bodyBytes,
        );
      }
    } catch (_) {
      // Never break receipt printing
      // because of an image failure.
    }

    return null;
  }

  // ============================================================
  // LOAN TYPE
  //
  // LOCKED:
  // * = NEW LOAN
  // # = EXISTING LOAN
  // ADDITIONAL = ADDITIONAL LOAN
  // ============================================================

  static String _loanTypeSymbol(
    dynamic value,
  ) {
    final type =
        _stringValue(value)
            .trim()
            .toUpperCase();

    switch (type) {
      case 'NEW_LOAN':
      case 'NEW':
      case '*':
        return '*';

      case 'EXISTING_LOAN':
      case 'EXISTING':
      case '#':
        return '#';

      case 'ADDITIONAL_LOAN':
      case 'ADDITIONAL':
        return 'ADDITIONAL';

      default:
        return type.isEmpty
            ? '*'
            : type;
    }
  }

  // ============================================================
  // NUMBER
  // ============================================================

  static double _number(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value
              .toString()
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  // ============================================================
  // CALCULATE WEIGHT
  // ============================================================

  static double _calculateWeight(
    List items,
  ) {
    double total = 0;

    for (final rawItem in items) {
      final item =
          _mapValue(rawItem);

      total += _number(
        item['weight'] ??
            item['pledged_weight'] ??
            item['pledgedWeight'] ??
            item['gold_weight'],
      );
    }

    return total;
  }

  // ============================================================
  // MAP HELPER
  // ============================================================

  static Map<String, dynamic> _mapValue(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // LIST HELPER
  // ============================================================

  static List _listValue(
    dynamic value,
  ) {
    if (value is List) {
      return value;
    }

    return <dynamic>[];
  }

  // ============================================================
  // STRING HELPER
  // ============================================================

  static String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // DISPLAY DATE
  // ============================================================

  static String _displayDate(
    dynamic value,
  ) {
    final raw =
        _stringValue(value);

    if (raw.isEmpty) {
      return _currentDate();
    }

    // ==========================================================
    // YYYY-MM-DD
    // ==========================================================

    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})',
    ).firstMatch(raw);

    if (iso != null) {
      return '${iso.group(3)}/'
          '${iso.group(2)}/'
          '${iso.group(1)}';
    }

    // ==========================================================
    // DD-MM-YYYY
    // ==========================================================

    final dash = RegExp(
      r'^(\d{2})-(\d{2})-(\d{4})',
    ).firstMatch(raw);

    if (dash != null) {
      return '${dash.group(1)}/'
          '${dash.group(2)}/'
          '${dash.group(3)}';
    }

    // ==========================================================
    // DD/MM/YYYY
    // ==========================================================

    final slash = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})',
    ).firstMatch(raw);

    if (slash != null) {
      return '${slash.group(1)}/'
          '${slash.group(2)}/'
          '${slash.group(3)}';
    }

    return raw;
  }

  // ============================================================
  // CURRENT DATE
  // ============================================================

  static String _currentDate() {
    final now =
        DateTime.now();

    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

  // ============================================================
  // CURRENT TIME
  // ============================================================

  static String _currentTime() {
    final now =
        DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PRINT RECEIPT
  // ============================================================

  static Future<void> printReceipt(
    Map<String, dynamic> data,
  ) async {
    final pdfBytes =
        await generateReceiptPdf(
      data,
    );

    final receiptNo =
        _stringValue(
      data['receipt_no'],
    );

    final safeName =
        receiptNo.isEmpty
            ? 'Receipt'
            : receiptNo.replaceAll(
                RegExp(
                  r'[\\/:*?"<>|]',
                ),
                '_',
              );

    await Printing.layoutPdf(
      onLayout:
          (PdfPageFormat format) async {
        return pdfBytes;
      },
      name: '$safeName.pdf',
      format: PdfPageFormat.a4,
    );
  }
}