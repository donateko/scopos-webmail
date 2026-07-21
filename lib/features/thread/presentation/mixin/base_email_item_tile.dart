
import 'package:core/presentation/constants/constants_ui.dart';
import 'package:collection/collection.dart';
import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/utils/style_utils.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/text/rich_text_builder.dart';
import 'package:core/presentation/views/text/text_overflow_builder.dart';
import 'package:core/utils/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:model/email/email_action_type.dart';
import 'package:model/email/presentation_email.dart';
import 'package:model/extensions/presentation_email_extension.dart';
import 'package:model/extensions/presentation_mailbox_extension.dart';
import 'package:model/mailbox/presentation_mailbox.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/extensions/presentation_mailbox_extension.dart';
import 'package:tmail_ui_user/features/thread/domain/model/search_query.dart';
import 'package:tmail_ui_user/features/thread/presentation/styles/item_email_tile_styles.dart';
import 'package:tmail_ui_user/features/thread/presentation/services/thread_count_provider.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

typedef OnPressEmailActionClick = void Function(EmailActionType, PresentationEmail);
typedef OnMoreActionClick = Future<void> Function(PresentationEmail, RelativeRect?);

mixin BaseEmailItemTile {

  final responsiveUtils = Get.find<ResponsiveUtils>();
  final imagePaths = Get.find<ImagePaths>();
  final mailboxDashBoardController = Get.find<MailboxDashBoardController>();

  int computeThreadCount(PresentationEmail email) {
    final threadKey = email.threadId?.id.value;
    if (threadKey == null) return 1;
    try {
      // Prefer authoritative provider when available
      final provider = Get.put(ThreadCountProvider(), permanent: true);
      provider.ensure(email.threadId!);
      final authoritative = provider.counts[email.threadId!];
      if (authoritative != null && authoritative > 0) {
        return authoritative;
      }
    } catch (_) {}

    // Fallback quick estimate: single item until provider fills
    return 1;
  }

  /// Reactive, cross-mailbox badge that updates when authoritative count arrives.
  Widget buildThreadCountBadgeReactive(BuildContext context, PresentationEmail email) {
    try {
      if (email.threadId != null) {
        final provider = Get.put(ThreadCountProvider(), permanent: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.ensure(email.threadId!);
        });
      }
    } catch (_) {}

    return Obx(() {
      int count = computeThreadCount(email);
      try {
        if (email.threadId != null) {
          final provider = Get.find<ThreadCountProvider>();
          final authoritative = provider.counts[email.threadId!];
          if (authoritative != null && authoritative >= count) {
            count = authoritative;
          }
        }
      } catch (_) {}

      if (count > 1) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          buildThreadCountBadge(context, count),
          const SizedBox(width: 4),
        ]);
      }
      return const SizedBox.shrink();
    });
  }

  Widget buildThreadCountBadge(BuildContext context, int count, {bool forceVisible = false}) {
    if (count <= 1 && !forceVisible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColor.lightGrayEBEDF0,
        borderRadius: BorderRadius.all(Radius.circular(0)),
      ),
      child: Text(
        '$count',
        style: ThemeUtils.defaultTextStyleInterFont.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColor.gray686E76,
        ),
      ),
    );
  }

  Widget buildMailboxContain(
    BuildContext context,
    bool isSearchEmailRunning,
    PresentationEmail email
  ) {
    // Show chips in unified and system folders (Inbox/Sent/Trash...), hide only
    // when browsing a personal folder (user-created label) and not searching.
    // Show label chips for personal folders (labels) only.
    // - Never show system/default mailboxes (Inbox/Sent/Trash...)
    // - Do not show the current container mailbox (when viewing inside that folder)

    // Show chips on all list views (when allowed), but skip the current folder chip itself

    // Do not show label chip for the mailbox currently being viewed

    final chips = <Widget>[];
    final allLabelNames = <String>[];
    final selected = mailboxDashBoardController.selectedMailbox.value;
    final inSpecificMailbox = selected != null && selected.id != PresentationMailbox.unifiedMailbox.id;
    final mailboxIds = email.mailboxIds;
    if (mailboxIds != null && mailboxIds.isNotEmpty == true) {
      final entries = mailboxIds.entries.where((e) => e.value == true);
      for (final entry in entries) {
        final mailbox = mailboxDashBoardController.mapMailboxById[entry.key];
        if (mailbox == null) continue;
        // Skip current container mailbox only when viewing inside that specific folder
        if (inSpecificMailbox && mailbox.id == selected.id) continue;
        // Skip system/default mailbox chips (Inbox, Sent, Trash, etc.)
        if (mailbox.isDefault) continue;
        final display = mailbox.getDisplayName(context);
        if (display.isEmpty) continue;
        allLabelNames.add(display);
        final chipColor = mailbox.colorHex != null ? Color(mailbox.colorHex!) : AppColor.backgroundCounterMailboxColor;
        // Compute perceived background after mixing with white (since we render translucently on white)
        const double fill = 0.25; // should match container fill strength
        final bgColor = Color.lerp(Colors.white, chipColor, fill)!;
        final isBgLight = bgColor.computeLuminance() >= 0.55;
        chips.add(Container(
          margin: const EdgeInsetsDirectional.only(start: 8),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(100)),
            color: bgColor,
            border: Border.all(color: chipColor.withOpacity(0.6)),
          ),
          child: TextOverflowBuilder(
            display,
            style: ThemeUtils.defaultTextStyleInterFont.copyWith(
              fontFamily: ConstantsUI.fontApp,
              fontSize: 10,
              color: isBgLight ? Colors.black : Colors.white,
              height: 24 / 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      }
    }
    int maxVisible = 3;
    if (responsiveUtils.isMobile(context)) {
      maxVisible = 1;
    } else if (responsiveUtils.isTablet(context)) {
      // Favor title width on tablet: show only 1 chip + N
      maxVisible = 1;
    }

    List<Widget> visibleChips = chips;
    if (chips.length > maxVisible) {
      final hidden = chips.length - maxVisible;
      visibleChips = chips.take(maxVisible).toList(growable: true);
      visibleChips.add(_buildMoreLabelsChip(context, hidden, allLabelNames));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: visibleChips),
    );
  }

  Widget _buildMoreLabelsChip(
    BuildContext context,
    int hiddenCount,
    List<String> allLabels,
  ) {
    const Color chipColor = AppColor.backgroundCounterMailboxColor;
    final Color bgColor = Color.lerp(Colors.white, chipColor, 0.25)!;
    final bool isBgLight = bgColor.computeLuminance() >= 0.55;
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(AppLocalizations.of(context).showAll),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allLabels.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(100)),
                      color: bgColor,
                      border: Border.all(color: chipColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      name,
                      style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                        fontFamily: ConstantsUI.fontApp,
                        fontSize: 12,
                        color: isBgLight ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).close),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 8),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(100)),
          color: bgColor,
          border: Border.all(color: chipColor.withOpacity(0.6)),
        ),
        child: Text(
          '+$hiddenCount',
          style: ThemeUtils.defaultTextStyleInterFont.copyWith(
            fontFamily: ConstantsUI.fontApp,
            fontSize: 10,
            color: isBgLight ? Colors.black : Colors.white,
            height: 24 / 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool isSearchEnabled(bool isSearchEmailRunning, SearchQuery? query) {
    return isSearchEmailRunning && query?.value.isNotEmpty == true;
  }

  FontWeight buildFontForReadEmail(PresentationEmail email) =>
      !email.hasRead ? FontWeight.w600 : FontWeight.normal;

  Color buildTextColorForReadEmail(PresentationEmail email) =>
      email.hasRead ? AppColor.steelGray400 : Colors.black;

  bool hasMailboxLabel(bool isSearchEmailRunning, PresentationEmail email) {
    return isSearchEmailRunning && email.mailboxContain != null;
  }

  String informationSender(PresentationEmail email, PresentationMailbox? mailbox) {
    // Inbox-like folders: show RecipientNameOrEmail, then ", me", then count (no badge)
    final isComposerSide = mailbox?.isSent == true || mailbox?.isDrafts == true || mailbox?.isOutbox == true;
    if (isComposerSide) {
      return email.recipientsName();
    }

    // Gather combined view for thread-level heuristics
    final String own = mailboxDashBoardController.ownEmailAddress.value.toLowerCase();
    final threadKey = email.threadId?.id.value;
    final combined = <PresentationEmail>{}
      ..addAll(mailboxDashBoardController.emailsInCurrentMailbox)
      ..addAll(mailboxDashBoardController.listResultSearch);
    final selected = mailboxDashBoardController.selectedEmail.value;
    if (selected != null && selected.threadId?.id.value == threadKey) {
      combined.add(selected);
    }

    // Derive a counterpart display name (prefer displayName, else short email)
    String counterpartName = '';
    String resolveAddressName(String? nameOrDisplay, String? emailAddr) {
      if (nameOrDisplay != null && nameOrDisplay.trim().isNotEmpty) return nameOrDisplay.trim();
      return _shortenEmail(emailAddr ?? '');
    }

    bool isFromMe(PresentationEmail e) =>
      e.from?.any((a) => (a.email ?? '').toLowerCase() == own) == true;

    // Prefer the other party from the current email
    final currentFromIsMe = isFromMe(email);
    if (!currentFromIsMe) {
      final fromAddr = email.from?.firstOrNull;
      if (fromAddr != null && (fromAddr.email ?? '').toLowerCase() != own) {
        // Use display name if present, else email
        final name = (fromAddr.name ?? '').trim().isNotEmpty
          ? (fromAddr.name ?? '')
          : fromAddr.email ?? '';
        counterpartName = resolveAddressName(name, fromAddr.email);
      }
    } else {
      // When I sent the current email, show the first recipient (even if it's me)
      final toOther = email.to?.firstOrNull;
      if (toOther != null) {
        final name = (toOther.name ?? '').trim().isNotEmpty
          ? (toOther.name ?? '')
          : toOther.email ?? '';
        counterpartName = resolveAddressName(name, toOther.email);
      }
    }
    if (counterpartName.isEmpty && threadKey != null) {
      // Fallback to any email in thread not from me
      final anyOther = combined
          .where((e) => e.threadId?.id.value == threadKey)
          .firstWhereOrNull((e) => !isFromMe(e));
      if (anyOther != null) {
        final from = anyOther.from?.firstOrNull;
        final name = (from?.name ?? '').trim().isNotEmpty
          ? (from?.name ?? '')
          : from?.email ?? '';
        counterpartName = resolveAddressName(name, from?.email);
      }
    }
    if (counterpartName.isEmpty) {
      // Last fallback: current sender name or shortened email
      final from = email.from?.firstOrNull;
      counterpartName = resolveAddressName(email.getSenderName(), from?.email);
    }

    // Smart truncation to keep ", me" and count visible on narrow rows
    String _truncateDisplayName(String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return trimmed;
      final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      // If long, keep only the first word; else allow up to two words
      String candidate;
      if (trimmed.length > 15) {
        candidate = words.isNotEmpty ? words.first : trimmed;
      } else {
        candidate = words.length >= 2 ? '${words[0]} ${words[1]}' : words.first;
      }
      if (candidate.length > 15) {
        candidate = candidate.substring(0, 15) + '…';
      }
      return candidate;
    }

    String _truncateEmailSimple(String emailStr) {
      if (emailStr.length <= 10) return emailStr;
      return emailStr.substring(0, 10) + '…';
    }

    bool _looksLikeEmail(String s) => s.contains('@');

    // Apply truncation rules
    counterpartName = _looksLikeEmail(counterpartName)
        ? _truncateEmailSimple(counterpartName)
        : _truncateDisplayName(counterpartName);

    // Participation marker
    // Show ", me" when I have participated in the conversation (sent any message
    // in this thread, including the very first email or any reply). This is
    // more robust than relying on the $answered keyword alone.
    // Show "me" when there are replies in the thread
    bool meTagged = computeThreadCount(email) > 1;

    // Keep count reactive via provider later

    // Determine ordering using authoritative thread chronology when possible
    bool iStarted = false;
    try {
      if (threadKey != null && email.threadId != null) {
        final provider = Get.put(ThreadCountProvider(), permanent: true);
        provider.ensure(email.threadId!);
        final authoritative = provider.startedByMe[email.threadId!];
        if (authoritative != null) {
          iStarted = authoritative;
        } else {
          // Fallback quick heuristic until provider fetches
          final emailsInThread = combined
              .where((e) => e.threadId?.id.value == threadKey)
              .toList()
            ..sort((a, b) {
              final aTime = a.receivedAt?.value ?? a.sentAt?.value ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = b.receivedAt?.value ?? b.sentAt?.value ?? DateTime.fromMillisecondsSinceEpoch(0);
              return aTime.compareTo(bTime);
            });
          if (emailsInThread.isNotEmpty) iStarted = isFromMe(emailsInThread.first);
        }
      }
    } catch (_) {}

    final ctx = Get.context;
    final String meLabel = ctx != null ? AppLocalizations.of(ctx).me_label : 'me';
    String head;
    if (meTagged && iStarted) {
      head = '$meLabel, $counterpartName';
    } else if (meTagged) {
      head = '$counterpartName, $meLabel';
    } else {
      head = counterpartName;
    }
    // Do not append count here; UI will render it separately with lighter style
    return head;
  }

  String _shortenEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    final shortDomain = domain.length <= 10 ? domain : '${domain.substring(0, 10)}…';
    String shortLocal;
    if (local.length <= 10) {
      shortLocal = local;
    } else {
      // Keep first 6 + … + last 2 for readability
      shortLocal = '${local.substring(0, 6)}…${local.substring(local.length - 2)}';
    }
    return '$shortLocal@$shortDomain';
  }

  Widget buildInformationSender(
    BuildContext context,
    PresentationEmail email,
    PresentationMailbox? mailbox,
    bool isSearchEmailRunning,
    SearchQuery? query
  ) {
    // Make this reactive to authoritative thread count changes
    if (email.threadId != null) {
      try {
        final provider = Get.put(ThreadCountProvider(), permanent: true);
        provider.ensure(email.threadId!);
        return Obx(() {
          // Depend on provider's count to trigger rebuild when it updates
          final count = provider.counts[email.threadId!] ?? computeThreadCount(email);
          final nameText = informationSender(email, mailbox);
          final baseStyle = !email.hasRead
              ? ThemeUtils.textStyleBodyContact(color: Colors.black)
              : ThemeUtils.textStyleBodyBody2(color: AppColor.steelGray400);
          final countStyle = Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
        fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColor.steelGray400,
              );
          final hideCountInSent = mailbox?.isSent == true;
          return Text.rich(
            TextSpan(children: [
              TextSpan(text: nameText, style: baseStyle),
              if (count > 1 && !hideCountInSent) TextSpan(text: ' $count', style: countStyle),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        });
      } catch (_) {}
    }

    // Non-reactive fallback (no thread id)
    final nameText = informationSender(email, mailbox);
    final baseStyle = !email.hasRead
        ? ThemeUtils.textStyleBodyContact(color: Colors.black)
        : ThemeUtils.textStyleBodyBody2(color: AppColor.steelGray400);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: nameText, style: baseStyle),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget buildEmailTitle(
    BuildContext context,
    PresentationEmail email,
    bool isSearchEmailRunning,
    SearchQuery? query
  ) {
    String cleanSubject(String subject) {
      // Restore original behavior: do not strip RE / RE[X] / Fwd prefixes
      return subject;
    }

    final cleanedTitle = cleanSubject(email.getEmailTitle());
    // Debug suffix to differentiate threads with same title
    String debugSuffix = '';
    try {
      final tid = email.threadId?.id.value;
      if (tid != null && tid.length >= 6) {
        debugSuffix = '  [${tid.substring(0,6)}]';
      }
    } catch (_) {}
    if (isSearchEnabled(isSearchEmailRunning, query)) {
      return RichTextBuilder(
        textOrigin: '$cleanedTitle$debugSuffix',
        wordToStyle: query?.value ?? '',
        preMarkedText: email.sanitizedSearchSnippetSubject,
        ensureHighlightVisible: true,
        styleOrigin: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: buildTextColorForReadEmail(email),
          fontWeight: buildFontForReadEmail(email),
        ),
        styleWord: Theme.of(context).textTheme.bodySmall?.copyWith(
          backgroundColor: Colors.amberAccent[200],
          color: buildTextColorForReadEmail(email),
          fontWeight: buildFontForReadEmail(email),
        ),
      );
    } else {
      return TextOverflowBuilder(
        '$cleanedTitle$debugSuffix',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: buildTextColorForReadEmail(email),
          fontWeight: buildFontForReadEmail(email),
        ),
      );
    }
  }

  Widget buildEmailPartialContent(
    BuildContext context,
    PresentationEmail email,
    bool isSearchEmailRunning,
    SearchQuery? query
  ) {
    if (isSearchEnabled(isSearchEmailRunning, query)) {
      return RichTextBuilder(
        textOrigin: email.getPartialContent(),
        wordToStyle: query?.value ?? '',
        preMarkedText: email.sanitizedSearchSnippetPreview,
        ensureHighlightVisible: true,
        styleOrigin: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColor.steelGray400,
        ),
        styleWord: Theme.of(context).textTheme.bodySmall?.copyWith(
          backgroundColor: Colors.amberAccent[200],
        ),
      );
    } else {
      return TextOverflowBuilder(
        email.getPartialContent(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColor.steelGray400,
        )
      );
    }
  }

  Widget buildDateTime(BuildContext context, PresentationEmail email) {
    return Text(
        email.getReceivedAt(Localizations.localeOf(context).toLanguageTag()),
        maxLines: 1,
        softWrap: CommonTextStyle.defaultSoftWrap,
        overflow: CommonTextStyle.defaultTextOverFlow,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: buildTextColorForReadEmail(email),
          fontWeight: buildFontForReadEmail(email),
        ),
    );
  }

  Widget buildIconChevron() {
    return SvgPicture.asset(
        imagePaths.icChevron,
        width: 16,
        height: 16,
        fit: BoxFit.fill);
  }

  Widget buildIconAttachment() {
    return SvgPicture.asset(
        imagePaths.icAttachment,
        width: 16,
        height: 16,
        colorFilter: ItemEmailTileStyles.actionIconColor.asFilter(),
        fit: BoxFit.fill);
  }

  Widget buildIconUnreadStatus() {
    return SvgPicture.asset(
      imagePaths.icUnreadStatus,
      width: 9,
      height: 9,
      fit: BoxFit.fill,
    );
  }

  Widget buildIconStar() {
    return SvgPicture.asset(
        imagePaths.icStar,
        width: 15,
        height: 15,
        fit: BoxFit.fill);
  }

  Widget buildIconAvatarText(
    PresentationEmail email,
    {
      double? iconSize,
      TextStyle? textStyle
    }
  ) {
    return Container(
      width: iconSize ?? ItemEmailTileStyles.avatarIconSize,
      height: iconSize ?? ItemEmailTileStyles.avatarIconSize,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: email.avatarColors
        )
      ),
      child: Text(
        email.getAvatarText(),
        style: textStyle ?? ThemeUtils.textStyleHeadingHeadingSmall(
          color: Colors.white,
        ),
      )
    );
  }

  Widget buildIconAvatarSelection(
      BuildContext context,
      PresentationEmail email,
      {
        double? iconSize,
        TextStyle? textStyle
      }
  ) {
    if (PlatformInfo.isWeb) {
      return Container(
        color: Colors.transparent,
        width: iconSize ?? 48,
        height: iconSize ?? 48,
        alignment: Alignment.center,
        padding: responsiveUtils.isDesktop(context)
            ? const EdgeInsetsDirectional.symmetric(horizontal: 4)
            : const EdgeInsetsDirectional.all(12),
        child: SvgPicture.asset(
            email.isSelected
                ? imagePaths.icSelected
                : imagePaths.icUnSelected,
            fit: BoxFit.fill),
      );
    } else {
      return Container(
          alignment: Alignment.center,
          color: Colors.transparent,
          child: SvgPicture.asset(
              email.isSelected
                  ? imagePaths.icSelected
                  : imagePaths.icUnSelected,
              width: 24, height: 24));
    }
  }

  Widget buildIconAnsweredOrForwarded({
    required PresentationEmail presentationEmail,
    double? width,
    double? height
  }) {
    if (presentationEmail.isAnsweredAndForwarded) {
      return _iconAnsweredOrForwardedWidget(
        iconPath:  imagePaths.icReplyAndForward,
        width: width,
        height: height
      );
    } else if (presentationEmail.isAnswered) {
      return _iconAnsweredOrForwardedWidget(
        iconPath: imagePaths.icReply,
        width: width,
        height: height
      );
    } else if (presentationEmail.isForwarded) {
      return _iconAnsweredOrForwardedWidget(
        iconPath: imagePaths.icForwarded,
        width: width,
        height: height
      );
    } else {
      return const SizedBox(width: 16, height: 16);
    }
  }

  Widget _iconAnsweredOrForwardedWidget({
    required String iconPath,
    double? width,
    double? height
  }) {
    return SvgPicture.asset(
      iconPath,
      width: width ?? 20,
      height: height ?? 20,
      colorFilter: ItemEmailTileStyles.actionIconColor.asFilter(),
      fit: BoxFit.fill);
  }

  String? messageToolTipForAnsweredOrForwarded(BuildContext context, PresentationEmail presentationEmail) {
    if (presentationEmail.isAnsweredAndForwarded) {
      return AppLocalizations.of(context).repliedAndForwardedMessage;
    } else if (presentationEmail.isAnswered) {
      return AppLocalizations.of(context).repliedMessage;
    } else if (presentationEmail.isForwarded){
      return AppLocalizations.of(context).forwardedMessage;
    } else {
      return null;
    }
  }

  Widget buildCalendarEventIcon({
    required BuildContext context,
    required PresentationEmail presentationEmail
  }) {
    return Padding(
      padding: ItemEmailTileStyles.getSpaceCalendarEventIcon(context, responsiveUtils),
      child: SvgPicture.asset(
        imagePaths.icCalendarEvent,
        width: 20,
        height: 20,
        fit: BoxFit.fill,
        colorFilter: presentationEmail.hasRead
          ? ItemEmailTileStyles.actionIconColor.asFilter()
          : Colors.black.asFilter(),
      ),
    );
  }

  Widget buildMarkAsImportantIcon(BuildContext context) {
    return Padding(
      key: const Key('important_flag_icon'),
      padding: ItemEmailTileStyles.getSpaceCalendarEventIcon(
        context,
        responsiveUtils,
      ),
      child: SvgPicture.asset(
        imagePaths.icMarkAsImportant,
        width: 20,
        height: 20,
        fit: BoxFit.fill,
        colorFilter: ItemEmailTileStyles.actionIconColor.asFilter(),
      ),
    );
  }
}