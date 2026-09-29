import '../../data_state.dart';
import '../model/live/live_insights.dart';

/// Per-session sales and the comment feed (S-36). Implemented by
/// `DemoLiveInsightsRepository` until the live module reports them.
abstract class LiveInsightsRepository {
  Future<DataState<LiveStats>> getStats(int sessionId);

  Future<DataState<List<LiveComment>>> getComments(int sessionId);
}
