# ClipShelf

Every clip has its place.

## Demo scope

ClipShelf 是一个基于 **Tauri 2 + Vue 3 + Rust** 初始化的剪贴板管理 demo，当前目标是先跑通 **macOS** 桌面端体验：

- 自动轮询系统剪贴板。
- 识别并收集 **文本 / HTML / 图片（PNG）**。
- 三列布局：左侧分类 Tab、中间历史列表、右侧详情预览。
- 收藏视图。
- 文本 / HTML 使用类 CodeMirror 风格预览编辑区，图片使用大图预览。

## Project structure

```text
.
├── src/                 # Vue UI
└── src-tauri/           # Tauri + Rust backend
```

## macOS clipboard strategy

当前 demo 通过 Rust 调用 macOS 系统命令 `pbpaste` 轮询不同内容类型：

- `pbpaste -Prefer txt`
- `pbpaste -Prefer html`
- `pbpaste -Prefer png`

前端按内容指纹去重，形成轻量级剪贴板历史。

## Run locally

> 当前执行环境无法访问 npm / crates registry，因此这里只完成了项目初始化与 demo 代码落盘。
> 在正常联网环境下请先安装依赖再运行。

```bash
npm install
cargo fetch --manifest-path src-tauri/Cargo.toml
npm run tauri dev
```

## Next steps

- 使用 macOS pasteboard API 替代轮询 shell 命令，提高准确率和性能。
- 引入持久化存储（SQLite）。
- 接入真正的 CodeMirror 6 组件。
- 加入全局快捷键、搜索、固定置顶等功能。
