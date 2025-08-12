import 'dart:convert';

import 'package:core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'package:twake_previewer_flutter/core/previewer_options/options/loading_options.dart';
import 'package:twake_previewer_flutter/core/previewer_options/options/previewer_state.dart';
import 'package:twake_previewer_flutter/core/previewer_options/previewer_options.dart';
import 'package:twake_previewer_flutter/twake_pdf_previewer/twake_pdf_previewer.dart';

class DrivePreviewPage extends StatelessWidget {
  final Uint8List bytes;
  final String mimeType;
  final String title;

  const DrivePreviewPage({super.key, required this.bytes, required this.mimeType, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColor.textPrimary)),
        iconTheme: const IconThemeData(color: AppColor.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(bytes, title),
          ),
          if (mimeType.contains('pdf'))
            IconButton(
              tooltip: 'Print',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _print(bytes, title),
            ),
        ],
      ),
      body: _buildBody(context),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (mimeType.contains('pdf')) {
      return Stack(children: [
        Positioned.fill(
          child: TwakePdfPreviewer(
            bytes: bytes,
            previewerOptions: const PreviewerOptions(
              previewerState: PreviewerState.success,
            ),
            loadingOptions: const LoadingOptions(progress: 1.0, text: ''),
          ),
        ),
        // top gradient mask to hide any internal toolbar that might render at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 8,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    if (mimeType.contains('image')) {
      return InteractiveViewer(child: Center(child: Image.memory(bytes, fit: BoxFit.contain)));
    }
    if (mimeType.contains('text')) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(utf8.decode(bytes, allowMalformed: true)),
      );
    }
    return const Center(child: Text('Preview not supported'));
  }

  void _download(Uint8List data, String name) {
    if (!kIsWeb) return;
    final blob = html.Blob([data]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..download = name;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }

  void _print(Uint8List data, String name) {
    if (!kIsWeb) return;
    final blob = html.Blob([data], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }
}


