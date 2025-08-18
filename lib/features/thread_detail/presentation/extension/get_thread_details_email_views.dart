import 'package:flutter/material.dart';
import 'package:model/email/email_action_type.dart';
import 'package:model/extensions/presentation_email_extension.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:tmail_ui_user/features/email/presentation/email_view.dart';
import 'package:model/email/email_in_thread_status.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/extensions/handle_open_context_menu_extension.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/get_thread_detail_email_mailbox_contains.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/load_more_thread_detail_emails.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/thread_detail_on_email_action_click.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/thread_detail_open_email_address_detail_action.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_emails_by_ids_state.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/thread_detail_load_more_segments.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/toggle_thread_detail_collape_expand.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/extension/toggle_show_previous_messages.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/widgets/thread_detail_collapsed_email.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/widgets/thread_detail_load_more_circle.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

extension GetThreadDetailEmailViews on ThreadDetailController {
  List<Widget> getThreadDetailEmailViews() {
    final loadMoreSegments = Map<LoadMoreIndex, LoadMoreCount>.from(this.loadMoreSegments);

    // Determine the first NON-NULL email id to keep its header/title always visible
    EmailId? firstEmailId;
    for (final entry in emailIdsPresentation.entries) {
      final value = entry.value;
      if (value != null) {
        firstEmailId = entry.key;
        break;
      }
    }
    // Fallback: if still null, use the very first key
    firstEmailId ??= emailIdsPresentation.keys.isNotEmpty
        ? emailIdsPresentation.keys.first
        : null;

    // Get collapsed emails, but exclude the first message from grouping consideration
    final collapsedEmailsExcludingFirst = emailIdsPresentation.entries
        .where((entry) => entry.key != firstEmailId)
        .where((entry) => entry.value?.emailInThreadStatus == EmailInThreadStatus.collapsed)
        .toList();

    // Only show group bar if there are 3 or more collapsed emails after the first message
    final showGlobalCollapsedGroup = !showPreviousMessages.value && collapsedEmailsExcludingFirst.length >= 3;

    // Track index of the first non-null email for positioning the group bar
    final keysList = emailIdsPresentation.keys.toList();
    final firstIndex = firstEmailId != null ? keysList.indexOf(firstEmailId!) : -1;

    // Find the first VISIBLE email index after the group bar when grouping is active
    int nextVisibleAfterGroupBarIndex = -1;
    if (showGlobalCollapsedGroup && firstIndex != -1) {
      for (int i = firstIndex + 1; i < keysList.length; i++) {
        final key = keysList[i];
        final value = emailIdsPresentation[key];
        // When grouped, only expanded emails are visible
        if (value?.emailInThreadStatus == EmailInThreadStatus.expanded) {
          nextVisibleAfterGroupBarIndex = i;
          break;
        }
      }
    }

    // Determine the previous visible collapsed email before the NEWEST email (stable while grouped)
    // Find newest (last) non-null email index
    int newestIndex = -1;
    for (int i = keysList.length - 1; i >= 0; i--) {
      final key = keysList[i];
      final value = emailIdsPresentation[key];
      if (value != null) { newestIndex = i; break; }
    }
    final expandedId = currentExpandedEmailId.value;
    final expandedIndex = expandedId != null ? keysList.indexOf(expandedId) : -1;
    // Only show the second-last preview when the newest email is expanded, to avoid shifting preview on tap
    final showSecondLastPreview = showGlobalCollapsedGroup && expandedIndex == newestIndex;
    int secondLastIndex = -1;
    if (showSecondLastPreview && newestIndex > 0) {
      for (int i = newestIndex - 1; i >= 0; i--) {
        final key = keysList[i];
        if (key == firstEmailId) continue; // don't use the first as the preview here
        final value = emailIdsPresentation[key];
        if (value == null) continue; // skip null placeholders
        // We allow either collapsed or expanded here; if expanded, it will render in expanded branch
        secondLastIndex = i;
        break;
      }
    }
    final shouldRevealSecondLastCollapsed = showSecondLastPreview && secondLastIndex != -1;
    // If user expands a non-newest email while grouped, still show the newest email as collapsed
    final showNewestCollapsed = showGlobalCollapsedGroup && expandedIndex != -1 && newestIndex != -1 && expandedIndex != newestIndex;

    // Adjust group count if we're revealing the second-to-last collapsed message
    final adjustedGroupCount = collapsedEmailsExcludingFirst.length
        - (shouldRevealSecondLastCollapsed ? 1 : 0)
        - (showNewestCollapsed ? 1 : 0);

    // Always show expanded emails and optionally show individual collapsed emails
    return emailIdsPresentation.entries.map((entry) {
      final emailId = entry.key;
      final presentationEmail = entry.value;
      final indexOfEmailId = keysList.indexOf(emailId);
      
      if (presentationEmail == null) {
        // When the global collapsed group bar is active, do not render per-segment
        // load-more circles (from null placeholders). Otherwise we end up with
        // extra small groups like a lone "1" near the newest email.
        if (showGlobalCollapsedGroup) {
          return const SizedBox.shrink();
        }
        if (loadMoreSegments[indexOfEmailId] == null) {
          return const SizedBox.shrink();
        }

        return ThreadDetailLoadMoreCircle(
          count: loadMoreSegments[indexOfEmailId]!,
          onTap: () => loadMoreThreadDetailEmails(
            loadMoreIndex: indexOfEmailId,
            loadMoreCount: loadMoreSegments[indexOfEmailId]!,
          ),
          imagePaths: imagePaths,
          isLoading: viewState.value.fold(
            (failure) => false,
            (success) => success is GettingEmailsByIds &&
              success.loadingIndex == indexOfEmailId,
          ),
        );
      }

      final isFirstEmailInThreadDetail = emailId == firstEmailId;

      // Show collapsed emails if showPreviousMessages is true OR if there are fewer than 3 collapsed emails
      // Always render the first message even when grouping is active
      if ((presentationEmail.emailInThreadStatus == EmailInThreadStatus.collapsed ||
          presentationEmail.emailInThreadStatus == null) && 
          (isFirstEmailInThreadDetail
            || (shouldRevealSecondLastCollapsed && indexOfEmailId == secondLastIndex)
            || (showNewestCollapsed && indexOfEmailId == newestIndex)
            || showPreviousMessages.value
            || collapsedEmailsExcludingFirst.length < 3)) {
        
        final isSecondLastPreview = shouldRevealSecondLastCollapsed && indexOfEmailId == secondLastIndex;
        // Ensure expansion status is not null, so toggle works when tapping collapsed preview
        final normalizedPresentation = (presentationEmail.emailInThreadStatus == null)
            ? presentationEmail.copyWith(emailInThreadStatus: EmailInThreadStatus.collapsed)
            : presentationEmail;
        final collapsedWidget = ThreadDetailCollapsedEmail(
          presentationEmail: normalizedPresentation.copyWith(
            subject: isFirstEmailInThreadDetail
              ? emailIdsPresentation.values.last?.subject
              : null
          ),
          showSubject: isFirstEmailInThreadDetail,
          imagePaths: imagePaths,
          responsiveUtils: responsiveUtils,
          mailboxContain: normalizedPresentation.findMailboxContain(
            mailboxDashBoardController.mapMailboxById,
          ),
          emailLoaded: null,
          onEmailActionClick: threadDetailOnEmailActionClick,
          onMoreActionClick: (presentationEmail, position) => emailActionReactor.handleMoreEmailAction(
            mailboxContain: getThreadDetailEmailMailboxContains(normalizedPresentation),
            presentationEmail: normalizedPresentation,
            position: position,
            responsiveUtils: responsiveUtils,
            imagePaths: imagePaths,
            username: session?.username,
            handleEmailAction: threadDetailOnEmailActionClick,
            additionalActions: [
              EmailActionType.forward,
              EmailActionType.replyAll,
              EmailActionType.replyToList,
              EmailActionType.printAll,
              if (currentContext != null &&
                  responsiveUtils.isMobile(currentContext!))
                EmailActionType.moveToMailbox,
              if (!responsiveUtils.isDesktop(currentContext!)) ...[
                EmailActionType.markAsStarred,
                EmailActionType.unMarkAsStarred,
                EmailActionType.moveToTrash,
                EmailActionType.deletePermanently,
              ],
            ],
            emailIsRead: presentationEmail.hasRead,
            openBottomSheetContextMenu: mailboxDashBoardController.openBottomSheetContextMenu,
            openPopupMenu: mailboxDashBoardController.openPopupMenu,
          ),
          openEmailAddressDetailAction: (_, emailAddress) {
            openEmailAddressDetailAction(emailAddress);
          },
          onToggleThreadDetailCollapseExpand: () {
            // Expand the tapped item without revealing all grouped messages
            toggleThreadDetailCollapeExpand(normalizedPresentation);
          },
          // Borders when group bar is visible:
          // - First collapsed: hide bottom border only
          // - Second-last collapsed preview: hide top border only
          // - Newest collapsed (when a non-newest is expanded): no suppression
          suppressTopBorder: isSecondLastPreview,
          suppressBottomBorder: isFirstEmailInThreadDetail && showGlobalCollapsedGroup,
        );
        if (isFirstEmailInThreadDetail && showGlobalCollapsedGroup) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              collapsedWidget,
              ThreadDetailLoadMoreCircle(
                count: adjustedGroupCount,
                onTap: toggleShowPreviousMessages,
                imagePaths: imagePaths,
                isLoading: false,
              ),
            ],
          );
        }
        return collapsedWidget;
      }

