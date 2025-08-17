import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension ToggleShowPreviousMessages on ThreadDetailController {
  void toggleShowPreviousMessages() {
    showPreviousMessages.value = !showPreviousMessages.value;
    threadDetailManager.currentMobilePageViewIndex.refresh();
  }
}
