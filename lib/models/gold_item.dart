// lib/models/gold_item.dart

class GoldItem {
  final int id;
  final int customerId;
  final String itemName;
  final String purity;
  final double weight;
  final String? remarks;
  final String? photoUrl;
  final String status; // AVAILABLE, PLEDGED, RELEASED, PARTIALLY_RELEASED
  final String? createdAt;
  final String? customerName;
  final String? customerCode;
  final String? customerMobile;
  final String? loanNo;
  final String? lockerNo;
  final String? loanStatus;

  GoldItem({
    required this.id,
    required this.customerId,
    required this.itemName,
    this.purity = '22K',
    required this.weight,
    this.remarks,
    this.photoUrl,
    this.status = 'AVAILABLE',
    this.createdAt,
    this.customerName,
    this.customerCode,
    this.customerMobile,
    this.loanNo,
    this.lockerNo,
    this.loanStatus,
  });

  factory GoldItem.fromJson(Map<String, dynamic> json) {
    final rawId = int.tryParse(json['id']?.toString() ?? '0') ?? 0;
    return GoldItem(
      id: rawId,
      customerId: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      itemName: json['item_name'] ?? '',
      purity: json['purity'] ?? '22K',
      weight: double.tryParse(json['weight']?.toString() ?? '0.0') ?? 0.0,
      remarks: json['remarks'],
      photoUrl: json['photo_url'],
      status: json['status'] ?? 'AVAILABLE',
      createdAt: json['created_at'],
      customerName: json['customer_name'],
      customerCode: json['customer_code'],
      customerMobile: json['customer_mobile'],
      loanNo: json['loan_no'],
      lockerNo: json['locker_no'] ?? 'LCK-${rawId.toString().padLeft(3, '0')}',
      loanStatus: json['loan_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'item_name': itemName,
      'purity': purity,
      'weight': weight,
      'remarks': remarks,
      'photo_url': photoUrl,
      'status': status,
    };
  }

  bool get isAvailable => status == 'AVAILABLE';
  bool get isPledged => status == 'PLEDGED';
  bool get isReleased => status == 'RELEASED';
}
