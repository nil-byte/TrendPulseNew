# Grok (xAI) API 实时 X 数据采集集成经验报告 (V11.0)

> **与当前代码的关系**：早期实验曾采用固定「每批 15 条、三路并行」的 **Triple-Helix** 叙事。**当前仓库实现**见 `backend/src/adapters/x_adapter.py`：按 `limit` 与 **`X_BATCH_SIZE`**（默认 **20**）拆批；单批仅用 **Balanced Mix**；多批时按 **Balanced / Authority / Dissent / Latest** 循环注入维度；并行度受 **`X_PARALLEL_BATCHES`** 与运行时控流约束。细节以 [`技术说明-采集策略与AI-Prompt.md`](技术说明-采集策略与AI-Prompt.md) 为准。

## 1. 背景与目标
项目中原有的 `twscrape` 采集方案依赖于模拟登录和账号池，面临极高的风控风险（429 限流、账号封禁、验证挑战）。
**核心目标**：利用 Grok API 的原生实时 X 搜索能力，构建一个稳定、高质量、具备语义多样性的 X 数据采集器；任务侧常见上限为数十条量级（例如 **50** 条唯一推文），由 API `limit` 与批配置共同决定。

---

## 2. 核心瓶颈与“第一性原理”分析
在早期测试（V3.0 - V6.0）中，我们发现**单次**索要大量结构化 JSON 存在典型瓶颈：
1.  **内部工具限制**：`x_search` 单次有效规模有限；一次要满配额容易触发模型内多轮推理与超时。
2.  **推理疲劳与截断**：长 JSON 输出尾部易被截断或损坏。
3.  **幸存者偏差**：单一查询容易只剩高互动复读内容，缺少质疑与反向观点。

**第一性原理结论**：将 Grok 定位为**情报侦察官**而非搬运工；采用**分而治之**——**多批、每批控制在 `X_BATCH_SIZE` 以内**（当前默认 **20**），并为各批注入**不同语义维度**，再在后端按 `id` 去重合并。

---

## 3. 方案演进：当前批计划 + Triple-Helix 由来

### 3.1 当前实现（与代码一致）

| 场景 | 行为 |
|------|------|
| `limit ≤ X_BATCH_SIZE` | **一批**：维度名为 **Balanced Mix**，条数 = `limit`。 |
| `limit > X_BATCH_SIZE` | **多批**：总条数拆成若干批（每批 ≤ `X_BATCH_SIZE`）；批名如 `Authority Batch 2`；轮廓按 **Balanced Mix → Authority → Dissent → Latest** 循环。 |
| 并行 | `asyncio.gather` 发起各批 Grok 请求，并行上限由 **`X_PARALLEL_BATCHES`** 与 **`source_runtime_control`** 槽位约束。 |
| 鲁棒性 | **`stream=False`**、`temperature=0.2`；可恢复错误走重试；部分批失败且已有帖 → `PartialSourceCollectionError`。 |

早期为便于产品沟通，曾把三条典型维度口语化为 **Pulse（时效）/ Core（权威）/ Noise（分歧）**；**现行轮廓字面名**见上表（与源码 `_BATCH_PROFILES` 一致）。

### 3.2 历史叙事：三位一体螺旋（Triple-Helix）

下面三段描述的是**同一设计思想在不同时期的命名**，供对照旧文档；**不要**当作当前固定三路、每路 15 条的硬编码契约。

1.  **Pulse（脉搏）**：偏最新原发与短时窗。
2.  **Core（核心）**：偏高互动、权威定调。
3.  **Noise（分歧）**：偏质疑、风险与非主流技术观点。

---

## 4. 生产级提示词（与 `x_adapter` 对齐）

系统侧与仓库内 `_SYSTEM_PROMPT` 一致。用户侧模板在代码中为 `_USER_PROMPT_TEMPLATE`，核心占位包括：`keyword`、`target_language`、`shard_limit`（即本批条数）、`dimension_name`、`dimension_focus`、时间窗与 `recency_hours`。

### 系统提示词 (System Prompt)
```xml
<role>
You are a Social Intelligence Analyst. Your goal is to extract a high-signal dataset from X that accurately represents a specific dimension of public discourse.
</role>

<data_standard>
1. AUTHENTICITY: Every tweet must be a real, verifiable post from X.
2. SELECTIVITY: Filter out spam, bots, self-promotional links, and repetitive low-value phrases.
3. STRUCTURE: Output ONLY a valid JSON array.
</data_standard>

<schema>
[
  {
    "id": "str",
    "username": "str",
    "content": "str",
    "perspective": "Short tag: e.g., 'Technical', 'Market', 'Skeptical', 'Bullish'",
    "created_at": "ISO8601",
    "engagement": int,
    "url": "str"
  }
]
</schema>
```

