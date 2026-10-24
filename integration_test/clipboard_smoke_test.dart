import 'dart:convert';

import 'package:clipshelf/controllers/shelf_controller.dart';
import 'package:clipshelf/models/clip.dart';
import 'package:clipshelf/services/clip_repository.dart';
import 'package:clipshelf/services/clipboard_service.dart';
import 'package:clipshelf/services/desktop_service.dart';
import 'package:clipshelf/ui/shelf_app.dart';
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native clipboard text, HTML and PNG round-trip into history', (
    tester,
  ) async {
    final clipboard = SystemClipboardService();
    final original = await clipboard.read();
    final repository = SqliteClipRepository(sqlite3.openInMemory());
    final shelf = ShelfController(repository: repository, clipboard: clipboard);
    await shelf.initialize(monitor: false);
    final desktop = DesktopService(shelf);
    try {
      await tester.pumpWidget(ShelfApp(controller: shelf));
      await desktop.initialize();
      expect(desktop.warning, isNull);
      await clipboard.write(
        const ClipContent(kind: ClipKind.text, text: 'ClipShelf native smoke'),
      );
      expect((await clipboard.read())?.text, 'ClipShelf native smoke');
      await shelf.poll();
      await tester.pumpAndSettle();
      expect(find.text('ClipShelf native smoke'), findsWidgets);
      await clipboard.write(
        const ClipContent(
          kind: ClipKind.html,
          text: 'Rich clip',
          html: '<b>Rich clip</b>',
        ),
      );
      final html = await clipboard.read();
      expect(html?.kind, ClipKind.html);
      expect(html?.html, contains('Rich clip'));
      await shelf.poll();
      expect(shelf.clips.where((clip) => clip.groupId != null), hasLength(2));
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      await clipboard.write(ClipContent(kind: ClipKind.image, image: png));
      final image = await clipboard.read();
      expect(image?.kind, ClipKind.image);
      expect(image?.image, isNotEmpty);
      await shelf.poll();
      expect(shelf.selected?.content.kind, ClipKind.image);
      expect(await repository.load(), hasLength(4));
    } finally {
      await clipboard.write(
        original ?? const ClipContent(kind: ClipKind.text, text: ''),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await desktop.dispose();
      await shelf.shutdown();
      shelf.dispose();
    }
  });
}
