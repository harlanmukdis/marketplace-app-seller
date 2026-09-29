/// A platform-run campaign a seller can join (S-31, "Ikut campaign").
///
/// ⏳ Submitting products exists (`POST /stores/{id}/campaigns/{id}/products`)
/// but the list of campaigns is admin-only, so a seller has nothing to pick
/// from. This is the shape the missing seller-side list should have.
class PlatformCampaign {
  const PlatformCampaign({
    required this.id,
    required this.name,
    required this.description,
    this.startAt,
    this.endAt,
    this.registerBy,
    this.minDiscountPercent = 0,
    this.benefit,
    this.submittedProductIds = const <int>[],
  });

  final int id;
  final String name;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? registerBy;

  /// The smallest discount a submitted product must carry.
  final int minDiscountPercent;
  final String? benefit;

  /// Products this store has submitted, awaiting admin review.
  final List<int> submittedProductIds;

  bool isOpenAt(DateTime now) =>
      registerBy == null || now.isBefore(registerBy!);
}
