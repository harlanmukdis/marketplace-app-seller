import '../../../utils/json_parse.dart';

/// One row of `GET /me/notifications`.
///
/// The inbox is **per user, not per store**. An account that owns several
/// shops gets one stream for all of them, and nothing in the payload says
/// which store a notification came from — only [data] can, and only when the
/// sender bothered to put something there.
///
/// Twenty to a page, newest first, and **no `meta`** — the same silent
/// pagination as every other list on this API, so a short page is the only
/// end-of-list signal.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const <String, dynamic>{},
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String? body;

  /// Arrives as a **JSON string**, not an object — the same shape trap as
  /// `variant_options` on a product variant. Read through [asEncodedMap].
  final Map<String, dynamic> data;

  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asInt(json['id']),
        type: asString(json['type']),
        title: asString(json['title']),
        body: asStringOrNull(json['body']),
        data: asEncodedMap(json['data']),
        isRead: asBool(json['is_read']),
        createdAt: asCreatedDate(json),
      );

  /// The order this is about, when it is about one. `order_new` carries
  /// `{order_id, order_number}`, which is what makes the row actionable —
  /// without it the seller would have to go hunting in the order list.
  int? get orderId => asIntOrNull(data['order_id']);

  String? get orderNumber => asStringOrNull(data['order_number']);

  bool get isAboutOrder => orderId != null;

  /// Present on `staff_invitation`: accepting it joins the inviting store.
  String? get invitationToken => asStringOrNull(data['invitation_token']);
}

/// The `type` values a seller actually sees.
///
/// Not a closed list — the column is free text and admin broadcasts can carry
/// anything — so [label] falls through to the raw value rather than hiding an
/// unknown notification.
abstract class NotificationType {
  /// Sent to the store owner when a buyer confirms checkout (v1.5.0). Until
  /// that release the order lifecycle raised no notifications at all; staff
  /// invitations were the only thing that ever called `Notification_model`.
  static const String orderNew = 'order_new';
  static const String orderPaid = 'order_paid';
  static const String staffInvitation = 'staff_invitation';

  static String label(String? type) => switch (type) {
        orderNew => 'Pesanan baru',
        orderPaid => 'Pesanan dibayar',
        staffInvitation => 'Undangan staf',
        _ => type == null || type.isEmpty ? 'Notifikasi' : type,
      };
}
