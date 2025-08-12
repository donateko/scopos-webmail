import 'dart:async';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/calendar/data/network/caldav_api.dart';
import 'package:tmail_ui_user/features/calendar/presentation/model/calendar_event_item.dart';

class CalendarListController extends BaseController {
  final CalDavApi _calDavApi = Get.find<CalDavApi>();

  final events = <CalendarEventItem>[].obs;
  final isLoading = false.obs;
  final _query = ''.obs;
  bool _initialized = false;
  Session? _session;
  Timer? _retryInitTimer;
  int _initAttempts = 0;

  @override
  void onReady() {
    super.onReady();
    _ensureInitFromDashboardIfPossible();
  }

  void initialize({required Session session}) {
    _session = session;
    _initialized = true;
    fetchEvents();
  }

  void ensureInitialized({required Session session}) {
    if (!_initialized) {
      initialize(session: session);
    }
  }

  void _ensureInitFromDashboardIfPossible() {
    if (_initialized) return;
    MailboxDashBoardController? dash;
    if (Get.isRegistered<MailboxDashBoardController>()) {
      dash = Get.find<MailboxDashBoardController>();
    }
    final sess = dash?.sessionCurrent;
    if (sess != null) {
      initialize(session: sess);
    } else if (_initAttempts < 20) {
      _retryInitTimer?.cancel();
      _retryInitTimer = Timer(const Duration(milliseconds: 200), _ensureInitFromDashboardIfPossible);
      _initAttempts++;
    }
  }

  @override
  void onClose() {
    _retryInitTimer?.cancel();
    super.onClose();
  }

  Future<void> fetchEvents() async {
    if (_session == null) return;
    isLoading.value = true;
    try {
      final list = await _calDavApi.listEvents(_session!);
      events.value = _applyQuery(list, _query.value);
    } catch (e, s) {
      super.onError(e, s);
    } finally {
      isLoading.value = false;
    }
  }

  void setQuery(String q) {
    _query.value = q;
    events.value = _applyQuery(events, q);
  }

  List<CalendarEventItem> _applyQuery(List<CalendarEventItem> source, String q) {
    if (q.isEmpty) return List<CalendarEventItem>.from(source);
    final lower = q.toLowerCase();
    return source.where((e) {
      final summary = e.summary?.toLowerCase() ?? '';
      final location = e.location?.toLowerCase() ?? '';
      return summary.contains(lower) || location.contains(lower);
    }).toList();
  }

  void loadMoreIfNeeded(int index) {}

  String formatEventTimeRange(CalendarEventItem e) {
    final start = e.startLocalFormatted;
    final end = e.endLocalFormatted;
    return (start != null && end != null) ? '$start – $end' : '';
  }
}



