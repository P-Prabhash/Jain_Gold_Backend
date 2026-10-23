// lib/models/transaction.dart

class LoanTransaction {
  final int id;
  final String transactionCode;
  final int customerId;
  final int loanId;
  final String transactionType;
  final double amount;
  final double weight;
  final String? referenceId;
  final String date;
  final String time;
  final String? createdBy;
  final String? remarks;
  final String? createdAt;

  // Joined
  final String? customerName;
  final String? customerCode;
  final String? customerMobile;
  final String? loanNo;
  final String? loanType;
  final String? loanStatus;

  LoanTransaction({
    required this.id,
    required this.transactionCode,
    required this.customerId,
    required this.loanId,
    required this.transactionType,
    required this.amount,
    required this.weight,
    this.referenceId,
    required this.date,
    required this.time,
    this.createdBy,
    this.remarks,
    this.createdAt,
    this.customerName,
    this.customerCode,
    this.customerMobile,
    this.loanNo,
    this.loanType,
    this.loanStatus,
  });

  factory LoanTransaction.fromJson(Map<String, dynamic> json) {
    return LoanTransaction(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      transactionCode: json['transaction_code'] ?? '',
      customerId: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      loanId: int.tryParse(json['loan_id']?.toString() ?? '0') ?? 0,
      transactionType: json['transaction_type'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0.0') ?? 0.0,
      weight: double.tryParse(json['weight']?.toString() ?? '0.0') ?? 0.0,
      referenceId: json['reference_id'],
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      createdBy: json['created_by'],
      remarks: json['remarks'],
      createdAt: json['created_at'],
      customerName: json['customer_name'],
      customerCode: json['customer_code'],
      customerMobile: json['customer_mobile'],
      loanNo: json['loan_no'],
      loanType: json['loan_type'],
      loanStatus: json['loan_status'],
    );
  }

  String get humanReadableType {
    switch (transactionType) {
      case 'LOAN_CREATED':
        return 'New Loan Created';
      case 'EXISTING_LOAN_CREATED':
        return 'Existing Loan Registered';
      case 'ADDITIONAL_LOAN':
        return 'Additional Loan Created';
      case 'PAYMENT':
        return 'Payment Received';
      case 'PARTIAL_PAYMENT':
        return 'Partial Payment Received';
      case 'FULL_PAYMENT':
        return 'Full Payment Received';
      case 'FINAL_MANUAL_INTEREST':
        return 'Manual Final Interest';
      case 'FINAL_SETTLEMENT':
        return 'Final Settlement Payment';
      case 'PARTIAL_RELEASE':
        return 'Partial Gold Release';
      case 'FULL_RELEASE':
        return 'Full Gold Release';
      case 'LOAN_CLOSED':
        return 'Loan Closed';
      default:
        return transactionType.replaceAll('_', ' ');
    }
  }
}
