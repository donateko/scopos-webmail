
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';


class WebDavApi {
  final Dio _dio;
  WebDavApi(this._dio);

  Uri _baseDavUri(Session session) {
    final api = session.apiUrl;
    return Uri(scheme: api.scheme == 'https' ? 'https' : 'http', host: api.host, port: api.hasPort ? api.port : null);
  }

  // List files in a path (Depth: 1)
  Future<List<WebDavItem>> list(Session session, {String userPath = ''}) async {
    final root = _baseDavUri(session);
    final normalized = userPath.endsWith('/') ? userPath : '$userPath/';
    final target = root.replace(path: '/dav/file/$normalized');
    const reqBody = '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:resourcetype/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';
    final resp = await _dio.request(
      target.toString(),
      data: reqBody,
      options: Options(
        method: 'PROPFIND',
        headers: {
          'Depth': '1',
          'Content-Type': 'application/xml',
          'Accept': 'application/xml',
        },
        responseType: ResponseType.plain,
      ),
    );
    final body = resp.data is String ? resp.data as String : resp.data.toString();
    return _parsePropfind(body);
  }

  // Upload file
  Future<void> upload(Session session, {required String userPath, required String fileName, required List<int> bytes, String? contentType, void Function(int, int)? onSendProgress}) async {
    final root = _baseDavUri(session);
    final target = root.replace(path: '/dav/file/$userPath/$fileName');
    await _dio.request(
      target.toString(),
      data: Stream.fromIterable([bytes]),
      options: Options(
        method: 'PUT',
        headers: {
          'Content-Type': contentType ?? 'application/octet-stream',
        },
      ),
      onSendProgress: onSendProgress,
    );
  }

  // Delete file/folder
  Future<void> delete(Session session, {required String href}) async {
    final uri = Uri.parse(href);
    final base = _baseDavUri(session);
    final absolute = uri.hasScheme
        ? uri
        : base.replace(path: uri.path.startsWith('/') ? uri.path : '/${uri.path}');
    await _dio.request(absolute.toString(), options: Options(method: 'DELETE'));
  }

