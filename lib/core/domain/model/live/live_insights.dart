/// What S-36 shows that the live API does not return yet: a comment feed,
/// and orders / gross sales attributed to one session.
class LiveStats {
  const LiveStats({
    required this.orders,
    required this.grossSales,
    this.totalViews = 0,
  });

  final int orders;
  final int grossSales;
  final int totalViews;
}

class LiveComment {
  const LiveComment({
    required this.buyerName,
    required this.text,
    this.at,
    this.checkedOut = false,
  });

  /// Masked, like every buyer the seller sees.
  final String buyerName;
  final String text;
  final DateTime? at;
  final bool checkedOut;
}
