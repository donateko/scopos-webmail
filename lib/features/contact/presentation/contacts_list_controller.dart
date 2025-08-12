import 'dart:async';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/contact/contacts.dart';
import 'package:tmail_ui_user/features/contact/data/network/carddav_api.dart';

class ContactsListController extends BaseController {
  final CardDavApi _cardDavApi = Get.find<CardDavApi>();

  final contacts = <Contacts>[].obs;
  final isLoading = false.obs;
  final selected = Rxn<Contacts>();
  final _query = ''.obs;
  List<Contacts> _allContacts = const [];
  bool _initialized = false;
  final int _pageSize = 50;
  int _loaded = 0;
  Timer? _retryInitTimer;
  int _initAttempts = 0;

  @override
  void onReady() {
    super.onReady();
    _ensureInitFromDashboardIfPossible();
  }

  Session? _session;

  void initialize({required Session session}) {
    _session = session;
    _initialized = true;
    fetchContacts();
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

  Future<void> fetchContacts() async {
    if (_session == null) return;
    isLoading.value = true;
    try {
      final list = await _cardDavApi.listContacts(_session!);
      _allContacts = list;
      _loaded = (_pageSize < _allContacts.length) ? _pageSize : _allContacts.length;
      contacts.value = _applyQuery(_allContacts, _query.value);
    } catch (e, s) {
      super.onError(e, s);
    } finally {
      isLoading.value = false;
    }
  }

  void setQuery(String q) {
    _query.value = q;
    // filter current list in memory for responsiveness
    contacts.value = _applyQuery(_allContacts, q);
  }

  List<Contacts> _applyQuery(List<Contacts> source, String q) {
    if (q.isEmpty) return List<Contacts>.from(source);
    final lower = q.toLowerCase();
    return source.where((c) {
      final name = c.fullName?.toLowerCase() ?? '';
      final emails = c.emails.join(' ').toLowerCase();
      final phones = c.phones.join(' ').toLowerCase();
      return name.contains(lower) || emails.contains(lower) || phones.contains(lower);
    }).toList();
  }

  void loadMoreIfNeeded(int index) {
    if (_query.value.isNotEmpty) return; // skip load-more when filtering
    if (index >= _loaded - 5 && _loaded < _allContacts.length) {
      final next = (_loaded + _pageSize) < _allContacts.length ? (_loaded + _pageSize) : _allContacts.length;
      _loaded = next;
      // Defer state update to next microtask to avoid 'setState during build'
      Future.microtask(() {
        contacts.value = _allContacts.take(_loaded).toList();
      });
    }
  }

  Future<void> addContact(Contacts contact) async {
    if (_session == null) return;
    try {
      final created = await _cardDavApi.createContact(_session!, contact);
      _allContacts = [created, ..._allContacts];
      contacts.value = _applyQuery(_allContacts, _query.value);
    } catch (e, s) {
      super.onError(e, s);
    }
  }

  Future<void> updateContact(Contacts contact) async {
    if (_session == null) return;
    try {
      await _cardDavApi.updateContact(_session!, contact);
      final idxAll = _allContacts.indexWhere((c) => c.href == contact.href);
      if (idxAll >= 0) {
        _allContacts[idxAll] = contact;
      }
      contacts.value = _applyQuery(_allContacts, _query.value);
    } catch (e, s) {
      super.onError(e, s);
    }
  }

  Future<void> deleteContact(Contacts contact) async {
    if (_session == null) return;
    try {
      await _cardDavApi.deleteContact(_session!, contact);
      _allContacts = _allContacts.where((c) => c.href != contact.href).toList();
      contacts.value = _applyQuery(_allContacts, _query.value);
    } catch (e, s) {
      super.onError(e, s);
    }
  }
}


