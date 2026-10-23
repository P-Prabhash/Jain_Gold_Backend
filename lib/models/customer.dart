// lib/models/customer.dart

class Customer {
  final int id;
  final String customerCode;
  final String name;
  final String mobile;
  final String address;
  final String? aadhaarNumber;
  final String? panNumber;
  final String? photoUrl;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  // Aggregated metrics from API
  final int totalGoldItems;
  final double totalGoldWeight;
  final int totalLoans;
  final int activeLoans;
  final double totalOutstanding;

  Customer({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.mobile,
    required this.address,
    this.aadhaarNumber,
    this.panNumber,
    this.photoUrl,
    this.status = 'ACTIVE',
    this.createdAt,
    this.updatedAt,
    this.totalGoldItems = 0,
    this.totalGoldWeight = 0.0,
    this.totalLoans = 0,
    this.activeLoans = 0,
    this.totalOutstanding = 0.0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: int.tryParse(json['id']?.toString() ?? json['customer_id']?.toString() ?? '0') ?? 0,
      customerCode: json['customer_code'] ?? '',
      name: json['name'] ?? json['customer_name'] ?? '',
      mobile: json['mobile'] ?? '',
      address: json['address'] ?? '',
      aadhaarNumber: json['aadhaar_number'] ?? json['aadhaar'],
      panNumber: json['pan_number'] ?? json['pan'],
      photoUrl: json['photo_url'] ?? json['customer_photo_url'],
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      totalGoldItems: int.tryParse(json['total_gold_items']?.toString() ?? '0') ?? 0,
      totalGoldWeight: double.tryParse(json['total_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      totalLoans: int.tryParse(json['total_loans']?.toString() ?? '0') ?? 0,
      activeLoans: int.tryParse(json['active_loans']?.toString() ?? '0') ?? 0,
      totalOutstanding: double.tryParse(json['total_outstanding']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_code': customerCode,
      'name': name,
      'mobile': mobile,
      'address': address,
      'aadhaar_number': aadhaarNumber,
      'pan_number': panNumber,
      'photo_url': photoUrl,
      'status': status,
    };
  }
}

class CustomerSummary {
  final int totalGoldItems;
  final double totalGoldWeight;
  final double pledgedGoldWeight;
  final double releasedGoldWeight;
  final double availableGoldWeight;
  final double remainingPledgedWeight;
  final int totalLoans;
  final int activeLoans;
  final int closedLoans;
  final double totalLoanAmount;
  final double totalPaid;
  final double totalInterest;
  final double totalOutstanding;

  CustomerSummary({
    this.totalGoldItems = 0,
    this.totalGoldWeight = 0.0,
    this.pledgedGoldWeight = 0.0,
    this.releasedGoldWeight = 0.0,
    this.availableGoldWeight = 0.0,
    this.remainingPledgedWeight = 0.0,
    this.totalLoans = 0,
    this.activeLoans = 0,
    this.closedLoans = 0,
    this.totalLoanAmount = 0.0,
    this.totalPaid = 0.0,
    this.totalInterest = 0.0,
    this.totalOutstanding = 0.0,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      totalGoldItems: int.tryParse(json['total_gold_items']?.toString() ?? '0') ?? 0,
      totalGoldWeight: double.tryParse(json['total_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      pledgedGoldWeight: double.tryParse(json['pledged_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      releasedGoldWeight: double.tryParse(json['released_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      availableGoldWeight: double.tryParse(json['available_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      remainingPledgedWeight: double.tryParse(json['remaining_pledged_weight']?.toString() ?? '0.0') ?? 0.0,
      totalLoans: int.tryParse(json['total_loans']?.toString() ?? '0') ?? 0,
      activeLoans: int.tryParse(json['active_loans']?.toString() ?? '0') ?? 0,
      closedLoans: int.tryParse(json['closed_loans']?.toString() ?? '0') ?? 0,
      totalLoanAmount: double.tryParse(json['total_loan_amount']?.toString() ?? '0.0') ?? 0.0,
      totalPaid: double.tryParse(json['total_paid']?.toString() ?? '0.0') ?? 0.0,
      totalInterest: double.tryParse(json['total_interest']?.toString() ?? '0.0') ?? 0.0,
      totalOutstanding: double.tryParse(json['total_outstanding']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
