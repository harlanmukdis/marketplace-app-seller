import '../../data_state.dart';
import '../../domain/model/live/live_insights.dart';
import '../../domain/repositories/live_insights_repository.dart';
import 'demo_support.dart';

class DemoLiveInsightsRepository implements LiveInsightsRepository {
  const DemoLiveInsightsRepository();

  @override
  Future<DataState<LiveStats>> getStats(int sessionId) => demoOr(
      'Statistik penjualan live',
      () => const LiveStats(orders: 84, grossSales: 3425000, totalViews: 8420));

  @override
  Future<DataState<List<LiveComment>>> getComments(int sessionId) {
    final now = DateTime.now();
    return demoOr(
        'Komentar live',
        () => <LiveComment>[
              LiveComment(
                buyerName: 'D******',
                text: 'Kak kopinya single origin Gayo asli kan?',
                at: now.subtract(const Duration(minutes: 2)),
              ),
              LiveComment(
                buyerName: 'R******',
                text: 'Checkout 2 kak yang 250g, tolong kirim hari ini ya!',
                at: now.subtract(const Duration(minutes: 1)),
                checkedOut: true,
              ),
              LiveComment(
                buyerName: 'S****',
                text: 'Bisa request giling halus untuk V60?',
                at: now,
              ),
            ]);
  }
}
