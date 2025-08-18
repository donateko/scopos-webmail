import 'package:core/utils/platform_info.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/main/universal_import/html_stub.dart' as html;
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/dashboard_routes.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension WebPageTitleExtension on MailboxDashBoardController {
  void updateWebTitleFromInboxAndProfile() {
    if (!PlatformInfo.isWeb) return;

    // Prefer the current email subject when available.
    final route = dashboardRoute.value;
    final isDetailed = route == DashboardRoutes.emailDetailed || route == DashboardRoutes.threadDetailed;
    String? subject = isDetailed ? selectedEmail.value?.subject?.trim() : null;

    // Non-mail routes: set simple titles and exit early
    // Detect settings by URL path as it's not in DashboardRoutes
    try {
      final path = (() { try { return html.window.location.pathname ?? ''; } catch (_) { return ''; } })();
      final hash = (() { try { return html.window.location.hash ?? ''; } catch (_) { return ''; } })();
      final href = (() { try { return html.window.location.href ?? ''; } catch (_) { return ''; } })();
      final base = (() { try { return html.document.baseUri ?? ''; } catch (_) { return ''; } })();
      bool matches(String segment) {
        // Match '/segment' or '#/segment' with boundaries anywhere in URL
        final boundary = RegExp(r'[#/]' + segment + r'(?:[/?#]|$)', caseSensitive: false);
        return boundary.hasMatch(path) || boundary.hasMatch(hash) || boundary.hasMatch(href) || boundary.hasMatch(base);
      }

      if (matches('settings')) {
        html.document.title = 'Settings - Mailbux';
        return;
      }
      if (matches('calendar')) {
        html.document.title = 'Calendar - Mailbux';
        return;
      }
      if (matches('drive')) {
        html.document.title = 'Drive - Mailbux';
        return;
      }
      if (matches('contacts')) {
        html.document.title = 'Contacts - Mailbux';
        return;
      }
    } catch (_) {
      // ignore if window is not available in current context
    }

    if (route == DashboardRoutes.drive) {
      html.document.title = 'Drive - Mailbux';
      return;
    }
    if (route == DashboardRoutes.contacts) {
      html.document.title = 'Contacts - Mailbux';
      return;
    }

    // Fallback: when viewing thread detail, selectedEmail may be null briefly.
    // In that case, try to use the expanded email subject from ThreadDetailController.
    if ((subject == null || subject.isEmpty) && route == DashboardRoutes.threadDetailed) {
      if (Get.isRegistered<ThreadDetailController>()) {
        final threadCtrl = Get.find<ThreadDetailController>();
        final expandedId = threadCtrl.currentExpandedEmailId.value;
        subject = expandedId != null ? threadCtrl.emailIdsPresentation[expandedId]?.subject?.trim() : null;
      } else {
      }
    }

    if (subject != null && subject.isNotEmpty) {
      html.document.title = subject;
      return;
    }

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
    // Avoid duplicating app name when folderName (or only part) already equals 'Mailbux'
    if (parts.isEmpty || parts.last != 'Mailbux') {
      parts.add('Mailbux');
    }

    html.document.title = parts.join(' - ');
  }
}