### 用户提示词模板（逻辑结构；条数以 `shard_limit` 注入）
```xml
<context>
Keyword: "{keyword}"
Target language: {target_language}
Target: {shard_limit} items
Dimension: {dimension_name}
Search Focus: {dimension_focus}
Current UTC time: {current_utc}
Allowed post window: {window_start} to {current_utc}
</context>

<task>
Analyze the X search space for the above keyword.
Identify {shard_limit} unique, high-signal tweets that best represent the assigned 'Dimension'.
Prioritize variety in authors and specific, detailed content over generic reactions.
</task>

<!-- 代码中还包含 language_requirement、time_requirement 与 instruction 末句 Generate JSON array of {shard_limit} objects -->
```

---

## 5. 调用配置与 SDK 实战

### 基础信息
*   **Provider Mode**: `official_xai`（默认） / `openai_compatible`（显式开启第三方 OpenAI SDK 兼容端点）
*   **Base URL**: `https://api.x.ai/v1`
*   **API Key**: 仅通过环境变量 `GROK_API_KEY` 注入；仓库文档与示例文件只保留占位符或空值，禁止提交真实值
*   **Model**: `grok-4.20-reasoning` (当前规范默认值)

### 推荐配置策略
*   **默认官方模式**：`GROK_PROVIDER_MODE=official_xai`，沿用官方 `https://api.x.ai/v1` 与默认模型。
*   **兼容端点模式**：仅当需要切换第三方 OpenAI SDK 兼容 Grok 端点时，显式设置 `GROK_PROVIDER_MODE=openai_compatible`，并同步覆盖 `GROK_BASE_URL` / `GROK_MODEL`。
*   **显式优于隐式**：不要只改 `GROK_BASE_URL` 而不声明模式，否则容易让“官方默认”和“兼容覆盖”语义混淆。

### 与仓库一致的整合思路（伪代码）
```python
# 1. 客户端：设置见 src.config.settings（grok_*、X_BATCH_SIZE、X_PARALLEL_BATCHES 等）
client = AsyncOpenAI(
    api_key=settings.grok_api_key,
    base_url=settings.grok_base_url,
    timeout=settings.grok_http_timeout_seconds,
)

# 2. 剥离推理标签：仓库在 llm_adapter / x_adapter 侧处理 </redacted_thinking> 等

# 3. 批计划：按 limit 与 x_batch_size 得到 [(dimension_name, focus, shard_limit), ...]
#    再 asyncio.gather 各批 _query_shard（内层有槽位、重试、stream=False）

# 4. 后端：按 source_id 去重，时间窗与语言过滤见 x_adapter
```

---

## 6. 实验效果评估

以下为**多小批 + 分维度**策略在联调阶段的观测，**具体条数与耗时会随 `limit`、`X_BATCH_SIZE` 与话题热度变化**；保留作风险与收益定性参考。

*   **并发耗时**：约 **70s - 230s**（取决于话题热度和模型推理深度）。
*   **数据达成率**：在控制单批规模后，**唯一帖规模**较单次大 JSON 更稳定（历史窗口内曾观测约 **30–45** 条量级，仅供参考）。
*   **语义多样性**：分维度批能分别强化「最新 / 权威共识 / 质疑与风险」等信号；现行四轮廓在 **Authority / Dissent / Latest** 上与上述目标对应。
*   **稳定性**：缩小单批输出规模，显著降低网关截断与整批 JSON 损坏概率。

---

## 7. 经验贴士 (Lessons Learned)
1.  **别让它猜**：在 Prompt 中明确 `Dimension`（维度）与 **Search Focus**，减少模型泛泛而谈。
2.  **温度控制**：设置 **`temperature=0.2`**。过低易重复，过高易破坏 JSON 结构。
3.  **防御机制**：避免指令注入式措辞；用角色与数据标准引导合规输出。
4.  **去重逻辑**：必须在 Python 后端根据 **`id`（`source_id`）** 再次去重；多批在高热话题下仍可能重叠。
5.  **流式响应**：对 X 采集请求使用 **`stream=False`**，避免部分网关默认 SSE 导致非流式 JSON 解析失败。
