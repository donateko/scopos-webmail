import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/email/presentation_email.dart';
import 'package:model/email/email_in_thread_status.dart';
import 'package:tmail_ui_user/features/email/presentation/bindings/email_bindings.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_thread_by_id_state.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension HandleGetEmailIdsByThreadIdSuccess on ThreadDetailController {
  void handleGetEmailIdsByThreadIdSuccess(
    GetThreadByIdSuccess success,
  ) {
    final currentThreadId = mailboxDashBoardController.selectedEmail.value?.threadId;
    if (success.emailIds.isEmpty || success.threadId != currentThreadId) {
      return;
    }

    // Reset the show previous messages flag for each new thread
    showPreviousMessages.value = false;

    final allEmailIds = success.emailIds;
    if (success.updateCurrentThreadDetail) {
      final newEmailIds = allEmailIds.where(
        (emailId) => !emailIdsPresentation.keys.contains(emailId),
      );
      emailIdsPresentation
        ..removeWhere((key, _) => !allEmailIds.contains(key))
        ..addEntries(
          newEmailIds.map((emailId) => MapEntry(emailId, null)),
        );
      return;
    }

    final selectedEmail = mailboxDashBoardController.selectedEmail.value;
    final selectedEmailId = selectedEmail?.id;
    
    // Preserve existing email data and add all thread email IDs
    final existingData = Map<EmailId, PresentationEmail?>.from(emailIdsPresentation);
    emailIdsPresentation.clear();
    
    // Find the chronologically latest email to expand by timestamp
    EmailId? latestEmailId;
    DateTime? latestTimestamp;
    
    // First pass: check existing data for timestamps
    for (final id in allEmailIds) {
      final emailData = existingData[id] ?? (id == selectedEmailId ? selectedEmail : null);
      if (emailData?.receivedAt != null) {
        final timestamp = emailData!.receivedAt!.value;
        if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
          latestTimestamp = timestamp;
          latestEmailId = id;
        }
      }
    }
    
    // If no timestamp found in existing data, default to selected email
    latestEmailId ??= selectedEmailId;

    // Initialize ALL emails with proper status
    for (final id in allEmailIds) {
      final isLatest = id == latestEmailId;
      final status = isLatest
          ? EmailInThreadStatus.expanded
          : EmailInThreadStatus.collapsed;

      final emailData = existingData[id] ?? (id == selectedEmailId ? selectedEmail : null);
      
      if (isLatest) {
        EmailBindings(currentEmailId: id).dependencies();
        currentExpandedEmailId.value = id;
      }
      
      emailIdsPresentation[id] = emailData?.copyWith(emailInThreadStatus: status);
    }
  }
}
