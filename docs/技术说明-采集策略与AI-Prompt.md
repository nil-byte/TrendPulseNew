# TrendPulse：采集策略、AI Prompt 与工程化处理说明

本文档依据当前仓库实现整理，对应后端主要路径：`backend/src/services/collector_service.py`、`backend/src/services/search_query_service.py`、`backend/src/services/analyzer_service.py`、`backend/src/adapters/*`、`backend/src/services/source_runtime_control.py`。

---

## 1. 采集策略总览

### 1.1 编排层（CollectorService）

- **并发**：对请求中每个有效数据源创建 `asyncio.Task`，用 `asyncio.gather(..., return_exceptions=True)` 并行采集，互不阻塞。
- **统一搜索词**：先调用 `SearchQueryService.build_search_query`，得到「本地化/改写后的搜索词」`search_query`；**各适配器收到的 keyword 均为该词**（Reddit、YouTube、X 一致），便于跨平台对齐语义。
- **单源上限**：`limit` 表示**每个已选源**最多返回的条数（`per_source_limit = limit`）。
- **失败语义**：
  - 不支持的数据源名 → `unsupported_source`，不发起采集。
  - 某一源抛错 → 归一化为 `SourceFailure`；若异常为 `PartialSourceCollectionError`，会**保留已拿到的 `partial_posts`** 并合并进总帖子列表，同时记录该源失败。
  - 成功/失败会通知 `source_availability_service`（`record_success` / `record_failure`），用于前端或上层感知可用性。

### 1.2 全局时间窗

- 配置项 `COLLECTION_RECENCY_HOURS`（默认 24 小时，上限 168）：**Reddit、X 等在拉到内容后按发布时间过滤**；与具体源的 API 参数（如 Reddit `time_filter="day"`）组合使用，保证「近期」一致。

### 1.3 搜索词本地化（SearchQueryService）

**目的**：用户关键词可能是英文而内容语言选中文（或相反），直接拿去各平台搜，召回质量差。

**策略**：

| 分支 | 行为 |
|------|------|
| 空关键词 | `status=empty`，query 为空 |
| 启发式已匹配目标语言（中英脚本计数） | `status=unchanged`，不调用 LLM |
| 未配置 `llm_api_key` / `llm_model` | `status=fallback`，**原样使用关键词** |
| LLM 调用失败或清洗后为空 | `status=fallback`，回退原关键词 |
| 成功 | `status=localized`，使用清洗后的单行查询 |

**实现要点**：系统/用户 Prompt 要求「只输出一条自然语言查询、无解释」；输出经去引号、取首行、压缩空白规范化。

---

## 2. 分源采集策略

### 2.1 Reddit（RedditAdapter）

- **API**：asyncpraw，搜索 `r/all`，`sort="new"`, `time_filter="day"`。
- ** oversample**：候选上限 `min(limit * 3, 250)`，在时间窗与语言过滤后再截断到 `limit`，提高有效条数概率。
- **语言**：与 X 相同的中英启发式（`_matches_target_language`），只丢弃**明显语言不对**的帖。
- **网络**：可选 HTTPS 代理、自定义 CA、`trust_env=False` 的独立 `ClientSession`，错误映射为稳定 `reason_code`（代理、SSL、超时等）。

### 2.2 YouTube（YouTubeAdapter）

- **流程**：Google Data API 搜索视频 → 按需拉字幕（`youtube_transcript_api`）→ 合成 `RawPost`（文本截断到配置的上限字符数）。
- **语言**：搜索与字幕语言偏好与请求的 `language` 对齐；字幕失败时仍可能产生无长文本的降级行为（详见适配器内日志与 `transcript_status`）。

### 2.3 X（Grok）（XAdapter）

模块注释中称为 **Triple-Helix** 思路（多「维度」并行采样）；**当前实现**是按 `limit` 与 `X_BATCH_SIZE`（默认 20，最大 20）**拆成多批**，每批带不同 **批次轮廓（profile）**：

- **仅一批**（`limit ≤ batch_size`）：单一 **「Balanced Mix」** 轮廓（均衡最新、权威、反向观点等）。
- **多批**：按序循环使用 **Balanced Mix / Authority / Dissent / Latest** 等轮廓，批名如 `Authority Batch 2`，并行度受 `X_PARALLEL_BATCHES` 限制。

