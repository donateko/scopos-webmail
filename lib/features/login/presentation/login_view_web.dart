import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/responsive/responsive_widget.dart';
import 'package:core/presentation/views/text/slogan_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:tmail_ui_user/features/base/widget/application_logo_with_text_widget.dart';
import 'package:tmail_ui_user/features/base/widget/application_version_widget.dart';
import 'package:tmail_ui_user/features/login/presentation/base_login_view.dart';
import 'package:tmail_ui_user/features/login/presentation/login_form_type.dart';
import 'package:tmail_ui_user/features/login/presentation/privacy_link_widget.dart';
import 'package:tmail_ui_user/features/login/presentation/widgets/login_message_widget.dart';
import 'package:tmail_ui_user/features/login/presentation/widgets/try_again_button.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

class LoginView extends BaseLoginView {

  const LoginView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.primaryLightColor,
      // Site hero treatment: the world-map image darkened to brightness 0.3
      // and desaturated, under the same two near-black gradients the marketing
      // hero uses. Keeps the consultant tool visually continuous with the
      // public site, and removes the bright first paint entirely.
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/world-map-pillar.webp'),
            fit: BoxFit.cover,
            alignment: Alignment.centerLeft,
            colorFilter: ColorFilter.matrix(<double>[
              0.3, 0.0, 0.0, 0, 0,
              0.0, 0.3, 0.0, 0, 0,
              0.0, 0.0, 0.3, 0, 0,
              0.0, 0.0, 0.0, 1, 0,
            ]),
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFA0D0D0D),
                Color(0xED0D0D0D),
                Color(0xC20D0D0D),
                Color(0xA80D0D0D),
              ],
              stops: [0.0, 0.32, 0.56, 1.0],
            ),
          ),
          child: Center(child: SingleChildScrollView(
              child: ResponsiveWidget(
                responsiveUtils: controller.responsiveUtils,
                mobile: _buildMobileForm(context),
                desktop: _buildWebForm(context),
              ))),
        ),
      ),
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    return Stack(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 720, minHeight: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 67),
                child: ApplicationLogoWidthTextWidget()
              ),
              Padding(
                padding: const EdgeInsets.only(top: 67),
                child: Text(
                    AppLocalizations.of(context).signIn,
                    style: ThemeUtils.defaultTextStyleInterFont.copyWith(fontSize: 32, color: AppColor.colorNameEmail, fontWeight: FontWeight.w900)
                )
              ),
              Obx(() => LoginMessageWidget(
                formType: controller.loginFormType.value,
                viewState: controller.viewState.value,
              )),
              Obx(() {
                switch (controller.loginFormType.value) {
                  case LoginFormType.credentialForm:
                    return buildInputCredentialForm(context);
                  case LoginFormType.retry:
                    return TryAgainButton(
                      onRetry: controller.retryCheckOidc,
                      responsiveUtils: controller.responsiveUtils,
                    );
                  default:
                    return const SizedBox.shrink();
                }
              }),
              _buildLoadingProgress(context),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: PrivacyLinkWidget(),
              ),
              const ApplicationVersionWidget(padding: EdgeInsets.only(top: 8)),
            ],
          )
        ),
        // The bottom mark was a vendor "powered by" credit. With the app
        // fully rebranded it only duplicates the logo in the sign-in card,
        // so it is removed rather than restyled.
      ],
    );
  }

  Widget _buildWebForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor marketing panel (JMAP pitch, feature bullets, product
          // illustration) removed: this is an internal consultant tool, not a
          // product landing page. The sign-in card now centres on the hero.
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Site .hero-portrait-accent: a 1px red keyline at 35%
                  // alpha, offset 12px up and left, sitting behind the panel.
                  Positioned(
                    left: -12,
                    top: -12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0x59AC0014),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  Container(
                height: 684,
                width: 458,
                padding: const EdgeInsets.symmetric(horizontal: 31),
                clipBehavior: Clip.antiAlias,
                decoration: const ShapeDecoration(
                  // Site DNA: cards are --black on dark ground, never a light
                  // panel, with square corners rather than a soft radius.
                  color: Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  shadows: [
                    BoxShadow(
                      color: AppColor.loginViewShadowColor,
                      blurRadius: 40,
                      offset: Offset(0, 2),
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 66),
                      // Light-on-dark lockup, vector. The earlier raster swap
                      // was working around paint-time downscaling, which the
                      // SVG does not suffer since it rasterises at draw size.
                      child: SvgPicture.asset(
                        'assets/images/scopos_logo_lockup.svg',
                        width: 220,
                        fit: BoxFit.contain,
                      )
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 67),
                      child: Text(
                        AppLocalizations.of(context).signIn,
                        // Ivory, scoped to this view: colorNameEmail is near
                        // black and is used across the inbox on light ground,
                        // so it must not be changed globally.
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 40,
                          height: 1.1,
                          letterSpacing: 0.02,
                          color: Color(0xFFF4F3F0),
                          fontWeight: FontWeight.w800,
                        )
                      )
                    ),
                    Obx(() => LoginMessageWidget(
                      formType: controller.loginFormType.value,
                      viewState: controller.viewState.value,
                    )),
                    Obx(() {
                      switch (controller.loginFormType.value) {
                        case LoginFormType.credentialForm:
                          return buildInputCredentialForm(context);
                        case LoginFormType.retry:
                          return TryAgainButton(
                            onRetry: controller.retryCheckOidc,
                            responsiveUtils: controller.responsiveUtils,
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    }),
                    _buildLoadingProgress(context),
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: PrivacyLinkWidget()
                    ),
                    const ApplicationVersionWidget(padding: EdgeInsets.only(top: 8)),
                  ],
                )
              ),
                ],
              ),
              // Second vendor "powered by" credit, on the narrow layout.
              // Removed for the same reason as the wide one: it duplicates
              // the sign-in card logo now that the app is fully rebranded.
            ]
          )
        ],
      )
    );
  }

  Widget _buildLoadingProgress(BuildContext context) {
    return Obx(() => controller.viewState.value.fold(
      (failure) {
        switch (controller.loginFormType.value) {
          case LoginFormType.credentialForm:
            return buildLoginButton(context);
          default:
            return const SizedBox.shrink();
        }
      },
      (success) {
        if (success is LoadingState) {
          return buildLoadingCircularProgress();
        } else {
          switch (controller.loginFormType.value) {
            case LoginFormType.credentialForm:
              return buildLoginButton(context);
            default:
              return const SizedBox.shrink();
          }
        }
      }
    ));
  }
}