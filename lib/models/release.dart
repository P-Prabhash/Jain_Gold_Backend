// lib/models/release.dart

class PartialRelease {
  final int id;
  final String releaseNo;
  final int loanId;
  final int customerId;
  final int? paymentId;
  final double totalWeightReleased;
  final String releaseDate;
  final String releaseTime;
  final String? remarks;
  final String? createdBy;
  final String? createdAt;

  final String releaseType;

  // Joined
  final String? loanNo;
  final String? customerName;
  final String? customerCode;
  final String? customerMobile;
  final double? paymentAmount;
  final int itemsCount;

  PartialRelease({
    required this.id,
    required this.releaseNo,
    required this.loanId,
    required this.customerId,
    this.paymentId,
    required this.releaseType,
    required this.totalWeightReleased,
    required this.releaseDate,
    required this.releaseTime,
    this.remarks,
    this.createdBy,
    this.createdAt,
    this.loanNo,
    this.customerName,
    this.customerCode,
    this.customerMobile,
    this.paymentAmount,
    this.itemsCount = 0,
  });

  factory PartialRelease.fromJson(Map<String, dynamic> json) {
    final rawType = json['release_type']?.toString().toUpperCase();
    final releaseNoStr = json['release_no']?.toString().toUpperCase() ?? '';
    final computedType = (rawType == 'FULL' || releaseNoStr.contains('-FULL-'))
        ? 'FULL RELEASE'
        : 'PARTIAL RELEASE';

    return PartialRelease(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      releaseNo: json['release_no'] ?? '',
      loanId: int.tryParse(json['loan_id']?.toString() ?? '0') ?? 0,
      customerId: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      paymentId: int.tryParse(json['payment_id']?.toString() ?? ''),
      releaseType: computedType,
      totalWeightReleased: double.tryParse(json['total_weight_released']?.toString() ?? '0.0') ?? 0.0,
      releaseDate: json['release_date'] ?? '',
      releaseTime: json['release_time'] ?? '',
      remarks: json['remarks'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      loanNo: json['loan_no'],
      customerName: json['customer_name'],
      customerCode: json['customer_code'],
      customerMobile: json['customer_mobile'],
      paymentAmount: double.tryParse(json['payment_amount']?.toString() ?? ''),
      itemsCount: int.tryParse(json['items_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class ReleaseItem {
  final int id;
  final int releaseId;
  final int goldItemId;
  final String itemName;
  final String purity;
  final double weight;

  ReleaseItem({
    required this.id,
    required this.releaseId,
    required this.goldItemId,
    required this.itemName,
    required this.purity,
    required this.weight,
  });

  factory ReleaseItem.fromJson(Map<String, dynamic> json) {
    return ReleaseItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      releaseId: int.tryParse(json['release_id']?.toString() ?? '0') ?? 0,
      goldItemId: int.tryParse(json['gold_item_id']?.toString() ?? '0') ?? 0,
      itemName: json['item_name'] ?? '',
      purity: json['purity'] ?? '22K',
      weight: double.tryParse(json['weight']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
