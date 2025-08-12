import 'dart:io';

import 'package:core/presentation/extensions/uri_extension.dart';
import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/contact/contacts.dart';

class CardDavApi {
  final Dio _dio;

  CardDavApi(this._dio);

  Uri _serverRootBaseUrl(Session session) {
    final base = session.apiUrl;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  String _userAddressBookUrl({required Session session}) {
    final base = _serverRootBaseUrl(session);
    final qualified = Uri.parse('/dav/card/${session.username.value}/default').toQualifiedUrl(baseUrl: base);
    return qualified.toString();
  }

  Future<List<Contacts>> listContacts(Session session) async {
    final candidates = await _discoverAddressBookUrls(session);
    final Set<String> tried = {};
    final List<Contacts> all = [];
    for (final url in candidates) {
      if (tried.contains(url)) continue;
      tried.add(url);
      try {
        final results = await _queryAddressBook(url);
        all.addAll(results);
      } catch (e) {
        log('CardDavApi::listContacts: failed to query "$url" | $e');
      }
    }
    // Deduplicate by email + name to avoid duplicates across collections
    final unique = <String, Contacts>{};
    for (final c in all) {
      final key = '${c.fullName ?? ''}|${c.emails.join(',')}';
      unique[key] = c;
    }
    return unique.values.toList();
  }

  Future<List<String>> _discoverAddressBookUrls(Session session) async {
    final base = _serverRootBaseUrl(session);
    final root = Uri.parse('/dav/card/${session.username.value}').toQualifiedUrl(baseUrl: base).toString();
    final def = _userAddressBookUrl(session: session);
    final urls = <String>{def};
    // PROPFIND Depth:1 to list child collections
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
            final isAddressBook = RegExp(r'addressbook', caseSensitive: false).hasMatch(r);
            if (isAddressBook && abs != root) {
              urls.add(abs);
            }
          }
        }
      }
    } catch (_) {}
    return urls.toList();
  }

  Future<List<Contacts>> _queryAddressBook(String url) async {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<card:addressbook-query xmlns:d="DAV:" xmlns:card="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <d:getetag/>
    <card:address-data/>
  </d:prop>
  <card:filter/>
</card:addressbook-query>''';

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
    final contacts = <Contacts>[];
    final baseUri = Uri.parse(url);
    final blocks = RegExp(r'<(?:\w+:)?response\b[\s\S]*?</(?:\w+:)?response>', caseSensitive: false)
        .allMatches(body)
        .map((m) => m.group(0)!)
        .toList();
    for (final raw in blocks) {
      final dataMatch = RegExp(r'<(?:\w+:)?address-data[^>]*>([\s\S]*?)</(?:\w+:)?address-data>', caseSensitive: false)
          .firstMatch(raw);
      if (dataMatch == null) continue;
      final vCard = dataMatch.group(1)?.trim();
      if (vCard == null || vCard.isEmpty || !vCard.contains('BEGIN:VCARD')) continue;

      String href = '';
      final hrefMatch = RegExp(r'<(?:\w+:)?href>([\s\S]*?)</(?:\w+:)?href>', caseSensitive: false).firstMatch(raw);
      if (hrefMatch != null) {
        final h = hrefMatch.group(1)!.trim();
        try {
          href = (Uri.tryParse(h)?.hasScheme == true) ? h : baseUri.resolve(h).toString();
        } catch (_) {
          href = h;
        }
      }

      String? etag;
      final etagMatch = RegExp(r'<(?:\w+:)?getetag>([\s\S]*?)</(?:\w+:)?getetag>', caseSensitive: false).firstMatch(raw);
      if (etagMatch != null) {
        etag = etagMatch.group(1)?.trim();
      }

      try {
        contacts.add(Contacts.fromVCard(vCard, href: href, etag: etag));
      } catch (e) {
        log('CardDavApi::_queryAddressBook: parse error for item href=$href | $e');
      }
    }
    log('CardDavApi::_queryAddressBook: url=$url | parsed=${contacts.length}');
    return contacts;
  }

  Future<Contacts> createContact(Session session, Contacts contact) async {
    // Try default, then discovered books
    final candidates = await _discoverAddressBookUrls(session);
    final vcard = contact.toVCard();
    final uid = DateTime.now().microsecondsSinceEpoch.toString();
    final headers = <String, dynamic>{
      HttpHeaders.contentTypeHeader: 'text/vcard; charset=utf-8',
      HttpHeaders.acceptHeader: '*/*',
    };

    DioError? lastError;
    for (final book in candidates) {
      final url = '$book/$uid.vcf';
      try {
        log('CardDavApi::createContact: PUT $url');
        await _dio.request(url, data: vcard, options: Options(method: 'PUT', headers: headers, responseType: ResponseType.plain));
        log('CardDavApi::createContact: success (email=${contact.emails.isNotEmpty ? contact.emails.first : ''})');
        return Contacts(href: url, fullName: contact.fullName, emails: contact.emails, phones: contact.phones);
      } catch (e) {
        if (e is DioError) {
          lastError = e;
          continue;
        } else {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('Failed to create contact');
  }

  Future<void> updateContact(Session session, Contacts contact) async {
    final url = Uri.parse(contact.href).toQualifiedUrl(baseUrl: _serverRootBaseUrl(session)).toString();
    final headers = <String, dynamic>{
      HttpHeaders.contentTypeHeader: 'text/vcard; charset=utf-8',
      HttpHeaders.acceptHeader: '*/*',
    };
    if (contact.etag != null) {
      headers['If-Match'] = contact.etag!;
    }
    await _dio.request(url, data: contact.toVCard(), options: Options(method: 'PUT', headers: headers, responseType: ResponseType.plain));
  }

  Future<void> deleteContact(Session session, Contacts contact) async {
    var url = Uri.parse(contact.href).toQualifiedUrl(baseUrl: _serverRootBaseUrl(session)).toString();
    // Some older contacts may use relative hrefs without default trailing slash; normalize
    if (!url.endsWith('.vcf')) {
      if (!url.endsWith('/')) url = '$url/';
      url = '$url${contact.fullName ?? 'contact'}.vcf';
    }
    final headers = <String, dynamic>{
      HttpHeaders.acceptHeader: '*/*',
    };
    if (contact.etag != null) {
      headers['If-Match'] = contact.etag!;
    }
    try {
      await _dio.request(url, options: Options(method: 'DELETE', headers: headers, responseType: ResponseType.plain));
    } catch (e) {
      // Retry without If-Match when server doesn't return etag for legacy entries
      headers.remove('If-Match');
      await _dio.request(url, options: Options(method: 'DELETE', headers: headers, responseType: ResponseType.plain));
    }
  }
}


