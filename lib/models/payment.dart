// lib/models/payment.dart

class Payment {
  final int id;
  final String receiptNo;
  final int loanId;
  final int customerId;
  final String paymentType; // NORMAL, PARTIAL, FINAL_SETTLEMENT, RELEASE_PAYMENT
  final double amount;
  final String paymentDate;
  final String paymentTime;
  final String paymentMode; // CASH, BANK_TRANSFER, UPI, CHEQUE
  final double previousPaid;
  final double newTotalPaid;
  final double remainingBalance;
  final String? remarks;
  final String? createdBy;
  final String? createdAt;

  // Joined
  final String? loanNo;
  final String? loanType;
  final String? loanStatus;
  final String? customerName;
  final String? customerCode;
  final String? customerMobile;

  Payment({
    required this.id,
    required this.receiptNo,
    required this.loanId,
    required this.customerId,
    this.paymentType = 'PARTIAL',
    required this.amount,
    required this.paymentDate,
    required this.paymentTime,
    this.paymentMode = 'CASH',
    required this.previousPaid,
    required this.newTotalPaid,
    required this.remainingBalance,
    this.remarks,
    this.createdBy,
    this.createdAt,
    this.loanNo,
    this.loanType,
    this.loanStatus,
    this.customerName,
    this.customerCode,
    this.customerMobile,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      receiptNo: json['receipt_no'] ?? '',
      loanId: int.tryParse(json['loan_id']?.toString() ?? '0') ?? 0,
      customerId: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      paymentType: json['payment_type'] ?? 'PARTIAL',
      amount: double.tryParse(json['amount']?.toString() ?? '0.0') ?? 0.0,
      paymentDate: json['payment_date'] ?? '',
      paymentTime: json['payment_time'] ?? '',
      paymentMode: json['payment_mode'] ?? 'CASH',
      previousPaid: double.tryParse(json['previous_paid']?.toString() ?? '0.0') ?? 0.0,
      newTotalPaid: double.tryParse(json['new_total_paid']?.toString() ?? '0.0') ?? 0.0,
      remainingBalance: double.tryParse(json['remaining_balance']?.toString() ?? '0.0') ?? 0.0,
      remarks: json['remarks'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      loanNo: json['loan_no'],
      loanType: json['loan_type'],
      loanStatus: json['loan_status'],
      customerName: json['customer_name'],
      customerCode: json['customer_code'],
      customerMobile: json['customer_mobile'],
    );
  }

  bool get isPartial => paymentType == 'PARTIAL';
  bool get isFinalSettlement => paymentType == 'FINAL_SETTLEMENT';
}
