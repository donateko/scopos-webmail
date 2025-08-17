import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:tmail_ui_user/features/email/presentation/utils/email_utils.dart';
import 'package:tmail_ui_user/features/home/data/exceptions/session_exceptions.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/dashboard_routes.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_emails_by_ids_state.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_thread_by_id_state.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/utils/thread_detail_presentation_utils.dart';

extension InitializeThreadDetailEmails on ThreadDetailController {
  void initializeThreadDetailEmails(GetThreadByIdSuccess success) {
    final currentThreadId = mailboxDashBoardController.selectedEmail.value?.threadId;
    if (success.skipLoadingMetadata || currentThreadId != success.threadId) return;

    final selectedEmailId = mailboxDashBoardController.selectedEmail.value?.id;
    if (skipLoadThreadMetaData(
      selectedEmailId: selectedEmailId,
      updateCurrentThreadDetail: success.updateCurrentThreadDetail,
    )) {
      return;
    }

    // Load metadata for ALL emails except the selected one (not just first load subset)
    List<EmailId> emailIdsToLoadMetaData = emailIdsPresentation.keys
        .where((emailId) => emailId != selectedEmailId)
        .toList();


    if (accountId == null || session == null) {
      consumeState(Stream.value(Left(GetEmailsByIdsFailure(
        exception: NotFoundSessionException(),
        updateCurrentThreadDetail: false,
      ))));
      return;
    }
    
    final onlyContainsSelected = _currentThreadOnlyContainsSelectedEmail(selectedEmailId);
    
    if (onlyContainsSelected) return;

    consumeState(getEmailsByIdsInteractor.execute(
      session!,
      accountId!,
      emailIdsToLoadMetaData,
      properties: EmailUtils.getPropertiesForEmailGetMethod(
        session!,
        accountId!,
      ).union(additionalProperties),
      updateCurrentThreadDetail: success.updateCurrentThreadDetail,
    ));
  }

  bool _currentThreadOnlyContainsSelectedEmail(EmailId? selectedEmailId) {
    return selectedEmailId != null &&
        emailIdsPresentation.length == 1 &&
        emailIdsPresentation.keys.contains(selectedEmailId);
  }

  bool skipLoadThreadMetaData({
    EmailId? selectedEmailId,
    bool updateCurrentThreadDetail = false,
  }) {
    // Allow metadata loading when in threadDetailed route even if thread detail is disabled
    final isInThreadDetailedRoute = mailboxDashBoardController.dashboardRoute.value == DashboardRoutes.threadDetailed;
    
    return selectedEmailId == null ||
        (!isThreadDetailEnabled && !isInThreadDetailedRoute) ||
        !networkConnected ||
        updateCurrentThreadDetail;
  }
}
