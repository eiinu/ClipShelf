import 'package:flutter/material.dart';

import 'controllers/shelf_controller.dart';
import 'services/clip_repository.dart';
import 'services/clipboard_service.dart';
import 'services/desktop_service.dart';
import 'ui/shelf_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await SqliteClipRepository.openDefault();
    final controller = ShelfController(
      repository: repository,
      clipboard: SystemClipboardService(),
    );
    await controller.initialize();
    final desktop = DesktopService(controller);
    await desktop.initialize();
    runApp(ShelfApp(controller: controller, desktopWarning: desktop.warning));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'ClipShelf 启动失败\n$error\n\n请检查数据文件和桌面环境后重新启动。原始 clips.json 不会被修改。',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
