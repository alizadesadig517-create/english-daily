import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app.dart';
import '../logic/dates.dart';
import '../models/lesson.dart';
import '../services/lesson_card_html.dart';
import '../services/share_service.dart';

/// The lesson rendered as a self-contained HTML page, with sharing.
class LessonCardScreen extends StatefulWidget {
  const LessonCardScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  State<LessonCardScreen> createState() => _LessonCardScreenState();
}

class _LessonCardScreenState extends State<LessonCardScreen> {
  late final WebViewController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..loadHtmlString(lessonCardHtml(widget.lesson));
  }

  Future<void> _share() async {
    final format = await showModalBottomSheet<ShareFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Share lesson card as…')),
            ListTile(
              leading: const Icon(Icons.html),
              title: const Text('HTML page'),
              subtitle: const Text('Opens in any browser'),
              onTap: () => Navigator.pop(context, ShareFormat.html),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(context, ShareFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image (PNG)'),
              onTap: () => Navigator.pop(context, ShareFormat.image),
            ),
          ],
        ),
      ),
    );
    if (format == null) return;
    setState(() => _busy = true);
    try {
      await ShareService.share(widget.lesson, format);
    } catch (e) {
      showMessage('Sharing failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lesson card · ${shortDate(widget.lesson.date)}')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _share,
        icon: const Icon(Icons.share),
        label: const Text('Share'),
      ),
    );
  }
}
