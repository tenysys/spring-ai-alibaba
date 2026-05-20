# data-agent-service 提示词及变量实现清单

## 1. 目标

在 `I:\java\workplace\data-agent-service\basic-agent` 上补齐 `instructions` 与 `prompt_variables` 能力，使其具备与 `spring-ai-alibaba-admin` 中 `BasicAgent` 一致的核心行为：

- 支持在智能体配置中定义 `instructions`
- 支持在智能体配置中声明 `prompt_variables`
- 支持变量默认值
- 支持请求时覆盖变量
- 请求只能覆盖已声明变量
- 支持知识增强场景的延迟渲染
- 支持发布态快照保存和草稿态编辑恢复

本文只聚焦提示词和变量能力，不展开模型、记忆、工具、完整执行链的全部实现。

## 2. 现状结论

### 2.1 admin 模块已有能力

`spring-ai-alibaba-admin` 已实现运行时提示词处理，关键逻辑如下：

- `buildMessages()` 在执行前装配 system message
- `buildInstructions()` 负责：
  - 读取 `config.instructions`
  - 读取 `config.promptVariables`
  - 组装默认变量值
  - 用 `request.promptVariables` 覆盖默认值
  - 删除空白变量
  - 普通场景直接用 `SystemPromptTemplate` 渲染
  - 文件检索场景先缓存变量，再延迟到 RAG advisor 渲染
- RAG 场景要求模板中必须包含 `{documents}`

参考位置：

- [BasicAgentExecutor.java](/I:/java/workplace/spring-ai-alibaba/spring-ai-alibaba-admin/spring-ai-alibaba-admin-server-core/src/main/java/com/alibaba/cloud/ai/studio/core/agent/BasicAgentExecutor.java:316)
- [BasicAgentExecutor.java](/I:/java/workplace/spring-ai-alibaba/spring-ai-alibaba-admin/spring-ai-alibaba-admin-server-core/src/main/java/com/alibaba/cloud/ai/studio/core/agent/BasicAgentExecutor.java:353)
- [KnowledgeBaseRetrievalAdvisor.java](/I:/java/workplace/spring-ai-alibaba/spring-ai-alibaba-admin/spring-ai-alibaba-admin-server-core/src/main/java/com/alibaba/cloud/ai/studio/core/rag/advisor/KnowledgeBaseRetrievalAdvisor.java:136)

### 2.2 data-agent-service/basic-agent 当前状态

`data-agent-service/basic-agent` 当前只实现了：

- 应用管理
- 版本管理
- 发布
- 发布快照
- 从发布快照恢复草稿配置

当前并没有：

- `AgentConfig` 配置模型
- `AgentRequest / AgentResponse / AgentContext`
- `BasicAgentExecutor`
- `instructions` 渲染逻辑
- `prompt_variables` 合并逻辑
- RAG 延迟渲染逻辑

当前 `config` 只是一个原始 JSON 字符串：

- 保存时原样写入版本表
- 发布时被包进 `AgentVersionSnapshot.config`
- 草稿恢复时再原样取出

参考位置：

- [AgentAppVersionSaveRequest.java](/I:/java/workplace/data-agent-service/basic-agent/src/main/java/com/nrec/service/basicagent/model/request/AgentAppVersionSaveRequest.java:32)
- [AgentAppVersionServiceImpl.java](/I:/java/workplace/data-agent-service/basic-agent/src/main/java/com/nrec/service/basicagent/service/app/impl/AgentAppVersionServiceImpl.java:153)
- [AgentVersionSnapshotServiceImpl.java](/I:/java/workplace/data-agent-service/basic-agent/src/main/java/com/nrec/service/basicagent/service/snapshot/impl/AgentVersionSnapshotServiceImpl.java:35)

## 3. 设计原则

- 配置管理与运行时渲染分离
- 草稿态和发布态统一围绕 `AgentConfig` 工作
- 发布快照保留完整可运行配置
- 请求侧变量只允许覆盖配置中已声明变量
- 提示词渲染过程可独立封装，避免散落在 controller/service 中
- 优先兼容现有 `config` 字符串保存模式，避免一次性重构版本体系

## 4. 建议目标结构

### 4.1 配置模型

建议新增运行时配置对象：

`com.nrec.service.basicagent.model.config.AgentConfig`

建议至少包含：

- `String modelProvider`
- `String model`
- `String instructions`
- `Parameter parameter`
- `Memory memory`
- `List<PromptVariable> promptVariables`
- `KnowledgeConfig knowledgeConfig`

