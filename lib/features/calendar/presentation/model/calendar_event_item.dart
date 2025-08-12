class CalendarEventItem {
  final String? href;
  final String? etag;
  final String? uid;
  final String? summary;
  final String? location;
  final DateTime? start;
  final DateTime? end;
  final List<String> attendees;
  final Map<String, String> attendeePartStat; // email -> PARTSTAT
  final String? colorHex;

  CalendarEventItem({
    this.href,
    this.etag,
    this.uid,
    this.summary,
    this.location,
    this.start,
    this.end,
    this.attendees = const [],
    this.attendeePartStat = const {},
    this.colorHex,
  });

  static CalendarEventItem? parseICS(String ics, {String? href, String? etag}) {
    String? firstMatch(String pattern) {
      // Handle folded lines (RFC 5545): lines may be continued by CRLF + space
      final normalized = ics.replaceAll(RegExp(r'\r?\n '), '');
      final re = RegExp('^' + pattern + r':(.*)$', multiLine: true);
      final m = re.firstMatch(normalized);
      return m?.group(1)!.trim();
    }

    String? uid = firstMatch('UID');
    String? summary = firstMatch('SUMMARY');
    String? location = firstMatch('LOCATION');
    String? color = firstMatch('COLOR') ?? _extractColorFromCategories(firstMatch('CATEGORIES'));

    // attendees
    final attendees = <String>[];
    final attendeePartStat = <String, String>{};
    final attendeeRegex = RegExp(r'^ATTENDEE(;[^:]+)?:mailto:([^\r\n]+)$', multiLine: true);
    for (final match in attendeeRegex.allMatches(ics)) {
      final params = match.group(1) ?? '';
      final email = match.group(2)?.trim();
      if (email != null && email.isNotEmpty) {
        attendees.add(email);
        final ps = RegExp(r'PARTSTAT=([^;:]+)', caseSensitive: false).firstMatch(params)?.group(1);
        if (ps != null) attendeePartStat[email] = ps.toUpperCase();
      }
    }
    DateTime? parseDate(String? v) {
      if (v == null) return null;
      try {
        if (v.endsWith('Z')) {
          final y = int.parse(v.substring(0, 4));
          final mo = int.parse(v.substring(4, 6));
          final d = int.parse(v.substring(6, 8));
          final hh = int.parse(v.substring(9, 11));
          final mm = int.parse(v.substring(11, 13));
          final ss = int.parse(v.substring(13, 15));
          return DateTime.utc(y, mo, d, hh, mm, ss).toLocal();
        } else if (v.length >= 8) {
          final y = int.parse(v.substring(0, 4));
          final mo = int.parse(v.substring(4, 6));
          final d = int.parse(v.substring(6, 8));
          return DateTime(y, mo, d);
        }
      } catch (_) {}
      return null;
    }

    final start = parseDate(firstMatch('DTSTART(?:;[^:]*)?'));
    final end = parseDate(firstMatch('DTEND(?:;[^:]*)?'));
    return CalendarEventItem(
      href: href,
      etag: etag,
      uid: uid,
      summary: summary,
      location: location,
      start: start,
      end: end,
      attendees: attendees,
      attendeePartStat: attendeePartStat,
      colorHex: color,
    );
  }

  String? get startLocalFormatted => start != null ? _fmt(start!) : null;
  String? get endLocalFormatted => end != null ? _fmt(end!) : null;

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $hh:$mm';
  }

  static String? _extractColorFromCategories(String? categories) {
    if (categories == null) return null;
    final m = RegExp(r'color=([#A-Fa-f0-9]+)').firstMatch(categories);
    return m?.group(1);
  }
}


