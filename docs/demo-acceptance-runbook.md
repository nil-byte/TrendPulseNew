# TrendPulse 演示与验收 Runbook

本文件用于答辩演示、联调自检和提交前验收，聚焦当前最影响评分与稳定性的主链路。

## 1. 演示前准备

- 复制 `backend/.env.example` 为本机私有的 `backend/.env`，只在本机填写真实密钥。
- 确认 `backend/.env` 中至少配置了 `GROK_PROVIDER_MODE`、`GROK_API_KEY`、`YOUTUBE_API_KEY`、`REDDIT_CLIENT_ID`、`REDDIT_CLIENT_SECRET`、`LLM_API_KEY`。
- 确认 `backend/.env` 中 `DEBUG=false`；仅在本机排障时临时改为 `true`。
- 若 `GROK_PROVIDER_MODE=openai_compatible`，额外确认 `GROK_BASE_URL` 与 `GROK_MODEL` 已改为目标兼容端点的实际值。
- 只有“真实抓取 + 实时演示”链路需要上述真实密钥；`scripts/verify-critical-paths.sh` 主要运行 mock / fake 驱动的自动化测试，通常不依赖真实密钥。
- Android 真机或模拟器演示前，先确保后端 `GET /health` 返回 `{"status":"ok"}`。
- 如需一键拉起 Android 演示环境，使用 `scripts/dev-android.sh`。
- 若用浏览器调试（如 Flutter Web），后端默认只放行 `localhost` / `127.0.0.1` 本地源；如需额外域名请在 `backend/.env` 中补 `CORS_ALLOWED_ORIGINS`。
- 若本地 SQLite 数据因当前开发阶段的结构重构而不再兼容，直接删除 `backend/trendpulse.db` 后重启后端，让初始化逻辑重新建库即可。

## 2. 推荐演示顺序

### A. 基础分析链路

1. 在分析页输入关键词并发起任务。
2. 等待任务进入 `collecting` / `analyzing`，说明状态机可见。
3. 打开任务详情页，展示 `Report` 与 `Raw Data` 两个页签。
4. 在 `Raw Data` 页签切换来源筛选，确认原始帖子可查看、可跳转原文。

### B. 订阅低分告警链路

1. 创建一个开启 `Enable low-score alerts` 的订阅。
2. 执行 `Run Now`，或等待调度器触发订阅任务。
3. 当某次订阅任务 `sentiment_score < 30` 时，确认：
   - 订阅列表卡片出现未读告警角标。
   - 订阅执行历史页顶部出现负面告警横幅。
   - 点击横幅可直接进入对应任务详情。
4. 返回订阅页，确认未读告警会在读取后消失。

### C. Mermaid 思维导图链路

1. 打开已完成的任务详情页。
2. 在 `Report` 页签中确认存在“思维导图”区块。
3. 展示导图根节点、摘要分支、关键洞察分支以及情绪/来源节点。
4. 说明后端接口 `GET /api/v1/tasks/{id}/report` 会返回 `mermaid_mindmap` 字段。
5. 补充说明：当前只支持后端 `build_mermaid_mindmap()` 产出的 `mindmap` 子集；如果收到其他 Mermaid 语法，页面会显示降级提示并保留原始 Mermaid 文本。

## 3. 验收清单

- [ ] 仓库文档、示例配置和设置默认值中不存在真实 API Key。
- [ ] `backend/.env.example` 仅包含占位符或空值，并明确禁止提交真实密钥。
- [ ] Grok 默认仍指向官方 xAI 配置，切换第三方兼容端点时必须显式设置 `GROK_PROVIDER_MODE=openai_compatible`。
- [ ] 低分订阅任务会写入未读告警，并能在 App 内可见。
- [ ] 负面告警横幅可直达对应任务详情。
- [ ] 分析报告接口返回 `mermaid_mindmap`。
- [ ] Flutter 报告页可以渲染 Mermaid 思维导图卡片。

## 4. 自动验证

运行：

```bash
# 前端/后端静态检查
cd backend && python -m ruff check .
cd app && flutter analyze

# 自动化回归
scripts/verify-critical-paths.sh

# 仅验证后端
scripts/verify-critical-paths.sh --backend-only

# 仅验证 Flutter
scripts/verify-critical-paths.sh --flutter-only
```

该脚本会覆盖：

- Grok / 配置文档安全护栏测试
- 验证脚本参数与依赖预检回归测试
- 分析页拆分后的展示、可用性、搜索刷新与错误处理测试
- 订阅列表角标与低分告警创建/读取测试
- 任务创建与订阅手动执行 API 契约测试
- Mermaid 生成与报告接口契约测试
- Flutter 订阅告警页与报告页渲染测试

补充说明：

- 标准本机环境（已安装 Python + Flutter）可直接跑完整脚本。
- 若机器暂时缺少某一侧依赖，脚本会先给出明确提示，而不是在中途掉 `command not found`。

## 5. 人工抽查建议

- 使用一个明显负向的话题词，验证低分告警更容易复现。
- 切换中英文任务各做一次，确认摘要与思维导图文案随语言变化。
- 若刚做过结构性重构，先清理本地旧库再抽查详情页与思维导图链路，避免把开发期旧数据兼容问题误判为功能回归。
