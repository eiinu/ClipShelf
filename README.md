# ClipShelf

Every clip has its place.

基于 **Flutter + Dart** 的跨平台桌面剪贴板管理器，目标为 macOS、Windows 和 Linux。界面由 Flutter 绘制，不再使用 WebView、Vue 或 Tauri。

## 功能

- 监听并保存文本、HTML 和 PNG 图片；HTML 与其纯文本版本关联展示。
- 三栏界面、搜索、类型分类、收藏、置顶、自定义标签和删除。
- 文本及代码语法高亮、JSON 格式化、图片缩放预览。
- 将文本、HTML 或图片复制回系统剪贴板。
- SQLite 事务存储，保留最近 7 天的记录（包括收藏、置顶，与旧版保留规则一致）。
- 暂停/恢复监听、托盘显示/退出、关闭窗口后驻留后台。
- 旧版 clips.json 自动导入及手动 JSON 导入/导出。

## 开发环境

使用 [.flutter-version](.flutter-version) 中的 Flutter stable 版本（当前 3.47.8，包含 Dart）。无需 Node.js、pnpm 或应用级 Rust 工程。剪贴板插件 super_clipboard 的原生实现包含 Rust，优先下载经过签名校验的预编译库；没有匹配库时需要 **Rust stable** 来构建插件。

- **macOS**：macOS 12+、Xcode、命令行开发工具、CocoaPods。当前是非沙盒桌面分发配置，以便读取旧版应用数据；不适用于直接提交 Mac App Store。正式分发仍需单独配置签名和公证。
- **Windows**：Visual Studio 的 Desktop development with C++ 工作负载和 Windows SDK。
- **Linux**：GTK 3 桌面环境、Clang、CMake、Ninja、pkg-config、AppIndicator 和 SQLite 开发库。Debian/Ubuntu 示例：

  ```bash
  sudo apt-get update
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libayatana-appindicator3-dev libsqlite3-dev
  ```

```bash
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d macos   # Windows 改为 windows，Linux 改为 linux
```

应用启动后每 750ms 检查一次剪贴板，内容未变化时不重复入库；复制自己的历史记录也不会再添加一条记录。Ctrl+F / Cmd+F 聚焦搜索。工具栏可暂停监听，通过历史管理菜单导入、导出。

## 数据迁移与存储

SQLite 数据库 clipshelf.sqlite 位于系统应用支持目录。首次启动会寻找应用目录及旧版标识 me.eiinu.clipshelf 对应目录下的 clips.json，完整校验后以单次事务导入。源文件保持不变，成功导入后记录迁移标记，不会每次启动重新导入已删除的历史。找不到旧文件时，可从右上角菜单手动选择文件。

导入保留原始 ID、时间、收藏、置顶、标签、HTML/图片及关联分组。按 ID 去重，非法文件整份拒绝，不做部分导入。超过 7 天的记录仍按保留策略清理。导出 JSON 与旧版内容字段兼容。

历史、图片与导出文件均为本地明文数据，不会上传。后台监听会记录复制的内容；复制敏感内容前可暂停监听。

## 验证与构建

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
flutter build linux --release   # 或 macos / windows，须在对应操作系统构建
```

原生剪贴板冒烟测试会临时改写系统剪贴板，结束后尽力恢复原有的文本、HTML 或 PNG 内容：

```bash
flutter test integration_test/clipboard_smoke_test.dart -d linux
# 无显示器的 Linux CI：
xvfb-run -a flutter test integration_test/clipboard_smoke_test.dart -d linux
```

CI 包含三个桌面平台的构建、静态检查和单元/界面测试，以及 Linux X11 原生剪贴板冒烟测试，并保存构建产物。CI 文件的存在不代表三个平台已经验证通过。构建产物不含签名、公证或安装器；旧版自动 DMG 发布已移除。

本次迁移已在 Linux 完成静态检查、12 项单元/界面测试、调试和发布构建，以及 1 项原生集成测试（窗口/托盘初始化、文本/HTML/PNG 剪贴板往返与入库）。实际发布应用也已启动验证。macOS 和 Windows 尚待对应平台验证。

## 平台边界

- **Linux Wayland**：后台剪贴板读取受合成器和会话权限限制，不能保证全局监听；当前原生集成测试以 X11 为目标。
- **系统托盘**：依赖桌面环境支持，部分 GNOME 会话需要 AppIndicator 扩展。初始化失败时，关闭窗口会退出，不会将应用隐藏到不可恢复的状态。
- **预览格式化**：文本、HTML、Markdown、JSON、JS、TS、XML 支持语法高亮；目前仅 JSON 提供格式化，旧版 Prettier 的其他语言格式化尚未迁移。HTML 显示源码，不执行内容。
- **全局快捷键和开机启动**：尚未实现，当前仅提供应用内搜索快捷键。

## 结构

```text
lib/models/         剪贴板内容、历史记录、旧版 JSON 格式
lib/controllers/    监听状态、筛选、保留规则、历史操作
lib/services/       系统剪贴板、SQLite、窗口与托盘
lib/ui/             Flutter 桌面界面
linux/ macos/ windows/  各平台标准 Flutter runner
test/               状态、数据库事务、数据迁移、界面测试
integration_test/   实际原生剪贴板集成测试
```

## macOS 测试包

专用的 Package macOS 工作流先构建通用应用，再将主程序、Flutter 引擎、Dart AOT 和原生插件中的 Mach-O 二进制全部拆分为单架构，并重新签名。在对应 Actions 运行页按设备下载：

- **ClipShelf-macOS-arm64**：Apple Silicon（M 系列）。
- **ClipShelf-macOS-x86_64**：Intel Mac。

每个 artifact 仅包含该架构的 DMG、SHA256SUMS 和首次启动说明，不再重复附带一份应用 ZIP。下载保留 14 天。

本地 macOS 也可执行：

```bash
flutter config --no-enable-macos-arm64-only
flutter pub get --enforce-lockfile
flutter build macos --release
bash tool/package_macos.sh
```

默认生成 dist/macos/arm64 和 dist/macos/x86_64 两个目录；也可传入 arm64 或 x86_64 只生成其中一种。原始通用应用保持不变。脚本逐个检查包内所有 Mach-O 只含目标架构，完成签名完整性与 DMG 校验。此签名不包含 Developer ID 身份或 Apple 公证，首次打开可能需要在系统设置的“隐私与安全性”中确认来源。正式公开分发前仍需开发者签名和公证。
