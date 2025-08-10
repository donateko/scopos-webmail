import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/button/icon_button_web.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:core/presentation/views/quick_search/quick_search_input_form.dart';
import 'package:core/presentation/views/quick_search/quick_search_suggestion_box_decoration.dart';
import 'package:core/presentation/views/quick_search/quick_search_text_field_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/drive/presentation/drive_list_controller.dart';

class DriveSearchInput extends StatelessWidget {
  const DriveSearchInput({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DriveListController>();
    final imagePaths = Get.find<ImagePaths>();
    return QuickSearchInputForm<Object, Object, Object>(
      maxHeight: 52,
      suggestionsBoxVerticalOffset: 0.0,
      hideSuggestionsBox: true,
      textFieldConfiguration: QuickSearchTextFieldConfiguration(
        onChanged: controller.applyQuery,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Search files/folders',
          hintStyle: ThemeUtils.textStyleBodyBody2(
            color: AppColor.steelGray400,
          ),
          labelStyle: ThemeUtils.defaultTextStyleInterFont.copyWith(color: Colors.black, fontSize: 16.0),
        ),
        leftButton: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: TMailButtonWidget.fromIcon(
            icon: imagePaths.icSearchBar,
            iconColor: AppColor.steelGray400,
            iconSize: 22,
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            onTapActionCallback: () {},
          ),
        ),
        clearTextButton: buildIconWeb(
          icon: SvgPicture.asset(
            imagePaths.icClearTextSearch,
            width: 16,
            height: 16,
            colorFilter: AppColor.steelGray400.asFilter(),
            fit: BoxFit.fill,
          ),
          onTap: () => controller.applyQuery(''),
        ),
      ),
      suggestionsBoxDecoration: const QuickSearchSuggestionsBoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      debounceDuration: const Duration(milliseconds: 150),
      suggestionsCallback: (_) async => const <Object>[],
      itemBuilder: (context, _) => const SizedBox.shrink(),
      onSuggestionSelected: (_) {},
    );
  }
}


