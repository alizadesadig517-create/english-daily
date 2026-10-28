import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lesson.dart';
import 'lesson_card_html.dart';

enum ShareFormat { html, pdf, image }

/// Shares a lesson card through the Android share sheet.
class ShareService {
  static Future<File> _write(String name, List<int> bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // The Android WebView prints the HTML card, so every script (ə, ğ, ş...)
  // renders with system fonts. Deprecated upstream but still supported on
  // Android.
  // ignore: deprecated_member_use
  static Future<Uint8List> pdfBytes(Lesson lesson) => Printing.convertHtml(
        html: lessonCardHtml(lesson),
        format: PdfPageFormat.a4.copyWith(
          marginLeft: 0, marginRight: 0, marginTop: 18, marginBottom: 18),
      );

  /// All PDF pages stacked into one tall PNG.
  static Future<Uint8List> imageBytes(Lesson lesson) async {
    final pdf = await pdfBytes(lesson);
    final pages = <img.Image>[];
    await for (final page in Printing.raster(pdf, dpi: 110)) {
      final decoded = img.decodePng(await page.toPng());
      if (decoded != null) pages.add(decoded);
    }
    if (pages.isEmpty) throw StateError('Could not render the lesson card');
    final width = pages.map((p) => p.width).reduce((a, b) => a > b ? a : b);
    final height = pages.fold<int>(0, (sum, p) => sum + p.height);
    final out = img.Image(width: width, height: height);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));
    var y = 0;
    for (final p in pages) {
      img.compositeImage(out, p, dstY: y);
      y += p.height;
    }
    return Uint8List.fromList(img.encodePng(out, level: 6));
  }

  static Future<void> share(Lesson lesson, ShareFormat format) async {
    final base = 'english-daily-${lesson.date}';
    final XFile file;
    switch (format) {
      case ShareFormat.html:
        final f = await _write('$base.html', utf8.encode(lessonCardHtml(lesson)));
        file = XFile(f.path, mimeType: 'text/html');
      case ShareFormat.pdf:
        final f = await _write('$base.pdf', await pdfBytes(lesson));
        file = XFile(f.path, mimeType: 'application/pdf');
      case ShareFormat.image:
        final f = await _write('$base.png', await imageBytes(lesson));
        file = XFile(f.path, mimeType: 'image/png');
    }
    await SharePlus.instance.share(ShareParams(
      files: [file],
      subject: 'English Daily - ${lesson.date}',
      title: 'English Daily - ${lesson.date}',
    ));
  }
}
