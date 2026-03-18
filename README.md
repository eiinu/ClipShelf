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
├── .github/workflows/    # CI / DMG release pipeline
├── src/                  # Vue UI
└── src-tauri/            # Tauri + Rust backend
```

## macOS clipboard strategy

当前 demo 通过 Rust 调用 macOS 系统命令 `pbpaste` 轮询不同内容类型：

- `pbpaste -Prefer txt`
- `pbpaste -Prefer html`
- `pbpaste -Prefer png`

前端按内容指纹去重，形成轻量级剪贴板历史。

## Run locally

> 当前执行环境无法访问 pnpm / crates registry，因此这里只完成了项目初始化与 demo 代码落盘。
> 在正常联网环境下请先安装依赖再运行。

```bash
corepack enable
pnpm install
cargo fetch --manifest-path src-tauri/Cargo.toml
pnpm run tauri dev
```

## Build and package

本地构建与打包命令已经拆分完成：

```bash
corepack enable
pnpm install
pnpm run typecheck      # 仅做前端类型检查
pnpm run build          # 前端 + Tauri 前置构建
pnpm run build:desktop  # 构建桌面应用
pnpm run bundle:dmg     # 仅生成 macOS DMG 安装包
```

`src-tauri/tauri.conf.json` 已将 bundle target 固定为 `dmg`，确保发布流程产物与 GitHub Release 保持一致。

## GitHub Actions pipeline

仓库内置了两条工作流：

- `ci.yml`：在 push / pull request 时使用 Node.js 24 + pnpm 10 执行依赖安装、前端构建与 `cargo check`。
- `release-dmg.yml`：在推送 `v*` tag，或手动触发 Actions 时，使用 Node.js 24 + pnpm 10 自动构建 macOS DMG，并上传到 GitHub Release。

### 发布前准备

1. 在 GitHub 仓库 `Settings > Actions > General > Workflow permissions` 中启用 **Read and write permissions**。
2. 准备版本号，并同步更新以下文件中的版本：
   - `package.json`
   - `src-tauri/Cargo.toml`
   - `src-tauri/tauri.conf.json`
3. 如需 Apple 签名 / notarization，在 GitHub Secrets 中配置：
   - `APPLE_CERTIFICATE`
   - `APPLE_CERTIFICATE_PASSWORD`
   - `APPLE_SIGNING_IDENTITY`
   - `APPLE_ID`
   - `APPLE_PASSWORD`
   - `APPLE_TEAM_ID`

> 若未配置上述 secrets，工作流仍会尝试生成 DMG；是否允许分发取决于你的 macOS 安全策略与签名要求。

### 自动发布 DMG 到 GitHub Release

推荐流程：

```bash
# 1. 更新版本号后提交代码
git add .
git commit -m "release: v0.1.0"

# 2. 打 tag 并推送
git tag v0.1.0
git push origin HEAD --tags
```

完成后，`release-dmg.yml` 会：

1. 在 `macos-latest` runner 上安装 Node.js 与 Rust。
2. 执行 `pnpm install`。
3. 通过 `tauri-apps/tauri-action` 运行 `tauri build --bundles dmg`。
4. 自动创建或更新 `v__VERSION__` 对应的 GitHub Release。
5. 将生成的 `.dmg` 文件作为 Release Asset 上传。

### 手动触发发布

也可以在 GitHub Actions 页面手动执行 `release-dmg` 工作流：

- `release_draft=true`：先生成草稿 Release，便于人工确认。
- `prerelease=true`：将本次版本标记为预发布版本。

## Next steps

- 使用 macOS pasteboard API 替代轮询 shell 命令，提高准确率和性能。
- 引入持久化存储（SQLite）。
- 接入真正的 CodeMirror 6 组件。
- 加入全局快捷键、搜索、固定置顶等功能。
