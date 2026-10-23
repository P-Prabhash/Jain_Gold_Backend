// lib/config/constants.dart

import 'package:intl/intl.dart';

class AppConstants {
  // ============================================================
  // APP
  // ============================================================

  static const String appName =
      'Jain Gold & Pawn Shop';

  static const String appVersion = '1.0.0';

  // ============================================================
  // API
  // ============================================================

  static const String defaultApiBaseUrl =
      'http://localhost/gold_pawn_erp/backend';

  static const String baseUrl =
      defaultApiBaseUrl;

  // ============================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================

  static const double mobileBreakpoint = 600;

  static const double tabletBreakpoint = 900;

  static const double desktopBreakpoint = 1200;

  // ============================================================
  // PAGINATION
  // ============================================================

  static const int defaultPageSize = 20;

  static const int maxPageSize = 100;

  // ============================================================
  // DATE FORMATS
  // ============================================================

  static const String dateFormat =
      'dd-MM-yyyy';

  static const String databaseDateFormat =
      'yyyy-MM-dd';

  static const String dateTimeFormat =
      'dd-MM-yyyy HH:mm:ss';

  static const String timeFormat =
      'HH:mm:ss';

  // ============================================================
  // CURRENCY
  // ============================================================
  //
  // IMPORTANT:
  // Use ASCII "Rs" instead of Unicode "₹".
  // This prevents PDF font errors for U+20B9.
  //
  // Example:
  // Rs 25,000.00
  //
  // ============================================================

  static const String currencySymbol = 'Rs';

  static String formatCurrency(
    dynamic amount,
  ) {
    final value = safeDouble(amount);

    final formatter = NumberFormat(
      '#,##0.00',
      'en_IN',
    );

    return '$currencySymbol ${formatter.format(value)}';
  }

  // ============================================================
  // NUMBER FORMATTING
  // ============================================================

  static String formatNumber(
    dynamic value, {
    int decimals = 2,
  }) {
    final number = safeDouble(value);

    final pattern =
        '#,##0.${'0' * decimals}';

    return NumberFormat(
      pattern,
      'en_IN',
    ).format(number);
  }

  // ============================================================
  // WEIGHT
  // ============================================================

  static String formatWeight(
    dynamic weight,
  ) {
    final value = safeDouble(weight);

    return '${value.toStringAsFixed(2)} g';
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  static String formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    DateTime? date;

    try {
      date = DateTime.tryParse(text);
    } catch (_) {
      date = null;
    }

    if (date == null) {
      return text;
    }

    return DateFormat(
      dateFormat,
    ).format(date);
  }

  static String formatDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    DateTime? date;

    try {
      date = DateTime.tryParse(text);
    } catch (_) {
      date = null;
    }

    if (date == null) {
      return text;
    }

