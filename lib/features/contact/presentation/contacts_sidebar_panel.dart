import 'package:core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/base/widget/application_version_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/widgets/mailbox_app_bar.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:model/contact/contacts.dart';
import 'package:tmail_ui_user/features/contact/presentation/contacts_list_controller.dart';
import 'package:tmail_ui_user/features/quotas/presentation/quotas_view.dart';
import 'package:core/presentation/utils/responsive_utils.dart';

class ContactsSidebarPanel extends StatelessWidget {
  const ContactsSidebarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ContactsListController>()
        ? Get.find<ContactsListController>()
        : Get.put(ContactsListController(), permanent: false);
    // Keep consistent width like left menu; get responsive util
    final responsive = Get.find<ResponsiveUtils>();
    final imagePaths = Get.find<ImagePaths>();
    return Drawer(
      backgroundColor: AppColor.colorBgDesktop,
      shape: InputBorder.none,
      shadowColor: AppColor.blackAlpha20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mobile/tablet header identical to mailbox app bar
          if (!responsive.isWebDesktop(context))
            SafeArea(
              bottom: false,
              child: MailboxAppBar(
                imagePaths: imagePaths,
                username: Get.find<MailboxDashBoardController>().ownEmailAddress.value,
                openSettingsAction: Get.find<MailboxDashBoardController>().goToSettings,
                openAppGridAction: null,
                openContactSupportAction: null,
              ),
            ),
          // Add Contact button styled like Compose
          SizedBox(
            width: ResponsiveUtils.defaultSizeMenu,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 8),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                onPressed: () => _openEditDialog(context, controller),
                icon: Icon(Icons.person_add_alt, color: Colors.white, size: 24),
                label: const Text('Add contact'),
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
            child: Text('Collections', style: Theme.of(context).textTheme.titleSmall),
          ),
          // Keep section divider only; drawer has no right border
          const Divider(height: 1, color: AppColor.folderDivider),
          ListTile(
            dense: true,
            leading: const Icon(Icons.people_outline),
            title: const Text('All contacts'),
            onTap: () {
              controller.setQuery('');
              controller.fetchContacts();
            },
          ),
          // Placeholder for listing each address book collection name
          // TODO: replace with dynamic collections fetched from CardDAV discovery
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined),
            title: const Text('default'),
            onTap: () {
              controller.setQuery('');
              controller.fetchContacts();
            },
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

  Future<void> _openEditDialog(BuildContext context, ContactsListController controller) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Contact'),
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
              final newContact = Contacts(
                href: '',
                fullName: nameCtrl.text.trim(),
                emails: emails,
                phones: phones,
              );
              controller.addContact(newContact);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