**每批请求**：

- 使用 **OpenAI 兼容**的 `chat.completions.create`，`temperature=0.2`。
- **硬性 `stream=False`**：避免部分网关默认 SSE 导致 SDK 非流式解析异常（见下文「问题与解决方案」）。
- 在 `source_runtime_control.acquire_slot("x")` 内发起调用，与并发/token 节流、冷却逻辑配合。

**后处理**：

- 解析模型返回的 **JSON 数组** → `RawPost`（`source_id` 用推文 `id`）。
- **时间窗**：Prompt 要求 + 服务端 `_filter_posts_by_recency` 双保险。
- **语言**：`_filter_posts_by_language`（中英启发式）。
- **去重**：按 `source_id` 合并多批结果，再截取前 `limit` 条。
- **部分成功**：若部分批失败但已有帖子 → `PartialSourceCollectionError`，携带 `partial_posts`；全失败且无帖 → `SourceCollectionError`。

**重试**：对可恢复错误（限速、连接、超时、5xx）按 `X_RETRY_MAX_ATTEMPTS`、指数退避 + 抖动重试；不可恢复或超限则向上抛出。

---

## 3. AI Prompt 设计

### 3.1 搜索词改写（SearchQueryService）

- **System**：说明角色为「重写社交平台搜索关键词」；要求**仅一条**简洁查询；**目标自然语言**为 `{target_language}`；保留品牌/专名。
- **User**：原始关键词 + 目标内容语言；再次强调「只返回查询」。
- **参数**：`temperature=0.1`，`max_tokens=64`，偏确定、短输出。

### 3.2 X 采集（x_adapter）

- **System（结构化 XML 风格片段）**：
  - **角色**：Social Intelligence Analyst，从 X 抽取高信号、可代表某一 discourse 维度的数据。
  - **数据标准**：真实可验证；过滤spam/机器人/纯水贴；**仅输出合法 JSON 数组**。
  - **Schema**：字段 `id`, `username`, `content`, `perspective`, `created_at`, `engagement`, `url`。
- **User 模板**：注入关键词、目标语言、本批条数、**维度名称与 Search Focus**、当前 UTC、允许的时间窗、`recency_hours`；任务描述强调**多样性作者、具体细节**；**语言要求**；**时间要求**（窗外或时间无效则排除，不凑数）；最后一句要求生成 JSON 数组。

设计意图：**把「搜什么、要多少、哪类观点、语言、时间」全部结构化进 Prompt**，减少模型自由发挥；输出契约为 JSON 数组，便于程序化解析。

### 3.3 情感与分析（AnalyzerService）— Map-Reduce

**清洗（非 LLM）**：

- 过短、重复内容、启发式 spam（多链接、全大写比例异常、连续重复字符）剔除；正文截断到 500 字符。

**Map 阶段**：

- **System**：角色为情感分析专家；自然语言字段用 `{output_language}`（简体中文或 English）；**JSON key 保持英文**。
- 要求：每条帖情感（正/负/中）、观点；整体分数 0–100、分布计数、`key_opinions`、`post_sentiments`。
- **User**：枚举帖子，`[source]` 前缀 + 正文。
- 帖子按 **20 条** 分块，**每块一次 LLM**。

**本地聚合（Reduce 的数学后备）**：

- 按块情感计数与 `overall_score` 加权，得到全局比率与得分；从众包的 `key_opinions` 合并频率，取 Top 3 为 `KeyInsight`；并生成中英模板化 `summary`（无 LLM 也可用）。

**LLM Reduce 阶段**：

- **输入**：仅 **压缩后的 chunk 摘要**（`chunk_analyses`：每块分数、分类数、`key_opinions` 最多 5 条等）+ 聚合情感 + 候选洞察；**不附带原始帖全文**（省 token、减泄露面）。
- **System**：高级分析师；输出 JSON：`summary`、`key_insights`（最多 3 条、含 `source_count`）；要求可辩论、优先重复或对立观点；**禁止 Markdown 与 JSON 外多余文字**。
- **参数**：`temperature=0.2`，`max_tokens=1200`。
- **失败**：任一异常或校验失败 → **回退到本地聚合结果**；`raw_analysis` 中记录 `reduce_llm_succeeded` 等诊断字段。