  // Download file bytes by href
  Future<Uint8List> downloadBytes(Session session, {required String href, void Function(int, int)? onReceiveProgress}) async {
    final uri = Uri.parse(href);
    final base = _baseDavUri(session);
    final absolute = uri.hasScheme
        ? uri
        : base.replace(path: uri.path.startsWith('/') ? uri.path : '/${uri.path}');
    final resp = await _dio.request(
      absolute.toString(),
      options: Options(
        method: 'GET',
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'application/octet-stream',
        },
      ),
      onReceiveProgress: onReceiveProgress,
    );
    final data = resp.data;
    if (data is List<int>) {
      return Uint8List.fromList(data);
    } else if (data is Uint8List) {
      return data;
    }
    return Uint8List(0);
  }

  // Build absolute URL for a given WebDAV href
  String absoluteHref(Session session, {required String href}) {
    final uri = Uri.parse(href);
    final base = _baseDavUri(session);
    final absolute = uri.hasScheme
        ? uri
        : base.replace(path: uri.path.startsWith('/') ? uri.path : '/${uri.path}');
    return absolute.toString();
  }

  // Move file to a destination (WebDAV MOVE)
  Future<void> move(Session session, {required String srcHref, required String destHref, void Function(double progress)? onProgress}) async {
    final base = _baseDavUri(session);
    final src = Uri.parse(srcHref).hasScheme
        ? Uri.parse(srcHref)
        : base.replace(path: srcHref.startsWith('/') ? srcHref : '/$srcHref');
    final dst = Uri.parse(destHref).hasScheme
        ? Uri.parse(destHref)
        : base.replace(path: destHref.startsWith('/') ? destHref : '/$destHref');

    // Ensure destination parent directories exist
    await _ensureDestinationParents(session, dst);

    // 1) Try MOVE with absolute Destination header
    try {
      await _dio.request(
        src.toString(),
        options: Options(
          method: 'MOVE',
          headers: {
            'Destination': dst.toString(),
            'Overwrite': 'T',
          },
        ),
      );
      onProgress?.call(1.0);
      return;
    } catch (_) {/* continue fallback */}

    // 2) Try MOVE with path-only Destination header (some proxies require this)
    try {
      await _dio.request(
        src.toString(),
        options: Options(
          method: 'MOVE',
          headers: {
            'Destination': dst.path,
            'Overwrite': 'T',
          },
        ),
      );
      onProgress?.call(1.0);
      return;
    } catch (_) {/* continue fallback */}

    // 3) Try COPY + DELETE (still may be blocked by CORS)
    try {
      await copy(session, srcHref: src.toString(), destHref: dst.toString());
      await _dio.request(src.toString(), options: Options(method: 'DELETE'));
      onProgress?.call(1.0);
      return;
    } catch (_) {/* continue fallback */}

    // 4) Final fallback for browsers: download -> upload -> delete
    try {
      // download with progress [0, 0.5]
      final bytes = await downloadBytes(session, href: src.toString(), onReceiveProgress: (rec, total) {
        if (total > 0) onProgress?.call((rec / total) * 0.5);
      });
      // Derive target userPath and fileName from destination
      final dstSegments = dst.path.split('/').where((s) => s.isNotEmpty).toList();
      // expected: ['dav','file','<user>'[, sub...], '<file>']
      final fileName = Uri.decodeComponent(dstSegments.last);
      final userName = Uri.decodeComponent(dstSegments[2]);
      final subParts = dstSegments.length > 4
          ? dstSegments.sublist(3, dstSegments.length - 1).map(Uri.decodeComponent).toList()
          : <String>[];
      final fullUserPath = subParts.isEmpty ? userName : '$userName/${subParts.join('/')}'
      ;
      // ensure again in case of race
      await _ensureDestinationParents(session, dst);
      await upload(
        session,
        userPath: fullUserPath,
        fileName: fileName,
        bytes: bytes,
        contentType: 'application/octet-stream',
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(0.5 + (sent / total) * 0.5);
        },
      );
      await _dio.request(src.toString(), options: Options(method: 'DELETE'));
      onProgress?.call(1.0);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _ensureDestinationParents(Session session, Uri dst) async {
    try {
      final segments = dst.path.split('/').where((s) => s.isNotEmpty).toList();
      // We need to create all folders up to the parent of the last segment (file name)
      if (segments.length < 4) return; // must at least have dav/file/<user>/file
      // Start from '/dav/file/<user>' (index 0:'dav',1:'file',2:'<user>')
      String current = '/${segments[0]}/${segments[1]}/${segments[2]}';
      for (int i = 3; i < segments.length - 1; i++) {
        current = '$current/${segments[i]}';
        final target = _baseDavUri(session).replace(path: current);
        try {
          await _dio.request(
            target.toString(),
            options: Options(
              method: 'MKCOL',
              headers: {
                'Content-Type': 'application/xml',
                'Accept': 'application/xml',
              },
            ),
          );
        } catch (_) {
          // ignore if already exists (405) or other non-fatal
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> copy(Session session, {required String srcHref, required String destHref}) async {
    final base = _baseDavUri(session);
    final src = Uri.parse(srcHref).hasScheme
        ? Uri.parse(srcHref)
        : base.replace(path: srcHref.startsWith('/') ? srcHref : '/$srcHref');
    final dst = Uri.parse(destHref).hasScheme
        ? Uri.parse(destHref)
        : base.replace(path: destHref.startsWith('/') ? destHref : '/$destHref');
    await _dio.request(
      src.toString(),
      options: Options(
        method: 'COPY',
        headers: {
          'Destination': dst.toString(),
          'Overwrite': 'T',
        },
      ),
    );
  }
  // Stat a single file/folder (Depth: 0)
  Future<WebDavItem?> stat(Session session, {required String userPath, required String fileName}) async {
    final root = _baseDavUri(session);
    final target = root.replace(path: '/dav/file/$userPath/$fileName');
    const reqBody = '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:resourcetype/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';
    final resp = await _dio.request(
      target.toString(),
      data: reqBody,
      options: Options(
        method: 'PROPFIND',
        headers: {
          'Depth': '0',
          'Content-Type': 'application/xml',
          'Accept': 'application/xml',
        },
        responseType: ResponseType.plain,
      ),
    );
    final list = _parsePropfind(resp.data is String ? resp.data as String : resp.data.toString());
    if (list.isEmpty) return null;
    return list.first;
  }

  // Create folder
  Future<void> createFolder(Session session, {required String userPath, required String folderName}) async {
    final root = _baseDavUri(session);
    final target = root.replace(path: '/dav/file/$userPath/$folderName');
    await _dio.request(
      target.toString(),
      options: Options(
        method: 'MKCOL',
        headers: {
          'Content-Type': 'application/xml',
          'Accept': 'application/xml',
        },
      ),
    );
  }

  List<WebDavItem> _parsePropfind(String xml) {
    final results = <WebDavItem>[];
    final responseRegex = RegExp(r'<(?:\w+:)?response\b[\s\S]*?<\/(?:\w+:)?response>', caseSensitive: false);
    final hrefRegex = RegExp(r'<(?:\w+:)?href>([\s\S]*?)<\/(?:\w+:)?href>', caseSensitive: false);
    final nameRegex = RegExp(r'<(?:\w+:)?displayname>([\s\S]*?)<\/(?:\w+:)?displayname>', caseSensitive: false);
    final typeDirRegex = RegExp(r'<(?:\w+:)?resourcetype>[\s\S]*?<(?:\w+:)?collection\/?[\s\S]*?<\/(?:\w+:)?resourcetype>', caseSensitive: false);
    final sizeRegex = RegExp(r'<(?:\w+:)?getcontentlength>(\d+)<\/(?:\w+:)?getcontentlength>', caseSensitive: false);
    final typeRegex = RegExp(r'<(?:\w+:)?getcontenttype>([\s\S]*?)<\/(?:\w+:)?getcontenttype>', caseSensitive: false);

    for (final m in responseRegex.allMatches(xml)) {
      final block = m.group(0)!;
      final href = hrefRegex.firstMatch(block)?.group(1)?.trim() ?? '';
      if (href.isEmpty) continue;
      String name = nameRegex.firstMatch(block)?.group(1)?.trim() ?? '';
      final isDir = typeDirRegex.hasMatch(block);
      final size = int.tryParse(sizeRegex.firstMatch(block)?.group(1) ?? '0') ?? 0;
      final mime = typeRegex.firstMatch(block)?.group(1)?.trim() ?? (isDir ? 'inode/directory' : 'application/octet-stream');

      if (name.isEmpty) {
        try {
          final parsed = Uri.parse(href);
          if (parsed.pathSegments.isNotEmpty) {
            name = parsed.pathSegments.where((s) => s.isNotEmpty).last;
            name = Uri.decodeComponent(name);
          } else {
            name = href;
          }
        } catch (_) {
          name = href;
        }
      }

      // Skip entries that point to the parent itself without a name
      if (name.isEmpty) continue;

      results.add(WebDavItem(
        name: name,
        href: href,
        isDirectory: isDir,
        size: size,
        contentType: mime,
      ));
    }
    return results;
  }
}

class WebDavItem {
  final String name;
  final String href;
  final bool isDirectory;
  final int size;
  final String contentType;
  WebDavItem({required this.name, required this.href, required this.isDirectory, required this.size, required this.contentType});
}


