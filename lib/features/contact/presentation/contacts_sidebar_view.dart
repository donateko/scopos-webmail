import 'package:core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/features/quotas/presentation/quotas_view.dart';

class ContactsSidebarView extends StatelessWidget {
  const ContactsSidebarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: InputBorder.none,
      shadowColor: AppColor.blackAlpha20,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Contacts collections', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1, color: AppColor.folderDivider),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('All contacts'),
              onTap: () {},
            ),
            const Spacer(),
            const QuotasView(),
          ],
        ),
      ),
    );
  }
}