**Mindmap**：在终稿 summary + insights 上生成 Mermaid mindmap 字符串，标签做 sanitize 以兼容 Mermaid 语法。

---

## 4. 遇到的问题与解决方案（实现侧）

| 问题 | 原因/表现 | 解决方案（代码位置） |
|------|-----------|----------------------|
| Grok/网关默认流式响应 | 省略 `stream` 时返回 SSE，SDK 按非流解析出错 | **`stream=False`** 强制 JSON completions（`x_adapter._query_shard`） |
| 兼容网关返回体嵌套 | 某些代理把 OpenAI 体包在 `data`/`result`/`response` 里 | **`_unwrap_relay_envelope`** 剥一层（`x_adapter`） |
| `choices` 为空或非标准 | 错误网关或错误端点 | 抛出 **`grok_provider_incompatible`**，提示检查 `/v1/chat/completions` 与 `GROK_BASE_URL` 以 `/v1` 结尾（`_INCOMPATIBLE_MESSAGE`） |
| 推理模型「正文」在别处 | `content` 为空但 `reasoning_content`/`reasoning` 有字 | **`_text_from_message_dict`** 多字段兜底（`x_adapter`；`llm_adapter` 对 `</redacted_thinking>` 截断） |
| Provider 返回业务错误 JSON | HTTP 200 但 body 内 `error` | **`_source_error_from_provider_payload`** 归类为限速或通用 `grok_provider_error` |
| 分析模型输出非纯净 JSON | 夹杂 Markdown 围栏或前后废话 | **`_extract_json_object`**：去 ```json 围栏、截取首尾 `{}`（`analyzer_service`） |
| Map 阶段 JSON 仍解析失败 | 模型偶发截断/格式错 | **中性 fallback**：50 分、全 `neutral`、空观点（`_parse_llm_json`） |
| Reduce 阶段失败或无效 | 网络/解析/`key_insights` 为空 | **丢弃 Reduce 输出，使用本地聚合**的 summary/insights（`_run_reduce_llm`） |
| X 多批一侧失败 | 单批限速或超时 | **部分成功**：`PartialSourceCollectionError` + `partial_posts`；全败无帖再抛 `SourceCollectionError` |
| 连续可恢复失败打爆接口 | 重试风暴 | **`SourceRuntimeControlService`**：信号量、`X_FAILURE_THRESHOLD` + `X_COOLDOWN_SECONDS` 冷却；与 `source_availability_service` 联动展示 cooldown |
| 官方 xAI 与自建兼容端混用 | `GROK_BASE_URL` 与模式不一致 | **`Settings.validate_grok_provider_configuration`**：`official_xai` 强制官方 URL；否则必须 `openai_compatible` + 合法 http(s) URL |
| 搜索词改写无 LLM | 开发/测试环境未配 key | **启发式跳过 + `llm_not_configured` 回退原词**，不阻断采集 |

---

## 5. 关键环境变量（便于对照）

| 变量（示例） | 用途 |
|--------------|------|
| `COLLECTION_RECENCY_HOURS` | 各源发布时间窗（小时） |
| `X_BATCH_SIZE` / `X_PARALLEL_BATCHES` | X 单批条数与并行批数 |
| `X_RETRY_*` / `X_FAILURE_THRESHOLD` / `X_COOLDOWN_SECONDS` | X 重试与冷却 |
| `GROK_*` | X 采集端点、模型、超时、provider 模式 |
| `LLM_*`（或等价分析用 key/url/model） | 搜索改写 + Map-Reduce 分析 |

---

## 6. 文档与代码一致性说明

- `x_adapter` 文件头注释中的 **「Pulse / Core / Noise」** 命名与当前 `_BATCH_PROFILES` 中的 **Balanced / Authority / Dissent / Latest** 字面名不完全相同；**行为以批计划与 Prompt 中注入的 `dimension_name` / `dimension_focus` 为准**。
- 若产品文档需统一对外术语，建议在后续迭代中要么改注释对齐实现，要么恢复三轴固定命名并在 `dimension_*` 中映射。

