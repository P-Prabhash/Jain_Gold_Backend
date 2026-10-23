// lib/models/receipt_data.dart

class ReceiptModel {
  final int? id;
  final String receiptNo;
  final String receiptType; // PAWN_LOAN, PAYMENT, PARTIAL_RELEASE, CLOSURE
  final String? referenceId;
  final int? customerId;
  final int? loanId;
  final String? generatedAt;

  /// Complete receipt payload.
  ///
  /// This intentionally keeps the complete backend response so fields such as:
  /// - customer.photo_url
  /// - collateral[].photo_url
  /// - released_gold[].photo_url
  /// - remaining_pledged_gold[].photo_url
  /// - gold.released_items[].photo_url
  /// are preserved for the A4 viewer and PDF receipt.
  final Map<String, dynamic> rawData;

  ReceiptModel({
    this.id,
    required this.receiptNo,
    required this.receiptType,
    this.referenceId,
    this.customerId,
    this.loanId,
    this.generatedAt,
    required this.rawData,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final dynamic receiptData = json['receipt_data'];

    Map<String, dynamic> raw;

    if (receiptData is Map<String, dynamic>) {
      raw = Map<String, dynamic>.from(receiptData);
    } else if (receiptData is Map) {
      raw = Map<String, dynamic>.from(receiptData);
    } else {
      // If the API does not wrap the receipt inside receipt_data,
      // preserve the complete response.
      raw = Map<String, dynamic>.from(json);
    }

    // Preserve important top-level receipt metadata inside rawData too.
    //
    // This is useful when the backend sends metadata outside receipt_data.
    if (!raw.containsKey('receipt_no') &&
        json['receipt_no'] != null) {
      raw['receipt_no'] = json['receipt_no'];
    }

    if (!raw.containsKey('receipt_type') &&
        json['receipt_type'] != null) {
      raw['receipt_type'] = json['receipt_type'];
    }

    if (!raw.containsKey('reference_id') &&
        json['reference_id'] != null) {
      raw['reference_id'] = json['reference_id'];
    }

    if (!raw.containsKey('customer_id') &&
        json['customer_id'] != null) {
      raw['customer_id'] = json['customer_id'];
    }

    if (!raw.containsKey('loan_id') &&
        json['loan_id'] != null) {
      raw['loan_id'] = json['loan_id'];
    }

    if (!raw.containsKey('generated_at') &&
        json['generated_at'] != null) {
      raw['generated_at'] = json['generated_at'];
    }

    final String receiptNo =
        json['receipt_no']?.toString() ??
        raw['receipt_no']?.toString() ??
        '';

    final String receiptType =
        json['receipt_type']?.toString() ??
        raw['receipt_type']?.toString() ??
        'PAYMENT';

    return ReceiptModel(
      id: _parseNullableInt(json['id']),
      receiptNo: receiptNo,
      receiptType: receiptType,
      referenceId:
          json['reference_id']?.toString() ??
          raw['reference_id']?.toString(),
      customerId:
          _parseNullableInt(
            json['customer_id'] ??
                raw['customer_id'],
          ),
      loanId:
          _parseNullableInt(
            json['loan_id'] ??
                raw['loan_id'],
          ),
      generatedAt:
          json['generated_at']?.toString() ??
          raw['generated_at']?.toString(),
      rawData: raw,
    );
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }
}