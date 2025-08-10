import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/upload/file_info.dart';
import 'package:tmail_ui_user/features/upload/domain/usecases/local_file_picker_interactor.dart';
import 'package:tmail_ui_user/features/upload/domain/state/local_file_picker_state.dart';
import 'package:tmail_ui_user/features/drive/data/network/webdav_api.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

class DriveListController extends GetxController {
  final files = <WebDavItem>[].obs;
  final path = ''.obs; // user-relative path (e.g., username[/subfolder])
  final isLoading = true.obs;
  final hasLoaded = false.obs;
  final uploading = <String, double>{}.obs; // fileName -> progress 0..1
  final recent = <String, DateTime>{}.obs; // fileName -> timestamp

  WebDavApi get _api => Get.find<WebDavApi>();
  MailboxDashBoardController get _dash => Get.find<MailboxDashBoardController>();
  Worker? _ownEmailWatcher;
  Timer? _retryInitTimer;
  int _initAttempts = 0;

  @override
  void onInit() {
    super.onInit();
    // When own email becomes available, trigger load
    _ownEmailWatcher = ever<String>(_dash.ownEmailAddress, (email) {
      if (email.isNotEmpty && files.isEmpty) {
        _load();
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    _ensureSessionThenLoad();
  }

  @override
  void onClose() {
    super.onClose();
    _ownEmailWatcher?.dispose();
    _retryInitTimer?.cancel();
  }

  Future<void> _load() async {
    final session = _dash.sessionCurrent;
    if (session == null) return;
    isLoading.value = true;
    try {
      final items = await _api.list(session, userPath: _currentUserPath(session));
      files.assignAll(items);
      _sortFiles();
      hasLoaded.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshList() => _load();

  String _currentUserPath(Session session) {
    final base = _dash.ownEmailAddress.value.isNotEmpty
        ? _dash.ownEmailAddress.value
        : session.username.value;
    final sub = path.value.trim();
    if (sub.isEmpty) return base;
    return '$base/$sub';
  }

  String _rootName() {
    final session = _dash.sessionCurrent;
    if (session == null) return _dash.ownEmailAddress.value;
    return _dash.ownEmailAddress.value.isNotEmpty
        ? _dash.ownEmailAddress.value
        : session.username.value;
  }

  List<WebDavItem> get sidebarDirectories {
    final root = _rootName();
    return files.where((f) => f.isDirectory && f.name != root).toList();
  }

  Future<void> openDirectory(WebDavItem dir) async {
    if (!dir.isDirectory) return;
    final name = dir.name;
    path.value = path.value.isEmpty ? name : '${path.value}/$name';
    await _load();
  }

  Future<void> goUp() async {
    if (path.value.isEmpty) return;
    final parts = path.value.split('/')..removeLast();
    path.value = parts.join('/');
    await _load();
  }

  Future<void> goToRoot() async {
    path.value = '';
    await _load();
  }

  void _ensureSessionThenLoad() {
    if (_dash.sessionCurrent != null) {
      _load();
      return;
    }
    if (_initAttempts < 30) {
      _retryInitTimer?.cancel();
      _retryInitTimer = Timer(const Duration(milliseconds: 200), _ensureSessionThenLoad);
      _initAttempts++;
    }
  }

  Future<void> uploadFiles(List<FileInfo> picked) async {
    final session = _dash.sessionCurrent;
    if (session == null || picked.isEmpty) return;
    final userPath = _currentUserPath(session);
    for (final f in picked) {
      Uint8List bytes = f.bytes ?? Uint8List(0);
      if (bytes.isEmpty && (f.filePath?.isNotEmpty == true)) {
        try {
          bytes = io.File(f.filePath!).readAsBytesSync();
        } catch (_) {}
      }
      _ensurePlaceholder(f.fileName);
      uploading[f.fileName] = 0;
      uploading.refresh();
      await _api.upload(
        session,
        userPath: userPath,
        fileName: f.fileName,
        bytes: bytes,
        contentType: f.mimeType,
        onSendProgress: (sent, total) {
          if (total > 0) {
            uploading[f.fileName] = sent / total;
            uploading.refresh();
          }
        },
      );
      uploading.remove(f.fileName);
      uploading.refresh();
      // After upload, fetch the file metadata and update the row without full reload
      final stat = await _api.stat(session, userPath: userPath, fileName: f.fileName);
      final idx = files.indexWhere((e) => e.name == f.fileName);
      if (stat != null) {
        if (idx >= 0) {
          files[idx] = stat;
        } else {
          files.insert(0, stat);
        }
        _sortFiles();
      }
      markRecentlyUploaded(f.fileName);
    }
    // Do NOT force a full refresh; the list is already updated inline
  }

  void _ensurePlaceholder(String name) {
    final existing = files.indexWhere((e) => e.name == name);
    if (existing == -1) {
      files.insert(0, WebDavItem(name: name, href: '', isDirectory: false, size: 0, contentType: 'application/octet-stream'));
      _sortFiles();
    }
  }

  void markRecentlyUploaded(String name) {
    recent[name] = DateTime.now();
    recent.refresh();
    Future.delayed(const Duration(milliseconds: 4000), () {
      recent.remove(name);
      recent.refresh();
      // Force a repaint even if some widgets are not directly listening to `recent`
      files.refresh();
    });
  }

  void _sortFiles() {
    files.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1; // directories first
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    files.refresh();
  }

  Future<void> createFolder(String folderName) async {
    final session = _dash.sessionCurrent;
    if (session == null || folderName.trim().isEmpty) return;
    await _api.createFolder(
      session,
      userPath: _currentUserPath(session),
      folderName: folderName.trim(),
    );
    await _load();
  }

  Future<void> pickAndUploadFiles() async {
    final interactor = Get.put(LocalFilePickerInteractor());
    List<FileInfo> files = [];
    await for (final either in interactor.execute()) {
      either.fold((_) {}, (success) {
        if (success is LocalFilePickerSuccess) {
          files = success.pickedFiles;
        }
      });
    }
    if (files.isNotEmpty) {
      await uploadFiles(files);
    }
  }
}


