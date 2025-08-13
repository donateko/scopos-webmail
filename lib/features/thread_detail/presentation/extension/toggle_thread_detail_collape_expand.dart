import 'package:model/email/presentation_email.dart';
import 'package:tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:tmail_ui_user/features/email/presentation/bindings/email_bindings.dart';
import 'package:model/email/email_in_thread_status.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension ToggleThreadDetailCollapeExpand on ThreadDetailController {
  void toggleThreadDetailCollapeExpand(PresentationEmail presentationEmail) {
    final emailId = presentationEmail.id;
    final expansionStatus = presentationEmail.emailInThreadStatus;
    if (emailId == null || expansionStatus == null) return;

    if (expansionStatus == EmailInThreadStatus.expanded) {
      if (emailIdsPresentation.length == 1) return;

      emailIdsPresentation[emailId] = presentationEmail.copyWith(
        emailInThreadStatus: EmailInThreadStatus.collapsed,
      );
      mailboxDashBoardController.dispatchEmailUIAction(
        CollapseEmailInThreadDetailAction(emailId),
      );
      currentExpandedEmailId.value = null;
      threadDetailManager.currentMobilePageViewIndex.refresh();
      return;
    }

    EmailBindings(currentEmailId: presentationEmail.id).dependencies();
    // Single-expand accordion behavior: collapse all others, expand only the tapped one
    emailIdsPresentation.updateAll((key, value) {
      if (key == emailId) {
        return (value ?? presentationEmail).copyWith(
          emailInThreadStatus: EmailInThreadStatus.expanded,
        );
      }
      if (value == null) return null;
      return value.copyWith(emailInThreadStatus: EmailInThreadStatus.collapsed);
    });
    currentExpandedEmailId.value = emailId;
    threadDetailManager.currentMobilePageViewIndex.refresh();
  }
}