其中 `PromptVariable` 建议结构：

- `String name`
- `String type`
- `String description`
- `String defaultValue`

说明：

- 版本表中的 `config` 仍然存 JSON 字符串
- 但应用层和运行时层都应把这段 JSON 映射为 `AgentConfig`

### 4.2 运行协议

建议补齐：

- `AgentRequest`
- `AgentResponse`
- `AgentContext`
- `ChatMessage`

至少需要为提示词能力提供：

- `AgentRequest.promptVariables`
- `AgentContext.config`
- `AgentContext.promptVariables`

## 5. 提示词能力拆分

### 5.1 配置层

职责：

- 在草稿配置中保存 `instructions`
- 在草稿配置中保存 `prompt_variables`
- 发布时将其一并固化到快照的 `config`
- 草稿恢复时完整恢复

结论：

- 这一层基本沿用当前 `config` JSON 机制即可
- 不需要为 `instructions` 或 `prompt_variables` 单独建表

### 5.2 运行时解析层

建议新增：

- `PromptVariableResolver`
- `PromptTemplateService`

职责拆分：

`PromptVariableResolver`

- 读取 `AgentConfig.promptVariables`
- 生成默认变量 map
- 合并 `AgentRequest.promptVariables`
- 拒绝未声明变量覆盖
- 删除空值/空白值

`PromptTemplateService`

- 根据 `instructions` 和变量 map 生成最终 system prompt
- 普通场景立即渲染
- 知识增强场景支持延迟渲染

## 6. 需要复用 admin 的具体行为

### 6.1 普通场景

行为要求：

- `instructions` 作为模板
- `prompt_variables.defaultValue` 作为默认变量值
- 请求变量覆盖默认值
- 使用模板引擎渲染为最终 system prompt

建议直接对齐 admin 逻辑：

1. 先构造 `Map<String, Object> resolvedVariables`
2. 遍历 `config.promptVariables` 写入默认值
3. 遍历 `request.promptVariables` 进行覆盖
4. 只允许覆盖已声明变量
5. 删除空白值
6. 用 `SystemPromptTemplate(instructions).createMessage(resolvedVariables)` 渲染

### 6.2 知识增强场景

行为要求：

- 若启用知识增强，不应过早渲染 system prompt
- 应先保留原始 `instructions`
- 检索出文档后再与 `{documents}` 和 `promptVariables` 一起渲染

建议直接对齐 admin 逻辑：

1. 在执行器构建 instructions 时仅保存 `context.promptVariables`
2. 返回未渲染的 system message
3. 在知识增强 advisor 中：
   - 注入 `{documents}`
   - 合并 `context.promptVariables`
   - 强校验模板中存在 `{documents}`
   - 重新生成最终 system message

## 7. 建议新增类清单

建议最小新增如下：

- `com.nrec.service.basicagent.model.config.AgentConfig`
- `com.nrec.service.basicagent.model.request.AgentRequest`
- `com.nrec.service.basicagent.model.response.AgentResponse`
- `com.nrec.service.basicagent.model.runtime.AgentContext`
- `com.nrec.service.basicagent.service.prompt.PromptVariableResolver`
- `com.nrec.service.basicagent.service.prompt.PromptTemplateService`
- `com.nrec.service.basicagent.executor.BasicAgentExecutor`

如果一期不做完整执行链，至少也应先补：

- `AgentConfig`
- `PromptVariableResolver`
- `PromptTemplateService`

## 8. 对现有 basic-agent 模块的改造点

### 8.1 配置存储改造

改造目标：

- 继续保留 `AgentAppVersionEntity.config` 为字符串
- 但新增统一解析入口，把字符串转为 `AgentConfig`

建议新增方法：

- `AgentConfig parseConfig(String configJson)`
- `String serializeConfig(AgentConfig config)`

建议位置：

- `basic-agent` 模块内新增 `AgentConfigMapper` 或 `AgentConfigCodec`

### 8.2 快照服务改造

当前 [AgentVersionSnapshotServiceImpl.java](/I:/java/workplace/data-agent-service/basic-agent/src/main/java/com/nrec/service/basicagent/service/snapshot/impl/AgentVersionSnapshotServiceImpl.java:35) 已将 `editableConfig` 原样放入 `snapshot.config`。

这里对提示词能力的要求是：

