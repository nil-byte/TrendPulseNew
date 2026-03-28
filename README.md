# TrendPulse - 多源舆情分析系统

输入关键词，自动从 Reddit、YouTube、X (Twitter) 抓取最新数据，通过 AI 生成舆情分析报告。

## 功能特性

- **多源采集**: Reddit (官方 API) + YouTube (Data API + 字幕) + X (Grok API)
- **AI 分析**: Map-Reduce 链式处理，情感分析 + 核心观点提取 + 热度指标
- **实时仪表盘**: 情感得分、热度指数、核心观点卡片、情感分布
- **历史记录**: 查看过往分析任务，支持删除
- **订阅监控**: 按关键词与周期创建订阅，自动拉取并生成任务
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
- Grok API Key (用于 X 数据采集)
- LLM API Key (OpenAI SDK 兼容，用于 AI 分析)

### 后端启动

```bash
cd backend
pip install -e ".[dev]"
cp .env.example .env
# 编辑 .env 填入 API Keys
uvicorn src.main:app --reload
```

API 文档: http://localhost:8000/docs

### 前端启动

```bash
cd app
flutter pub get
flutter run
```

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
└── README.md
```

## 开发规范

- **Python**: 强制类型注解 + Google-style docstring + Black + Ruff + mypy
- **Flutter**: Feature-first 分层 + Riverpod 状态管理 + 统一状态处理
- **Git**: Conventional Commits (feat/fix/refactor/test/docs/chore)
- **安全**: API Key 通过环境变量管理，不得硬编码

## 测试

后端与前端均包含自动化测试；具体用例数以仓库内 `backend/tests/` 与 `app/test/` 为准。

```bash
# 后端测试
cd backend && python -m pytest tests/ -v

# 前端测试
cd app && flutter test
```

## 许可证

MIT
