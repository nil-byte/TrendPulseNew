# TrendPulse 目标与范围

## 产品目标

**TrendPulse** 提供「关键词 → 多平台采集 → AI 舆情报告」的闭环能力：用户围绕单一主题发起分析或订阅，系统从 Reddit（官方 API）、YouTube（Data API 与字幕）、X（经 Grok / OpenAI 兼容 API）等来源拉取近期公开内容，清洗入库后由 LLM 产出情感得分、观点聚合、摘要与可选的 Mermaid 思维导图；Flutter 客户端用于仪表盘、历史、报告详情、源数据浏览与订阅监控。

## 范围与非目标

- **范围内**：任务与订阅生命周期、多源采集编排、降级与源可用性展示、本地 SQLite 持久化、REST API 与 OpenAPI 契约、Android 客户端（本仓库含 `app/android/`，不含 `app/ios/`）。
- **范围外（当前仓库不承诺）**：Docker/Compose 一键部署、根目录 SPDX `LICENSE` 文件、独立的「演示 runbook」文档；详细密钥与线上运维以各环境为准。
- **持续集成**：推送至 `main`/`master` 时由 `ci.yml` 跑后端测试与 Flutter **分包** debug/release，产物在 **Actions Artifacts**；打 `v*` 标签或手动运行 `release-apk.yml` 时在 **GitHub Releases** 仅挂 **release** APK。CI 下签名见 README。

## 相关文档

- 采集策略、AI Prompt 与实现侧问题（与代码对齐）：[`技术说明-采集策略与AI-Prompt.md`](技术说明-采集策略与AI-Prompt.md)
- X / Grok 接入与经验（演进背景；批计划细节以 `x_adapter` 与上文技术说明为准）：[`GROK_API_INTEGRATION_REPORT.md`](GROK_API_INTEGRATION_REPORT.md)
- 运行方式、架构与端点索引：仓库根目录 [`README.md`](../README.md)
