# TrendPulse

## 工程规范 (Engineering Standards)
1. **Python**: 
   - 强制使用类型注解 (Type Hints)；关键函数必须有 Docstring。
   - 使用 `Ruff` 进行 Lint，`Black` 进行格式化。
   - 严禁硬编码 API Key，必须从环境变量读取。
   - 使用统一 settings 配置。
   - 外部 API 调用必须走 adapter 层。
2. **Flutter**: 
   - 统一处理 Loading/Empty/Error 状态。
   - 页面跳转使用命令式路由或 go_router 命名路由。
   - feature-first + 分层结构
   - 页面、状态、数据访问分离
   - Widget 不直接写网络请求
3. **Git 提交 (Conventional Commits)**:
   - `feat`: 新功能；`fix`: 修复 Bug；`refactor`: 重构；`perf`: 性能优化；`docs`: 文档；`test`: 测试；`chore`: 其他；`build`: 构建；`ci`: 持续集成；`style`: 代码格式；`revert`: 回退。
   - 示例: `feat(api): add task priority queue`