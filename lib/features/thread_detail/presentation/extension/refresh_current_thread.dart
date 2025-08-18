import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/action/thread_detail_ui_action.dart';

extension RefreshCurrentThread on ThreadDetailController {
  void refreshCurrentThread() {
    final currentThreadId = mailboxDashBoardController.selectedEmail.value?.threadId;
    if (currentThreadId != null) {
      // Hide the new message notification
      showNewMessageNotification.value = false;
      
      // Use the existing refresh mechanism
      mailboxDashBoardController.dispatchThreadDetailUIAction(
        LoadThreadDetailAfterSelectedEmailAction(currentThreadId),
      );
    }
  }
  
  void showNewMessageReceived() {
    // Only show notification if we're currently viewing a thread
    final currentRoute = mailboxDashBoardController.dashboardRoute.value;
    if (currentRoute?.name == 'threadDetailed') {
      showNewMessageNotification.value = true;
    }
  }
  
  void dismissNewMessageNotification() {
    showNewMessageNotification.value = false;
  }
}
