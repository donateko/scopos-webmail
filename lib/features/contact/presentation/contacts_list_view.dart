import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:tmail_ui_user/features/contact/presentation/contacts_search_input.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:model/contact/contacts.dart';
import 'package:tmail_ui_user/features/contact/presentation/contacts_list_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

class ContactsListView extends StatelessWidget {
  const ContactsListView({super.key});

  @override
  Widget build(BuildContext context) {
final controller = Get.isRegistered<ContactsListController>()
        ? Get.find<ContactsListController>()
        : Get.put(ContactsListController(), permanent: false);

    // Ensure the controller has a session to load contacts
    if (Get.isRegistered<MailboxDashBoardController>()) {
      final dash = Get.find<MailboxDashBoardController>();
      final session = dash.sessionCurrent;
      if (session != null) {
        controller.ensureInitialized(session: session);
      }
    }
    final responsive = Get.find<ResponsiveUtils>();
    final imagePaths = Get.find<ImagePaths>();

    return Container(
      margin: const EdgeInsetsDirectional.only(top: 16, end: 16, bottom: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(0)),
        color: Colors.white
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!responsive.isWebDesktop(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  TMailButtonWidget.fromIcon(
                    key: const Key('mobile_contacts_menu_button'),
                    icon: imagePaths.icMenuDrawer,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.all(8),
                    tooltipMessage: 'Open collections',
                    onTapActionCallback: () => Get.find<MailboxDashBoardController>().scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: ContactsSearchInput()),
                ]),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text('Contacts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1, color: AppColor.folderDivider),
            Expanded(
              child: Obx(() {
                final isLoading = controller.isLoading.value;
                final items = controller.contacts;
                // Avoid setState during build exceptions by not mutating state inside builder
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }
                return ListView.separated(
                              key: const ValueKey('contactsList'),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColor.folderDivider),
                              itemBuilder: (_, i) {
                      final c = items[i];
                      if (i >= items.length - 5) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMoreIfNeeded(i));
                      }
                                final title = c.fullName?.isNotEmpty == true ? c.fullName! : (c.emails.isNotEmpty ? c.emails.first : c.href);
                                final subtitle = c.emails.join(', ');
                                return ListTile(
                                  title: Text(title),
                                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                                  onTap: () => _openEditDialog(context, contact: c),
                        trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await controller.deleteContact(c);
                          },
                                    tooltip: 'Delete',
                                  ),
                                );
                    },
                  );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context, {Contacts? contact}) async {
    final controller = Get.isRegistered<ContactsListController>()
        ? Get.find<ContactsListController>()
        : Get.put(ContactsListController(), permanent: false);
    final nameCtrl = TextEditingController(text: contact?.fullName ?? '');
    final emailCtrl = TextEditingController(text: contact?.emails.join(', ') ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phones.join(', ') ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Emails (comma separated)')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phones (comma separated)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final emails = emailCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final phones = phoneCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final updated = Contacts(
                href: contact?.href ?? '',
                etag: contact?.etag,
                fullName: nameCtrl.text.trim(),
                emails: emails,
                phones: phones,
              );
              if (contact == null) {
                controller.addContact(updated);
              } else {
                controller.updateContact(updated);
              }
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


