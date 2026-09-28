import '../../../utils/json_parse.dart';

/// A ticket to the platform — "Xpedia 911" (API v1.23.0).
///
/// A separate channel from Chat: Chat is buyer <-> seller, a ticket is the
/// account <-> platform admins. Tickets belong to the **user**, not the store.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.category,
    required this.subject,
    this.description = '',
    this.status = SupportTicketStatus.open,
    this.storeId,
    this.relatedOrderId,
    this.createdAt,
    this.resolvedAt,
  });

  final int id;
  final String ticketNumber;
  final String category;
  final String subject;
  final String description;
  final String status;
  final int? storeId;
  final int? relatedOrderId;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: asInt(json['id']),
        ticketNumber: asString(json['ticket_number']),
        category: asString(json['category']),
        subject: asString(json['subject']),
        description: asString(json['description']),
        status: asString(json['status'], fallback: SupportTicketStatus.open),
        storeId: asIntOrNull(json['store_id']),
        relatedOrderId: asIntOrNull(json['related_order_id']),
        createdAt: asCreatedDate(json),
        resolvedAt: asDateTime(json['resolved_at']),
      );

  bool get isClosed =>
      status == SupportTicketStatus.resolved ||
      status == SupportTicketStatus.closed;
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.message,
    this.isAdminReply = false,
    this.attachmentUrl,
    this.createdAt,
  });

  final int id;
  final String message;
  final bool isAdminReply;
  final String? attachmentUrl;
  final DateTime? createdAt;

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) =>
      SupportTicketMessage(
        id: asInt(json['id']),
        message: asString(json['message']),
        isAdminReply: asBool(json['is_admin_reply']),
        attachmentUrl: asStringOrNull(json['attachment_url']),
        createdAt: asCreatedDate(json),
      );
}

/// Exactly four categories, and the server refuses any other.
///
/// They do **not** match the design's S-41 tiles (Pesanan, Pengiriman, Wallet,
/// Produk): the backend picked its own four, noting the blueprint never named
/// them. Shipping issues fold into the order category, and there is no product
/// category at all. The labels follow the server until the two agree.
abstract class SupportCategory {
  static const String orderTransaction = 'order_transaction';
  static const String accountSecurity = 'account_security';
  static const String paymentWallet = 'payment_wallet';
  static const String reportViolation = 'report_violation';

  static const List<String> all = <String>[
    orderTransaction,
    paymentWallet,
    accountSecurity,
    reportViolation,
  ];

  static String label(String? c) => switch (c) {
        orderTransaction => 'Pesanan & Pengiriman',
        accountSecurity => 'Akun & Keamanan',
        paymentWallet => 'Xpedia Wallet',
        reportViolation => 'Laporan Pelanggaran',
        _ => c ?? '-',
      };
}

abstract class SupportTicketStatus {
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static String label(String? s) => switch (s) {
        open => 'Terbuka',
        inProgress => 'Diproses',
        resolved => 'Selesai',
        closed => 'Ditutup',
        _ => s ?? '-',
      };
}

extension SupportCategoryHint on String {
  String get supportHint => switch (this) {
        SupportCategory.orderTransaction =>
          'Pembatalan, refund, resi macet, kurir terlambat',
        SupportCategory.paymentWallet =>
          'Pencairan tertahan, rekonsiliasi dana',
        SupportCategory.accountSecurity => 'Akses akun, PIN, verifikasi toko',
        SupportCategory.reportViolation =>
          'Penipuan, pelanggaran, konten terlarang',
        _ => '',
      };
}
