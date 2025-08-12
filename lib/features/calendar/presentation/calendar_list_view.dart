import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/calendar/presentation/calendar_list_controller.dart';
import 'package:tmail_ui_user/features/calendar/presentation/model/calendar_event_item.dart';
import 'package:tmail_ui_user/features/calendar/data/network/caldav_api.dart';
import 'package:tmail_ui_user/features/calendar/presentation/calendar_search_input.dart';

class CalendarListView extends StatelessWidget {
  const CalendarListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CalendarListController>()
        ? Get.find<CalendarListController>()
        : Get.put(CalendarListController(), permanent: false);

    final responsive = Get.find<ResponsiveUtils>();
    final imagePaths = Get.find<ImagePaths>();
    return Container(
      margin: const EdgeInsetsDirectional.only(top: 16, end: 16, bottom: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mobile/tablet header only (mirror Contacts)
            if (!responsive.isWebDesktop(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  TMailButtonWidget.fromIcon(
                    key: const Key('mobile_calendar_menu_button'),
                    icon: imagePaths.icMenuDrawer,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.all(8),
                    tooltipMessage: 'Open calendars',
                    onTapActionCallback: () => Get.find<MailboxDashBoardController>().scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: CalendarSearchInput()),
                ]),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text('Calendar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1, color: AppColor.folderDivider),
            Expanded(child: _CalendarResponsiveGrid(controller: controller))
          ],
        ),
      ),
    );
  }
}

class _CalendarResponsiveGrid extends StatefulWidget {
  final CalendarListController controller;
  const _CalendarResponsiveGrid({required this.controller});

  @override
  State<_CalendarResponsiveGrid> createState() => _CalendarResponsiveGridState();
}

