import 'package:core/utils/app_logger.dart';
import 'package:jmap_dart_client/jmap/identities/identity.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/extensions/web_page_title_extension.dart';

extension UpdateOwnEmailAddressExtension on MailboxDashBoardController {

  void synchronizeOwnEmailAddress(String emailAddress) {
    log('UpdateOwnEmailAddressExtension::synchronizeOwnEmailAddress:OwnEmailAddress = ${ownEmailAddress.value}, NewEmailAddress = $emailAddress');
    if (ownEmailAddress.value.isNotEmpty || emailAddress.isEmpty) return;
    ownEmailAddress.value = emailAddress;
    // Keep browser tab title in sync when own email becomes available
    updateWebTitleFromInboxAndProfile();
  }

  void updateOwnEmailAddressFromIdentities(List<Identity> listIdentities) {
    final identityEmailAddress = listIdentities.firstOrNull?.email ?? '';

    if (identityEmailAddress.isNotEmpty) {
      synchronizeOwnEmailAddress(identityEmailAddress);
    } else {
      synchronizeOwnEmailAddress(sessionCurrent?.getUserDisplayName() ?? '');
    }
  }
}