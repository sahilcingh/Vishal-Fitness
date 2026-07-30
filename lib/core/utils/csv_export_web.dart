// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<void> exportCsv(String content, String filename) async {
  // BOM so Excel reads the file as UTF-8 (otherwise ₹ and other symbols get mangled)
  final bytes = utf8.encode('﻿$content');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
