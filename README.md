# TrendPulse - 多源舆情分析系统

输入关键词，自动从 Reddit、YouTube、X (Twitter) 抓取最新数据，通过 AI 生成舆情分析报告。

## 功能特性

- **多源采集**: Reddit (官方 API) + YouTube (Data API + 字幕) + X (Grok API)
- **AI 分析**: Map-Reduce 链式处理，情感分析 + 核心观点提取 + 热度指标
- **实时仪表盘**: 情感得分、热度指数、核心观点卡片、情感分布
- **历史记录**: 查看过往分析任务，支持删除
- **订阅监控**: 按关键词与周期创建订阅，自动拉取并生成任务
- **负面告警**: 订阅任务低于阈值（`sentiment_score < 30`）时生成未读告警，并在 App 内展示提醒
- **Mermaid 思维导图**: 分析报告接口返回 Mermaid 字符串；当前支持后端生成的 `mindmap` 子集，解析失败时会显示降级提示并保留原始文本
- **源数据浏览**: 在任务详情中按平台筛选原始帖子，点击跳转原文
- **主题切换**: 支持浅色/深色主题，Neo-Minimal 设计风格

## 技术架构

```
┌─────────────────────────────────────────┐
│       Flutter App (前端)                 │
│  Analysis │ History │ Subscription │ Settings │
│  ─────────────────────────────────────  │
│  Riverpod │ GoRouter │ Dio              │
└──────────────┬──────────────────────────┘
               │ HTTP/REST
┌──────────────▼──────────────────────────┐
│      FastAPI Backend (后端)             │
│  ┌─────────┐  ┌──────────────┐          │
│  │ Adapters │  │ AI Analyzer  │          │
│  │ Reddit   │  │ Map-Reduce   │          │
│  │ YouTube  │  │ LLM Chain    │          │
│  │ X (Grok) │  │              │          │
│  └────┬─────┘  └──────┬───────┘          │
│       └───────┬───────┘                  │
│          ┌────▼────┐                    │
│          │ SQLite  │                    │
│          └─────────┘                    │
└─────────────────────────────────────────┘
```

## 快速开始

### 环境要求

