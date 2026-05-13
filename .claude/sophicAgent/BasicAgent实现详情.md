# BasicAgent实现详情

## 1. 说明

本文档用于整理 `BasicAgent` 的实现要点。  
当前内容聚焦两部分：

- 版本控制
- 配置信息及对象关系

其余如执行链、消息构建、工具递归调用、流式输出等，可在后续继续补充到本文档。

## 2. 类型定位

`BasicAgent` 在系统中不是独立实体，而是一种应用类型：

- `Application.type = AppType.BASIC`
- 序列化值为 `basic`

可理解为：

```text
BasicAgent = 一类 BASIC 应用
```

## 3. 相关对象

### 3.1 AppEntity

`AppEntity` 是应用主表实体，对应应用本身的元数据，主要保存：

- `appId`
- `workspaceId`
- `type`
- `status`
- `name`
- `description`
- `icon`
- `source`

另外还挂接两个运行时版本引用：

- `latestVersion`
- `publishedVersion`

`AppEntity` 不直接保存 `BasicAgent` 的完整配置。

### 3.2 AppVersionEntity

`AppVersionEntity` 是应用版本快照实体，用来保存某个应用某一版的配置。

核心含义：

- 一条记录对应一个版本
- `config` 字段保存该版本配置的 JSON 快照
- 所有历史版本都保存在版本表中

`latestVersion` 和 `publishedVersion` 只是 `AppEntity` 上的快捷引用，不代表版本表中只有两条记录。

### 3.3 AgentConfig

`AgentConfig` 是 `BASIC` 类型应用的配置模型。  
对于 `BasicAgent` 来说，`AppVersionEntity.config` 的内容会被反序列化为 `AgentConfig`。

它主要描述：

- 模型配置
- 提示词配置
- 记忆配置
- 知识库配置
- 工具与 MCP 配置
- agent/workflow 组件配置

## 4. 三者关系

三者关系可以概括为：

```text
AppEntity
  -> 表示“一个应用”
  -> 挂 latestVersion / publishedVersion

AppVersionEntity
  -> 表示“这个应用的某一个版本”
  -> config 保存版本配置 JSON

AgentConfig
  -> BASIC 应用版本配置 JSON 的 Java 结构
```

进一步看：

```text
AppEntity
  -> latestVersion : AppVersionEntity
  -> publishedVersion : AppVersionEntity

AppVersionEntity.config
  -> JSON
  -> AgentConfig
```

## 5. 配置读写关系

### 5.1 创建和保存

创建或更新 `BasicAgent` 时，配置会先进入应用层对象，再被序列化后写入版本表：

```text
Application.config
  -> JSON
  -> AppVersionEntity.config
```

因此，真正持久化保存 `BasicAgent` 配置的是版本表，而不是 `AppEntity`。

### 5.2 查询和组装

查询应用时，服务层会将版本表中的配置重新组装回运行时对象：

- `latestVersion.config` -> `Application.configStr`
- `publishedVersion.config` -> `Application.pubConfigStr`

### 5.3 执行时

执行 `BasicAgent` 时：

- 调试草稿时读取 `configStr`
- 正式调用时读取 `pubConfigStr`

之后再将 JSON 反序列化为 `AgentConfig`，交给 `BasicAgentExecutor` 使用：

```text
configStr / pubConfigStr
  -> AgentConfig
  -> BasicAgentExecutor
```

## 6. 版本控制

`BasicAgent` 是有版本控制的，但版本控制发生在应用服务层和版本表层，不在 `BasicAgentExecutor` 内。

### 6.1 初始版本

创建应用时会同时创建首个版本：

- 应用状态：`DRAFT`
- 初始版本号：`1`
- 版本状态：`DRAFT`

### 6.2 未发布状态编辑

如果应用尚未发布：

- 更新时直接修改当前 `latestVersion`
- 不新建版本

### 6.3 已发布状态编辑

如果应用已经发布：

- 不直接改已发布版本
- 复制 `publishedVersion` 生成新的草稿版本
- 版本号递增
- 新版本状态为 `DRAFT`
- 应用状态通常切换为 `PUBLISHED_EDITING`

### 6.4 发布

发布时：

- 取最新版本
- 做发布前校验
- 将该版本置为 `PUBLISHED`
- 更新应用状态
- 同时刷新：
  - `publishedVersion`
  - `latestVersion`

### 6.5 历史版本获取

历史版本不是丢弃的，而是全部保存在 `AppVersionEntity` 对应表中。

可支持：

- 查询某应用全部版本
- 查询最新版本
- 查询已发布版本
- 按版本号查询某一版

## 7. AgentConfig中的核心配置

