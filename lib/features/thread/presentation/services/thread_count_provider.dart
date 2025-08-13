import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/thread_detail/data/network/thread_detail_api.dart';

/// Provides authoritative, cross-mailbox thread counts by ThreadId.
/// Fetches thread emailIds via JMAP Thread/get and exposes a reactive map.
class ThreadCountProvider extends GetxService {
  final counts = <ThreadId, int>{}.obs;
  final _pending = <ThreadId>{};
  final _fetchedAt = <ThreadId, DateTime>{};
  final startedByMe = <ThreadId, bool>{}.obs;

  /// Ensure we have a recent count for [threadId]. Uses a small TTL to refresh
  /// after operations like delete/move.
  void ensure(ThreadId threadId, {Duration maxAge = const Duration(seconds: 3)}) {
    final fetched = _fetchedAt[threadId];
    if (fetched != null && DateTime.now().difference(fetched) < maxAge) {
      return;
    }
    if (_pending.contains(threadId)) return;

    final dash = Get.find<MailboxDashBoardController>();
    final accountId = dash.accountId.value;
    final session = dash.sessionCurrent;
    final own = dash.ownEmailAddress.value.toLowerCase();
    if (accountId == null || session == null) return;

    final api = Get.find<ThreadDetailApi>();
    _pending.add(threadId);

    api.getThreadById(threadId, accountId).then((emailIds) {
      // Count unique ids to be safe
      final unique = emailIds.map((e) => e.id.value).toSet();
      counts[threadId] = unique.length;
      _fetchedAt[threadId] = DateTime.now();

      // Compute initiator (who sent the earliest message)
      if (!startedByMe.containsKey(threadId) && emailIds.isNotEmpty) {
        // Fetch minimal set: first and last ids to determine earliest
        final candidates = <EmailId>{emailIds.first, emailIds.last}.toList();
        api.getEmailsByIds(session, accountId, candidates).then((emails) {
          if (emails.isEmpty) return;
          emails.sort((a, b) {
            final aTime = a.receivedAt?.value ?? a.sentAt?.value ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.receivedAt?.value ?? b.sentAt?.value ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aTime.compareTo(bTime);
          });
          final earliest = emails.first;
          final fromMine = earliest.from?.any((addr) => (addr.email ?? '').toLowerCase() == own) == true;
          startedByMe[threadId] = fromMine;
        }).catchError((_) {});
      }
    }).catchError((_) {
      // Leave existing count as-is on error
    }).whenComplete(() {
      _pending.remove(threadId);
    });
  }

  void invalidate(ThreadId threadId) {
    counts.remove(threadId);
    _fetchedAt.remove(threadId);
    startedByMe.remove(threadId);
  }
}


