import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

import '../models/clip.dart';

abstract class ClipboardService {
  Future<ClipContent?> read();
  Future<void> write(ClipContent content);
}

class SystemClipboardService implements ClipboardService {
  SystemClipboard get _clipboard =>
      SystemClipboard.instance ?? (throw UnsupportedError('当前系统无法访问剪贴板'));

  @override
  Future<ClipContent?> read() async {
    final reader = await _clipboard.read();
    if (reader.canProvide(Formats.png)) {
      final completer = Completer<Uint8List?>();
      final progress = reader.getFile(
        Formats.png,
        (file) async {
          try {
            final bytes = await file.readAll();
            if (!completer.isCompleted) completer.complete(bytes);
          } catch (error, stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        synthesizeFilesFromURIs: false,
      );
      if (progress == null) completer.complete(null);
      final bytes = await completer.future.timeout(const Duration(seconds: 5));
      if (bytes != null && bytes.isNotEmpty) {
        return ClipContent(kind: ClipKind.image, image: bytes);
      }
    }
    final text = await reader.readValue(Formats.plainText);
    final html = await reader.readValue(Formats.htmlText);
    if (html != null && html.isNotEmpty) {
      return ClipContent(kind: ClipKind.html, text: text, html: html);
    }
    if (text != null && text.isNotEmpty) {
      return ClipContent(kind: ClipKind.text, text: text);
    }
    return null;
  }

  @override
  Future<void> write(ClipContent content) async {
    final item = DataWriterItem();
    if (content.kind == ClipKind.image) {
      item.add(Formats.png(content.image!));
    } else {
      if (content.html != null) item.add(Formats.htmlText(content.html!));
      item.add(Formats.plainText(content.text ?? content.html ?? ''));
    }
    await _clipboard.write([item]);
  }
}
