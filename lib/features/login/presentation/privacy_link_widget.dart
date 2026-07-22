import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class PrivacyLinkWidget extends StatelessWidget {
  final String privacyUrlString;

  const PrivacyLinkWidget({Key? key, this.privacyUrlString = AppConfig.linagoraPrivacyUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).byContinuingYouAreAgreeingToOur,
          // Space Mono: the site's mono face, used for fine print.
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            color: Color(0xFF8A8A8A),
            fontSize: 12,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w400,
          ),
        ),
        RichText(
          text: TextSpan(
            text: AppLocalizations.of(context).privacyPolicy,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              color: Color(0xFFAC0014),
              fontSize: 12,
              letterSpacing: 0.2),
            recognizer: TapGestureRecognizer()..onTap = () => AppUtils.launchLink(privacyUrlString)
          )
        ),
        // AGPL-3.0 s.13 source offer: the deployed build is a modified
        // network-served AGPL work, so its corresponding source is offered here.
        RichText(
          text: TextSpan(
            text: 'Source code',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              color: Color(0xFF8A8A8A),
              fontSize: 11,
              letterSpacing: 0.2),
            recognizer: TapGestureRecognizer()..onTap = () => AppUtils.launchLink(AppConfig.sourceCodeUrl)
          )
        )
      ],
    );
  }
}
