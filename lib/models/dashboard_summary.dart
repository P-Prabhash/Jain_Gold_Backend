// lib/models/dashboard_summary.dart

import 'loan.dart';
import 'payment.dart';
import 'release.dart';

class DashboardSummary {
  // 10 Primary KPIs
  final int totalCustomers;
  final int totalGoldItems;
  final int goldAvailableCount;
  final int goldPledgedCount;
  final int goldReleasedCount;
  final double totalGoldWeight;
  final double availableGoldWeight;
  final double pledgedGoldWeight;
  final double releasedGoldWeight;

  final double totalGivenLoan;
  final double todayGivenLoan;
  final int todayGivenLoanCount;
  final int todayClosedLoans;
  final double todayClosedAmount;
  final int totalClosedLoans;
  final double totalCollection;
  final double totalOutstanding;
  final double totalPartial;
  final int totalPartialCount;
  final int totalReleases;
  final double totalReleasedWeight;

  // Feeds
  final List<Loan> recentLoans;
  final List<Payment> recentPayments;
  final List<PartialRelease> recentReleases;

  DashboardSummary({
    this.totalCustomers = 0,
    this.totalGoldItems = 0,
    this.goldAvailableCount = 0,
    this.goldPledgedCount = 0,
    this.goldReleasedCount = 0,
    this.totalGoldWeight = 0.0,
    this.availableGoldWeight = 0.0,
    this.pledgedGoldWeight = 0.0,
    this.releasedGoldWeight = 0.0,
    this.totalGivenLoan = 0.0,
    this.todayGivenLoan = 0.0,
    this.todayGivenLoanCount = 0,
    this.todayClosedLoans = 0,
    this.todayClosedAmount = 0.0,
    this.totalClosedLoans = 0,
    this.totalCollection = 0.0,
    this.totalOutstanding = 0.0,
    this.totalPartial = 0.0,
    this.totalPartialCount = 0,
    this.totalReleases = 0,
    this.totalReleasedWeight = 0.0,
    this.recentLoans = const [],
    this.recentPayments = const [],
    this.recentReleases = const [],
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    var rawRecentLoans = json['recent_loans'] as List? ?? [];
    var rawRecentPayments = json['recent_payments'] as List? ?? [];
    var rawRecentReleases = json['recent_releases'] as List? ?? [];

    return DashboardSummary(
      totalCustomers: int.tryParse(json['total_customers']?.toString() ?? '0') ?? 0,
      totalGoldItems: int.tryParse(json['total_gold_items']?.toString() ?? '0') ?? 0,
      goldAvailableCount: int.tryParse(json['gold_available_count']?.toString() ?? '0') ?? 0,
      goldPledgedCount: int.tryParse(json['gold_pledged_count']?.toString() ?? '0') ?? 0,
      goldReleasedCount: int.tryParse(json['gold_released_count']?.toString() ?? '0') ?? 0,
      totalGoldWeight: double.tryParse(json['total_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      availableGoldWeight: double.tryParse(json['available_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      pledgedGoldWeight: double.tryParse(json['pledged_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      releasedGoldWeight: double.tryParse(json['released_gold_weight']?.toString() ?? '0.0') ?? 0.0,
      totalGivenLoan: double.tryParse(json['total_given_loan']?.toString() ?? '0.0') ?? 0.0,
      todayGivenLoan: double.tryParse(json['today_given_loan']?.toString() ?? '0.0') ?? 0.0,
      todayGivenLoanCount: int.tryParse(json['today_given_loan_count']?.toString() ?? '0') ?? 0,
      todayClosedLoans: int.tryParse(json['today_closed_loans']?.toString() ?? '0') ?? 0,
      todayClosedAmount: double.tryParse(json['today_closed_amount']?.toString() ?? '0.0') ?? 0.0,
      totalClosedLoans: int.tryParse(json['total_closed_loans']?.toString() ?? '0') ?? 0,
      totalCollection: double.tryParse(json['total_collection']?.toString() ?? '0.0') ?? 0.0,
      totalOutstanding: double.tryParse(json['total_outstanding']?.toString() ?? '0.0') ?? 0.0,
      totalPartial: double.tryParse(json['total_partial']?.toString() ?? '0.0') ?? 0.0,
      totalPartialCount: int.tryParse(json['total_partial_count']?.toString() ?? '0') ?? 0,
      totalReleases: int.tryParse(json['total_releases']?.toString() ?? '0') ?? 0,
      totalReleasedWeight: double.tryParse(json['total_released_weight']?.toString() ?? '0.0') ?? 0.0,
      recentLoans: rawRecentLoans.map((l) => Loan.fromJson(l)).toList(),
      recentPayments: rawRecentPayments.map((p) => Payment.fromJson(p)).toList(),
      recentReleases: rawRecentReleases.map((r) => PartialRelease.fromJson(r)).toList(),
    );
  }
}
