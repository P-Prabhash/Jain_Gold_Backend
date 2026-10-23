// lib/models/loan.dart


class Loan {
  final int id;
  final String loanNo;
  final String? manualLoanNo;
  final int customerId;
  final String loanType; // NEW_LOAN, EXISTING_LOAN, ADDITIONAL_LOAN
  final String openedDate;
  final String? manualOpenedDate;
  final String? closedDate;
  final String? manualClosedDate;
  final double principalAmount;
  final double monthlyInterestRate;
  final String interestType;
  final double totalInterest;
  final double manualFinalInterest;
  final double totalDue;
  final double totalPaid;
  final double remainingBalance;
  final String status; // ACTIVE, CLOSED, PARTIALLY_PAID, PARTIALLY_RELEASED
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined fields
  final String? customerName;
  final String? customerCode;
  final String? customerMobile;
  final String? customerPhoto;
  final int totalItemsCount;
  final double totalPledgedWeight;
  final double totalReleasedWeight;
  final double remainingPledgedWeight;

  Loan({
    required this.id,
    required this.loanNo,
    this.manualLoanNo,
    required this.customerId,
    this.loanType = 'NEW_LOAN',
    required this.openedDate,
    this.manualOpenedDate,
    this.closedDate,
    this.manualClosedDate,
    required this.principalAmount,
    this.monthlyInterestRate = 2.0,
    this.interestType = 'MONTHLY_SIMPLE',
    this.totalInterest = 0.0,
    this.manualFinalInterest = 0.0,
    required this.totalDue,
    this.totalPaid = 0.0,
    required this.remainingBalance,
    this.status = 'ACTIVE',
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerCode,
    this.customerMobile,
    this.customerPhoto,
    this.totalItemsCount = 0,
    this.totalPledgedWeight = 0.0,
    this.totalReleasedWeight = 0.0,
    this.remainingPledgedWeight = 0.0,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    final double pledgedW = double.tryParse(
      json['total_pledged_weight']?.toString() ??
      json['pledged_weight']?.toString() ??
      '0.0',
    ) ?? 0.0;

    final double releasedW = double.tryParse(
      json['total_released_weight']?.toString() ??
      json['released_weight']?.toString() ??
      '0.0',
    ) ?? 0.0;

    final double remW = json['remaining_pledged_weight'] != null
        ? (double.tryParse(json['remaining_pledged_weight'].toString()) ?? 0.0)
        : (pledgedW - releasedW);

    final int itemsCount = int.tryParse(
      json['total_items_count']?.toString() ??
      json['collateral_count']?.toString() ??
      json['total_items']?.toString() ??
      '0',
    ) ?? 0;

    return Loan(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      loanNo: json['loan_no'] ?? '',
      manualLoanNo: json['manual_loan_no'],
      customerId: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      loanType: json['loan_type'] ?? 'NEW_LOAN',
      openedDate: json['opened_date'] ?? '',
      manualOpenedDate: json['manual_opened_date'],
      closedDate: json['closed_date'],
      manualClosedDate: json['manual_closed_date'],
      principalAmount: double.tryParse(json['principal_amount']?.toString() ?? '0.0') ?? 0.0,
      monthlyInterestRate: double.tryParse(json['monthly_interest_rate']?.toString() ?? '2.0') ?? 2.0,
      interestType: json['interest_type'] ?? 'MONTHLY_SIMPLE',
      totalInterest: double.tryParse(json['total_interest']?.toString() ?? '0.0') ?? 0.0,
      manualFinalInterest: double.tryParse(json['manual_final_interest']?.toString() ?? '0.0') ?? 0.0,
      totalDue: double.tryParse(json['total_due']?.toString() ?? '0.0') ?? 0.0,
      totalPaid: double.tryParse(json['total_paid']?.toString() ?? '0.0') ?? 0.0,
      remainingBalance: double.tryParse(json['remaining_balance']?.toString() ?? '0.0') ?? 0.0,
      status: json['status'] ?? 'ACTIVE',
      remarks: json['remarks'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      customerName: json['customer_name'],
      customerCode: json['customer_code'],
      customerMobile: json['customer_mobile'],
      customerPhoto: json['customer_photo'],
      totalItemsCount: itemsCount,
      totalPledgedWeight: pledgedW,
      totalReleasedWeight: releasedW,
      remainingPledgedWeight: remW < 0 ? 0.0 : remW,
    );
  }

  bool get isActive => status == 'ACTIVE' || status == 'PARTIALLY_PAID' || status == 'PARTIALLY_RELEASED';
  bool get isClosed => status == 'CLOSED';
}

class LoanCollateralItem {
  final int loanGoldItemId;
  final int goldItemId;
  final String itemName;
  final String purity;
  final double totalWeight;
  final double pledgedWeight;
  final double releasedWeight;
  final String collateralStatus; // PLEDGED, RELEASED
  final String? pledgeDate;
  final String? releaseDate;
  final String? remarks;
  final String? photoUrl;

  LoanCollateralItem({
    required this.loanGoldItemId,
    required this.goldItemId,
    required this.itemName,
    required this.purity,
    required this.totalWeight,
    required this.pledgedWeight,
    this.releasedWeight = 0.0,
    required this.collateralStatus,
    this.pledgeDate,
    this.releaseDate,
    this.remarks,
    this.photoUrl,
  });

  factory LoanCollateralItem.fromJson(Map<String, dynamic> json) {
    return LoanCollateralItem(
      loanGoldItemId: int.tryParse(json['loan_gold_item_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      goldItemId: int.tryParse(json['gold_item_id']?.toString() ?? '0') ?? 0,
      itemName: json['item_name'] ?? '',
      purity: json['purity'] ?? '22K',
      totalWeight: double.tryParse(json['total_weight']?.toString() ?? json['original_item_weight']?.toString() ?? json['weight']?.toString() ?? '0.0') ?? 0.0,
      pledgedWeight: double.tryParse(json['pledged_weight']?.toString() ?? json['weight']?.toString() ?? '0.0') ?? 0.0,
      releasedWeight: double.tryParse(json['released_weight']?.toString() ?? '0.0') ?? 0.0,
      collateralStatus: json['collateral_status'] ?? json['status'] ?? 'PLEDGED',
      pledgeDate: json['pledge_date'],
      releaseDate: json['release_date'],
      remarks: json['remarks'],
      photoUrl: json['photo_url'] ?? json['gold_photo_url'],
    );
  }

  bool get isPledged => collateralStatus == 'PLEDGED';
  bool get isReleased => collateralStatus == 'RELEASED';
}