- 不改变现有行为
- 确保 `instructions` 与 `prompt_variables` 在 `config` 内完整保存
- 确保 `extractEditableConfig()` 可原样恢复

结论：

- 快照服务无需为提示词单独扩展字段
- 只需保证 `config` 中的 `AgentConfig` 是稳定结构

### 8.3 版本接口改造

现有接口：

- `/api/basic-agents/versions/update`
- `/api/basic-agents/version/access`

建议前端/调用方在 `config` JSON 中显式传入：

- `instructions`
- `promptVariables`

建议示例：

```json
{
  "instructions": "你是一个数据分析助手。当前租户是 {tenant_name}。",
  "promptVariables": [
    {
      "name": "tenant_name",
      "type": "string",
      "description": "租户名称",
      "defaultValue": "默认租户"
    }
  ]
}
```

## 9. 运行时实现清单

### 9.1 AgentConfig

- 新增 `AgentConfig` 类
- 新增 `PromptVariable` 内部类或独立类
- 为 `instructions`、`promptVariables`、`knowledgeConfig` 定义稳定字段名
- 保证 Jackson 可序列化/反序列化

### 9.2 AgentRequest

- 新增 `promptVariables: Map<String, String>`
- 支持后续扩展 `messages`、`conversationId`、`stream`

### 9.3 AgentContext

- 新增 `config: AgentConfig`
- 新增 `request: AgentRequest`
- 新增 `promptVariables: Map<String, Object>`

### 9.4 PromptVariableResolver

- 实现 `resolveDeclaredVariables(AgentConfig, AgentRequest)`
- 默认值装载
- 请求值覆盖
- 拒绝未声明变量
- 删除空值
- 返回 `Map<String, Object>`

### 9.5 PromptTemplateService

- 实现 `renderInstructions(String instructions, Map<String, Object> variables)`
- 内部统一使用模板渲染能力
- 后续可扩展 `renderInstructionsWithDocuments(...)`

### 9.6 BasicAgentExecutor

- 新增 `buildMessages()`
- 新增 `buildInstructions()`
- system message 优先由 `config.instructions` 生成
- 对齐 admin 的 prompt 变量处理流程

### 9.7 知识增强

- 若当前一期已接知识库，新增 advisor/增强器
- 支持 `{documents}` 延迟注入
- 缺失 `{documents}` 时明确报错

## 10. 实现顺序建议

### 一期最小闭环

1. 新增 `AgentConfig`
2. 统一 `config JSON <-> AgentConfig` 编解码
3. 新增 `AgentRequest / AgentContext`
4. 新增 `PromptVariableResolver`
5. 新增 `PromptTemplateService`
6. 新增最小版 `BasicAgentExecutor`
7. 支持普通场景的 `instructions` 渲染
8. 支持请求覆盖已声明变量

### 二期增强

1. 知识增强延迟渲染
2. `{documents}` 校验
3. Prompt 构建日志
4. Prompt 审计与调试信息输出

## 11. 验收标准

### 11.1 配置保存

- 草稿配置可保存 `instructions`
- 草稿配置可保存 `promptVariables`
- 发布后快照中保留这两部分内容
- 从发布版本切换回草稿时内容不丢失

### 11.2 变量渲染

- 仅声明变量可被覆盖
- 未声明变量不会进入渲染结果
- 空值变量会被过滤
- 普通场景能正确渲染 system prompt

### 11.3 知识增强

- 开启知识增强时支持 `{documents}` 注入
- 模板缺失 `{documents}` 时抛出明确错误

## 12. 需要重点避免的问题

- 不要把 `prompt_variables` 设计成请求可任意注入的新变量
- 不要把运行时变量解析逻辑继续塞在 controller 或版本 service 中
- 不要在发布快照里拆散保存 `instructions` 和变量定义，保持仍由 `config` 承载
- 不要在知识增强场景过早渲染 `instructions`

## 13. 最终建议

对 `data-agent-service/basic-agent` 的正确补齐方式不是直接修改现有版本管理逻辑，而是：

- 保留现有版本快照体系
- 把 `instructions` 和 `prompt_variables` 纳入统一 `AgentConfig`
- 新增运行时 prompt 解析与渲染层
- 对齐 `spring-ai-alibaba-admin` 的三个关键行为：
  - 已声明变量覆盖
  - 空值过滤
  - `{documents}` 延迟注入

这样改动最小，也最容易和后续 `BasicAgentExecutor`、知识增强、记忆能力接轨。
