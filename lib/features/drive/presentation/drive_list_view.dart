import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/drive/data/network/webdav_api.dart';
import 'package:tmail_ui_user/features/drive/presentation/drive_list_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/draggable_app_state.dart';
// web only listeners
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
import 'dart:typed_data';
import 'package:tmail_ui_user/features/drive/presentation/drive_preview_page.dart';
import 'package:tmail_ui_user/features/drive/presentation/drive_search_input.dart';
import 'dart:html' as html;
import 'package:tmail_ui_user/main/routes/route_navigation.dart';
import 'package:tmail_ui_user/features/composer/presentation/mixin/drag_drog_file_mixin.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/web/local_file_drop_zone_widget.dart';

class DriveListView extends StatelessWidget with DragDropFileMixin {
  const DriveListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DriveListController>()
        ? Get.find<DriveListController>()
        : Get.put(DriveListController());
    Get.find<ResponsiveUtils>();
    Get.find<ImagePaths>();
    final dash = Get.find<MailboxDashBoardController>();
    // Ensure we toggle drag state based on browser events
    if (GetPlatform.isWeb) {
      html.window.onDragEnter.listen((event) {
        event.preventDefault();
        dash.localFileDraggableAppState.value = DraggableAppState.active;
      });
      html.window.onDragOver.listen((event) {
        event.preventDefault();
        dash.localFileDraggableAppState.value = DraggableAppState.active;
      });
      html.window.onDragLeave.listen((event) {
        event.preventDefault();
        dash.localFileDraggableAppState.value = DraggableAppState.inActive;
      });
      html.window.onDrop.listen((event) {
        event.preventDefault();
        dash.localFileDraggableAppState.value = DraggableAppState.inActive;
      });
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(top: 16, end: 16, bottom: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(0)),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(0)),
        child: Column(
          children: [
            Obx(() {
              final responsive = Get.find<ResponsiveUtils>();
              final ctrl = Get.find<DriveListController>();
              final inFolder = ctrl.path.value.isNotEmpty;
              if (!responsive.isWebDesktop(context)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    if (inFolder)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        onPressed: () => ctrl.goUp(),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Open folders',
                        onPressed: () => Get.find<MailboxDashBoardController>().scaffoldKey.currentState?.openDrawer(),
                      ),
                    const SizedBox(width: 8),
                    const Expanded(child: DriveSearchInput()),
                  ]),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(children: [
                  if (inFolder)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: () => ctrl.goUp(),
                    ),
                  Expanded(
                    child: Row(children: [
                      const Text('Drive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (inFolder)
                        Flexible(
                          child: Text(
                            '/${ctrl.path.value}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColor.gray686E76),
                          ),
                        ),
                    ]),
                  ),
                ]),
              );
            }),
            const Divider(height: 1, color: AppColor.folderDivider),
            Obx(() {
              final ctrl = Get.find<DriveListController>();
              if (!ctrl.selectionMode.value) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColor.colorBgMailboxSelected,
                child: Row(children: [
                  Text('${ctrl.selectedHrefs.length} selected'),
                  const SizedBox(width: 12),
                  TextButton(onPressed: ctrl.selectAllVisible, child: const Text('Select all')),
                  const Spacer(),
                  TextButton(onPressed: ctrl.cancelSelection, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final count = ctrl.selectedHrefs.length;
                      if (count == 0) return;
                      final ok = await _confirmDelete(context, count);
                      if (ok) await ctrl.deleteSelected();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ]),
              );
            }),
             Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = controller.pagedItems;
                if (items.isEmpty && controller.hasLoaded.value) {
              final responsive = Get.find<ResponsiveUtils>();
              final isDesktop = responsive.isDesktop(context);
              final inFolder = controller.path.value.isNotEmpty;
                  return Stack(children: [
                    Center(child: Text(inFolder ? 'This folder is empty' : 'No files')),
                    if (isDesktop)
                      Positioned.fill(
                        child: LocalFileDropZoneWidget(
                          imagePaths: Get.find<ImagePaths>(),
                          onLocalFileDropZoneListener: (details) async {
                            final list = await onDragDone(context: context, details: details);
                            if (list.isNotEmpty) {
                              await controller.uploadFiles(list);
                            }
                          },
                        ),
                      )
                  ]);
                }
                final responsive = Get.find<ResponsiveUtils>();
                final isDesktop = responsive.isDesktop(context);
                return Stack(
                  children: [
                    ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColor.folderDivider),
                      itemBuilder: (_, i) {
                        controller.loadMoreIfNeeded(i);
                        final f = items[i];
                        final isDir = f.isDirectory;
                        final icon = isDir ? Icons.folder_outlined : _iconForMime(f.contentType);
                        final uploadingProgress = controller.uploading[f.name];
                        final isUploading = uploadingProgress != null;
                        final isRecent = controller.recent.containsKey(f.name);
                        // Animated container listens to `isRecent` via Obx above; when `recent` map drops the key, we rebuild and style resets
                          return Obx(() {
                          final isSelected = controller.isSelected(f);
                            final isHoverTarget = controller.hoverTargets.contains(f.href);
                            return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                                color: isHoverTarget
                                    ? AppColor.lightGrayEBEDF0
                                    : (isRecent && !isSelected)
                                        ? AppColor.toastSuccessBackgroundColor.withOpacity(0.15)
                                        : Colors.transparent,
                                border: isSelected
                                    ? Border.all(color: AppColor.folderDivider, width: 1.5)
                                    : (isRecent
                                        ? Border.all(color: AppColor.toastSuccessBackgroundColor, width: 1)
                                        : (isHoverTarget ? Border.all(color: AppColor.m3Tertiary70, width: 1) : null)),
                                // No border radius per request for highlighted/selected rows
                                borderRadius: BorderRadius.zero,
                            ),
                              child: DragTarget<WebDavItem>(
                                onWillAcceptWithDetails: (details) {
                                  if (!f.isDirectory) return false;
                                  controller.setHover(f.href, true);
                                  return true;
                                },
                                onLeave: (_) => controller.setHover(f.href, false),
                                onAcceptWithDetails: (details) async {
                                  controller.setHover(f.href, false);
                                  final destRel = controller.relativePathFromHref(f.href) ?? '';
                                  await controller.moveItemsToFolder(destRel, [details.data.href]);
                                  controller.flashTarget(f.href);
                                },
                                builder: (context, candidate, rejected) {
                                  final isDesktopEnv = Get.find<ResponsiveUtils>().isDesktop(context);
                                  final feedback = Material(
                                    color: Colors.transparent,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 400),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColor.lightGrayEBEDF0,
                                          border: Border.all(color: AppColor.folderDivider, width: 2),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.folder_open, size: 18),
                                              const SizedBox(width: 8),
                                              Text(f.name == '.trash' ? 'Trash' : f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                  final rowChild = GestureDetector(
                                      onSecondaryTapDown: (details) async {
                                        await _openContextMenu(context, controller, f, details.globalPosition);
                                      },
                                      child: Column(
                                        children: [
                                          ListTile(
                              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(0),
                                      border: Border.all(color: AppColor.folderDivider, width: 1),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => controller.toggleSelection(f),
                                        child: isSelected
                                            ? Center(
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: AppColor.steelGray400,
                                                    borderRadius: BorderRadius.circular(0),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(icon),
                              ]),
                              title: Row(
                                children: [
                                  Expanded(child: Text(f.name == '.trash' ? 'Trash' : f.name)),
                                  if (isUploading)
                                    SizedBox(
                                      width: 140,
                                      child: LinearProgressIndicator(value: uploadingProgress),
                                    ),
                                ],
                              ),
                              onTap: () {
                                if (controller.selectionMode.value) {
                                  controller.toggleSelection(f);
                                } else if (isDir) {
                                  controller.openDirectory(f);
                                } else {
                                  _previewFile(context, f);
                                }
                              },
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                IconButton(
                                            icon: const Icon(Icons.download_outlined),
                                            tooltip: 'Download',
                                            onPressed: () async {
                                              final session = Get.find<MailboxDashBoardController>().sessionCurrent;
                                              if (session == null) return;
                                              final bytes = await Get.find<WebDavApi>().downloadBytes(session, href: f.href);
                                              final blob = html.Blob([bytes]);
                                              final url = html.Url.createObjectUrlFromBlob(blob);
                                              final a = html.AnchorElement(href: url)..download = f.name;
                                              a.click();
                                              html.Url.revokeObjectUrl(url);
                                            },
                                          ),
                                          
                                          if (!isDir)
                                            IconButton(
                                              icon: const Icon(Icons.drive_file_move_outline),
                                              tooltip: 'Move',
                                              onPressed: () async {
                                                await _openMoveDialog(context, controller, f);
                                              },
                                            ),
                                            if (f.name != '.trash') IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                              onPressed: () async {
                                                controller.selectedHrefs.assignAll([f.href]);
                                                final ok = await _confirmDelete(context, 1);
                                                if (ok) {
                                                  await controller.deleteSelected();
                                                } else {
                                                  controller.selectedHrefs.clear();
                                                }
                                              },
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      ),
                                        onLongPress: () => controller.startSelection(f),
                                          ),
                                          // moving progress under the row
                                          Obx(() {
                                            final p = controller.movingProgress[f.href] ?? 0;
                                            if (p <= 0 || p >= 1) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.fromLTRB(54, 0, 16, 10),
                                              child: LinearProgressIndicator(value: p),
                                            );
                                          })
                                        ],
                                      ),
                                    );
                                  if (isDesktopEnv) {
                                    return Draggable<WebDavItem>(
                                      data: f,
                                      dragAnchorStrategy: pointerDragAnchorStrategy,
                                      feedback: feedback,
                                      childWhenDragging: Opacity(opacity: 0.6, child: rowChild),
                                      child: rowChild,
                                    );
                                  } else {
                                    return LongPressDraggable<WebDavItem>(
                                      data: f,
                                      dragAnchorStrategy: pointerDragAnchorStrategy,
                                      feedback: feedback,
                                      childWhenDragging: Opacity(opacity: 0.6, child: rowChild),
                                      child: rowChild,
                                    );
                                  }
                                },
                              ),
                          );
                        });
                      },
                    ),
                    // Overlay a drop target across the list for desktop, but only when dragging files over the window
                    if (isDesktop && Get.find<MailboxDashBoardController>().isLocalFileDraggableAppActive)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: false,
                          child: LocalFileDropZoneWidget(
                            imagePaths: Get.find<ImagePaths>(),
                            onLocalFileDropZoneListener: (details) async {
                              final list = await onDragDone(context: context, details: details);
                              if (list.isNotEmpty) {
                                await controller.uploadFiles(list);
                                // quick green check toast without text
                                final appToast = Get.find<ToastManager>().appToast;
                                final overlay = currentOverlayContext;
                                if (overlay != null) {
                                  appToast.showToastSuccessMessage(overlay, '', duration: const Duration(milliseconds: 1200));
                                }
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
            if (Get.find<ResponsiveUtils>().isWebDesktop(context))
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<void> _openMoveDialog(BuildContext context, DriveListController controller, WebDavItem item) async {
    String? selectedRel;
    double dialogProgress = 0;
    bool isMoving = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        final dash = Get.find<MailboxDashBoardController>();
        final session = dash.sessionCurrent;
        final root = (dash.ownEmailAddress.value.isNotEmpty
            ? dash.ownEmailAddress.value
            : (session?.username.value ?? ''));
        final Map<String, List<WebDavItem>> tree = {'': const []};
        final Set<String> expanded = {''};
        bool loading = true;

        Future<void> loadChildren(String rel, StateSetter setState) async {
          if (session == null) return;
          final userPath = rel.isEmpty ? root : '$root/$rel';
          final items = await Get.find<WebDavApi>().list(session, userPath: userPath);
          final encoded = userPath.split('/').map(Uri.encodeComponent).join('/');
          final children = items.where((e) {
            try {
              final path = Uri.parse(e.href).path;
              return e.isDirectory && !{'/dav/file/$encoded', '/dav/file/$encoded/'}.contains(path);
            } catch (_) {
              return e.isDirectory;
            }
          }).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          tree[rel] = children;
          setState(() {});
        }

        List<Widget> buildNodes(String rel, StateSetter setState, {int depth = 0}) {
          final children = tree[rel] ?? const [];
          final tiles = <Widget>[];
          for (final d in children) {
            if (d.name == '.trash') continue; // handle Trash after
            final pathRel = rel.isEmpty ? d.name : '$rel/${d.name}';
            final isExpanded = expanded.contains(pathRel);
            tiles.add(
              ListTile(
                contentPadding: EdgeInsets.only(left: 12 + depth * 16.0, right: 12),
                leading: const Icon(Icons.folder_outlined),
                title: Text(d.name),
                trailing: Radio<String>(
                  value: pathRel,
                  groupValue: selectedRel,
                  onChanged: (v) {
                    selectedRel = v;
                    setState(() {});
                  },
                ),
                selected: selectedRel == pathRel,
                selectedTileColor: AppColor.lightGrayEBEDF0,
                onTap: () async {
                  // Toggle expansion; if no children, select
                  if (!tree.containsKey(pathRel)) {
                    await loadChildren(pathRel, setState);
                  }
                  if ((tree[pathRel]?.isNotEmpty ?? false)) {
                    if (isExpanded) {
                      expanded.remove(pathRel);
                    } else {
                      expanded.add(pathRel);
                    }
                    setState(() {});
                  } else {
                    selectedRel = pathRel;
                    setState(() {});
                  }
                },
              ),
            );
            if (isExpanded) {
              tiles.addAll(buildNodes(pathRel, setState, depth: depth + 1));
            }
          }
          return tiles;
        }

        return StatefulBuilder(builder: (ctx, setState) {
          if (loading) {
            loading = false;
            Future.microtask(() async {
              await loadChildren('', setState);
              setState(() {});
            });
          }
          // Extract trash from root if exists
          final trash = (tree[''] ?? const []).firstWhereOrNull((e) => e.name == '.trash');
          return AlertDialog(
            title: const Text('Move to folder'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMoving)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(value: dialogProgress == 0 || dialogProgress >= 1 ? null : dialogProgress),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        // Root selector
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('All Files'),
                          trailing: Radio<String>(
                            value: '',
                            groupValue: selectedRel,
                            onChanged: (v) {
                              selectedRel = v;
                              setState(() {});
                            },
                          ),
                          selected: (selectedRel ?? 'x') == '',
                          selectedTileColor: AppColor.lightGrayEBEDF0,
                          onTap: () {
                            selectedRel = '';
                            setState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ...buildNodes('', setState),
                        if (trash != null) ...[
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: const Icon(Icons.delete_outline),
                            title: const Text('Trash'),
                            trailing: Radio<String>(
                              value: '.trash',
                              groupValue: selectedRel,
                              onChanged: (v) {
                                selectedRel = v;
                                setState(() {});
                              },
                            ),
                            selected: selectedRel == '.trash',
                            selectedTileColor: AppColor.lightGrayEBEDF0,
                            onTap: () {
                              selectedRel = '.trash';
                              setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: selectedRel == null || isMoving
                    ? null
                    : () async {
                        isMoving = true;
                        dialogProgress = 0;
                        (ctx as Element).markNeedsBuild();
                        await controller.moveItemToFolderByPaths(
                          item.href,
                          selectedRel!,
                          item.name,
                          onProgress: (p) {
                            dialogProgress = p;
                            (ctx).markNeedsBuild();
                          },
                        );
                        if (Navigator.canPop(ctx)) Navigator.of(ctx).pop();
                      },
                child: SizedBox(
                  width: 140,
                  child: (!isMoving || dialogProgress >= 1)
                      ? const Center(child: Text('Move'))
                      : LinearProgressIndicator(value: dialogProgress == 0 ? null : dialogProgress, color: Colors.white, backgroundColor: Colors.white24),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('image')) return Icons.image_outlined;
    if (mime.contains('text')) return Icons.description_outlined;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('gzip')) return Icons.archive_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _previewFile(BuildContext context, WebDavItem item) async {
    final session = Get.find<MailboxDashBoardController>().sessionCurrent;
    if (session == null) return;
    final api = Get.find<WebDavApi>();
    Uint8List bytes = Uint8List(0);
    try {
      bytes = await api.downloadBytes(session, href: item.href);
    } catch (_) {
      // Retry once after interceptor refresh
      try {
        bytes = await api.downloadBytes(session, href: item.href);
      } catch (e) {
        final overlay = currentOverlayContext;
        if (overlay != null) {
          Get.find<ToastManager>().appToast.showToastErrorMessage(overlay, 'Failed to open file');
        }
        return;
      }
    }
    final mime = item.contentType;
    if (!(mime.contains('pdf') || mime.contains('image') || mime.contains('text'))) {
      final overlay = currentOverlayContext;
      if (overlay != null) {
        Get.find<ToastManager>().appToast.showToastWarningMessage(overlay, 'Preview not supported');
      }
      return;
    }
    // Use full-screen page on mobile/tablet
    await Get.to(() => DrivePreviewPage(bytes: bytes, mimeType: mime, title: item.name));
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete items'),
        content: Text('Delete $count ${count == 1 ? 'item' : 'items'}? You can undo from Trash.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openContextMenu(BuildContext context, DriveListController controller, WebDavItem item, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final menuItems = <PopupMenuEntry<String>>[ 
      const PopupMenuItem(value: 'download', child: Text('Download')),
      const PopupMenuItem(value: 'move', child: Text('Move')),
      const PopupMenuItem(value: 'copy', child: Text('Copy')),
      const PopupMenuItem(value: 'rename', child: Text('Rename')),
    ];
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        (overlay?.size.width ?? 0) - globalPosition.dx,
        (overlay?.size.height ?? 0) - globalPosition.dy,
      ),
      items: menuItems,
    );
    if (selected == null) return;
    switch (selected) {
      case 'download':
        final session = Get.find<MailboxDashBoardController>().sessionCurrent;
        if (session == null) return;
        final bytes = await Get.find<WebDavApi>().downloadBytes(session, href: item.href);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final a = html.AnchorElement(href: url)..download = item.name;
        a.click();
        html.Url.revokeObjectUrl(url);
        break;
      case 'move':
        await _openMoveDialog(context, controller, item);
        break;
      case 'copy':
        await _openCopyDialog(context, controller, item);
        break;
      case 'rename':
        await _openRenameDialog(context, controller, item);
        break;
    }
  }

  Future<void> _openCopyDialog(BuildContext context, DriveListController controller, WebDavItem item) async {
    String? selectedRel;
    bool isCopying = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        final dash = Get.find<MailboxDashBoardController>();
        final session = dash.sessionCurrent;
        final root = (dash.ownEmailAddress.value.isNotEmpty
            ? dash.ownEmailAddress.value
            : (session?.username.value ?? ''));
        final Map<String, List<WebDavItem>> tree = {'': const []};
        final Set<String> expanded = {''};
        bool loading = true;

        Future<void> loadChildren(String rel, StateSetter setState) async {
          if (session == null) return;
          final userPath = rel.isEmpty ? root : '$root/$rel';
          final items = await Get.find<WebDavApi>().list(session, userPath: userPath);
          final encoded = userPath.split('/').map(Uri.encodeComponent).join('/');
          final children = items.where((e) {
            try {
              final path = Uri.parse(e.href).path;
              return e.isDirectory && !{'/dav/file/$encoded', '/dav/file/$encoded/'}.contains(path);
            } catch (_) {
              return e.isDirectory;
            }
          }).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          tree[rel] = children;
          setState(() {});
        }

        List<Widget> buildNodes(String rel, StateSetter setState, {int depth = 0}) {
          final children = tree[rel] ?? const [];
          final tiles = <Widget>[];
          for (final d in children) {
            if (d.name == '.trash') continue;
            final pathRel = rel.isEmpty ? d.name : '$rel/${d.name}';
            final isExpanded = expanded.contains(pathRel);
            tiles.add(
              ListTile(
                contentPadding: EdgeInsets.only(left: 12 + depth * 16.0, right: 12),
                leading: const Icon(Icons.folder_outlined),
                title: Text(d.name),
                trailing: Radio<String>(
                  value: pathRel,
                  groupValue: selectedRel,
                  onChanged: (v) {
                    selectedRel = v;
                    setState(() {});
                  },
                ),
                selected: selectedRel == pathRel,
                selectedTileColor: AppColor.lightGrayEBEDF0,
                onTap: () async {
                  if (!tree.containsKey(pathRel)) {
                    await loadChildren(pathRel, setState);
                  }
                  if ((tree[pathRel]?.isNotEmpty ?? false)) {
                    if (isExpanded) {
                      expanded.remove(pathRel);
                    } else {
                      expanded.add(pathRel);
                    }
                    setState(() {});
                  } else {
                    selectedRel = pathRel;
                    setState(() {});
                  }
                },
              ),
            );
            if (isExpanded) {
              tiles.addAll(buildNodes(pathRel, setState, depth: depth + 1));
            }
          }
          return tiles;
        }

        return StatefulBuilder(builder: (ctx, setState) {
          if (loading) {
            loading = false;
            Future.microtask(() async {
              await loadChildren('', setState);
              setState(() {});
            });
          }
          final trash = (tree[''] ?? const []).firstWhereOrNull((e) => e.name == '.trash');
          return AlertDialog(
            title: const Text('Copy to folder'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isCopying)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('All Files'),
                          trailing: Radio<String>(
                            value: '',
                            groupValue: selectedRel,
                            onChanged: (v) {
                              selectedRel = v;
                              setState(() {});
                            },
                          ),
                          selected: (selectedRel ?? 'x') == '',
                          selectedTileColor: AppColor.lightGrayEBEDF0,
                          onTap: () {
                            selectedRel = '';
                            setState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ...buildNodes('', setState),
                        if (trash != null) ...[
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: const Icon(Icons.delete_outline),
                            title: const Text('Trash'),
                            trailing: Radio<String>(
                              value: '.trash',
                              groupValue: selectedRel,
                              onChanged: (v) {
                                selectedRel = v;
                                setState(() {});
                              },
                            ),
                            selected: selectedRel == '.trash',
                            selectedTileColor: AppColor.lightGrayEBEDF0,
                            onTap: () {
                              selectedRel = '.trash';
                              setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: selectedRel == null || isCopying
                    ? null
                    : () async {
                        isCopying = true;
                        (ctx as Element).markNeedsBuild();
                        await controller.copyItemsToFolder(selectedRel!, [item.href]);
                        if (Navigator.canPop(ctx)) Navigator.of(ctx).pop();
                      },
                child: SizedBox(
                  width: 140,
                  child: isCopying
                      ? const LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24)
                      : const Center(child: Text('Copy')),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _openRenameDialog(BuildContext context, DriveListController controller, WebDavItem item) async {
    var name = item.name;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
          controller: TextEditingController(text: name),
          onChanged: (v) => name = v,
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            await controller.renameItem(item.href, name);
            if (Navigator.canPop(ctx)) Navigator.of(ctx).pop();
          }, child: const Text('Rename')),
        ],
      ),
    );
  }
}

// Inline search bar removed; replaced with shared DriveSearchInput identical to contacts search style


