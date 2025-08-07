
import 'package:core/presentation/resources/image_paths.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

enum ProfileSettingActionType {
  manageAccount,
  addOrSwitchAccount,
  signOut;

  String getTitle(AppLocalizations appLocalizations) {
    switch(this) {
      case ProfileSettingActionType.manageAccount:
        return appLocalizations.manage_account;
      case ProfileSettingActionType.addOrSwitchAccount:
        return appLocalizations.add_or_switch_account;
      case ProfileSettingActionType.signOut:
        return appLocalizations.sign_out;
    }
  }

  String getIcon(ImagePaths imagePaths) {
    switch(this) {
      case ProfileSettingActionType.manageAccount:
        return imagePaths.icSetting;
      case ProfileSettingActionType.addOrSwitchAccount:
        return imagePaths.icAddNewFolder;
      case ProfileSettingActionType.signOut:
        return imagePaths.icLogout;
    }
  }
}