`BasicAgent` 的能力主要通过 `AgentConfig` 挂载。

当前已确认的主要配置项包括：

- `modelProvider`
- `model`
- `instructions`
- `memory`
- `parameter`
- `tools`
- `mcpServers`
- `agentComponents`
- `workflowComponents`
- `promptVariables`
- `fileSearch`

这些配置决定 `BasicAgent` 的实际行为，例如：

- 使用哪个模型
- 是否保留多轮记忆
- 是否启用知识库检索
- 是否可调用插件工具
- 是否可调用 MCP 工具
- 是否挂载 agent/workflow 组件

## 8. 能力关联方式

从目前实现看，`BasicAgent` 与扩展能力的关联方式如下：

### 8.1 工具

- 配置来源：`AgentConfig.tools`
- 运行时形式：工具回调

### 8.2 MCP

- 配置来源：`AgentConfig.mcpServers`
- 运行时形式：工具回调

### 8.3 Agent组件

- 配置来源：`AgentConfig.agentComponents`
- 运行时形式：组件工具回调

### 8.4 Workflow组件

- 配置来源：`AgentConfig.workflowComponents`
- 运行时形式：组件工具回调

### 8.5 知识库

- 配置来源：`AgentConfig.fileSearch`
- 运行时形式：检索 advisor

### 8.6 记忆

- 配置来源：`AgentConfig.memory`
- 运行时形式：memory advisor

## 9. 当前结论

基于当前代码可以先得到以下结论：

- `BasicAgent` 本质上是 `BASIC` 类型应用
- `AppEntity` 表示应用主信息
- `AppVersionEntity` 表示应用版本快照
- `AgentConfig` 表示 `BasicAgent` 的具体配置结构
- `BasicAgent` 的版本控制由应用服务层和版本表共同完成
- `BasicAgentExecutor` 负责消费 `AgentConfig`，不负责版本管理本身

## 10. BasicAgentExecutor执行链

`BasicAgentExecutor` 是 `BasicAgent` 的核心执行器，负责将 `AgentConfig` 装配为可执行的模型调用链，并处理工具调用、知识库检索、记忆、流式输出等运行时行为。

### 10.1 入口

`BasicAgentExecutor` 不直接由控制器调用，而是由 `AgentServiceImpl` 按应用类型分发：

- `AppType.BASIC` -> `basicAgentExecutor.streamExecute(...)`
- `AppType.BASIC` -> `basicAgentExecutor.execute(...)`

在进入执行器之前，`AgentServiceImpl` 已完成：

- 读取应用配置
- 判断草稿态或发布态
- 反序列化为 `AgentConfig`
- 写入 `AgentContext`

因此执行器接收到的是已经准备好的运行时上下文。

### 10.2 主要涉及的类

执行链涉及的核心类包括：

- `AgentServiceImpl`
- `AgentContext`
- `AgentRequest`
- `AgentResponse`
- `BasicAgentExecutor`
- `AgentExecutor`
- `AgentConfig`
- `ModelFactory`
- `ChatClient`
- `ChatModel`
- `CompositeToolCallbackProvider`
- `ToolCallingManager`
- `ToolExecutionResult`
- `PluginToolCallback`
- `McpToolCallback`
- `AppComponentToolCallback`
- `MessageChatMemoryAdvisor`
- `KnowledgeBaseRetrievalAdvisor`

### 10.3 执行前装配

无论流式还是非流式，`BasicAgentExecutor` 都先完成以下准备工作：

1. 构建模型参数 `chatOptions`
2. 构建工具回调提供器 `toolCallbackProvider`
3. 构建消息列表 `messages`
4. 构建 `ChatClient`

整体过程如下：

```text
AgentConfig
  -> buildChatOptions(...)
  -> buildToolCallbackProvider(...)
  -> buildMessages(...)
  -> buildChatClient(...)
```

#### 10.3.1 buildChatOptions

该步骤负责将 `AgentConfig` 中的模型参数转换为模型调用参数，例如：

- `model`
- `maxTokens`
- `temperature`
- `topP`
- `repetitionPenalty`

#### 10.3.2 buildToolCallbackProvider

该步骤会根据 `AgentConfig` 中的能力配置，组装统一的工具回调提供器：

- `tools` -> `PluginToolCallback`
- `mcpServers` -> `McpToolCallback`
- `agentComponents` -> `AppComponentToolCallback(type=Agent)`
- `workflowComponents` -> `AppComponentToolCallback(type=Workflow)`

运行时这些能力会以 `ToolCallback[]` 的形式注入模型调用参数中。

#### 10.3.3 buildMessages

该步骤负责将业务层消息转换成模型消息。

主要处理三类角色：