class _CalendarResponsiveGridState extends State<_CalendarResponsiveGrid> {
  DateTime anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String viewMode = 'month'; // month | week | day

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final days = nextMonth.difference(first).inDays;
    final list = <DateTime>[];
    for (int i = 0; i < days; i++) {
      list.add(DateTime(month.year, month.month, i + 1));
    }
    return list;
  }

  void _prevMonth() {
    setState(() => anchor = DateTime(anchor.year, anchor.month - 1, 1));
  }

  void _nextMonth() {
    setState(() => anchor = DateTime(anchor.year, anchor.month + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(anchor);
    final responsive = Get.find<ResponsiveUtils>();
    final isMobile = responsive.isMobile(context);
    const crossAxisCount = 7;

    return Obx(() {
      final items = widget.controller.events;
      if (widget.controller.isLoading.value && items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // View mode switcher
      final modeSwitcher = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Month'),
            selected: viewMode == 'month',
            onSelected: (_) => setState(() => viewMode = 'month'),
          ),
          ChoiceChip(
            label: const Text('Week'),
            selected: viewMode == 'week',
            onSelected: (_) => setState(() => viewMode = 'week'),
          ),
          ChoiceChip(
            label: const Text('Day'),
            selected: viewMode == 'day',
            onSelected: (_) => setState(() => viewMode = 'day'),
          ),
        ]),
      );

      // On mobile/tablet: show a date-grouped list by default
      if (isMobile || responsive.isTablet(context)) {
        if (viewMode == 'day') {
          return Column(children: [modeSwitcher, const Divider(height: 1, color: AppColor.folderDivider), Expanded(child: _buildDayView(items))]);
        }
        if (viewMode == 'week') {
          return Column(children: [modeSwitcher, const Divider(height: 1, color: AppColor.folderDivider), Expanded(child: _buildWeekView(items))]);
        }
        // Date-grouped list for small screens
        final grouped = <DateTime, List<CalendarEventItem>>{};
        for (final e in items) {
          if (e.start == null) continue;
          final k = DateTime(e.start!.year, e.start!.month, e.start!.day);
          grouped.putIfAbsent(k, () => <CalendarEventItem>[]).add(e);
        }
        final keys = grouped.keys.toList()
          ..sort((a, b) => a.compareTo(b));
        return Column(children: [modeSwitcher, const Divider(height: 1, color: AppColor.folderDivider), Expanded(child: ListView.builder(
          itemCount: keys.length,
          itemBuilder: (context, idx) {
            final day = keys[idx];
            final list = grouped[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add event',
                        onPressed: () => _openCreateEventDialogForDay(context, day),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColor.folderDivider),
                ...list.map((ev) => ListTile(
                  leading: _buildEventColorDot(ev),
                  title: Text(ev.summary ?? '(no title)'),
                  subtitle: Text(widget.controller.formatEventTimeRange(ev)),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _openEventDetailDialog(context, ev),
                  ),
                  onTap: () => _openEventDetailDialog(context, ev),
                )),
                const Divider(height: 1, color: AppColor.folderDivider),
              ],
            );
          },
        ))]);
      }

      if (viewMode == 'day') {
        return Column(children: [modeSwitcher, const Divider(height: 1, color: AppColor.folderDivider), Expanded(child: _buildDayView(items))]);
      }
      if (viewMode == 'week') {
        return Column(children: [modeSwitcher, const Divider(height: 1, color: AppColor.folderDivider), Expanded(child: _buildWeekView(items))]);
      }

      return Column(children: [modeSwitcher,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            // Year dropdown
            DropdownButton<int>(
              value: anchor.year,
              items: List<int>.generate(12, (i) => DateTime.now().year - 5 + i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (y) {
                if (y == null) return;
                setState(() => anchor = DateTime(y, anchor.month, 1));
              },
            ),
            const SizedBox(width: 8),
            // Month dropdown
            DropdownButton<int>(
              value: anchor.month,
              items: List<int>.generate(12, (i) => i + 1)
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (m) {
                if (m == null) return;
                setState(() => anchor = DateTime(anchor.year, m, 1));
              },
            ),
            const Spacer(),
            IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
          ]),
        ),
        const Divider(height: 1, color: AppColor.folderDivider),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayEvents = items.where((e) => e.start != null && e.start!.year == day.year && e.start!.month == day.month && e.start!.day == day.day).toList();
              return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(day.day.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          InkWell(
                            onTap: () => _openCreateEventDialogForDay(context, day),
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...dayEvents.take(3).map((ev) => Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _eventBgColor(ev),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () => _openEventDetailDialog(context, ev),
                          child: Row(
                            children: [
                              _buildEventColorDot(ev, size: 8),
                              const SizedBox(width: 4),
                              Expanded(child: Text(
                                ev.summary ?? '(no title)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              )),
                            ],
                          ),
                        ),
                      )),
                      if (dayEvents.length > 3)
                        InkWell(
                          onTap: () => _openDayEventsDialog(context, day, dayEvents),
                          child: Text('+${dayEvents.length - 3} more', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                    ],
                  ),
                
              );
            },
          ),
        )
      ]);
    });
  }

  // Helpers
  Color _eventColor(CalendarEventItem ev) {
    final hex = ev.colorHex;
    if (hex == null || hex.isEmpty) return Colors.blue;
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    if (value == null) return Colors.blue;
    return Color(0xFF000000 | value);
  }

  Color _eventBgColor(CalendarEventItem ev) {
    final c = _eventColor(ev);
    return c.withOpacity(0.15);
  }

  Widget _buildEventColorDot(CalendarEventItem ev, {double size = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _eventColor(ev), shape: BoxShape.circle),
    );
  }

  Widget _buildWeekView(List<CalendarEventItem> items) {
    final startOfWeek = anchor.subtract(Duration(days: anchor.weekday - 1));
    final days = List<DateTime>.generate(7, (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i));
    final hours = List<int>.generate(11, (i) => 8 + i); // 8..18
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('Week of ${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}'),
          const Spacer(),
          IconButton(onPressed: () => setState(() => anchor = anchor.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => setState(() => anchor = anchor.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
        ]),
      ),
    const Divider(height: 1, color: AppColor.folderDivider),
      Expanded(
        child: Row(children: [
          SizedBox(width: 48, child: Column(children: hours.map((h) => Expanded(child: Align(alignment: Alignment.topLeft, child: Text('$h:00', style: const TextStyle(fontSize: 10))))).toList())),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: days.length * hours.length,
              itemBuilder: (context, idx) {
                final d = days[idx % 7];
                final h = hours[idx ~/ 7];
                final slotStart = DateTime(d.year, d.month, d.day, h);
                final slotEnd = slotStart.add(const Duration(hours: 1));
                final slotEvents = items.where((e) => e.start != null && e.end != null && !(e.end!.isBefore(slotStart) || e.start!.isAfter(slotEnd))).toList();
                return InkWell(
                  onTap: () => _openCreateEventDialogForDay(context, slotStart),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB))),
                    padding: const EdgeInsets.all(2),
                    child: slotEvents.isEmpty
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: _eventBgColor(slotEvents.first), borderRadius: BorderRadius.circular(4)),
                              child: Text(slotEvents.first.summary ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                  ),
                );
              },
            ),
          )
        ]),
      )
    ]);
  }

  Widget _buildDayView(List<CalendarEventItem> items) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    final hours = List<int>.generate(11, (i) => 8 + i);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
          const Spacer(),
          IconButton(onPressed: () => setState(() => anchor = anchor.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => setState(() => anchor = anchor.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right)),
        ]),
      ),
      const Divider(height: 1, color: AppColor.folderDivider),
      Expanded(
        child: ListView.builder(
          itemCount: hours.length,
          itemBuilder: (context, idx) {
            final h = hours[idx];
            final slotStart = DateTime(d.year, d.month, d.day, h);
            final slotEnd = slotStart.add(const Duration(hours: 1));
            final slotEvents = items.where((e) => e.start != null && e.end != null && !(e.end!.isBefore(slotStart) || e.start!.isAfter(slotEnd))).toList();
            return InkWell(
              onTap: () => _openCreateEventDialogForDay(context, slotStart),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
                child: Row(children: [
                  SizedBox(width: 48, child: Text('$h:00', style: const TextStyle(fontSize: 10))),
                  const SizedBox(width: 8),
                  if (slotEvents.isEmpty)
                    const Expanded(child: SizedBox())
                  else
                    Expanded(
                      child: Wrap(spacing: 4, runSpacing: 4, children: slotEvents.map((ev) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _eventBgColor(ev), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _buildEventColorDot(ev, size: 8), const SizedBox(width: 4),
                          Text(ev.summary ?? '', style: const TextStyle(fontSize: 12)),
                        ]),
                      )).toList()),
                    )
                ]),
              ),
            );
          },
        ),
      )
    ]);
  }

  void _openDayEventsDialog(BuildContext context, DateTime day, List<CalendarEventItem> events) {
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: Text('Events on ${day.year}-${day.month}-${day.day}'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final ev = events[i];
              return ListTile(
                leading: _buildEventColorDot(ev),
                title: Text(ev.summary ?? '(no title)'),
                subtitle: Text(widget.controller.formatEventTimeRange(ev)),
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () { Navigator.of(context).pop(); _openEventDetailDialog(context, ev); }),
                onTap: () { Navigator.of(context).pop(); _openEventDetailDialog(context, ev); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
    });
  }

  void _openEventDetailDialog(BuildContext context, CalendarEventItem ev) {
    showDialog(context: context, builder: (_) {
      return AlertDialog(
        title: Row(children: [
          Expanded(child: Text(ev.summary ?? '(no title)')),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          )
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.controller.formatEventTimeRange(ev)),
            if (ev.location?.isNotEmpty == true) Text('Location: ${ev.location}'),
            const SizedBox(height: 8),
            const Text('Attendees:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: ev.attendees.map((email) {
              final status = ev.attendeePartStat[email]?.toUpperCase() ?? 'NEEDS-ACTION';
              Color bg;
              switch (status) {
                case 'ACCEPTED': bg = Colors.green.withOpacity(0.15); break;
                case 'TENTATIVE': bg = Colors.orange.withOpacity(0.15); break;
                case 'DECLINED': bg = Colors.red.withOpacity(0.15); break;
                default: bg = Colors.grey.withOpacity(0.15);
              }
              return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)), child: Text(email, style: const TextStyle(fontSize: 12)));
            }).toList()),
          ]),
        ),
        actions: [
          TextButton(onPressed: () async { await _deleteEvent(ev); Navigator.of(context).pop(); }, child: const Text('Delete')),
          FilledButton(onPressed: () { Navigator.of(context).pop(); _openEditEventDialog(context, ev); }, child: const Text('Edit')),
        ],
      );
    });
  }

  Future<void> _deleteEvent(CalendarEventItem ev) async {
    final dash = Get.find<MailboxDashBoardController>();
    final session = dash.sessionCurrent;
    if (session == null) return;
    final api = Get.find<CalDavApi>();
    await api.deleteEvent(session, ev);
    try { await widget.controller.fetchEvents(); } catch (_) {}
  }

  void _openEditEventDialog(BuildContext context, CalendarEventItem ev) {
    final summaryCtrl = TextEditingController(text: ev.summary ?? '');
    final locationCtrl = TextEditingController(text: ev.location ?? '');
    final descriptionCtrl = TextEditingController();
    final attendeesCtrl = TextEditingController(text: ev.attendees.join(', '));
    DateTime start = ev.start ?? DateTime.now();
    DateTime end = ev.end ?? start.add(const Duration(hours: 1));
    String? selectedColor = ev.colorHex;
    // Reserved for future edit of alarms
    // int? reminderMinutes;
    // bool emailNotification = false;

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) {
      Future<void> pickStart() async {
        final date = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date == null) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
        if (time == null) return;
        setState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }
      Future<void> pickEnd() async {
        final date = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date == null) return;
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end));
        if (time == null) return;
        setState(() => end = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }

      return AlertDialog(
        title: Row(children: [
          const Text('Edit event'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: summaryCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
            TextField(controller: descriptionCtrl, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: attendeesCtrl, decoration: const InputDecoration(labelText: 'Attendees (comma-separated emails)')),
            const SizedBox(height: 8),
            _buildColorPicker(selectedColor, (c) => setState(() => selectedColor = c)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: pickStart, child: Text('Start: ${widget.controller.formatEventTimeRange(CalendarEventItem(start: start, end: end))}'))),
            ]),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: pickEnd, child: Text('End: ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'))),
            ]),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            final dash = Get.find<MailboxDashBoardController>();
            final session = dash.sessionCurrent;
            if (session == null) return;
            final api = Get.find<CalDavApi>();
            await api.updateEvent(
              session,
              ev,
              summary: summaryCtrl.text.trim(),
              start: start,
              end: end,
              location: locationCtrl.text.trim(),
              description: descriptionCtrl.text.trim(),
              attendees: attendeesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              colorHex: selectedColor,
            );
            try { await widget.controller.fetchEvents(); } catch (_) {}
            Navigator.of(context).pop();
          }, child: const Text('Save')),
        ],
      );
    }));
  }

  Widget _buildColorPicker(String? selected, ValueChanged<String> onSelected) {
    const colors = ['#E57373','#64B5F6','#81C784','#FFD54F','#BA68C8','#4DD0E1','#A1887F','#90A4AE'];
    return Wrap(spacing: 8, runSpacing: 8, children: colors.map((hex){
      final c = Color(0xFF000000 | int.parse(hex.replaceAll('#',''), radix: 16));
      final isSel = selected == hex;
      return GestureDetector(
        onTap: () => onSelected(hex),
        child: Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: isSel ? Border.all(color: Colors.black, width: 2) : null,
          ),
        ),
      );
    }).toList());
  }
}

