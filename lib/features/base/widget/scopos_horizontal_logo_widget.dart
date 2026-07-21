import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Horizontal Scopos lockup: the mark beside the wordmark.
///
/// The brand ships stacked lockups and a standalone wordmark, but no
/// single horizontal asset, so the pairing is composed here. A wide, short
/// header reads far better with a horizontal lockup than with a scaled-up
/// stacked one.
///
/// Light variants throughout: the app bar this sits in is dark.
class ScoposHorizontalLogoWidget extends StatelessWidget {
  final double height;
  final VoidCallback? onTapAction;

  const ScoposHorizontalLogoWidget({
    super.key,
    this.height = 30,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    // The wordmark asset is 656x36; deriving its width from the requested
    // height keeps the pairing proportional at any size.
    final wordmarkHeight = height * 0.42;

    final lockup = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/scopos_mark_light.svg',
          height: height,
          fit: BoxFit.contain,
        ),
        SizedBox(width: height * 0.38),
        Image.asset(
          'assets/images/scopos_wordmark_light.png',
          height: wordmarkHeight,
          // Decode near display size rather than downscaling at paint time,
          // which aliases the thin letterforms.
          cacheHeight: (wordmarkHeight * 3).round(),
          filterQuality: FilterQuality.high,
          fit: BoxFit.contain,
        ),
      ],
    );

    if (onTapAction == null) return lockup;

    return InkWell(
      onTap: onTapAction,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: lockup,
    );
  }
}
