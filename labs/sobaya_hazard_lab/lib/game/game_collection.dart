import 'game_campaign.dart';

/// Serialize pickups and resets so an older in-flight save cannot resurrect IDs.
class HazardCollectionStore {
  HazardCollectionStore(this.write);
  final Future<bool> Function(List<String>) write;
  Future<void> _queue = Future.value();

  Future<bool> save(Iterable<String> ids) {
    final snapshot = ids.toList();
    final result = _queue.then((_) => write(snapshot));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> reset(HazardCampaign campaign) async {
    if (!await save(const [])) return false;
    campaign.resetCollection();
    return true;
  }
}