void _openCreateEventDialogForDay(BuildContext context, DateTime day) {
  final summaryCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final attendeesCtrl = TextEditingController();
  DateTime start = DateTime(day.year, day.month, day.day, 9, 0);
  DateTime end = start.add(const Duration(hours: 1));
  int? reminderMinutes;
  bool emailNotification = false;
  String? selectedColor;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (context, setState) {
      Future<void> pickStart() async {
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
        if (time == null) return;
        setState(() => start = DateTime(day.year, day.month, day.day, time.hour, time.minute));
      }
      Future<void> pickEnd() async {
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end));
        if (time == null) return;
        setState(() => end = DateTime(day.year, day.month, day.day, time.hour, time.minute));
      }

      return AlertDialog(
        title: Text('Add event on ${day.year}-${day.month}-${day.day}'),
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
                const SizedBox(height: 8),
                // Color picker (same palette as edit dialog)
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
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: pickStart, child: Text('Start: ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: pickEnd, child: Text('End: ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'))),
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
                    child: CheckboxListTile(
                      value: emailNotification,
                      onChanged: (v) => setState(() => emailNotification = v ?? false),
                      title: const Text('Email notification'),
                      controlAffinity: ListTileControlAffinity.leading,
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
                  start: start,
                  end: end,
                  location: locationCtrl.text.trim(),
                  description: descriptionCtrl.text.trim(),
                  attendees: attendeesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  reminderMinutes: reminderMinutes,
                  emailNotification: emailNotification,
                  colorHex: selectedColor,
                );
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


