import '../../data_state.dart';
import '../model/notification/announcement.dart';

/// Platform announcements (S-11) and help-centre articles for global
/// search (S-12). Implemented by `DemoDiscoveryRepository` until the API has
/// either. Orders and products in search come from their own repositories.
abstract class DiscoveryRepository {
  Future<DataState<List<Announcement>>> getAnnouncements();

  Future<DataState<List<HelpArticle>>> searchHelp(String query);
}
