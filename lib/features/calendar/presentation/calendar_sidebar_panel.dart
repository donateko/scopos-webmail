import 'package:core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/widgets/mailbox_app_bar.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/extensions/open_app_grid_extension.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/mailbox_controller.dart';
import 'package:tmail_ui_user/features/quotas/presentation/quotas_view.dart';
import 'package:tmail_ui_user/features/base/widget/application_version_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:tmail_ui_user/features/calendar/data/network/caldav_api.dart';
import 'package:tmail_ui_user/features/calendar/presentation/calendar_list_controller.dart';

class CalendarSidebarPanel extends StatelessWidget {
  const CalendarSidebarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Get.find<ResponsiveUtils>();
    final imagePaths = Get.find<ImagePaths>();
    return Drawer(
      backgroundColor: AppColor.colorBgDesktop,
      shape: InputBorder.none,
      shadowColor: AppColor.blackAlpha20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!responsive.isWebDesktop(context))
            SafeArea(
              bottom: false,
              child: MailboxAppBar(
                imagePaths: imagePaths,
                username: Get.find<MailboxDashBoardController>().ownEmailAddress.value,
                openSettingsAction: Get.find<MailboxDashBoardController>().goToSettings,
                openAppGridAction: () {
                  final dash = Get.find<MailboxDashBoardController>();
                  final apps = dash.appGridDashboardController.listLinagoraApp;
                  Get.find<MailboxController>().openAppGrid(apps);
                },
                openContactSupportAction: null,
              ),
            ),
          // Add Event button above section title (as requested)
          SizedBox(
            width: ResponsiveUtils.defaultSizeMenu,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 8),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _openCreateEventDialog(context),
                  icon: const Icon(Icons.event_available, color: Colors.white, size: 24),
                  label: const Text('Add event'),
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
            child: Text('Calendars', style: Theme.of(context).textTheme.titleSmall),
          ),
          const Divider(height: 1, color: AppColor.folderDivider),
          const ListTile(
            dense: true,
            leading: Icon(Icons.calendar_month_outlined),
            title: Text('My calendar'),
          ),
          const Spacer(),
          const QuotasView(),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: 16,
              start: 24,
              end: 24,
            ),
            child: ApplicationVersionWidget(
              title: '${AppLocalizations.of(context).version.toLowerCase()} ',
            ),
          ),
        ],
      ),
    );
  }
}

void _openCreateEventDialog(BuildContext context) {
  final summaryCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final attendeesCtrl = TextEditingController();
  DateTime? start = DateTime.now();
  DateTime? end = DateTime.now().add(const Duration(hours: 1));
  int? reminderMinutes;
  bool emailNotification = false;
  String? selectedColor;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (context, setState) {
      Future<void> pickStart() async {
        final date = await showDatePicker(
          context: context,
          initialDate: start!,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start!));
        if (time == null) return;
        setState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }

      Future<void> pickEnd() async {
        final date = await showDatePicker(
          context: context,
          initialDate: end!,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end!));
        if (time == null) return;
        setState(() => end = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }

      return AlertDialog(
        title: Row(children: [
          const Text('Add event'),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: summaryCtrl, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
                TextField(controller: descriptionCtrl, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: attendeesCtrl, decoration: const InputDecoration(labelText: 'Attendees (comma-separated emails)')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['#E57373','#64B5F6','#81C784','#FFD54F','#BA68C8','#4DD0E1','#A1887F','#90A4AE']
                      .map((hex) {
                    final c = Color(0xFF000000 | int.parse(hex.replaceAll('#',''), radix: 16));
                    final isSel = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = hex),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.black, width: 2) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: pickStart, child: Text('Start: ${start!.toLocal()}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: pickEnd, child: Text('End: ${end!.toLocal()}'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reminder (minutes before)'),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        reminderMinutes = n;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setStateInner) => CheckboxListTile(
                        value: emailNotification,
                        onChanged: (v) => setStateInner(() => emailNotification = v ?? false),
                        title: const Text('Email notification'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final dash = Get.find<MailboxDashBoardController>();
              final session = dash.sessionCurrent;
              if (session != null && summaryCtrl.text.trim().isNotEmpty) {
                final api = Get.find<CalDavApi>();
                await api.createEvent(
                  session,
                  summary: summaryCtrl.text.trim(),
                  start: start!,
                  end: end!,
                  location: locationCtrl.text.trim(),
                  description: descriptionCtrl.text.trim(),
                  attendees: attendeesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  reminderMinutes: reminderMinutes,
                  emailNotification: emailNotification,
                  colorHex: selectedColor,
                );
                // Optionally refresh list
                try {
                  final listController = Get.find<CalendarListController>();
                  await listController.fetchEvents();
                } catch (_) {}
              }
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      );
    }),
  );
}