- `SYSTEM`
- `USER`
- `ASSISTANT`

同时也会处理：

- 指令模板
- prompt variables
- 多模态消息

#### 10.3.4 buildChatClient

该步骤负责组装真正的模型客户端。

包含三类附加能力：

- 记忆
- 知识库检索
- 工具回调

具体表现为：

- 若开启记忆，则挂载 `MessageChatMemoryAdvisor`
- 若开启知识库检索，则挂载 `KnowledgeBaseRetrievalAdvisor`
- 若存在工具，则将 `ToolCallback[]` 写入 `chatOptions`

### 10.4 非流式执行链

非流式执行入口是：

- `BasicAgentExecutor.execute(...)`

流程如下：

```text
execute(...)
  -> buildChatOptions
  -> buildToolCallbackProvider
  -> buildMessages
  -> buildChatClient
  -> 调用模型
  -> 判断是否有 tool call
```

若没有 tool call：

- 直接调用 `convertResponse(...)`
- 转换为 `AgentResponse`

若有 tool call：

1. 调用 `ToolCallingManager.executeToolCalls(prompt, response)`
2. 获取工具执行后的 `conversationHistory`
3. 基于新的会话历史重新构造 `Prompt`
4. 再调用一次模型
5. 将工具调用和工具结果补入最终响应

因此非流式模式下，工具调用通常表现为“两段模型调用”：

```text
第一次模型调用
  -> 产生 tool call
  -> 执行工具
第二次模型调用
  -> 基于工具结果生成最终回答
```

### 10.5 流式执行链

流式执行入口是：

- `BasicAgentExecutor.streamExecute(...)`

它和非流式的区别在于，工具调用不会被整体折叠，而是通过递归逐段向前端输出。

核心方法是：

- `processToolCallsRecursively(...)`

其逻辑如下：

1. 先流式调用模型
2. 收到响应后判断是否包含 tool call
3. 如果没有 tool call
   - 直接转换为最终输出
4. 如果有 tool call
   - 先输出“模型发起工具调用”的响应
   - 再执行工具
   - 再输出“工具执行结果”的响应
   - 用新的 `conversationHistory` 重新构造 `Prompt`
   - 再次调用模型
   - 若新响应仍包含 tool call，则继续递归

可以表示为：

```text
LLM stream response
  -> tool call?
     -> no  -> final response
     -> yes -> output tool call
             -> execute tool
             -> output tool result
             -> rebuild prompt
             -> recall model
             -> recursive process
```

这也是 `BasicAgentExecutor` 中最关键的控制流程。

### 10.6 工具执行链

工具执行并不由 `BasicAgentExecutor` 直接硬编码实现，而是通过 `ToolCallingManager + ToolCallback` 体系完成。

关系如下：

```text
ToolCallingManager
  -> ToolCallback
     -> PluginToolCallback
     -> McpToolCallback
     -> AppComponentToolCallback
```

三类典型能力的实际落点为：

- 插件工具：`ToolExecutionService.callOpenApi(...)`
- MCP 工具：`McpServerService.callTool(...)`
- 组件工具：
  - agent 组件 -> `AppComponentManager.executeAgentComponent(...)`
  - workflow 组件 -> `AppComponentManager.executeWorkflowComponent(...)`

因此 `BasicAgentExecutor` 更像是“编排器”，不直接实现每种外部能力。

### 10.7 响应转换链

模型返回后，`BasicAgentExecutor` 还负责将 Spring AI 的响应结构转换为业务层响应。

核心包括：

- `convertResponse(...)`
- `convertToolCall(...)`
- `convertToolResult(...)`

主要转换内容有：

- 模型名称
- 输出文本
- reasoning content
- usage
- finishReason
- tool call 信息
- tool result 信息

最终统一转换为：

- `AgentResponse`

### 10.8 执行链总览

可以将 `BasicAgentExecutor` 的执行链概括为：

```text
AgentServiceImpl
  -> BasicAgentExecutor
     -> buildChatOptions
     -> buildToolCallbackProvider
     -> buildMessages
     -> buildChatClient
        -> memory advisor
        -> retrieval advisor
        -> tool callbacks
     -> call model
     -> tool calling recursive process
     -> convert response
     -> AgentResponse
```

从职责上看：

- `AgentServiceImpl` 负责准备上下文与类型分发
- `BasicAgentExecutor` 负责装配与执行
- `ToolCallingManager` 负责工具调用编排
- 各类 `ToolCallback` 负责真正落地执行

## 11. 后续可补充内容

本文档后续建议继续补充：

- 消息构建过程
- ChatClient 装配过程
- Tool calling 递归流程
- 流式与非流式调用差异
- 响应对象转换过程
