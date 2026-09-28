import '../../../utils/json_parse.dart';

/// A live-selling session (S-36).
///
/// ⚠️ `GET /live-sessions/{id}` is **public and returns every column,
/// `stream_key` included** — anyone who knows an id can read the key. The
/// app shows it only to the owner, but the leak is the backend's to close.
class LiveSession {
  const LiveSession({
    required this.id,
    required this.title,
    this.status = LiveStatus.scheduled,
    this.storeId,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.viewerCount = 0,
    this.peakViewerCount = 0,
    this.streamKey,
    this.playbackUrl,
    this.products = const <LiveProduct>[],
  });

  final int id;
  final String title;
  final String status;
  final int? storeId;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int viewerCount;
  final int peakViewerCount;
  final String? streamKey;
  final String? playbackUrl;
  final List<LiveProduct> products;

  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession(
        id: asInt(json['id']),
        title: asString(json['title']),
        status: asString(json['status'], fallback: LiveStatus.scheduled),
        storeId: asIntOrNull(json['store_id']),
        scheduledAt: asDateTime(json['scheduled_at']),
        startedAt: asDateTime(json['started_at']),
        endedAt: asDateTime(json['ended_at']),
        viewerCount: asInt(json['viewer_count']),
        peakViewerCount: asInt(json['peak_viewer_count']),
        streamKey: asStringOrNull(json['stream_key']),
        playbackUrl: asStringOrNull(json['playback_url']),
        products: asModelList(json['products'], LiveProduct.fromJson),
      );

  /// The server checks no transitions: an ended session can be "started"
  /// again. These flags are the only guard.
  bool get canStart => status == LiveStatus.scheduled;
  bool get canEnd => status == LiveStatus.live;
  bool get isLive => status == LiveStatus.live;
  bool get isOver =>
      status == LiveStatus.ended || status == LiveStatus.cancelled;

  Duration? get duration {
    final a = startedAt;
    if (a == null) return null;
    return (endedAt ?? DateTime.now()).difference(a);
  }
}

class LiveProduct {
  const LiveProduct({
    required this.productId,
    this.isPinned = false,
    this.livePrice,
    this.sortOrder = 0,
  });

  final int productId;
  final bool isPinned;

  /// Null means the product's normal price.
  final int? livePrice;
  final int sortOrder;

  factory LiveProduct.fromJson(Map<String, dynamic> json) => LiveProduct(
        productId: asInt(json['product_id']),
        isPinned: asBool(json['is_pinned']),
        livePrice: asIntOrNull(json['live_price']),
        sortOrder: asInt(json['sort_order']),
      );
}

class LiveVoucher {
  const LiveVoucher({
    required this.voucherId,
    required this.code,
    this.quota = 0,
    this.discountType,
    this.discountValue = 0,
  });

  final int voucherId;
  final String code;
  final int quota;
  final String? discountType;
  final int discountValue;

  factory LiveVoucher.fromJson(Map<String, dynamic> json) => LiveVoucher(
        voucherId: asInt(json['voucher_id']),
        code: asString(json['code']),
        quota: asInt(json['quota']),
        discountType: asStringOrNull(json['discount_type']),
        discountValue: asInt(json['discount_value']),
      );
}

/// What `start` hands back: where an encoder such as OBS should push.
class LiveIngest {
  const LiveIngest({
    required this.rtmpUrl,
    required this.streamKey,
    this.playbackUrl,
  });

  final String rtmpUrl;
  final String streamKey;
  final String? playbackUrl;

  factory LiveIngest.fromJson(Map<String, dynamic> json) => LiveIngest(
        rtmpUrl: asString(json['rtmp_url']),
        streamKey: asString(json['stream_key']),
        playbackUrl: asStringOrNull(json['playback_url']),
      );
}

abstract class LiveStatus {
  static const String scheduled = 'scheduled';
  static const String live = 'live';
  static const String ended = 'ended';
  static const String cancelled = 'cancelled';

  static String label(String s) => switch (s) {
        scheduled => 'Terjadwal',
        live => 'Sedang Live',
        ended => 'Selesai',
        cancelled => 'Dibatalkan',
        _ => s,
      };
}
