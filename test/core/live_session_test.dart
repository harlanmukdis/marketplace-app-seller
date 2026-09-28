import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/live/live_session.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  Map<String, dynamic> detail(String status) => <String, dynamic>{
        'id': '1',
        'store_id': '26',
        'host_user_id': '30',
        'title': 'Probe Live',
        'stream_key': '9476b927e11356ae8c88fe4dbdcc8c15',
        'playback_url': null,
        'status': status,
        'viewer_count': '0',
        'peak_viewer_count': '0',
        'scheduled_at': null,
        'started_at': '2026-09-29 07:10:00',
        'ended_at': null,
        'products': <dynamic>[
          <String, dynamic>{
            'id': '1',
            'live_session_id': '1',
            'product_id': '23',
            'is_pinned': '1',
            'live_price': '45000.00',
            'sort_order': '1',
          },
        ],
      };

  test('reads a session with a pinned product', () {
    final s = LiveSession.fromJson(detail('live'));

    expect(s.isLive, isTrue);
    expect(s.products.single.isPinned, isTrue);
    expect(s.products.single.livePrice, 45000);
    // The public detail leaks the key; the model reads it for the owner.
    expect(s.streamKey, isNotEmpty);
  });

  test('gates transitions the server does not', () {
    expect(LiveSession.fromJson(detail('scheduled')).canStart, isTrue);
    expect(LiveSession.fromJson(detail('live')).canEnd, isTrue);
    // Verified: the server restarts an ended session; the app must not offer.
    final ended = LiveSession.fromJson(detail('ended'));
    expect(ended.canStart, isFalse);
    expect(ended.canEnd, isFalse);
    expect(ended.isOver, isTrue);
  });

  test('reads what start hands back', () {
    final i = LiveIngest.fromJson(<String, dynamic>{
      'rtmp_url': 'rtmp://ingest.marketplace.id/live',
      'stream_key': 'abc',
      'playback_url': 'https://cdn.marketplace.id/live/1/index.m3u8',
    });
    expect(i.rtmpUrl, startsWith('rtmp://'));
  });
}