      // Show expanded emails
      if (presentationEmail.emailInThreadStatus == EmailInThreadStatus.expanded) {
        // Do not suppress expanded top border; it must return when group is expanded
        final expanded = Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 16),
          child: EmailView(
            key: GlobalObjectKey('${presentationEmail.id?.id.value ?? ''}${isFirstEmailInThreadDetail ? 'firstInThread' : ''}'),
            isInsideThreadDetailView: true,
            emailId: presentationEmail.id,
            isFirstEmailInThreadDetail: isFirstEmailInThreadDetail,
            suppressTopBorder: false,
            threadSubject: isFirstEmailInThreadDetail
                ? emailIdsPresentation.values.last?.subject
                : null,
            onToggleThreadDetailCollapseExpand: () {
              toggleThreadDetailCollapeExpand(presentationEmail);
            },
            scrollController: scrollController,
          ),
        );
        // If this is the first email, and global grouping is active, append the group bar AFTER the first email
        if (isFirstEmailInThreadDetail && showGlobalCollapsedGroup) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              expanded,
              ThreadDetailLoadMoreCircle(
                count: adjustedGroupCount,
                onTap: toggleShowPreviousMessages,
                imagePaths: imagePaths,
                isLoading: false,
              ),
            ],
          );
        }
        return expanded;
      }

      // Don't show collapsed emails if showPreviousMessages is false AND there are 3+ collapsed emails (they're grouped)
      // but never hide the first message and the chosen second-to-last collapsed preview
      if (!isFirstEmailInThreadDetail
          && (!shouldRevealSecondLastCollapsed || indexOfEmailId != secondLastIndex)
          && (!showNewestCollapsed || indexOfEmailId != newestIndex)
          && !showPreviousMessages.value && collapsedEmailsExcludingFirst.length >= 3 &&
           (presentationEmail.emailInThreadStatus == EmailInThreadStatus.collapsed ||
            presentationEmail.emailInThreadStatus == null)) {
        return const SizedBox.shrink();
      }

      return const SizedBox.shrink();
    }).where((widget) => widget is! SizedBox || (widget as SizedBox).child != null).toList();
  }
}
