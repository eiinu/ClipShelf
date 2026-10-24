import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/shelf_controller.dart';

class DesktopService with WindowListener, TrayListener {
  DesktopService(this.controller);

  final ShelfController controller;
  bool _trayReady = false;
  bool _quitting = false;
  String? warning;

  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 860),
        minimumSize: Size(760, 560),
        center: true,
        title: 'ClipShelf',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png',
      );
      // tray_manager's Linux implementation has no tooltip method.
      if (!Platform.isLinux) await trayManager.setToolTip('ClipShelf');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: '显示 ClipShelf'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: '退出 ClipShelf'),
          ],
        ),
      );
      _trayReady = true;
      // Never hide the only window unless a tray icon was successfully installed.
      await windowManager.setPreventClose(true);
    } catch (error) {
      warning = '系统托盘不可用，关闭窗口将退出：$error';
      await windowManager.setPreventClose(true);
    }
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    await controller.shutdown();
    if (_trayReady) await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> dispose() async {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    if (_trayReady) await trayManager.destroy();
    _trayReady = false;
    await windowManager.setPreventClose(false);
  }

  @override
  void onWindowClose() {
    if (_trayReady) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(show());
  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') unawaited(show());
    if (menuItem.key == 'quit') unawaited(quit());
  }
}
