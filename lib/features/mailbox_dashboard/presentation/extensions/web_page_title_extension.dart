import 'package:core/utils/platform_info.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/main/universal_import/html_stub.dart' as html;

extension WebPageTitleExtension on MailboxDashBoardController {
  void updateWebTitleFromInboxAndProfile() {
    if (!PlatformInfo.isWeb) return;

    final inboxId = mapDefaultMailboxIdByRole[PresentationMailbox.roleInbox];
    final inbox = inboxId != null ? mapMailboxById[inboxId] : null;

    // Prefer unreadThreads, fallback to unreadEmails, default 0
    final num unreadNum = inbox?.unreadThreads?.value.value
            ?? inbox?.unreadEmails?.value.value
            ?? 0;
    final int inboxUnread = unreadNum.toInt();

    final email = ownEmailAddress.value;

    // Build title similarly to UI: show Inbox(X) only when X > 0
    final parts = <String>[];
    if (inboxUnread > 0) {
      parts.add('Inbox($inboxUnread)');
    }
    if (email.isNotEmpty) {
      parts.add(email);
    }
    parts.add('Mailbux');

    html.document.title = parts.join(' - ');
  }
}
