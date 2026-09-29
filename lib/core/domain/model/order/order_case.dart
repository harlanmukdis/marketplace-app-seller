/// Buyer-raised cases on an order: a cancellation request after the waybill
/// (S-18) and a complaint with evidence (S-19).
///
/// ⏳ Neither exists in the API. `refund-request` carries only a reason and
/// an amount, has no evidence, no deadline and no seller-side list; there is
/// no cancellation request at all. These models are what the two screens
/// need, and what the backend is asked to provide.
class CaseItem {
  const CaseItem({
    required this.name,
    required this.price,
    this.variant,
    this.quantity = 1,
  });

  final String name;
  final String? variant;
  final int quantity;
  final int price;
}

abstract class CaseStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String escalated = 'escalated';

  static String label(String s) => switch (s) {
        pending => 'Menunggu Respon Seller',
        approved => 'Disetujui',
        rejected => 'Ditolak',
        escalated => 'Dieskalasi ke Mediasi',
        _ => s,
      };
}

class CancellationRequest {
  const CancellationRequest({
    required this.id,
    required this.orderNumber,
    required this.buyerName,
    required this.reason,
    required this.items,
    this.orderId,
    this.buyerNote,
    this.requestedAt,
    this.respondBy,
    this.orderStage,
    this.courier,
    this.awb,
    this.status = CaseStatus.pending,
    this.rejectReason,
    this.isSample = false,
  });

  final int id;
  final int? orderId;
  final String orderNumber;

  /// Masked, as everywhere a buyer appears.
  final String buyerName;
  final String reason;
  final String? buyerNote;
  final DateTime? requestedAt;

  /// Past this, the system approves on the seller's behalf.
  final DateTime? respondBy;
  final String? orderStage;
  final String? courier;
  final String? awb;
  final List<CaseItem> items;
  final String status;
  final String? rejectReason;
  final bool isSample;

  bool get isPending => status == CaseStatus.pending;

  int get total => items.fold(0, (n, i) => n + i.price * i.quantity);

  CancellationRequest decided(String status, {String? rejectReason}) =>
      CancellationRequest(
        id: id,
        orderId: orderId,
        orderNumber: orderNumber,
        buyerName: buyerName,
        reason: reason,
        buyerNote: buyerNote,
        requestedAt: requestedAt,
        respondBy: respondBy,
        orderStage: orderStage,
        courier: courier,
        awb: awb,
        items: items,
        status: status,
        rejectReason: rejectReason,
        isSample: isSample,
      );

  /// The fixed list S-18 offers when refusing.
  static const List<String> rejectReasons = <String>[
    'Paket sudah diserahkan ke kurir',
    'Paket sedang dalam proses packing ketat',
    'Varian yang diminta pembeli tetap tersedia',
  ];
}

class CaseEvidence {
  const CaseEvidence({required this.label, this.isVideo = false, this.url});

  final String label;
  final bool isVideo;
  final String? url;
}

/// The four answers S-19 allows a seller.
enum ComplaintResolution {
  refund(
      'Setujui Retur & Refund',
      'Pembeli kirim balik unit. Dana dilepas setelah Anda menerima dan '
          'memverifikasi kondisi barang di gudang.'),
  replacement(
      'Setujui Penggantian Barang (Replacement)',
      'Kirimkan unit baru kepada pembeli tanpa pembatalan pesanan saat '
          'barang retur tiba.'),
  reject(
      'Tolak Komplain',
      'Unggah bukti video serah terima, foto packing utuh, atau serial '
          'number sebelum pengiriman awal.'),
  escalate(
      'Eskalasi Kasus ke Tim Mediasi Xpedia',
      'Gunakan jika terdapat perbedaan klaim yang belum tercapai '
          'kesepakatan secara mufakat.');

  const ComplaintResolution(this.title, this.description);

  final String title;
  final String description;
}

class Complaint {
  const Complaint({
    required this.id,
    required this.number,
    required this.issue,
    required this.requestedSolution,
    required this.amount,
    required this.item,
    required this.buyerName,
    this.orderId,
    this.orderNumber,
    this.buyerCity,
    this.buyerNote,
    this.evidence = const <CaseEvidence>[],
    this.awb,
    this.receivedAt,
    this.respondBy,
    this.status = CaseStatus.pending,
    this.resolution,
    this.isSample = false,
  });

  final int id;
  final String number;
  final int? orderId;
  final String? orderNumber;
  final String issue;
  final String requestedSolution;
  final int amount;
  final CaseItem item;
  final String buyerName;
  final String? buyerCity;
  final String? buyerNote;
  final List<CaseEvidence> evidence;
  final String? awb;
  final DateTime? receivedAt;

  /// 2×24 working hours from filing; the design's countdown.
  final DateTime? respondBy;
  final String status;
  final ComplaintResolution? resolution;
  final bool isSample;

  bool get isPending => status == CaseStatus.pending;

  Complaint resolved(ComplaintResolution r) => Complaint(
        id: id,
        number: number,
        orderId: orderId,
        orderNumber: orderNumber,
        issue: issue,
        requestedSolution: requestedSolution,
        amount: amount,
        item: item,
        buyerName: buyerName,
        buyerCity: buyerCity,
        buyerNote: buyerNote,
        evidence: evidence,
        awb: awb,
        receivedAt: receivedAt,
        respondBy: respondBy,
        status: switch (r) {
          ComplaintResolution.reject => CaseStatus.rejected,
          ComplaintResolution.escalate => CaseStatus.escalated,
          _ => CaseStatus.approved,
        },
        resolution: r,
        isSample: isSample,
      );
}

/// "Sisa 18j 30m" — or "Lewat batas" once past.
String remainingLabel(DateTime? deadline, {DateTime? now}) {
  if (deadline == null) return '';
  final left = deadline.difference(now ?? DateTime.now());
  if (left.isNegative) return 'Lewat batas';
  final h = left.inHours;
  final m = left.inMinutes % 60;
  return h > 0 ? 'Sisa ${h}j ${m}m' : 'Sisa ${m}m';
}
