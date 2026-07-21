import 'dart:io';

import 'package:core/presentation/extensions/uri_extension.dart';
import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/calendar/presentation/model/calendar_event_item.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:uuid/uuid.dart';

class CalDavApi {
  final Dio _dio;
  CalDavApi(this._dio);

  Uri _serverRootBaseUrl(Session session) {
    final base = session.apiUrl;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  String _userCalendarRootUrl({required Session session}) {
    final base = _serverRootBaseUrl(session);
    final qualified = Uri.parse('/dav/cal/${session.username.value}').toQualifiedUrl(baseUrl: base);
    return qualified.toString();
  }

  String _userDefaultCalendarUrl({required Session session}) {
    final base = _serverRootBaseUrl(session);
    final qualified = Uri.parse('/dav/cal/${session.username.value}/default').toQualifiedUrl(baseUrl: base);
    return qualified.toString();
  }

  Future<List<String>> _discoverCalendars(Session session) async {
    final base = _serverRootBaseUrl(session);
    final root = _userCalendarRootUrl(session: session);
    final def = _userDefaultCalendarUrl(session: session);
    final urls = <String>{def};

    try {
      final headers = <String, dynamic>{
        HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
        HttpHeaders.acceptHeader: 'application/xml, text/xml, */*',
        'Depth': '1',
      };
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype/>
  </d:prop>
</d:propfind>''';
      final resp = await _dio.request(
        root,
        data: xml,
        options: Options(method: 'PROPFIND', headers: headers, responseType: ResponseType.plain),
      );
      final body = resp.data is String ? resp.data as String : resp.data.toString();
      final responseBlocks = RegExp(r'<(?:\w+:)?response\b[\s\S]*?</(?:\w+:)?response>', caseSensitive: false)
          .allMatches(body)
          .map((m) => m.group(0)!)
          .toList();
      for (final r in responseBlocks) {
        final hrefMatch = RegExp(r'<(?:\w+:)?href>([\s\S]*?)</(?:\w+:)?href>', caseSensitive: false).firstMatch(r);
        if (hrefMatch != null) {
          final href = hrefMatch.group(1)!.trim();
          if (href.isNotEmpty) {
            final abs = Uri.parse(href).toQualifiedUrl(baseUrl: base).toString();
            final isCalendar = RegExp(r'calendar', caseSensitive: false).hasMatch(r) || abs.endsWith('/default');
            if (isCalendar && abs != root) {
              urls.add(abs);
            }
          }
        }
      }
    } catch (e) {
      log('CalDavApi::_discoverCalendars error: $e');
    }
    return urls.toList();
  }

  Future<List<CalendarEventItem>> listEvents(Session session) async {
    final candidates = await _discoverCalendars(session);
    final Set<String> tried = {};
    final List<CalendarEventItem> all = [];
    for (final url in candidates) {
      if (tried.contains(url)) continue;
      tried.add(url);
      try {
        final results = await _queryCalendar(url);
        all.addAll(results);
      } catch (e) {
        log('CalDavApi::listEvents: failed to query "$url" | $e');
      }
    }
    final unique = <String, CalendarEventItem>{};
    for (final ev in all) {
      final key = '${ev.uid ?? ''}|${ev.start?.toIso8601String() ?? ''}|${ev.summary ?? ''}';
      unique[key] = ev;
    }
    return unique.values.toList()
      ..sort((a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
  }

  Future<List<CalendarEventItem>> _queryCalendar(String url) async {
    const xml = '''<?xml version="1.0" encoding="utf-8" ?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR"/>
  </c:filter>
</c:calendar-query>''';

    final headers = <String, dynamic>{
      HttpHeaders.contentTypeHeader: 'application/xml; charset=utf-8',
      HttpHeaders.acceptHeader: 'application/xml, text/xml, */*',
      'Depth': '1',
    };

    final response = await _dio.request(
      url,
      data: xml,
      options: Options(method: 'REPORT', headers: headers, responseType: ResponseType.plain),
    );

    final body = response.data is String ? response.data as String : response.data.toString();
    final blocks = RegExp(r'<(?:\w+:)?response\b[\s\S]*?</(?:\w+:)?response>', caseSensitive: false)
        .allMatches(body)
        .map((m) => m.group(0)!)
        .toList();
    final items = <CalendarEventItem>[];
    for (final raw in blocks) {
      final dataMatch = RegExp(r'<(?:\w+:)?calendar-data[^>]*>([\s\S]*?)</(?:\w+:)?calendar-data>', caseSensitive: false)
          .firstMatch(raw);
      if (dataMatch == null) continue;
      final ics = dataMatch.group(1)?.trim();
      if (ics == null || ics.isEmpty) continue;
      String? href;
      String? etag;
      final hrefMatch = RegExp(r'<(?:\w+:)?href>([\s\S]*?)</(?:\w+:)?href>', caseSensitive: false).firstMatch(raw);
      if (hrefMatch != null) {
        final h = hrefMatch.group(1)?.trim();
        href = h != null ? _decodeXmlEntities(h) : null;
      }
      final etagMatch = RegExp(r'<(?:\w+:)?getetag>([\s\S]*?)</(?:\w+:)?getetag>', caseSensitive: false).firstMatch(raw);
      if (etagMatch != null) {
        final t = etagMatch.group(1)?.trim();
        etag = t != null ? _decodeXmlEntities(t) : null;
      }
      try {
        final parsed = CalendarEventItem.parseICS(ics, href: href, etag: etag);
        if (parsed != null) items.add(parsed);
      } catch (e) {
        log('CalDavApi::_queryCalendar: parse error | $e');
      }
    }
    return items;
  }

  Future<void> deleteEvent(Session session, CalendarEventItem item) async {
    if (item.href == null || item.href!.isEmpty) return;
    final url = Uri.parse(item.href!).toQualifiedUrl(baseUrl: _serverRootBaseUrl(session)).toString();
    final headers = <String, dynamic>{
      HttpHeaders.acceptHeader: '*/*',
    };
    if (!kIsWeb && item.etag != null && item.etag!.isNotEmpty) {
      headers['If-Match'] = _normalizeEtag(item.etag!);
    }
    await _dio.request(url, options: Options(method: 'DELETE', headers: headers, responseType: ResponseType.plain));
  }

  Future<void> updateEvent(Session session, CalendarEventItem current, {
    String? summary,
    DateTime? start,
    DateTime? end,
    String? location,
    String? description,
    List<String>? attendees,
    int? reminderMinutes,
    bool? emailNotification,
    String? colorHex,
  }) async {
    if (current.href == null || current.href!.isEmpty) return;
    final url = Uri.parse(current.href!).toQualifiedUrl(baseUrl: _serverRootBaseUrl(session)).toString();
    final headers = <String, dynamic>{
      HttpHeaders.acceptHeader: '*/*',
      HttpHeaders.contentTypeHeader: 'text/calendar; charset=utf-8',
    };
    if (!kIsWeb && current.etag != null && current.etag!.isNotEmpty) {
      headers['If-Match'] = _normalizeEtag(current.etag!);
    }

    final newIcs = _buildICS(
      uid: current.uid ?? const Uuid().v4(),
      summary: summary ?? current.summary ?? '',
      start: (start ?? current.start ?? DateTime.now()).toUtc(),
      end: (end ?? current.end ?? (current.start ?? DateTime.now()).add(const Duration(hours: 1))).toUtc(),
      location: location ?? current.location,
      description: description ?? '',
      organizerEmail: null,
      attendees: attendees ?? current.attendees,
      reminderMinutes: reminderMinutes,
      emailNotification: emailNotification ?? false,
      colorHex: colorHex ?? current.colorHex,
    );
    await _dio.request(url, data: newIcs, options: Options(method: 'PUT', headers: headers, responseType: ResponseType.plain));
  }

  Future<void> createEvent(Session session, {
    required String summary,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    List<String> attendees = const <String>[],
    int? reminderMinutes,
    bool emailNotification = false,
    String? colorHex,
  }) async {
    // Target default calendar
    final calendarUrl = _userDefaultCalendarUrl(session: session);
    final uid = const Uuid().v4();
    final ics = _buildICS(
      uid: uid,
      summary: summary,
      start: start.toUtc(),
      end: end.toUtc(),
      location: location,
      description: description,
      organizerEmail: session.getOwnEmailAddress(),
      attendees: attendees,
      reminderMinutes: reminderMinutes,
      emailNotification: emailNotification,
      colorHex: colorHex,
    );
    final url = calendarUrl.endsWith('/') ? '$calendarUrl$uid.ics' : '$calendarUrl/$uid.ics';
    final headers = <String, dynamic>{
      HttpHeaders.contentTypeHeader: 'text/calendar; charset=utf-8',
      HttpHeaders.acceptHeader: '*/*',
    };
    await _dio.request(
      url,
      data: ics,
      options: Options(method: 'PUT', headers: headers, responseType: ResponseType.plain),
    );
  }

  String _fmtUtc(DateTime dt) {
    // yyyymmddThhmmssZ
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$mo${d}T$hh$mm${ss}Z';
  }

  String _buildICS({
    required String uid,
    required String summary,
    required DateTime start,
    required DateTime end,
    String? location,
    String? description,
    String? organizerEmail,
    List<String> attendees = const <String>[],
    int? reminderMinutes,
    bool emailNotification = false,
    String? colorHex,
  }) {
    final now = DateTime.now().toUtc();
    final dtstamp = _fmtUtc(now);
    final dtstart = _fmtUtc(start);
    final dtend = _fmtUtc(end);
    // Use CRLF per RFC5545
    final b = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Scopos Mail//EN')
      ..writeln('CALSCALE:GREGORIAN')
      // ..writeln('METHOD:REQUEST') // Usually not required when storing resource; server handles scheduling
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:$dtstamp')
      ..writeln('DTSTART:$dtstart')
      ..writeln('DTEND:$dtend')
      ..writeln('SUMMARY:${_escapeText(summary)}');
    if (location != null && location.isNotEmpty) b.writeln('LOCATION:${_escapeText(location)}');
    if (description != null && description.isNotEmpty) b.writeln('DESCRIPTION:${_escapeText(description)}');
    if (organizerEmail != null && organizerEmail.isNotEmpty) {
      b.writeln('ORGANIZER:mailto:${_escapeText(organizerEmail)}');
    }
    for (final a in attendees) {
      final trimmed = a.trim();
      if (trimmed.isEmpty) continue;
      // Basic attendee line; server will manage scheduling per RFC 6638
      b.writeln('ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION:mailto:${_escapeText(trimmed)}');
    }
    if (reminderMinutes != null && reminderMinutes > 0) {
      b
        ..writeln('BEGIN:VALARM')
        ..writeln('TRIGGER:-PT${reminderMinutes}M')
        ..writeln('ACTION:DISPLAY')
        ..writeln('DESCRIPTION:${_escapeText(summary)}${emailNotification ? ' @email' : ''}')
        ..writeln('END:VALARM');
    }
    if (colorHex != null && colorHex.isNotEmpty) {
      final clean = colorHex.startsWith('#') ? colorHex : '#$colorHex';
      b.writeln('COLOR:$clean');
      b.writeln('CATEGORIES:color=$clean');
    }
    b
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');
    // Replace LF with CRLF
    return b.toString().replaceAll('\n', '\r\n');
  }

  String _escapeText(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _normalizeEtag(String raw) {
    var tag = _decodeXmlEntities(raw).trim();
    if (tag.isEmpty) return tag;
    // Ensure ETag is wrapped in quotes as per HTTP spec
    if (!(tag.startsWith('"') && tag.endsWith('"'))) {
      tag = '"$tag"';
    }
    return tag;
  }
}


