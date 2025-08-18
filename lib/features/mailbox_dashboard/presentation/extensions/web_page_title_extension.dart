import 'package:core/utils/platform_info.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/main/universal_import/html_stub.dart' as html;

extension WebPageTitleExtension on MailboxDashBoardController {
  void updateWebTitleFromInboxAndProfile() {
    if (!PlatformInfo.isWeb) return;

    // Determine the current mailbox to reflect in the title
    final PresentationMailbox? current = selectedMailbox.value;
    // Resolve the freshest mailbox from the map if possible
    final PresentationMailbox? mailbox = current != null
        ? mapMailboxById[current.id] ?? current
        : null;

    // Folder display name (always shown)
    final String folderName = mailbox?.displayName
        ?? mailbox?.name?.name
        ?? 'Mailbox';

    // Prefer unreadThreads, fallback to unreadEmails, default 0
    final num unreadNum = mailbox?.unreadThreads?.value.value
            ?? mailbox?.unreadEmails?.value.value
            ?? 0;
    final int unread = unreadNum.toInt();

    final email = ownEmailAddress.value;

    // Build title: Always folder. Append (X) when X > 0. Then email (if any). Then app name.
    final parts = <String>[];
    parts.add(unread > 0 ? '$folderName($unread)' : folderName);
    if (email.isNotEmpty) {
      parts.add(email);
    }
    parts.add('Mailbux');

    html.document.title = parts.join(' - ');
  }
}
