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
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class DriveListController extends GetxController {
  final files = <WebDavItem>[].obs;
  final visibleFiles = <WebDavItem>[].obs;
  final currentQuery = ''.obs;
  final selectionMode = false.obs;
  final selectedHrefs = <String>[].obs;
  final page = 0.obs;
  final pageSize = 50;
  final path = ''.obs; // user-relative path (e.g., username[/subfolder])
  final isLoading = true.obs;
  final hasLoaded = false.obs;
  final uploading = <String, double>{}.obs; // fileName -> progress 0..1
  final recent = <String, DateTime>{}.obs; // fileName -> timestamp
  final hoverTargets = <String>{}.obs; // hrefs currently hovered as drop target
  final flashingTargets = <String>{}.obs; // hrefs to flash after drop
  final movingProgress = <String, double>{}.obs; // href -> 0..1 when moving

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
      final userPath = _currentUserPath(session);
      final items = await _api.list(session, userPath: userPath);
      files.assignAll(_filterOutSelfEntry(items, userPath));
      _sortFiles();
      _applyCurrentQuery();
      hasLoaded.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshList() => _load();

  List<WebDavItem> get pagedItems {
    final end = ((page.value + 1) * pageSize).clamp(0, visibleFiles.length);
    return visibleFiles.take(end).toList();
  }

  void loadMoreIfNeeded(int index) {
    final threshold = (page.value + 1) * pageSize - 5;
    if (index >= threshold && ((page.value + 1) * pageSize) < visibleFiles.length) {
      page.value = page.value + 1;
    }
  }

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
    final list = files.where((f) => f.isDirectory && f.name != root).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Move .trash to the end
    final trashIndex = list.indexWhere((e) => e.name == '.trash');
    if (trashIndex >= 0) {
      final trash = list.removeAt(trashIndex);
      list.add(trash);
    }
    return list;
  }

  Future<void> openDirectory(WebDavItem dir) async {
    if (!dir.isDirectory) return;
    final session = _dash.sessionCurrent;
    if (session == null) return;
    final relative = _relativePathFromHref(dir.href, session);
    if (relative == null) return;
    path.value = relative;
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
    final dirs = files.where((e) => e.isDirectory && e.name != '.trash').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final trash = files.where((e) => e.isDirectory && e.name == '.trash').toList();
    final fls = files.where((e) => !e.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files
      ..clear()
      ..addAll(dirs)
      ..addAll(trash)
      ..addAll(fls);
    files.refresh();
    _applyCurrentQuery();
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

  void applyQuery(String q) {
    currentQuery.value = q;
    page.value = 0;
    _applyCurrentQuery();
  }

  void _applyCurrentQuery() {
    final q = currentQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      visibleFiles.assignAll(files);
    } else {
      visibleFiles.assignAll(files.where((e) => e.name.toLowerCase().contains(q)));
    }
    visibleFiles.refresh();
  }

  List<WebDavItem> _filterOutSelfEntry(List<WebDavItem> items, String userPath) {
    // Remove the PROPFIND response entry that represents the current directory itself
    final normalized = userPath.endsWith('/') ? userPath.substring(0, userPath.length - 1) : userPath;
    final encodedSegments = normalized.split('/').map(Uri.encodeComponent).toList();
    final encodedPath = encodedSegments.join('/');
    return items.where((i) {
      try {
        final href = Uri.parse(i.href);
        final path = href.path;
        final candidates = <String>{
          '/dav/file/$normalized',
          '/dav/file/$normalized/',
          '/dav/file/$encodedPath',
          '/dav/file/$encodedPath/',
        };
        return !candidates.contains(path);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  String _rootPrefixEncoded(Session session) {
    final root = _rootName();
    final encoded = root.split('/').map(Uri.encodeComponent).join('/');
    return '/dav/file/$encoded/';
  }

  String? _relativePathFromHref(String href, Session session) {
    try {
      final p = Uri.parse(href).path; // '/dav/file/<root>/sub/.../'
      var prefix = _rootPrefixEncoded(session);
      if (!p.startsWith(prefix)) return null;
      var remain = p.substring(prefix.length);
      if (remain.endsWith('/')) remain = remain.substring(0, remain.length - 1);
      return remain;
    } catch (_) {
      return null;
    }
  }

  // Selection helpers
  bool isSelected(WebDavItem item) => selectedHrefs.contains(item.href);

  void startSelection(WebDavItem item) {
    if (!selectionMode.value) selectionMode.value = true;
    toggleSelection(item);
  }

  void toggleSelection(WebDavItem item) {
    if (selectedHrefs.contains(item.href)) {
      selectedHrefs.remove(item.href);
    } else {
      selectedHrefs.add(item.href);
    }
    selectedHrefs.refresh();
    if (selectedHrefs.isEmpty) {
      selectionMode.value = false;
    } else {
      selectionMode.value = true;
    }
  }

  void cancelSelection() {
    selectedHrefs.clear();
    selectionMode.value = false;
  }

  void selectAllVisible() {
    selectedHrefs.assignAll(visibleFiles.map((e) => e.href));
  }

  Future<void> deleteSelected() async {
    final session = _dash.sessionCurrent;
    if (session == null || selectedHrefs.isEmpty) return;
    // Soft-delete: move to .trash so we can undo quickly
    await _ensureTrashFolder(session);
    final username = _rootName();
    final moves = <Map<String, String>>[]; // {src, dst}
    for (final href in List<String>.from(selectedHrefs)) {
      final name = _fileNameFromHref(href);
      if (name == '.trash') {
        // Skip deleting the Trash folder
        continue;
      }
      final dst = _absoluteHrefFor(session, '$username/.trash', name);
      await _api.move(session, srcHref: href, destHref: dst);
      moves.add({'src': href, 'dst': dst});
      files.removeWhere((e) => e.href == href);
    }
    selectedHrefs.clear();
    selectionMode.value = false;
    _sortFiles();
    _showUndoToast(moves);
  }

  Future<void> moveItemToFolderByPaths(String srcHref, String destRelativePath, String name, {void Function(double progress)? onProgress}) async {
    final session = _dash.sessionCurrent;
    if (session == null) return;
    final username = _rootName();
    final destDir = destRelativePath.isEmpty ? username : '$username/$destRelativePath';
    final dst = _absoluteHrefFor(session, destDir, name);
    try {
      movingProgress[srcHref] = 0;
      movingProgress.refresh();
      await _api.move(session, srcHref: srcHref, destHref: dst, onProgress: (p) {
        movingProgress[srcHref] = p;
        movingProgress.refresh();
        onProgress?.call(p);
      });
      files.removeWhere((e) => e.href == srcHref);
      movingProgress.remove(srcHref);
      _sortFiles();
    } catch (e) {
      final overlay = currentOverlayContext;
      if (overlay != null) {
        Get.find<ToastManager>().appToast.showToastErrorMessage(overlay, 'Move failed');
      }
      movingProgress.remove(srcHref);
      rethrow;
    }
  }

  Future<void> moveItemsToFolder(String destRelativePath, List<String> srcHrefs) async {
    final session = _dash.sessionCurrent;
    if (session == null || srcHrefs.isEmpty) return;
    final username = _rootName();
    for (final href in srcHrefs) {
      final name = _fileNameFromHref(href);
      final destDir = destRelativePath.isEmpty ? username : '$username/$destRelativePath';
      final dst = _absoluteHrefFor(session, destDir, name);
      try {
        movingProgress[href] = 0;
        movingProgress.refresh();
        await _api.move(session, srcHref: href, destHref: dst, onProgress: (p) {
          movingProgress[href] = p;
          movingProgress.refresh();
        });
        files.removeWhere((e) => e.href == href);
        movingProgress.remove(href);
      } catch (_) {
        // ignore individual failure to continue batch
        movingProgress.remove(href);
      }
    }
    _sortFiles();
    // Clear selection after successful batch move as requested
    selectedHrefs.clear();
    selectionMode.value = false;
  }

  Future<void> copyItemsToFolder(String destRelativePath, List<String> srcHrefs) async {
    final session = _dash.sessionCurrent;
    if (session == null || srcHrefs.isEmpty) return;
    final username = _rootName();
    final copyingIntoCurrent = destRelativePath == path.value;
    for (final href in srcHrefs) {
      final name = _fileNameFromHref(href);
      final dst = _absoluteHrefFor(session, '$username/$destRelativePath', name);
      try {
        await _api.copy(session, srcHref: href, destHref: dst);
        if (copyingIntoCurrent) {
          final stat = await _api.stat(session, userPath: _currentUserPath(session), fileName: name);
          if (stat != null) {
            files.add(stat);
          }
        }
      } catch (_) {
        // continue
      }
    }
    _sortFiles();
  }

  Future<void> renameItem(String srcHref, String newName) async {
    final session = _dash.sessionCurrent;
    if (session == null || newName.trim().isEmpty) return;
    final username = _rootName();
    final relative = _relativePathFromHref(srcHref, session);
    if (relative == null || !relative.contains('/')) return;
    final dir = relative.split('/')..removeLast();
    final destRelDir = dir.join('/');
    final dst = _absoluteHrefFor(session, '$username/$destRelDir', newName.trim());
    try {
      await _api.move(session, srcHref: srcHref, destHref: dst);
      // update local list
      final idx = files.indexWhere((e) => e.href == srcHref);
      if (idx >= 0) {
        files.removeAt(idx);
      }
      // If still inside current folder after rename, fetch stat and insert
      if (destRelDir == path.value) {
        final stat = await _api.stat(session, userPath: _currentUserPath(session), fileName: newName.trim());
        if (stat != null) files.add(stat);
      }
      _sortFiles();
    } catch (_) {}
  }

  void setHover(String href, bool isHover) {
    if (isHover) {
      hoverTargets.add(href);
    } else {
      hoverTargets.remove(href);
    }
    hoverTargets.refresh();
  }

  void flashTarget(String href) {
    flashingTargets.add(href);
    flashingTargets.refresh();
    Future.delayed(const Duration(milliseconds: 500), () {
      flashingTargets.remove(href);
      flashingTargets.refresh();
    });
  }

  String? relativePathFromHref(String href) {
    final session = _dash.sessionCurrent;
    if (session == null) return null;
    return _relativePathFromHref(href, session);
  }

  String _fileNameFromHref(String href) {
    try {
      final u = Uri.parse(href);
      return Uri.decodeComponent(u.pathSegments.isNotEmpty ? u.pathSegments.last : href.split('/').last);
    } catch (_) {
      return href.split('/').last;
    }
  }

  String _absoluteHrefFor(Session session, String destRelativeDir, String name) {
    final base = Uri(
      scheme: session.apiUrl.scheme == 'https' ? 'https' : 'http',
      host: session.apiUrl.host,
      port: session.apiUrl.hasPort ? session.apiUrl.port : null,
    );
    final encodedDir = destRelativeDir.split('/').map(Uri.encodeComponent).join('/');
    final encodedName = Uri.encodeComponent(name);
    return base.replace(path: '/dav/file/$encodedDir/$encodedName').toString();
  }

  Future<void> _ensureTrashFolder(Session session) async {
    try {
      await _api.createFolder(session, userPath: _rootName(), folderName: '.trash');
    } catch (_) {}
  }

  void _showUndoToast(List<Map<String, String>> moves) {
    final overlay = currentOverlayContext; // provided by route_navigation
    if (overlay == null) return;
    final appToast = Get.find<ToastManager>().appToast;
    appToast.showToastMessage(
      overlay,
      '${moves.length} deleted',
      duration: const Duration(seconds: 10),
      actionName: 'Undo',
      onActionClick: () async {
        final session = _dash.sessionCurrent;
        if (session == null) return;
        for (final m in moves) {
          final src = m['src']!;
          final dst = m['dst']!;
          final name = _fileNameFromHref(src);
          await _api.move(session, srcHref: dst, destHref: src);
          files.add(WebDavItem(name: name, href: src, isDirectory: false, size: 0, contentType: 'application/octet-stream'));
        }
        _sortFiles();
      },
    );
  }
}


