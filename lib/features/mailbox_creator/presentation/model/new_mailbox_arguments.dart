
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:model/mailbox/presentation_mailbox.dart';

class NewMailboxArguments with EquatableMixin {
  final MailboxName newName;
  final PresentationMailbox? mailboxLocation;
  final Color? color;

  NewMailboxArguments(this.newName, {this.mailboxLocation, this.color});

  @override
  List<Object?> get props => [newName, mailboxLocation, color];
}