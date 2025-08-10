import 'package:equatable/equatable.dart';

class Contacts with EquatableMixin {
  final String href;
  final String? etag;
  final String? fullName;
  final List<String> emails;
  final List<String> phones;

  const Contacts({
    required this.href,
    this.etag,
    this.fullName,
    this.emails = const [],
    this.phones = const [],
  });

  @override
  List<Object?> get props => [href, etag, fullName, emails, phones];

  static Contacts fromVCard(String vcard, {required String href, String? etag}) {
    // Unfold lines per RFC: continuation lines begin with space or tab
    final rawLines = vcard.split(RegExp(r'\r?\n'));
    final lines = <String>[];
    for (final raw in rawLines) {
      if (raw.isEmpty) continue;
      if (raw.startsWith(' ') || raw.startsWith('\t')) {
        if (lines.isNotEmpty) {
          lines[lines.length - 1] += raw.trimLeft();
        }
      } else {
        lines.add(raw);
      }
    }

    String? fn;
    final emails = <String>[];
    final phones = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final nameAndParams = upper.substring(0, colon);
      final value = line.substring(colon + 1).trim();

      if (upper.startsWith('FN:')) {
        fn = value;
        continue;
      }

      // Accept property names like EMAIL, ITEM1.EMAIL, etc.
      if (nameAndParams.endsWith('EMAIL') || nameAndParams.contains('EMAIL')) {
        // Extract email address from possible "mailto:" or parameterized values
        var v = value.trim();
        if (v.toLowerCase().startsWith('mailto:')) {
          v = v.substring(7);
        }
        if (v.isNotEmpty) emails.add(v);
        continue;
      }

      if (nameAndParams.endsWith('TEL') || nameAndParams.contains('TEL')) {
        final v = value.trim();
        if (v.isNotEmpty) phones.add(v);
        continue;
      }
    }

    return Contacts(href: href, etag: etag, fullName: fn, emails: emails, phones: phones);
  }

  String toVCard() {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:${fullName ?? (emails.isNotEmpty ? emails.first : '')}');
    for (final email in emails) {
      buffer.writeln('EMAIL;TYPE=INTERNET:$email');
    }
    for (final phone in phones) {
      buffer.writeln('TEL;TYPE=CELL:$phone');
    }
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }
}


