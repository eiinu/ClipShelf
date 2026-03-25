# ClipShelf

Every clip has its place.

ClipShelf 是一个基于 **Tauri 2 + Vue 3 + Rust** 的桌面端剪贴板管理 Demo，当前以 **macOS** 为主要目标平台。

## 功能概览

- 自动监听系统剪贴板变化并记录历史。
- 支持三类内容：**文本 / HTML / PNG 图片**。
- 三栏界面：左侧分类、中间历史列表、右侧详情预览。
- 支持收藏（Favorites）快速过滤。
- 支持复制详情内容回系统剪贴板。
- 常驻系统托盘，关闭主窗口后转为后台运行。
- 历史数据持久化到本地 `clips.json`。

## 技术栈

- **前端**：Vue 3 + TypeScript + Vite + Naive UI + CodeMirror 6
- **桌面容器**：Tauri 2
- **后端**：Rust
- **平台能力**：macOS `NSPasteboard` 原生剪贴板读取

## 项目结构

```text
.
├── src/                  # Vue 前端界面
├── src-tauri/            # Tauri + Rust（命令、托盘、剪贴板监听）
└── .github/workflows/    # CI 与 DMG 发布流水线
```

## 环境要求

- Node.js `>= 24`
- pnpm `>= 10`
- Rust（stable）
- macOS（推荐，用于完整体验原生剪贴板监听）

## 本地开发

```bash
corepack enable
pnpm install
pnpm run tauri dev
```

如果只想单独运行前端：

```bash
pnpm run dev
```

## 常用脚本

```bash
pnpm run dev            # 启动 Vite 前端开发服务器
pnpm run typecheck      # Vue + TS 类型检查
pnpm run build:web      # 构建前端静态资源
pnpm run build          # typecheck + build:web
pnpm run build:desktop  # 构建桌面应用
pnpm run bundle:dmg     # 构建 macOS DMG 安装包
```

## 数据持久化

应用通过 Tauri 的应用数据目录保存历史记录文件：

- 文件名：`clips.json`
- 内容：包含剪贴板条目、收藏状态、时间戳等信息

## 平台说明

- **macOS**：启用原生剪贴板监听（`NSPasteboard`），可自动捕获文本、HTML、PNG。
- **非 macOS**：当前版本会提示仅 macOS 启用原生监听（仍可启动 UI）。

## 系统托盘行为

- 点击窗口关闭按钮不会退出应用，而是隐藏到托盘。
- 可通过托盘菜单「显示主窗口」恢复。
- 可通过托盘菜单「退出 ClipShelf」彻底退出。

## CI 与发布

仓库内置两个 GitHub Actions 工作流：

- `ci.yml`：在 push / pull request 执行前端构建与 Rust 检查。
- `release-dmg.yml`：在 `v*` 标签推送或手动触发时构建并上传 DMG 到 GitHub Release。

### 发布建议流程

```bash
# 1) 更新版本号并提交
git add .
git commit -m "release: v0.1.0"

# 2) 创建并推送标签
git tag v0.1.0
git push origin HEAD --tags
```

## 后续规划（Roadmap）

- 更丰富的内容类型识别（如 RTF、文件引用等）。
- 搜索、置顶、批量操作等历史管理能力。
- 更完善的编辑与预览体验（主题、语法高亮细分）。
- 增强跨平台支持与差异化适配。