- Python 3.10+
- Flutter 3.x
- Reddit API 凭证 ([申请地址](https://www.reddit.com/prefs/apps))
- YouTube Data API Key ([申请地址](https://console.cloud.google.com/))
- Grok API Key (用于 X 数据采集；默认官方 xAI，可显式切换到第三方 OpenAI SDK 兼容端点)
- LLM API Key (OpenAI SDK 兼容，用于 AI 分析)

### 后端启动

```bash
cd backend
pip install -e ".[dev]"
cp .env.example .env
# 编辑 .env 填入 API Keys
# 官方 xAI: 保持 GROK_PROVIDER_MODE=official_xai
# 第三方兼容端点: 设置 GROK_PROVIDER_MODE=openai_compatible，并改写 GROK_BASE_URL / GROK_MODEL
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

- **API 文档**: http://localhost:8000/docs
- **`--host 0.0.0.0`**: 便于同局域网设备访问；若仅用 USB + `adb reverse`，也可只开 `--reload`，但统一加上更省事。

若启动时报 **`[Errno 48] Address already in use`**，表示 **8000 端口已被占用**（例如未关掉的旧 `uvicorn`）。处理：

```bash
lsof -i :8000        # 查看占用进程 PID
kill <PID>           # 仍不退出可用 kill -9 <PID>
```

或改用其它端口（如 8001），并同步修改 App 设置里的服务地址，以及你使用的 `adb reverse` 命令或本地开发脚本配置。

### 前端启动

```bash
cd app
flutter pub get
flutter run
# 指定设备：flutter devices 后使用 flutter run -d <deviceId>
```

### Android 真机通过 USB 连接本机后端（推荐）

手机上的 `127.0.0.1` 指向手机自身，要让 App 访问 **电脑上的后端**，应对 `8000` 做端口反向映射：

1. 后端已在电脑上监听 `8000`（见上一节）。
2. 建立端口反向映射（**多台设备/模拟器同时在线时须指定序列号**）：

```bash
# 仅一台设备时可省略 -s
adb reverse tcp:8000 tcp:8000

# 多设备时请显式指定序列号
adb -s <adb devices 第一列序列号> reverse tcp:8000 tcp:8000
```

3. App **设置** 中服务器地址填：`http://127.0.0.1:8000`（或 `http://localhost:8000`），保存。
4. `cd app && flutter run -d <真机设备ID>`。

**注意**：重插 USB 或 `adb` 重连后，若无映射需 **再执行一次** 上述 `adb reverse` 命令。

**一条龙脚本**：`scripts/dev-android.sh` 默认用于模拟器，也支持 USB 真机模式：

```bash
# 模拟器
scripts/dev-android.sh

# USB 真机（多设备时建议补 --device-serial）
scripts/dev-android.sh --usb --device-serial <adb devices 第一列序列号>
```

### Android：调试构建与 HTTP（简要）

- **Release 包**：Android 上明文 HTTP 仅允许少量本机相关 host（如 `localhost`、`127.0.0.1`、模拟器访问宿主机用的 `10.0.2.2`），公网服务应使用 **HTTPS**。
- **Debug / Profile 包**：工程内对 **RFC1918 私网 IP**（如 `192.168.x.x`）的 `http://` 在 Dart 校验与网络安全配置上放宽，便于 **Wi‑Fi 直连开发机**；上架与正式环境仍应使用 HTTPS。

### 应用启动图标维护

源文件位于 `app/assets/icons/`（`foreground.png`、`background.png`）。修改后重新生成各分辨率图标：

```bash
cd app
dart run flutter_launcher_icons
```

配置见 `app/pubspec.yaml` 中的 `flutter_launcher_icons`。重新安装 App 后才能在桌面看到新图标。

## API 端点

基础路径：`/api/v1`（与 OpenAPI 文档一致）。

### 任务与分析

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /health` | GET | 健康检查 |
| `POST /api/v1/tasks` | POST | 创建分析任务 |
| `GET /api/v1/tasks` | GET | 任务列表 |
| `GET /api/v1/tasks/{id}` | GET | 任务详情 |
| `DELETE /api/v1/tasks/{id}` | DELETE | 删除任务 |
| `GET /api/v1/tasks/{id}/report` | GET | 分析报告 |
| `GET /api/v1/tasks/{id}/posts` | GET | 原始帖子 |

### 订阅

| 端点 | 方法 | 说明 |
|------|------|------|
| `POST /api/v1/subscriptions` | POST | 创建订阅 |
| `GET /api/v1/subscriptions` | GET | 订阅列表 |
| `GET /api/v1/subscriptions/{id}` | GET | 订阅详情 |
| `PUT /api/v1/subscriptions/{id}` | PUT | 更新订阅 |
| `DELETE /api/v1/subscriptions/{id}` | DELETE | 删除订阅 |
| `GET /api/v1/subscriptions/{id}/tasks` | GET | 该订阅下的任务列表 |

### 热门关键词

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /api/v1/trending` | GET | 返回预设的热门关键词列表（后端占位接口，供前端后续接入） |

## 项目结构

```
TrendPulseNew/
├── backend/                    # Python 后端
│   ├── src/
│   │   ├── main.py            # FastAPI 入口
│   │   ├── config/settings.py # 统一配置
│   │   ├── models/            # 数据模型 + DB
│   │   ├── adapters/          # 外部 API 适配器
│   │   ├── services/          # 业务逻辑
│   │   └── api/endpoints/     # REST 端点
│   └── tests/                 # 后端测试
├── app/                        # Flutter 前端
│   ├── assets/
│   │   ├── icons/             # 启动图标源图（见「应用启动图标维护」）
│   │   └── fonts/             # 字体资源
│   ├── lib/
│   │   ├── core/              # 主题 + 网络 + 通用组件
│   │   └── features/          # 功能模块
│   │       ├── analysis/      # 分析仪表盘
│   │       ├── history/       # 历史记录
│   │       ├── subscription/  # 订阅（底部导航之一）
│   │       ├── detail/        # 任务详情（报告 / 原始数据）
│   │       ├── feed/          # 原始帖子数据访问（供详情等使用，非独立 Tab）
│   │       └── settings/      # 设置
│   └── test/                  # 前端测试
├── docs/                      # 演示 / 验收 / 补充文档
├── scripts/                   # 常用开发与验证脚本（如 dev-android.sh）
└── README.md
```

## 开发规范

- **Python**: 强制类型注解 + Google-style docstring + Black + Ruff + mypy
- **Flutter**: Feature-first 分层 + Riverpod 状态管理 + 统一状态处理
- **Git**: Conventional Commits (feat/fix/refactor/test/docs/chore)
- **安全**: API Key 通过环境变量管理，不得硬编码

## 测试

后端与前端均包含自动化测试；具体用例数以仓库内 `backend/tests/` 与 `app/test/` 为准。

演示/验收步骤见 `docs/demo-acceptance-runbook.md`。真实数据抓取演示通常需要在本机私有 `backend/.env` 中填写真实密钥；关键链路自动验证大多基于 mock / fake 测试，通常不依赖真实密钥。

```bash
# 后端测试
cd backend && python -m pytest tests/ -v

# 前端测试
cd app && flutter test

# 关键链路验收
scripts/verify-critical-paths.sh

# 仅验证后端
scripts/verify-critical-paths.sh --backend-only

# 仅验证 Flutter
scripts/verify-critical-paths.sh --flutter-only
```

## 许可证

MIT
