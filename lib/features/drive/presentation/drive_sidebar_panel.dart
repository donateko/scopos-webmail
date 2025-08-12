import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/base/widget/application_version_widget.dart';
import 'package:tmail_ui_user/features/composer/presentation/widgets/web/local_file_drop_zone_widget.dart';
import 'package:tmail_ui_user/features/composer/presentation/mixin/drag_drog_file_mixin.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/widgets/mailbox_app_bar.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/quotas/presentation/quotas_view.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:tmail_ui_user/features/drive/presentation/drive_list_controller.dart';
import 'package:tmail_ui_user/features/drive/data/network/webdav_api.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/mailbox_controller.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/extensions/open_app_grid_extension.dart';

class DriveSidebarPanel extends StatelessWidget with DragDropFileMixin {
  const DriveSidebarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DriveListController>()
        ? Get.find<DriveListController>()
        : Get.put(DriveListController());
    return Drawer(
      backgroundColor: AppColor.colorBgDesktop,
      shape: InputBorder.none,
      shadowColor: AppColor.blackAlpha20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!Get.find<ResponsiveUtils>().isWebDesktop(context))
            SafeArea(
              bottom: false,
              child: Builder(builder: (context) {
                final dash = Get.find<MailboxDashBoardController>();
                final apps = dash.appGridDashboardController.listLinagoraApp;
                return MailboxAppBar(
                  imagePaths: Get.find<ImagePaths>(),
                  username: dash.ownEmailAddress.value,
                  openSettingsAction: dash.goToSettings,
                  // Always show on mobile; overlay can open even before list arrives
                  openAppGridAction: () => Get.find<MailboxController>().openAppGrid(apps),
                  openContactSupportAction: null,
                );
              }),
            ),
          SizedBox(
            width: ResponsiveUtils.defaultSizeMenu,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 8),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (Get.isRegistered<DriveListController>()) {
                      _openUploadDialog(context, Get.find<DriveListController>());
                    }
                  },
                  icon: const Icon(Icons.upload_file, color: Colors.white, size: 24),
                  label: const Text('Add file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.blue700,
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    foregroundColor: Colors.white,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Folders', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'New folder',
                  onPressed: () async {
                    String name = '';
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Create folder'),
                        content: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(hintText: 'Folder name'),
                          onChanged: (v) => name = v,
                          onSubmitted: (_) => Navigator.of(ctx).pop(),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Create')),
                        ],
                      ),
                    );
                    if (name.trim().isNotEmpty && Get.isRegistered<DriveListController>()) {
                      await Get.find<DriveListController>().createFolder(name.trim());
                    }
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                )
              ],
            ),
          ),
          const Divider(height: 1, color: AppColor.folderDivider),
          Expanded(
            child: Obx(() {
              final dirs = controller.sidebarDirectories;
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('All files'),
                    onTap: () => controller.goToRoot(),
                  ),
                  const SizedBox(height: 4),
                  ...dirs.map((d) => DragTarget<WebDavItem>(
                        onWillAcceptWithDetails: (details) {
                          controller.setHover(d.href, true);
                          return true;
                        },
                        onLeave: (_) => controller.setHover(d.href, false),
                        onAcceptWithDetails: (details) async {
                          controller.setHover(d.href, false);
                          final destRel = controller.relativePathFromHref(d.href) ?? '';
                          await controller.moveItemsToFolder(destRel, [details.data.href]);
                        },
                        builder: (context, candidateData, rejected) {
                          final isHover = controller.hoverTargets.contains(d.href);
                          return Container(
                            decoration: BoxDecoration(
                              color: isHover ? AppColor.lightGrayEBEDF0 : Colors.transparent,
                              border: isHover ? Border.all(color: AppColor.m3Tertiary70) : null,
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder_outlined),
                               title: Row(children: [
                                 Expanded(child: Text(d.name == '.trash' ? 'Trash' : d.name)),
                                 IconButton(
                                   icon: const Icon(Icons.link, size: 18),
                                   tooltip: 'Copy folder link',
                                   onPressed: () async {
                                     final session = Get.find<MailboxDashBoardController>().sessionCurrent;
                                     if (session == null) return;
                                     final abs = Get.find<WebDavApi>().absoluteHref(session, href: d.href);
                                     try {
                                       await Clipboard.setData(ClipboardData(text: abs));
                                     } catch (_) {}
                                   },
                                 )
                               ]),
                               onTap: () => controller.openDirectory(d),
                            ),
                          );
                        },
                      )),
                ],
              );
            }),
          ),
          const QuotasView(),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 16, start: 24, end: 24),
            child: ApplicationVersionWidget(
              title: '${AppLocalizations.of(context).version.toLowerCase()} ',
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _openUploadDialog(BuildContext context, DriveListController controller) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.white,
        child: SizedBox(
          width: 720,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Text('Upload files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LocalFileDropZoneWidget(
                  imagePaths: Get.find<ImagePaths>(),
                  onLocalFileDropZoneListener: (details) async {
                    final list = await onDragDone(context: ctx, details: details);
                    if (list.isNotEmpty) {
                      await controller.uploadFiles(list);
                      if (Navigator.canPop(ctx)) Navigator.of(ctx).pop();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await controller.pickAndUploadFiles();
                      if (Navigator.canPop(ctx)) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Choose files'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


