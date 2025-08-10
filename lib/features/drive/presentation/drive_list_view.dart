import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/drive/data/network/webdav_api.dart';
import 'package:tmail_ui_user/features/drive/presentation/drive_list_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/draggable_app_state.dart';
import 'dart:html' as html show window; // web only listeners
import 'package:tmail_ui_user/main/utils/toast_manager.dart';
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
        borderRadius: BorderRadius.all(Radius.circular(20)),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Column(
          children: [
            Builder(builder: (context) {
              final responsive = Get.find<ResponsiveUtils>();
              if (!responsive.isWebDesktop(context)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Open folders',
                      onPressed: () => Get.find<MailboxDashBoardController>().scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColor.searchInputBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Text('Search files', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColor.colorHintSearchBar)),
                      ),
                    ),
                  ]),
                );
              }
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text('Drive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              );
            }),
            const Divider(height: 1, color: AppColor.folderDivider),
             Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                 final items = controller.files;
                if (items.isEmpty && controller.hasLoaded.value) {
                  final responsive = Get.find<ResponsiveUtils>();
                  final isDesktop = responsive.isDesktop(context);
                  return Stack(children: [
                    const Center(child: Text('No files')),
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
                        final f = items[i];
                        final isDir = f.isDirectory;
                        final icon = isDir ? Icons.folder_outlined : _iconForMime(f.contentType);
                        final uploadingProgress = controller.uploading[f.name];
                        final isUploading = uploadingProgress != null;
                        final isRecent = controller.recent.containsKey(f.name);
                        // Animated container listens to `isRecent` via Obx above; when `recent` map drops the key, we rebuild and style resets
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: isRecent ? AppColor.toastSuccessBackgroundColor.withOpacity(0.15) : Colors.transparent,
                            border: isRecent
                                ? Border.all(color: AppColor.toastSuccessBackgroundColor, width: 1)
                                : null,
                          ),
                          child: ListTile(
                            leading: Icon(icon),
                            title: Row(
                              children: [
                                Expanded(child: Text(f.name)),
                                if (isUploading)
                                  SizedBox(
                                    width: 140,
                                    child: LinearProgressIndicator(value: uploadingProgress),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (isDir) controller.openDirectory(f);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final session = Get.find<MailboxDashBoardController>().sessionCurrent;
                                if (session == null) return;
                                await Get.find<WebDavApi>().delete(session, href: f.href);
                                controller.refreshList();
                              },
                            ),
                          ),
                        );
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

  IconData _iconForMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('image')) return Icons.image_outlined;
    if (mime.contains('text')) return Icons.description_outlined;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('gzip')) return Icons.archive_outlined;
    return Icons.insert_drive_file_outlined;
  }
}