    return DateFormat(
      dateTimeFormat,
    ).format(date);
  }

  static String formatTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    DateTime? date;

    try {
      date = DateTime.tryParse(text);
    } catch (_) {
      date = null;
    }

    if (date == null) {
      return text;
    }

    return DateFormat(
      timeFormat,
    ).format(date);
  }

  // ============================================================
  // LOAN TYPES
  // ============================================================

  static const String newLoan =
      'NEW_LOAN';

  static const String existingLoan =
      'EXISTING_LOAN';

  static const String additionalLoan =
      'ADDITIONAL_LOAN';

  // ============================================================
  // LOAN SYMBOLS
  // ============================================================
  //
  // LOCKED:
  //
  // New Loan      = *
  // Existing Loan = #
  //
  // Loan number itself remains unchanged.
  //
  // Example:
  //
  // * LN-000016
  // # LN-000017
  //
  // ============================================================

  static const String newLoanSymbol = '*';

  static const String existingLoanSymbol = '#';

  static const String additionalLoanLabel =
      'ADDITIONAL';

  // ============================================================
  // LOAN TYPE SYMBOL
  // ============================================================

  static String loanTypeSymbol(
    dynamic type,
  ) {
    final value =
        type?.toString().trim().toUpperCase() ?? '';

    switch (value) {
      case 'NEW':
      case 'NEW_LOAN':
      case '*':
        return newLoanSymbol;

      case 'EXISTING':
      case 'EXISTING_LOAN':
      case '#':
        return existingLoanSymbol;

      case 'ADDITIONAL':
      case 'ADDITIONAL_LOAN':
        return additionalLoanLabel;

      default:
        return value.isEmpty
            ? newLoanSymbol
            : value;
    }
  }

  // ============================================================
  // LOAN DISPLAY NUMBER
  // ============================================================
  //
  // IMPORTANT:
  // This is only for UI display.
  //
  // Database loan number is NOT changed.
  //
  // New Loan:
  // * LN-000001
  //
  // Existing Loan:
  // # LN-000002
  //
  // ============================================================

  static String loanDisplayNo(
    dynamic loanNo,
    dynamic loanType,
  ) {
    final number =
        loanNo?.toString().trim() ?? '';

    final type =
        loanType?.toString().trim().toUpperCase() ?? '';

    if (number.isEmpty) {
      return '-';
    }

    if (type == 'EXISTING_LOAN' ||
        type == 'EXISTING' ||
        type == '#') {
      return '$existingLoanSymbol $number';
    }

    if (type == 'NEW_LOAN' ||
        type == 'NEW' ||
        type == '*') {
      return '$newLoanSymbol $number';
    }

    if (type == 'ADDITIONAL_LOAN' ||
        type == 'ADDITIONAL') {
      return number;
    }

    return number;
  }

  // ============================================================
  // LOAN INTEREST
  // ============================================================
  //
  // Interest rate is not part of the locked receipt.
  // Interest type is Monthly.
  //
  // ============================================================

  static const String interestTypeMonthly =
      'MONTHLY';

  static const String interestTypeMonthlyLabel =
      'Monthly';

  // ============================================================
  // LOAN STATUS
  // ============================================================

  static const String loanStatusActive =
      'ACTIVE';

  static const String loanStatusClosed =
      'CLOSED';

  static const String loanStatusPending =
      'PENDING';

  // ============================================================
  // CUSTOMER SEARCH
  // ============================================================

  static const String searchCustomerId =
      'Customer ID';

  static const String searchCustomerName =
      'Customer Name';

  static const String searchMobile =
      'Mobile Number';

  static const String searchAadhaar =
      'Aadhaar Number';

  // ============================================================
  // GOLD ITEM
  // ============================================================

  static const String goldItemName =
      'Item Name';

  static const String goldPurity =
      'Purity';

  static const String goldWeight =
      'Weight';

  static const String goldRemarks =
      'Remarks';

  static const String goldPhoto =
      'Item Photo';

  // ============================================================
  // IMAGE TYPES
  // ============================================================

  static const String imageTypeCustomer =
      'customers';

  static const String imageTypeGold =
      'gold';

  // ============================================================
  // RECEIPT TYPES
  // ============================================================

  static const String receiptTypeLoan =
      'LOAN';

  static const String receiptTypePawnLoan =
      'PAWN_LOAN';

  static const String receiptTypePayment =
      'PAYMENT';

  static const String receiptTypeRelease =
      'RELEASE';

  static const String receiptTypeClosure =
      'CLOSURE';

  // ============================================================
  // RECEIPT
  // ============================================================

  static const String receiptShopName =
      'GOLD & SILVER PAWN MANAGEMENT ERP';

  // ============================================================
  // RECEIPT LABELS
  // ============================================================

  static const String labelCustomer =
      'Customer';

  static const String labelCustomerId =
      'Customer ID';

  static const String labelMobile =
      'Mobile';

  static const String labelAddress =
      'Address';

  static const String labelLoanNo =
      'Loan No';

  static const String labelLoanType =
      'Type';

  static const String labelOpenedDate =
      'Opened Date';

  static const String labelClosedDate =
      'Closed Date';

  static const String labelPrincipal =
      'Principal Amount';

  static const String labelAmount =
      'Amount';

  static const String labelTotalDue =
      'Total Due';

  static const String labelTotalPaid =
      'Total Paid';

  static const String labelRemaining =
      'Remaining Balance';

  static const String labelPayment =
      'Payment';

  static const String labelGoldItems =
      'Gold Items';

  static const String labelTotalWeight =
      'Total Weight';

  // ============================================================
  // RECEIPT GOLD TABLE
  // ============================================================
  //
  // LOCKED:
  //
  // Photo | Item Name | Weight (g)
  //
  // Do NOT show:
  // - Purity
  // - Gross Weight
  // - Stone
  //
  // ============================================================

  static const String receiptPhoto =
      'Photo';

  static const String receiptItemName =
      'Item Name';

  static const String receiptWeight =
      'Weight (g)';

  // ============================================================
  // RECEIPT FOOTER
  // ============================================================

  static const String generatedDateLabel =
      'Generated Date';

  static const String generatedTimeLabel =
      'Generated Time';

  static const String customerSignatureLabel =
      'Customer Signature';

  static const String authorizedSignatureLabel =
      'Authorized Signature';

  // ============================================================
  // FILE UPLOAD
  // ============================================================

  static const int maxImageSizeMb = 10;

  static const int imageCompressionQuality = 85;

  // ============================================================
  // API TIMEOUT
  // ============================================================

  static const Duration apiTimeout =
      Duration(seconds: 30);

  static const Duration imageTimeout =
      Duration(seconds: 15);

  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String tokenKey =
      'auth_token';

  static const String userKey =
      'user_data';

  static const String userIdKey =
      'user_id';

  static const String usernameKey =
      'username';

  // ============================================================
  // VALIDATION
  // ============================================================

  static const int mobileNumberLength = 10;

  static const int aadhaarNumberLength = 12;

  static const int panNumberLength = 10;

  // ============================================================
  // APP MESSAGES
  // ============================================================

  static const String networkErrorMessage =
      'Unable to connect to server';

  static const String somethingWentWrongMessage =
      'Something went wrong';

  static const String savedSuccessfullyMessage =
      'Saved successfully';

  static const String updatedSuccessfullyMessage =
      'Updated successfully';

  static const String deletedSuccessfullyMessage =
      'Deleted successfully';

  // ============================================================
  // EMPTY VALUE
  // ============================================================

  static const String emptyValue = '-';

  // ============================================================
  // SAFE STRING
  // ============================================================

  static String safeString(
    dynamic value,
  ) {
    if (value == null) {
      return emptyValue;
    }

    final text =
        value.toString().trim();

    return text.isEmpty
        ? emptyValue
        : text;
  }

  // ============================================================
  // SAFE DOUBLE
  // ============================================================

  static double safeDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    var text =
        value.toString().trim();

    if (text.isEmpty) {
      return 0.0;
    }

    text = text
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .trim();

    return double.tryParse(text) ?? 0.0;
  }

  // ============================================================
  // SAFE INT
  // ============================================================

  static int safeInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }
}