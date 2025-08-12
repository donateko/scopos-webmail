import 'package:equatable/equatable.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:model/email/presentation_email.dart';

class ThreadConversation with EquatableMixin {
  final ThreadId threadId;
  final List<PresentationEmail> emails;
  final String subject;
  final bool isExpanded;
  final int unreadCount;
  final DateTime? latestEmailDate;
  final PresentationEmail? latestEmail;

  const ThreadConversation({
    required this.threadId,
    required this.emails,
    required this.subject,
    this.isExpanded = false,
    required this.unreadCount,
    this.latestEmailDate,
    this.latestEmail,
  });

  ThreadConversation copyWith({
    ThreadId? threadId,
    List<PresentationEmail>? emails,
    String? subject,
    bool? isExpanded,
    int? unreadCount,
    DateTime? latestEmailDate,
    PresentationEmail? latestEmail,
  }) {
    return ThreadConversation(
      threadId: threadId ?? this.threadId,
      emails: emails ?? this.emails,
      subject: subject ?? this.subject,
      isExpanded: isExpanded ?? this.isExpanded,
      unreadCount: unreadCount ?? this.unreadCount,
      latestEmailDate: latestEmailDate ?? this.latestEmailDate,
      latestEmail: latestEmail ?? this.latestEmail,
    );
  }

  bool get hasMultipleEmails => emails.length > 1;

  bool get hasUnreadEmails => unreadCount > 0;

  @override
  List<Object?> get props => [
    threadId,
    emails,
    subject,
    isExpanded,
    unreadCount,
    latestEmailDate,
    latestEmail,
  ];

  static ThreadConversation fromEmails(List<PresentationEmail> emails) {
    if (emails.isEmpty) {
      throw ArgumentError('Cannot create ThreadConversation from empty email list');
    }

    // Sort emails by received date (oldest first)
    final sortedEmails = List<PresentationEmail>.from(emails)
      ..sort((a, b) => (a.receivedAt?.value ?? DateTime.now())
          .compareTo(b.receivedAt?.value ?? DateTime.now()));

    final threadId = sortedEmails.first.threadId!;
    final subject = sortedEmails.first.subject ?? '';
    final unreadCount = sortedEmails.where((email) => !email.hasRead).length;
    final latestEmail = sortedEmails.last;
    final latestEmailDate = latestEmail.receivedAt?.value;

    return ThreadConversation(
      threadId: threadId,
      emails: sortedEmails,
      subject: subject,
      unreadCount: unreadCount,
      latestEmailDate: latestEmailDate,
      latestEmail: latestEmail,
    );
  }
}
