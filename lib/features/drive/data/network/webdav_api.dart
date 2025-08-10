
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
    final reqBody = '''<?xml version="1.0"?>
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

  // Stat a single file/folder (Depth: 0)
  Future<WebDavItem?> stat(Session session, {required String userPath, required String fileName}) async {
    final root = _baseDavUri(session);
    final target = root.replace(path: '/dav/file/$userPath/$fileName');
    final reqBody = '''<?xml version="1.0"?>
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


