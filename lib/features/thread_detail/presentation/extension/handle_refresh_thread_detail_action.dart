import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/email/email_in_thread_status.dart';
import 'package:model/extensions/email_extension.dart';
import 'package:model/extensions/keyword_identifier_extension.dart';
import 'package:model/extensions/list_email_extension.dart';
import 'package:tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:tmail_ui_user/features/email/presentation/extensions/email_extension.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_emails_by_ids_state.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_thread_by_id_state.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/usecases/get_thread_by_id_interactor.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/close_thread_detail_action.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/utils/thread_detail_presentation_utils.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

extension HandleRefreshThreadDetailAction on ThreadDetailController {
  void handleRefreshThreadDetailAction(
    RefreshThreadDetailAction action,
    GetThreadByIdInteractor getThreadByIdInteractor,
  ) {
    if (!isThreadDetailEnabled) {
      final currentEmailId = mailboxDashBoardController.selectedEmail.value?.id;
      final currentThreadId = mailboxDashBoardController.selectedEmail.value?.threadId;
      if (currentEmailId == null || currentThreadId == null) return;

      final updatedEmailIds = action
        .emailChangeResponse
        .updated
        ?.listEmailIds ?? [];
        
      // Also check for created emails in the current thread (e.g., new replies)
      final createdEmailsInThread = action
        .emailChangeResponse
        .created
        ?.where((email) => email.threadId == currentThreadId)
        .toList() ?? [];

      // Refresh if current email was updated OR if new emails were created in the thread
      if (updatedEmailIds.contains(currentEmailId) || createdEmailsInThread.isNotEmpty) {
        // Call the proper interactor to get ALL thread emails
        consumeState(getThreadByIdInteractor.execute(
          currentThreadId,
          session!,
          accountId!,
          sentMailboxId!,
          ownEmailAddress!,
          selectedEmailId: currentEmailId,
          updateCurrentThreadDetail: false,
        ));
      }

      return;
    }

    final currentThreadId = mailboxDashBoardController.selectedEmail.value?.threadId;
    if (currentThreadId == null) return;
    final emailIdsDestroyed = Set<EmailId>.from(
      action.emailChangeResponse.destroyed ?? const []);

    final emailsCreated = action.emailChangeResponse.created
      ?.where((email) => validateNewCreatedEmailForCurrentThread(
        email,
        currentThreadId,
      ))
      .map((email) => email.toPresentationEmail().copyWith(
        emailInThreadStatus: EmailInThreadStatus.collapsed,
      ))
      .toList(growable: false) ?? const [];

    final emailsUpdated = action.emailChangeResponse.updated
      ?.where((email) => email.threadId == currentThreadId)
      .map((email) => email.toPresentationEmail())
      .toList(growable: false) ?? const [];

    final afterRefreshedEmailIds = ThreadDetailPresentationUtils.refreshEmailIds(
      original: emailIdsPresentation.keys.toList(),
      created: emailsCreated.map((email) => email.id).nonNulls.toList(),
      destroyed: emailIdsDestroyed.toList(),
    );
    final afterRefreshedEmails = ThreadDetailPresentationUtils.refreshPresentationEmails(
      original: emailIdsPresentation.values.nonNulls.toList(),
      created: emailsCreated,
      updated: emailsUpdated,
      destroyed: emailIdsDestroyed.toList(),
    );

    // Align IDs to the set of refreshed email objects to avoid null placeholders
    final alignedIds = afterRefreshedEmails
      .map((e) => e.id)
      .nonNulls
      .toList(growable: false);

    if (alignedIds.isEmpty) {
  // Fallback: sometimes the change payload doesn't carry created/updated items
      // for this thread (e.g., self-sent replies). Trigger a full Thread/get to
      // rebuild the IDs and merge correctly.
      final currentEmailId = mailboxDashBoardController.selectedEmail.value?.id;
      if (session != null && accountId != null && sentMailboxId != null && ownEmailAddress != null) {
        consumeState(getThreadByIdInteractor.execute(
          currentThreadId,
          session!,
          accountId!,
          sentMailboxId!,
          ownEmailAddress!,
          selectedEmailId: currentEmailId,
          updateCurrentThreadDetail: true,
        ));
      }
      return;
    }

    consumeState(Stream.value(Right(GetThreadByIdSuccess(
      alignedIds,
      threadId: currentThreadId,
      updateCurrentThreadDetail: true,
    ))));
    consumeState(Stream.value(Right(GetEmailsByIdsSuccess(
      afterRefreshedEmails,
      updateCurrentThreadDetail: true,
    ))));

    final updatedExpandedEmail = afterRefreshedEmails.firstWhereOrNull(
      (email) => email.id == currentExpandedEmailId.value,
    );
    if (updatedExpandedEmail?.keywords?[KeyWordIdentifierExtension.unsubscribeMail] == true) {
      mailboxDashBoardController.dispatchEmailUIAction(
        UnsubscribeFromThreadAction(
          currentExpandedEmailId.value!,
          updatedExpandedEmail?.listUnsubscribe ?? '',
        ),
      );
    }
  }

  bool validateNewCreatedEmailForCurrentThread(
    Email email,
    ThreadId currentThreadId,
  ) {
    if (email.threadId != currentThreadId) return false;

    if (sentMailboxId != null && !email.inSentMailbox(sentMailboxId!)) {
      return true;
    }

    return ownEmailAddress != null &&
        (!email.fromMe(ownEmailAddress!) ||
            !email.recipientsHasMe(ownEmailAddress!));
  }
}
