import 'package:clipshelf/controllers/shelf_controller.dart';
import 'package:clipshelf/models/clip.dart';
import 'package:clipshelf/ui/shelf_app.dart';
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';

import 'shelf_controller_test.dart' show FakeClipboard, MemoryRepository;

void main() {
  for (final size in [const Size(1280, 860), const Size(760, 560)]) {
    testWidgets('desktop layout filters, previews and copies at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clipboard = FakeClipboard();
      final shelf = ShelfController(
        repository: MemoryRepository(),
        clipboard: clipboard,
      );
      await shelf.initialize(monitor: false);
      await shelf.capture(
        const ClipContent(kind: ClipKind.text, text: 'A Flutter clipboard'),
      );
      await tester.pumpWidget(ShelfApp(controller: shelf));
      await tester.pumpAndSettle();
      expect(find.text('A Flutter clipboard'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '复制'));
      await tester.pumpAndSettle();
      expect(clipboard.content?.text, 'A Flutter clipboard');
      await tester.enterText(find.byType(TextField).first, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('暂无记录，复制一些内容试试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await shelf.shutdown();
      shelf.dispose();
    });
  }
}
