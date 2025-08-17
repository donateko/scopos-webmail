import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:model/email/presentation_email.dart';
import 'package:tmail_ui_user/features/email/presentation/bindings/email_bindings.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/dashboard_routes.dart';
import 'package:model/email/email_in_thread_status.dart';
import 'package:tmail_ui_user/features/thread_detail/domain/state/get_emails_by_ids_state.dart';
import 'package:tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension HandleGetEmailsByIdsSuccess on ThreadDetailController {
  void handleGetEmailsByIdsSuccess(GetEmailsByIdsSuccess success) {
    final currentRoute = mailboxDashBoardController.dashboardRoute.value;
    // Allow processing for thread detailed route AND email detailed route (single email view)
    // and when we have thread emails to process
    final shouldProcessThreadEmails = currentRoute == DashboardRoutes.threadDetailed || 
        currentRoute == DashboardRoutes.emailDetailed ||
        success.presentationEmails.length > 1 ||
        emailIdsPresentation.isNotEmpty;
    
    if (!shouldProcessThreadEmails) {
      return;
    }

    final selectedEmailId = mailboxDashBoardController.selectedEmail.value?.id;
    final isLoadMore = emailIdsPresentation.values.nonNulls.isNotEmpty;
    
    // Find the chronologically latest email among ALL emails (including newly loaded ones)
    PresentationEmail? latestEmail;
    DateTime? latestTimestamp;
    
    // Check all emails in the presentation for the most recent timestamp
    for (final entry in emailIdsPresentation.entries) {
      final email = entry.value;
      if (email?.receivedAt != null) {
        final timestamp = email!.receivedAt!.value;
        if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
          latestTimestamp = timestamp;
          latestEmail = email;
        }
      }
    }
    
    // Also check the newly loaded emails
    for (var email in success.presentationEmails) {
      if (email.receivedAt != null) {
        final timestamp = email.receivedAt!.value;
        if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
          latestTimestamp = timestamp;
          latestEmail = email;
        }
      }
    }

    final latestEmailId = latestEmail?.id;

    for (var presentationEmail in success.presentationEmails) {
      if (presentationEmail.id == null) continue;

      // Expand only the chronologically latest email, collapse all others
      final shouldExpand = presentationEmail.id == latestEmailId;
      final finalStatus = shouldExpand ? EmailInThreadStatus.expanded : EmailInThreadStatus.collapsed;

      emailIdsPresentation[presentationEmail.id!] = presentationEmail.copyWith(
        emailInThreadStatus: finalStatus,
      );

      // If expanding this email, ensure its dependencies are injected
      if (shouldExpand) {
        EmailBindings(currentEmailId: presentationEmail.id).dependencies();
        currentExpandedEmailId.value = presentationEmail.id;
      }
    }

    // Also update any existing emails that might need status change
    emailIdsPresentation.updateAll((key, value) {
      if (value == null) return null;
      final shouldExpand = key == latestEmailId;
      return value.copyWith(
        emailInThreadStatus: shouldExpand ? EmailInThreadStatus.expanded : EmailInThreadStatus.collapsed,
      );
    });
    threadDetailManager.currentMobilePageViewIndex.refresh();

    // Metadata loaded

    if (_skipScrollJump(isLoadMore)) return;
    
    final currentExpandedEmailIndex = currentExpandedEmailId.value == null
      ? -1
      : emailIdsPresentation.keys.toList().indexOf(currentExpandedEmailId.value!);
    final firstLoadedMoreEmailId = success.presentationEmails.firstOrNull?.id;
    final firstLoadedMoreEmailIndex = firstLoadedMoreEmailId == null
      ? -1
      : emailIdsPresentation.keys.toList().indexOf(firstLoadedMoreEmailId);
    if (currentExpandedEmailIndex == -1 || firstLoadedMoreEmailIndex == -1) {
      return;
    }

    if (scrollController?.hasClients == false) return;
    final currentScrollPosition = scrollController?.position.pixels;
    final maxScrollExtent = scrollController?.position.maxScrollExtent;
    final currentBottomScrollPosition = currentScrollPosition != null
        && maxScrollExtent != null
      ? maxScrollExtent - currentScrollPosition
      : null;
    
    if (currentBottomScrollPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newMaxScrollExtent = scrollController?.position.maxScrollExtent;
        if (newMaxScrollExtent == null) return;

        if (currentExpandedEmailIndex < firstLoadedMoreEmailIndex) {
          return;
        } else if (newMaxScrollExtent != maxScrollExtent!) {
          scrollController?.jumpTo(newMaxScrollExtent - currentBottomScrollPosition);
        }
      });
    }
  }

  bool _skipScrollJump(bool isLoadMore) =>
      !isLoadMore || emailIdsPresentation.length == 1;
}
